<#
.SYNOPSIS
    Собирает и публикует артефакты sandbox (backend/frontend) в Nexus raw hosted-репозитории.

.DESCRIPTION
    Скрипт:
      1. Читает переменные из .env (или из окружения).
      2. Упаковывает артефакты в artifacts/sandbox-backend-<version>.tar.gz
         и artifacts/sandbox-frontend-<version>.tar.gz.
      3. Загружает их в Nexus по пути:
         <NEXUS_REPO_URL>/repository/<repo>/<version>/<file>-<version>.tar.gz
      4. Проверяет загрузку скачиванием и сравнением SHA256.

.PARAMETER Version
    Версия артефакта. По умолчанию берётся из $env:VERSION или 1.0.0.

.PARAMETER EnvFile
    Путь к .env относительно корня репозитория. По умолчанию .env.

.PARAMETER ArtifactsDir
    Каталог для собранных архивов. По умолчанию artifacts.

.PARAMETER SkipUpload
    Только собрать архивы, ничего не загружать.

.PARAMETER SkipVerify
    Не проверять загрузку скачиванием.

.PARAMETER Insecure
    Не проверять TLS-сертификат Nexus (curl -k). Только для лабораторного стенда.

.EXAMPLE
    .\scripts\publish-artifacts.ps1 -Version 1.0.0

.EXAMPLE
    .\scripts\publish-artifacts.ps1 -Version 1.0.0 -SkipUpload
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Version,
    [string]$EnvFile = ".env",
    [string]$ArtifactsDir = "artifacts",
    [switch]$SkipUpload,
    [switch]$SkipVerify,
    [switch]$Insecure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot      = Split-Path -Parent $PSScriptRoot
$EnvPath       = Join-Path $RepoRoot $EnvFile
$ArtifactsPath = Join-Path $RepoRoot $ArtifactsDir
$BackendSource = Join-Path $RepoRoot "src/backend"
$FrontendDist  = Join-Path $RepoRoot "src/frontend/dist"

function Import-DotEnv {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "  .env не найден: $Path (использую переменные окружения)"
        return
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }

        $separator = $line.IndexOf("=")
        if ($separator -lt 1) { return }

        $key = $line.Substring(0, $separator).Trim()
        $value = $line.Substring($separator + 1).Trim()

        if ($value.Length -ge 2) {
            $isDoubleQuoted = $value.StartsWith('"') -and $value.EndsWith('"')
            $isSingleQuoted = $value.StartsWith("'") -and $value.EndsWith("'")
            if ($isDoubleQuoted -or $isSingleQuoted) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        # Переменные окружения имеют приоритет над .env
        if (-not [Environment]::GetEnvironmentVariable($key, "Process")) {
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
}

function Get-CurlPath {
    $curlExe = Get-Command "curl.exe" -CommandType Application -ErrorAction SilentlyContinue
    if ($curlExe) { return $curlExe.Source }

    $curl = Get-Command "curl" -CommandType Application -ErrorAction SilentlyContinue
    if ($curl) { return $curl.Source }

    throw "curl не найден. Установите curl или запустите скрипт на Linux."
}

function Assert-RequiredEnv {
    $missing = @(
        "NEXUS_REPO_URL",
        "NEXUS_REPO_BACKEND_NAME",
        "NEXUS_REPO_FRONTEND_NAME",
        "NEXUS_REPO_USER",
        "NEXUS_REPO_PASS"
    ) | Where-Object { -not [Environment]::GetEnvironmentVariable($_, "Process") }

    if ($missing) {
        throw "Не заданы переменные: $($missing -join ', '). Добавьте их в .env или в переменные окружения."
    }
}

function New-ArtifactArchive {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$Entry
    )

    $archive = Join-Path $ArtifactsPath "$Name-$Version.tar.gz"
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }

    & tar -czf $archive -C $SourceDir $Entry
    if ($LASTEXITCODE -ne 0) {
        throw "tar завершился с ошибкой ($LASTEXITCODE) при создании $archive"
    }

    $sizeMb = [math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 2)
    Write-Host ("  создан {0} ({1} MB)" -f (Split-Path -Leaf $archive), $sizeMb)

    return $archive
}

function Get-NexusUrl {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$FilePath
    )

    $base = $env:NEXUS_REPO_URL.TrimEnd("/")
    $fileName = Split-Path -Leaf $FilePath
    return "$base/repository/$Repository/$Version/$fileName"
}

function Invoke-Curl {
    param([Parameter(Mandatory)][string[]]$Arguments)

    if ($Insecure) {
        $Arguments = @("-k") + $Arguments
    }

    & $script:Curl @Arguments
    return $LASTEXITCODE
}

function Publish-Artifact {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$FilePath
    )

    $url = Get-NexusUrl -Repository $Repository -FilePath $FilePath
    $exitCode = Invoke-Curl -Arguments @(
        "--fail",
        "--silent",
        "--show-error",
        "--user", "$($env:NEXUS_REPO_USER):$($env:NEXUS_REPO_PASS)",
        "--upload-file", $FilePath,
        $url
    )

    if ($exitCode -ne 0) {
        throw "Не удалось загрузить $FilePath (curl exit code $exitCode): $url"
    }

    Write-Host "  загружен $url"
}

function Test-Artifact {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$FilePath
    )

    $url = Get-NexusUrl -Repository $Repository -FilePath $FilePath
    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-" + [guid]::NewGuid().ToString("N") + ".tar.gz")

    try {
        $exitCode = Invoke-Curl -Arguments @(
            "--fail",
            "--location",
            "--silent",
            "--show-error",
            "--user", "$($env:NEXUS_REPO_USER):$($env:NEXUS_REPO_PASS)",
            "--output", $tempFile,
            $url
        )

        if ($exitCode -ne 0) {
            throw "Не удалось скачать $url (curl exit code $exitCode)"
        }

        $localHash  = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash
        $remoteHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash

        if ($localHash -ne $remoteHash) {
            throw "SHA256 не совпадает для $url"
        }

        Write-Host "  проверен $url (SHA256 $($localHash.Substring(0, 12))...)"
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}

# --- main ---------------------------------------------------------------

Write-Host "==> Корень репозитория: $RepoRoot"
Import-DotEnv -Path $EnvPath

if (-not $Version) {
    $Version = if ($env:VERSION) { $env:VERSION } else { "1.0.0" }
}

if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') {
    throw "Недопустимая версия '$Version'. Разрешены латиница, цифры, точка, дефис и подчёркивание."
}

$backendBinary = Join-Path $BackendSource "app"
$frontendIndex = Join-Path $FrontendDist "index.html"

if (-not (Test-Path -LiteralPath $backendBinary)) {
    throw "Не найден backend-артефакт: $backendBinary. Сначала соберите backend (lab1)."
}
if (-not (Test-Path -LiteralPath $frontendIndex)) {
    throw "Не найдена frontend-сборка: $frontendIndex. Сначала выполните npm run build (lab1)."
}

New-Item -ItemType Directory -Force -Path $ArtifactsPath | Out-Null

Write-Host "==> Упаковка версии $Version"
$backendArchive = New-ArtifactArchive -Name "sandbox-backend" -SourceDir $BackendSource -Entry "app"
if ($env:OS -eq "Windows_NT") {
    Write-Host "  примечание: tar на Windows не хранит бит исполнения; после распаковки на Linux выполните chmod +x app"
}

$stagingPath = Join-Path $ArtifactsPath "site"
if (Test-Path -LiteralPath $stagingPath) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
}

try {
    Copy-Item -LiteralPath $FrontendDist -Destination $stagingPath -Recurse -Force
    $frontendArchive = New-ArtifactArchive -Name "sandbox-frontend" -SourceDir $ArtifactsPath -Entry "site"
}
finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
}

if ($SkipUpload) {
    Write-Host "==> Загрузка пропущена (-SkipUpload)"
    Write-Host "==> Готово: $backendArchive, $frontendArchive"
    return
}

Assert-RequiredEnv
$script:Curl = Get-CurlPath

Write-Host "==> Загрузка в Nexus"
Publish-Artifact -Repository $env:NEXUS_REPO_BACKEND_NAME  -FilePath $backendArchive
Publish-Artifact -Repository $env:NEXUS_REPO_FRONTEND_NAME -FilePath $frontendArchive

if (-not $SkipVerify) {
    Write-Host "==> Проверка скачиванием"
    Test-Artifact -Repository $env:NEXUS_REPO_BACKEND_NAME  -FilePath $backendArchive
    Test-Artifact -Repository $env:NEXUS_REPO_FRONTEND_NAME -FilePath $frontendArchive
}

Write-Host ""
Write-Host "==> Готово. Версия $Version опубликована:"
Write-Host "    $(Get-NexusUrl -Repository $env:NEXUS_REPO_BACKEND_NAME  -FilePath $backendArchive)"
Write-Host "    $(Get-NexusUrl -Repository $env:NEXUS_REPO_FRONTEND_NAME -FilePath $frontendArchive)"
