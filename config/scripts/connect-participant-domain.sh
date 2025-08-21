#!/bin/bash

# Canton Participant-Domain Connection Script
# This script automates the connection of participants to domains
# and performs basic network setup tasks.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANTON_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-config/canton-single-participant.conf}"
PARTICIPANT_NAME="${PARTICIPANT_NAME:-participant1}"
DOMAIN_NAME="${DOMAIN_NAME:-mydomain}"
CONNECTION_TIMEOUT="${CONNECTION_TIMEOUT:-30}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Connects Canton participant to domain and performs network setup.

Environment Variables:
  CONFIG_FILE        Canton configuration file (default: config/canton-single-participant.conf)
  PARTICIPANT_NAME   Participant name (default: participant1)
  DOMAIN_NAME        Domain name (default: mydomain)
  CONNECTION_TIMEOUT Connection timeout in seconds (default: 30)

Options:
  -h, --help         Show this help message
  -c, --config FILE  Specify configuration file
  -p, --participant  Participant name
  -d, --domain       Domain name
  -t, --timeout      Connection timeout in seconds
  --create-parties   Create sample parties (Alice, Bob)
  --upload-dars      Upload DAR files from dars/ directory
  --interactive      Run in interactive mode
  --status-only      Only check connection status

Examples:
  # Basic connection
  ./connect-participant-domain.sh

  # Connect with party creation
  ./connect-participant-domain.sh --create-parties

  # Connect and upload DARs
  ./connect-participant-domain.sh --create-parties --upload-dars

  # Check status only
  ./connect-participant-domain.sh --status-only
EOF
}

check_canton_running() {
    log_info "Checking if Canton is running..."
    
    # Check if Canton process is running
    if pgrep -f "canton.*$CONFIG_FILE" > /dev/null; then
        log_success "Canton is running"
        return 0
    fi
    
    # Check if PID file exists
    local pid_file="log/canton.pid"
    if [[ -f "$pid_file" ]]; then
        local canton_pid=$(cat "$pid_file")
        if ps -p "$canton_pid" > /dev/null 2>&1; then
            log_success "Canton is running (PID: $canton_pid)"
            return 0
        else
            log_warn "Stale PID file found, removing it"
            rm -f "$pid_file"
        fi
    fi
    
    log_error "Canton is not running. Please start Canton first:"
    log_error "  ./config/scripts/start-canton-network.sh"
    return 1
}

wait_for_canton_ready() {
    log_info "Waiting for Canton to be ready..."
    
    local timeout=$CONNECTION_TIMEOUT
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        # Try to connect to admin API (simple port check)
        if command -v nc &> /dev/null; then
            if nc -z localhost 5012 2>/dev/null; then
                log_success "Canton admin API is responsive"
                return 0
            fi
        elif command -v curl &> /dev/null; then
            # Try HTTP health check if available
            if curl -s --connect-timeout 2 http://localhost:5012 > /dev/null 2>&1; then
                log_success "Canton admin API is responsive"
                return 0
            fi
        fi
        
        ((count++))
        if [[ $((count % 5)) -eq 0 ]]; then
            log_info "Still waiting for Canton... ($count/$timeout seconds)"
        fi
        sleep 1
    done
    
    log_error "Timeout waiting for Canton to become ready"
    return 1
}

create_canton_script() {
    local script_type="$1"
    local script_file=$(mktemp)
    
    case "$script_type" in
        "connect")
            cat > "$script_file" << 'EOF'
// Connect participant to domain
try {
    val connection = participant1.domains.connect_local(mydomain)
    println(s"✓ Successfully connected participant to domain: $connection")
} catch {
    case e: Exception => 
        println(s"✗ Failed to connect participant to domain: ${e.getMessage}")
        sys.exit(1)
}

// Verify connection
try {
    val connected = participant1.domains.list_connected()
    if (connected.nonEmpty) {
        println(s"✓ Participant is connected to ${connected.size} domain(s)")
        connected.foreach(domain => println(s"  - ${domain.domainId}"))
    } else {
        println("✗ No domain connections found")
        sys.exit(1)
    }
} catch {
    case e: Exception => 
        println(s"✗ Failed to check domain connections: ${e.getMessage}")
        sys.exit(1)
}

sys.exit(0)
EOF
            ;;
        "status")
            cat > "$script_file" << 'EOF'
// Check participant status
try {
    println("=== Participant Status ===")
    val status = participant1.health.status
    println(s"Participant Status: $status")
    
    val connected = participant1.domains.list_connected()
    if (connected.nonEmpty) {
        println(s"✓ Connected to ${connected.size} domain(s):")
        connected.foreach(domain => println(s"  - ${domain.domainId}"))
    } else {
        println("✗ Not connected to any domains")
    }
    
    val parties = participant1.parties.list()
    if (parties.nonEmpty) {
        println(s"✓ ${parties.size} parties hosted:")
        parties.foreach(party => println(s"  - ${party.party}"))
    } else {
        println("ℹ No parties hosted")
    }
} catch {
    case e: Exception => 
        println(s"✗ Failed to get participant status: ${e.getMessage}")
        sys.exit(1)
}

// Check domain status
try {
    println("\n=== Domain Status ===")
    val domainStatus = mydomain.health.status
    println(s"Domain Status: $domainStatus")
} catch {
    case e: Exception => 
        println(s"✗ Failed to get domain status: ${e.getMessage}")
        sys.exit(1)
}

sys.exit(0)
EOF
            ;;
        "create-parties")
            cat > "$script_file" << 'EOF'
// Create sample parties
try {
    println("Creating sample parties...")
    
    val alice = participant1.parties.enable("Alice")
    println(s"✓ Created party Alice: ${alice.party}")
    
    val bob = participant1.parties.enable("Bob")
    println(s"✓ Created party Bob: ${bob.party}")
    
    println("✓ Sample parties created successfully")
} catch {
    case e: Exception => 
        println(s"✗ Failed to create parties: ${e.getMessage}")
        sys.exit(1)
}

sys.exit(0)
EOF
            ;;
        "upload-dars")
            cat > "$script_file" << 'EOF'
import java.io.File

// Upload DAR files
try {
    val darDir = new File("dars")
    if (darDir.exists && darDir.isDirectory) {
        val darFiles = darDir.listFiles.filter(_.getName.endsWith(".dar"))
        
        if (darFiles.nonEmpty) {
            println(s"Found ${darFiles.length} DAR files to upload:")
            darFiles.foreach { darFile =>
                println(s"  - ${darFile.getName}")
                try {
                    participant1.dars.upload(darFile.getPath)
                    println(s"    ✓ Uploaded successfully")
                } catch {
                    case e: Exception => 
                        println(s"    ✗ Upload failed: ${e.getMessage}")
                }
            }
        } else {
            println("ℹ No DAR files found in dars/ directory")
        }
    } else {
        println("ℹ dars/ directory not found")
    }
} catch {
    case e: Exception => 
        println(s"✗ Failed to upload DARs: ${e.getMessage}")
        sys.exit(1)
}

sys.exit(0)
EOF
            ;;
    esac
    
    echo "$script_file"
}

run_canton_command() {
    local script_type="$1"
    local description="$2"
    
    log_info "$description..."
    
    local script_file=$(create_canton_script "$script_type")
    local log_file=$(mktemp)
    
    # Run Canton with the script
    if timeout "$CONNECTION_TIMEOUT" ./bin/canton -c "$CONFIG_FILE" --bootstrap "$script_file" > "$log_file" 2>&1; then
        # Show output
        if grep -q "✓" "$log_file"; then
            cat "$log_file" | grep "✓\|ℹ\|===" || true
            log_success "$description completed"
        else
            log_warn "$description completed (check output for details)"
        fi
        
        # Clean up
        rm -f "$script_file" "$log_file"
        return 0
    else
        log_error "$description failed"
        
        # Show error output
        if [[ -s "$log_file" ]]; then
            echo "Error output:"
            cat "$log_file" | tail -10
        fi
        
        # Clean up
        rm -f "$script_file" "$log_file"
        return 1
    fi
}

connect_participant_to_domain() {
    log_info "Connecting participant '$PARTICIPANT_NAME' to domain '$DOMAIN_NAME'..."
    
    if run_canton_command "connect" "Participant-domain connection"; then
        log_success "Participant successfully connected to domain"
        return 0
    else
        log_error "Failed to connect participant to domain"
        return 1
    fi
}

check_network_status() {
    log_info "Checking network status..."
    
    if run_canton_command "status" "Status check"; then
        return 0
    else
        log_error "Failed to get network status"
        return 1
    fi
}

create_sample_parties() {
    log_info "Creating sample parties..."
    
    if run_canton_command "create-parties" "Party creation"; then
        log_success "Sample parties created"
        return 0
    else
        log_warn "Failed to create some parties (they may already exist)"
        return 0  # Don't fail the entire script for this
    fi
}

upload_dar_files() {
    log_info "Uploading DAR files..."
    
    if run_canton_command "upload-dars" "DAR upload"; then
        log_success "DAR files processed"
        return 0
    else
        log_warn "Some DAR uploads may have failed"
        return 0  # Don't fail the entire script for this
    fi
}

run_interactive_mode() {
    log_info "Starting interactive Canton console..."
    log_info "Useful commands:"
    echo "  participant1.domains.list_connected()"
    echo "  participant1.parties.list()"
    echo "  participant1.health.status"
    echo "  mydomain.health.status"
    echo "  exit"
    echo ""
    
    exec ./bin/canton -c "$CONFIG_FILE" --console
}

main() {
    local CREATE_PARTIES=false
    local UPLOAD_DARS=false
    local INTERACTIVE=false
    local STATUS_ONLY=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -p|--participant)
                PARTICIPANT_NAME="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN_NAME="$2"
                shift 2
                ;;
            -t|--timeout)
                CONNECTION_TIMEOUT="$2"
                shift 2
                ;;
            --create-parties)
                CREATE_PARTIES=true
                shift
                ;;
            --upload-dars)
                UPLOAD_DARS=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --status-only)
                STATUS_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Change to Canton directory
    cd "$CANTON_DIR"
    
    log_info "Canton Network Connection Script"
    log_info "================================"
    log_info "Configuration: $CONFIG_FILE"
    log_info "Participant: $PARTICIPANT_NAME"
    log_info "Domain: $DOMAIN_NAME"
    echo ""
    
    # Check if Canton is running
    if ! check_canton_running; then
        exit 1
    fi
    
    # Wait for Canton to be ready
    if ! wait_for_canton_ready; then
        exit 1
    fi
    
    if [[ "$STATUS_ONLY" == "true" ]]; then
        # Only check status
        check_network_status
    elif [[ "$INTERACTIVE" == "true" ]]; then
        # Start interactive mode
        run_interactive_mode
    else
        # Connect participant to domain
        if ! connect_participant_to_domain; then
            exit 1
        fi
        
        # Create sample parties if requested
        if [[ "$CREATE_PARTIES" == "true" ]]; then
            create_sample_parties
        fi
        
        # Upload DAR files if requested
        if [[ "$UPLOAD_DARS" == "true" ]]; then
            upload_dar_files
        fi
        
        # Show final status
        echo ""
        log_info "Final network status:"
        check_network_status
        
        echo ""
        log_success "Network setup completed successfully!"
        log_info "Your Canton network is now ready for use."
        log_info "You can start creating contracts and running transactions."
    fi
}

main "$@"