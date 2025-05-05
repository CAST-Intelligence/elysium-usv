# Project Preferences and Configuration

## Package Management
- Always use UV for Python package management instead of pip

## Build Commands
- Go build: `go build -o bin/usvpipeline ./cmd/usvpipeline`
- Run app: `./bin/usvpipeline`
- Local dev: `./tools/local-dev.sh [setup|build|run|reset]`
- Test S3 etag: `python tools/test_s3_etag.py`
- Test Azurite: `go run tools/test_azurite.go`

## Code Style Preferences
- Go: Standard library imports first, then third-party (alphabetized)
- Indentation: 4 spaces
- Naming: PascalCase for exported, camelCase for unexported
- Error handling: Check immediately, wrap with context
- Comments: Document all public functions and complex logic
- Concurrency: Proper context handling and cancelation

## Codebase Structure Notes
- cmd/: Entry points
- internal/: Core application logic
- tools/: Development utilities
- Environment-based configuration via config package