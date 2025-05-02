package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/CAST-Intelligence/elysium-usv/internal/config"
)

// WorkerStatus interface for objects that can report status
type WorkerStatus interface {
	Status() string
	LastRun() time.Time
}

// Global status trackers
var (
	validationWorker WorkerStatus
	transferWorker   WorkerStatus
	cleanupWorker    WorkerStatus
)

// New creates a new HTTP server with the given configuration
func New(cfg *config.Config) *http.Server {
	// Create a new router
	mux := http.NewServeMux()

	// Register routes
	registerRoutes(mux)

	// Create and return the server
	return &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      mux,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  120 * time.Second,
	}
}

// RegisterWorkerStatusEndpoints registers worker status objects with the server
func RegisterWorkerStatusEndpoints(srv *http.Server, vw, tw, cw WorkerStatus) {
	validationWorker = vw
	transferWorker = tw
	cleanupWorker = cw
}

// registerRoutes registers the HTTP routes
func registerRoutes(mux *http.ServeMux) {
	// Health check endpoint
	mux.HandleFunc("/health", healthHandler)

	// Metrics endpoint
	mux.HandleFunc("/metrics", metricsHandler)

	// Version endpoint
	mux.HandleFunc("/version", versionHandler)

	// API routes
	mux.HandleFunc("/api/v1/status", statusHandler)
	mux.HandleFunc("/api/v1/workers", workersHandler)
}

// healthHandler handles health check requests
func healthHandler(w http.ResponseWriter, r *http.Request) {
	// Check worker health
	isHealthy := true
	if validationWorker != nil && transferWorker != nil && cleanupWorker != nil {
		// If any worker has "error" in its status, consider the system unhealthy
		for _, worker := range []WorkerStatus{validationWorker, transferWorker, cleanupWorker} {
			if status := worker.Status(); len(status) >= 5 && status[:5] == "error" {
				isHealthy = false
				break
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	if isHealthy {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy"}`))
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"status":"unhealthy"}`))
	}
}

// metricsHandler handles metrics requests
func metricsHandler(w http.ResponseWriter, r *http.Request) {
	// This would be expanded to include real metrics
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"metrics":{"workers":3,"processed":0}}`))
}

// versionHandler returns the application version
func versionHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"version":"0.1.0"}`))
}

// statusHandler returns the pipeline status
func statusHandler(w http.ResponseWriter, r *http.Request) {
	// Create a dynamic status response based on actual worker status
	status := map[string]interface{}{
		"pipeline_status": map[string]interface{}{
			"validation_worker": getWorkerStatus(validationWorker),
			"transfer_worker":   getWorkerStatus(transferWorker),
			"cleanup_worker":    getWorkerStatus(cleanupWorker),
			"last_validated":    formatLastRun(validationWorker),
			"last_transferred":  formatLastRun(transferWorker),
			"last_cleaned":      formatLastRun(cleanupWorker),
		},
	}

	// Marshal to JSON
	jsonData, err := json.Marshal(status)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(jsonData)
}

// workersHandler returns detailed worker status
func workersHandler(w http.ResponseWriter, r *http.Request) {
	workers := map[string]interface{}{
		"workers": map[string]interface{}{
			"validation": map[string]string{
				"status":   getWorkerStatus(validationWorker),
				"last_run": formatLastRun(validationWorker),
			},
			"transfer": map[string]string{
				"status":   getWorkerStatus(transferWorker),
				"last_run": formatLastRun(transferWorker),
			},
			"cleanup": map[string]string{
				"status":   getWorkerStatus(cleanupWorker),
				"last_run": formatLastRun(cleanupWorker),
			},
		},
	}

	// Marshal to JSON
	jsonData, err := json.Marshal(workers)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(jsonData)
}

// Helper functions
func getWorkerStatus(w WorkerStatus) string {
	if w == nil {
		return "not_initialized"
	}
	return w.Status()
}

func formatLastRun(w WorkerStatus) string {
	if w == nil {
		return "never"
	}
	lastRun := w.LastRun()
	if lastRun.IsZero() {
		return "never"
	}
	return lastRun.Format(time.RFC3339)
}