package dependencies

import (
	"context"
	"os"
	"strconv"

	"gitlab.praktikum-services.ru/Stasyan/momo-store/internal/store/orders"
	"gitlab.praktikum-services.ru/Stasyan/momo-store/internal/store/orders/postgres"
)

// NewOrdersStore returns orders store if database integration is enabled, otherwise nil
func NewOrdersStore(ctx context.Context) (orders.Store, error) {
	enabled, _ := strconv.ParseBool(os.Getenv("DB_ENABLED"))
	if !enabled {
		return nil, nil
	}

	store, err := postgres.New(ctx, postgres.Config{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnv("DB_PORT", "5432"),
		User:     getEnv("DB_USER", "postgres"),
		Password: os.Getenv("DB_PASSWORD"),
		DBName:   getEnv("DB_NAME", "postgres"),
		SSLMode:  getEnv("DB_SSLMODE", "disable"),
	})
	if err != nil {
		return nil, err
	}

	return store, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
