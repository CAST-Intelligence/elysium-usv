#\!/bin/bash
# Script to create the management group structure for Elysium USV

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default variables
PREFIX="USV-"
LOCATION="australiaeast"
VERBOSE=false
WAIT_TIME=5 # seconds to wait between management group creations

# Function to display usage
usage() {
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  -p, --prefix PREFIX      Resource name prefix (default: USV-TEST-)"
  echo -e "  -l, --location LOCATION  Azure region for deployment (default: australiaeast)"
  echo -e "  -w, --wait SECONDS       Wait time between MG creations in seconds (default: 5)"
  echo -e "  -v, --verbose            Enable verbose output"
  echo -e "  -h, --help               Show this help message"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -p|--prefix)
      PREFIX="$2"
      shift 2
      ;;
    -l|--location)
      LOCATION="$2"
      shift 2
      ;;
    -w|--wait)
      WAIT_TIME="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
  esac
done

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  
  case $level in
    "INFO")
      echo -e "${BLUE}[INFO] $message${NC}"
      ;;
    "SUCCESS")
      echo -e "${GREEN}[SUCCESS] $message${NC}"
      ;;
    "WARN")
      echo -e "${YELLOW}[WARNING] $message${NC}"
      ;;
    "ERROR")
      echo -e "${RED}[ERROR] $message${NC}"
      ;;
  esac
}

# Function to create a management group with error handling and wait
create_management_group() {
  local name="$1"
  local display_name="$2"
  local parent_reference="$3"
  
  if [[ "$VERBOSE" == true ]]; then
    log "INFO" "Creating management group: $name (Display: $display_name)"
    if [[ -n "$parent_reference" ]]; then
      log "INFO" "Parent: $parent_reference"
    fi
  fi
  
  # Check if management group already exists
  if az account management-group show --name "$name" &>/dev/null; then
    log "WARN" "Management group '$name' already exists. Skipping creation."
    return 0
  fi
  
  # Prepare the command
  local cmd="az account management-group create --name \"$name\" --display-name \"$display_name\""
  
  if [[ -n "$parent_reference" ]]; then
    cmd="$cmd --parent \"$parent_reference\""
  fi
  
  # Execute the command
  if [[ "$VERBOSE" == true ]]; then
    log "INFO" "Executing: $cmd"
  fi
  
  if eval "$cmd"; then
    log "SUCCESS" "Management group '$name' created successfully."
    # Wait to ensure Azure backend consistency
    if [[ "$WAIT_TIME" -gt 0 ]]; then
      if [[ "$VERBOSE" == true ]]; then
        log "INFO" "Waiting ${WAIT_TIME}s for Azure backend consistency..."
      fi
      sleep "$WAIT_TIME"
    fi
    return 0
  else
    log "ERROR" "Failed to create management group '$name'."
    return 1
  fi
}

# Start creating the management group structure
log "INFO" "Starting to create management group structure with prefix: $PREFIX"

# Level 0: Root management group
ROOT_MG="${PREFIX}ROOT"
create_management_group "$ROOT_MG" "USV Test Root"

# Level 1: Elysium management group
ELYSIUM_MG="${PREFIX}ELYSIUM"
create_management_group "$ELYSIUM_MG" "USV Test Elysium" "$ROOT_MG"

# Level 2: Environment and shared management groups
PROD_MG="${PREFIX}PROD"
TEST_MG="${PREFIX}TEST"
SHARED_MG="${PREFIX}SHARED"

create_management_group "$PROD_MG" "USV Test Production" "$ELYSIUM_MG"
create_management_group "$TEST_MG" "USV Test Environment" "$ELYSIUM_MG"
create_management_group "$SHARED_MG" "USV Test Shared" "$ELYSIUM_MG"

# Level 3: Production environment management groups
PROD_INFRA_MG="${PREFIX}PROD-INFRA"
PROD_APP_MG="${PREFIX}PROD-APP"
PROD_DATA_MG="${PREFIX}PROD-DATA"

create_management_group "$PROD_INFRA_MG" "USV Test Production Infrastructure" "$PROD_MG"
create_management_group "$PROD_APP_MG" "USV Test Production Application" "$PROD_MG"
create_management_group "$PROD_DATA_MG" "USV Test Production Data" "$PROD_MG"

# Level 3: Test environment management groups
TEST_INFRA_MG="${PREFIX}TEST-INFRA"
TEST_APP_MG="${PREFIX}TEST-APP"
TEST_DATA_MG="${PREFIX}TEST-DATA"

create_management_group "$TEST_INFRA_MG" "USV Test Environment Infrastructure" "$TEST_MG"
create_management_group "$TEST_APP_MG" "USV Test Environment Application" "$TEST_MG"
create_management_group "$TEST_DATA_MG" "USV Test Environment Data" "$TEST_MG"

# Level 3: Shared management groups
MONITOR_MG="${PREFIX}MONITOR"
SECURITY_MG="${PREFIX}SECURITY"

create_management_group "$MONITOR_MG" "USV Test Monitoring" "$SHARED_MG"
create_management_group "$SECURITY_MG" "USV Test Security" "$SHARED_MG"

# Get the current subscription and move it to the test management group
log "INFO" "Moving current subscription to test management group..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  if az account management-group subscription add --name "$TEST_MG" --subscription "$SUBSCRIPTION_ID"; then
    log "SUCCESS" "Subscription $SUBSCRIPTION_ID moved to $TEST_MG successfully."
  else
    log "ERROR" "Failed to move subscription to $TEST_MG."
  fi
else
  log "ERROR" "Could not determine current subscription ID."
fi

log "SUCCESS" "Management group structure created successfully\!"
echo
echo -e "${BLUE}Management Group Structure:${NC}"
echo -e "  ┌─ ${GREEN}$ROOT_MG${NC} (Root)"
echo -e "  └─┬─ ${GREEN}$ELYSIUM_MG${NC} (Elysium)"
echo -e "    ├─┬─ ${GREEN}$PROD_MG${NC} (Production)"
echo -e "    │ ├─── ${GREEN}$PROD_INFRA_MG${NC} (Infrastructure)"
echo -e "    │ ├─── ${GREEN}$PROD_APP_MG${NC} (Application)"
echo -e "    │ └─── ${GREEN}$PROD_DATA_MG${NC} (Data)"
echo -e "    ├─┬─ ${GREEN}$TEST_MG${NC} (Test)"
echo -e "    │ ├─── ${GREEN}$TEST_INFRA_MG${NC} (Infrastructure)"
echo -e "    │ ├─── ${GREEN}$TEST_APP_MG${NC} (Application)"
echo -e "    │ └─── ${GREEN}$TEST_DATA_MG${NC} (Data)"
echo -e "    └─┬─ ${GREEN}$SHARED_MG${NC} (Shared)"
echo -e "      ├─── ${GREEN}$MONITOR_MG${NC} (Monitoring)"
echo -e "      └─── ${GREEN}$SECURITY_MG${NC} (Security)"
EOF < /dev/null