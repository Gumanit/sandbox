package postgres

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
)

// Config represents PostgreSQL connection settings
type Config struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// Store is a PostgreSQL implementation of orders store
type Store struct {
	db *sql.DB
}

// New returns new PostgreSQL orders store and checks connection
func New(ctx context.Context, cfg Config) (*Store, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("cannot open database: %w", err)
	}

	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("cannot connect to database: %w", err)
	}

	if _, err := db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS orders (
		id BIGSERIAL PRIMARY KEY,
		order_id BIGINT NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("cannot create orders table: %w", err)
	}

	return &Store{db: db}, nil
}

// SaveOrder saves order into database
func (s *Store) SaveOrder(ctx context.Context, orderID int64) error {
	_, err := s.db.ExecContext(ctx, "INSERT INTO orders (order_id) VALUES ($1)", orderID)
	return err
}

// Close closes database connection
func (s *Store) Close() error {
	return s.db.Close()
}
