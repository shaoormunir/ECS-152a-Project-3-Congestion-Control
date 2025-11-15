#!/bin/bash
# Unified test script for students to test their sender implementation
# Usage: ./test_sender.sh <your_sender.py>

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print section headers
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Check if sender file is provided
if [ $# -eq 0 ]; then
    print_error "No sender file specified"
    echo "Usage: ./test_sender.sh <your_sender.py>"
    echo "Example: ./test_sender.sh my_tcp_tahoe.py"
    exit 1
fi

SENDER_FILE=$1

# Check if sender file exists
if [ ! -f "$SENDER_FILE" ]; then
    print_error "Sender file '$SENDER_FILE' not found"
    exit 1
fi

print_header "ECS 152A - Testing Your Sender Implementation"
print_info "Sender file: $SENDER_FILE"

# Pre-flight checks
print_header "Step 1/5: Pre-flight Checks"

# Check if Docker is installed
print_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    echo "Please install Docker first. See SETUP.md for instructions."
    exit 1
fi
print_success "Docker is installed"

# Check if Docker daemon is running
print_info "Checking if Docker daemon is running..."
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    echo "Please start Docker Desktop (macOS/Windows) or Docker service (Linux)"
    exit 1
fi
print_success "Docker daemon is running"

# Check if container exists
print_info "Checking if simulator container exists..."
if ! docker ps -a --format '{{.Names}}' | grep -q '^ecs152a-simulator$'; then
    print_warning "Simulator container not found"
    print_info "Starting simulator for the first time..."
    ./start-simulator.sh > /dev/null 2>&1 &
    SIMULATOR_PID=$!
    sleep 5
else
    # Container exists, check if it's running
    if ! docker ps --format '{{.Names}}' | grep -q '^ecs152a-simulator$'; then
        print_warning "Simulator container exists but is not running"
        print_info "Starting simulator..."
        docker start ecs152a-simulator > /dev/null
        sleep 3
    else
        print_info "Simulator container is already running"
    fi
fi

# Restart receiver to reset state
print_header "Step 2/5: Preparing Test Environment"
print_info "Restarting receiver to reset state..."
docker restart ecs152a-simulator > /dev/null 2>&1
sleep 3
print_success "Receiver restarted and ready"

# Copy sender file into container
print_info "Copying your sender file into container..."
docker cp "$SENDER_FILE" ecs152a-simulator:/app/sender.py 2>&1 | grep -v "deprecated" || true
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    print_error "Failed to copy sender file into container"
    exit 1
fi
print_success "Sender file copied"

# Ensure test file is in container
print_info "Copying test file (file.mp3) into container..."
if [ -f "file.mp3" ]; then
    docker cp file.mp3 ecs152a-simulator:/hdd/ > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "Failed to copy test file into container"
        exit 1
    fi
elif [ -f "hdd/file.mp3" ]; then
    docker cp hdd/file.mp3 ecs152a-simulator:/hdd/ > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "Failed to copy test file into container"
        exit 1
    fi
else
    print_error "Test file (file.mp3) not found in docker/ or docker/hdd/"
    exit 1
fi
print_success "Test file ready"

# Remove old output file if exists
docker exec ecs152a-simulator rm -f /hdd/file2.mp3 2>/dev/null || true

# Run the sender
print_header "Step 3/3: Running Your Sender"
print_info "Executing your sender implementation..."
echo ""

# Capture both stdout and the exit code
set +e  # Don't exit on error for this command
SENDER_OUTPUT=$(docker exec ecs152a-simulator python3 /app/sender.py 2>&1)
SENDER_EXIT_CODE=$?
set -e

echo "$SENDER_OUTPUT"
echo ""

if [ $SENDER_EXIT_CODE -ne 0 ]; then
    print_error "Sender exited with error code $SENDER_EXIT_CODE"
    print_warning "Check the output above for error messages"
    exit 1
fi

# Parse and display metrics
print_header "Performance Metrics"

# Extract metrics from sender output (assuming CSV format: throughput,delay,jitter,score)
METRICS_LINE=$(echo "$SENDER_OUTPUT" | grep -E '^[0-9]+\.?[0-9]*,[0-9]+\.?[0-9]*,[0-9]+\.?[0-9]*,[0-9]+\.?[0-9]*$' | tail -n 1)

if [ -n "$METRICS_LINE" ]; then
    IFS=',' read -r THROUGHPUT AVG_DELAY AVG_JITTER SCORE <<< "$METRICS_LINE"

    echo "Results:"
    echo "  Throughput:  ${THROUGHPUT} bytes/sec"
    echo "  Avg Delay:   ${AVG_DELAY} ms"
    echo "  Avg Jitter:  ${AVG_JITTER} ms"
    echo "  Score:       ${SCORE}"
    echo ""

    print_success "Test completed successfully!"
else
    print_warning "Could not parse metrics. Make sure your sender prints: throughput,delay,jitter,score"
fi
echo ""
