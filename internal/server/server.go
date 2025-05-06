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
	ftpWorker        WorkerStatus
	additionalWorkers []WorkerStatus
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
func RegisterWorkerStatusEndpoints(srv *http.Server, workers ...WorkerStatus) {
	// Clear additionalWorkers slice
	additionalWorkers = nil
	
	// Ensure we have at least the three main workers
	if len(workers) >= 3 {
		validationWorker = workers[0]
		transferWorker = workers[1]
		cleanupWorker = workers[2]
		
		// If there's an FTP worker (4th worker), register it
		if len(workers) >= 4 {
			ftpWorker = workers[3]
		}
		
		// Register any additional workers beyond the standard ones
		if len(workers) > 4 {
			additionalWorkers = workers[4:]
		}
	} else {
		// Handle the case where we have fewer than 3 workers
		for i, w := range workers {
			switch i {
			case 0:
				validationWorker = w
			case 1:
				transferWorker = w
			case 2:
				cleanupWorker = w
			}
		}
	}
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
		// Create a list of all active workers
		workers := []WorkerStatus{validationWorker, transferWorker, cleanupWorker}
		if ftpWorker != nil {
			workers = append(workers, ftpWorker)
		}
		workers = append(workers, additionalWorkers...)
		
		// If any worker has "error" in its status, consider the system unhealthy
		for _, worker := range workers {
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
	pipelineStatus := map[string]interface{}{
		"validation_worker": getWorkerStatus(validationWorker),
		"transfer_worker":   getWorkerStatus(transferWorker),
		"cleanup_worker":    getWorkerStatus(cleanupWorker),
		"last_validated":    formatLastRun(validationWorker),
		"last_transferred":  formatLastRun(transferWorker),
		"last_cleaned":      formatLastRun(cleanupWorker),
	}
	
	// Add FTP worker status if available
	if ftpWorker != nil {
		pipelineStatus["ftp_worker"] = getWorkerStatus(ftpWorker)
		pipelineStatus["last_ftp_check"] = formatLastRun(ftpWorker)
	}
	
	status := map[string]interface{}{
		"pipeline_status": pipelineStatus,
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
	workersMap := map[string]interface{}{
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
	}
	
	// Add FTP worker if available
	if ftpWorker != nil {
		workersMap["ftp"] = map[string]string{
			"status":   getWorkerStatus(ftpWorker),
			"last_run": formatLastRun(ftpWorker),
		}
	}
	
	workers := map[string]interface{}{
		"workers": workersMap,
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