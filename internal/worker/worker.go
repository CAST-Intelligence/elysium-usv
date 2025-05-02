package worker

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// Worker represents a background worker that processes tasks
type Worker struct {
	name       string
	processFn  ProcessFunc
	interval   time.Duration
	batchSize  int
	retryCount int
	ctx        context.Context
	cancel     context.CancelFunc
	wg         sync.WaitGroup
	status     string
	lastRun    time.Time
	mu         sync.RWMutex
}

// ProcessFunc is a function that processes a batch of work
type ProcessFunc func(ctx context.Context, batchSize int) error

// NewWorker creates a new worker with the given name and processing function
func NewWorker(name string, processFn ProcessFunc, interval time.Duration, batchSize, retryCount int) *Worker {
	ctx, cancel := context.WithCancel(context.Background())
	return &Worker{
		name:       name,
		processFn:  processFn,
		interval:   interval,
		batchSize:  batchSize,
		retryCount: retryCount,
		ctx:        ctx,
		cancel:     cancel,
		status:     "stopped",
		lastRun:    time.Time{},
	}
}

// Start starts the worker
func (w *Worker) Start() {
	w.mu.Lock()
	w.status = "running"
	w.mu.Unlock()

	w.wg.Add(1)
	go func() {
		defer w.wg.Done()
		w.run()
	}()
	log.Printf("Worker %s started", w.name)
}

// Stop stops the worker
func (w *Worker) Stop() {
	w.cancel()
	w.wg.Wait()
	w.mu.Lock()
	w.status = "stopped"
	w.mu.Unlock()
	log.Printf("Worker %s stopped", w.name)
}

// Status returns the current status of the worker
func (w *Worker) Status() string {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return w.status
}

// LastRun returns the time of the last run
func (w *Worker) LastRun() time.Time {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return w.lastRun
}

// run is the main worker loop
func (w *Worker) run() {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	// Process immediately on start
	w.process()

	for {
		select {
		case <-ticker.C:
			w.process()
		case <-w.ctx.Done():
			return
		}
	}
}

// process executes the processing function with retry logic
func (w *Worker) process() {
	for attempt := 0; attempt < w.retryCount; attempt++ {
		err := w.processFn(w.ctx, w.batchSize)
		
		// Update the last run time
		w.mu.Lock()
		w.lastRun = time.Now()
		w.mu.Unlock()
		
		if err == nil {
			// Success, break the retry loop
			return
		}
		
		// Log the error and retry
		log.Printf("Worker %s error (attempt %d/%d): %v", w.name, attempt+1, w.retryCount, err)
		
		// If this was the last attempt, update status to error
		if attempt == w.retryCount-1 {
			w.mu.Lock()
			w.status = fmt.Sprintf("error: %v", err)
			w.mu.Unlock()
			return
		}
		
		// Wait before retrying, with exponential backoff
		backoff := time.Duration(attempt+1) * time.Second
		time.Sleep(backoff)
	}
}