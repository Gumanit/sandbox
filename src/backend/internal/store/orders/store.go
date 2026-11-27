package orders

import (
	"context"
)

// Store represents abstract orders store
type Store interface {
	// SaveOrder stores new order into store
	SaveOrder(ctx context.Context, orderID int64) error
	// Close closes store
	Close() error
}
