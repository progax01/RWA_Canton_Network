# Canton Production Setup Scripts

This directory contains comprehensive scripts for setting up and managing a production Canton deployment. These scripts automate database setup, certificate management, environment validation, and network startup.

## 🚀 Quick Start

For a complete automated setup:

```bash
# Set required environment variables
export POSTGRES_ADMIN_PASSWORD=your_postgres_admin_password
export CANTON_DB_PASSWORD=your_strong_canton_password

# Run the master setup script
./config/scripts/setup-canton-production.sh --generate-certs --yes
```

For interactive setup with prompts:

```bash
./config/scripts/setup-canton-production.sh --interactive
```

## 📋 Available Scripts

### 1. `setup-canton-production.sh` - Master Setup Script

**Purpose**: Orchestrates the complete Canton production setup process.

**Features**:
- Environment validation
- Database creation and setup
- Certificate verification/generation
- Canton network startup
- Participant-domain connection
- Sample data creation

**Usage**:
```bash
# Interactive mode
./setup-canton-production.sh --interactive

# Non-interactive with test certificates
./setup-canton-production.sh --generate-certs --yes

# Setup only (don't start Canton)
./setup-canton-production.sh --setup-only
```

**Options**:
- `--interactive`: Interactive mode with prompts
- `--yes`: Answer yes to all prompts (non-interactive)
- `--generate-certs`: Generate test certificates
- `--setup-only`: Only run setup steps (don't start Canton)
- `--skip-validation`: Skip environment validation
- `--skip-database`: Skip database setup
- `--skip-certificates`: Skip certificate setup

### 2. `validate-environment.sh` - Environment Validation

**Purpose**: Validates system requirements, dependencies, and configuration.

**Checks**:
- System resources (RAM, CPU, disk)
- Java environment and version
- Required dependencies
- Canton installation
- Network connectivity
- Configuration file validity

**Usage**:
```bash
# Basic validation
./validate-environment.sh

# Generate detailed report
./validate-environment.sh --report

# Attempt to fix issues automatically
./validate-environment.sh --fix
```

### 3. `setup-database.sh` - Database Setup

**Purpose**: Creates PostgreSQL databases for Canton participant and domain.

**Features**:
- Creates `canton_participant` and `canton_domain` databases
- Sets up Canton user with proper permissions
- Applies PostgreSQL performance tuning
- Supports environment variable configuration
- Connection testing and verification

**Usage**:
```bash
# Basic setup (requires environment variables)
export POSTGRES_ADMIN_PASSWORD=admin_password
export CANTON_DB_PASSWORD=canton_password
./setup-database.sh

# With verification
./setup-database.sh --verify

# Force recreation of existing databases
./setup-database.sh --force

# Dry run (show what would be done)
./setup-database.sh --dry-run
```

**Environment Variables**:
- `POSTGRES_HOST`: PostgreSQL host (default: localhost)
- `POSTGRES_PORT`: PostgreSQL port (default: 5432)
- `POSTGRES_ADMIN_USER`: Admin user (default: postgres)
- `POSTGRES_ADMIN_PASSWORD`: Admin password (required)
- `CANTON_DB_USER`: Canton user (default: canton)
- `CANTON_DB_PASSWORD`: Canton password (required)

### 4. `verify-certificates.sh` - Certificate Management

**Purpose**: Verifies TLS certificates or generates test certificates.

**Features**:
- Certificate existence and validity checks
- Private key verification and matching
- Certificate expiration checking
- File permission validation
- Test certificate generation

**Usage**:
```bash
# Basic verification
./verify-certificates.sh

# Generate test certificates if missing
./verify-certificates.sh --generate

# Verbose output with expiration check
./verify-certificates.sh --verbose --check-expiry
```

**Certificate Files**:
- `config/tls/participant-cert-chain.crt`: Participant certificate
- `config/tls/participant-key.pem`: Participant private key
- `config/tls/domain-cert-chain.crt`: Domain certificate
- `config/tls/domain-key.pem`: Domain private key
- `config/tls/root-ca.crt`: Root CA certificate

### 5. `start-canton-network.sh` - Network Startup

**Purpose**: Starts Canton network with comprehensive pre-flight checks.

**Features**:
- System resource checking
- Port availability verification
- Database connectivity testing
- Certificate validation
- Health monitoring
- Background or foreground startup

**Usage**:
```bash
# Basic startup with all checks
./start-canton-network.sh

# Start in background
./start-canton-network.sh --background

# Start with console enabled
./start-canton-network.sh --console

# Skip checks and start immediately
./start-canton-network.sh --skip-db-check --skip-cert-check

# Dry run (show what would be done)
./start-canton-network.sh --dry-run
```

### 6. `connect-participant-domain.sh` - Network Connection

**Purpose**: Connects participant to domain and sets up basic network topology.

**Features**:
- Participant-domain connection
- Connection status verification
- Sample party creation
- DAR file upload
- Interactive console access

**Usage**:
```bash
# Basic connection
./connect-participant-domain.sh

# Connect and create sample parties
./connect-participant-domain.sh --create-parties

# Connect, create parties, and upload DARs
./connect-participant-domain.sh --create-parties --upload-dars

# Check status only
./connect-participant-domain.sh --status-only

# Interactive console
./connect-participant-domain.sh --interactive
```

## 🔧 Prerequisites

### System Requirements

- **OS**: Linux or macOS
- **RAM**: 6GB minimum, 8GB+ recommended
- **CPU**: 4 cores minimum, 8+ recommended
- **Disk**: 20GB+ free space
- **Java**: JDK 11+ (JDK 17+ recommended)

### Required Software

- **PostgreSQL**: 12+ with client tools (`psql`)
- **OpenSSL**: For certificate operations
- **Network tools**: `curl`, `nc` (netcat), `netstat`
- **Process tools**: `ps`, `pkill`

### Environment Variables

Set these before running the scripts:

```bash
# Database credentials
export POSTGRES_HOST=localhost                    # PostgreSQL host
export POSTGRES_ADMIN_PASSWORD=admin_password     # PostgreSQL admin password
export CANTON_DB_PASSWORD=strong_canton_password  # Canton database password

# Optional JVM tuning
export JAVA_OPTS="-Xms4g -Xmx4g -XX:+UseG1GC -XX:G1HeapRegionSize=16m"
```

## 📁 Directory Structure

After running the scripts, your Canton installation will have:

```
canton-open-source-2.10.2/
├── bin/canton                           # Canton executable
├── config/
│   ├── canton-single-participant.conf   # Main configuration
│   ├── scripts/                         # Setup scripts (this directory)
│   └── tls/                            # TLS certificates
├── log/                                # Canton logs
│   ├── canton.log                      # Main log file
│   ├── canton_errors.log              # Error log
│   └── canton.pid                      # Process ID file
└── dars/                               # DAR files for upload
```

## 🔍 Monitoring and Health Checks

### Service Endpoints

| Service | Port | Purpose |
|---------|------|---------|
| Participant Ledger API | 5011 | gRPC Ledger API for applications |
| Participant Admin API | 5012 | Administration interface |
| Participant Health Check | 5013 | gRPC health monitoring |
| Domain Public API | 5018 | Participant-to-domain communication |
| Domain Admin API | 5019 | Domain administration |
| Domain Health Check | 5014 | gRPC health monitoring |
| Prometheus Metrics | 9000 | Monitoring metrics |

### Health Check Commands

```bash
# Check if services are responding
nc -z localhost 5011  # Ledger API
nc -z localhost 5012  # Admin API
nc -z localhost 9000  # Metrics

# View metrics
curl http://localhost:9000/metrics

# Check logs
tail -f log/canton.log
```

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   ```bash
   # Test database connectivity
   psql -h localhost -U postgres -d postgres
   
   # Re-run database setup
   ./setup-database.sh --force
   ```

2. **Certificate Errors**
   ```bash
   # Generate test certificates
   ./verify-certificates.sh --generate
   
   # Check certificate details
   ./verify-certificates.sh --verbose
   ```

3. **Port Conflicts**
   ```bash
   # Check what's using the ports
   netstat -tuln | grep ':501[1289]\|:9000'
   
   # Kill conflicting processes
   pkill -f canton
   ```

4. **Java/JVM Issues**
   ```bash
   # Check Java version
   java -version
   
   # Set JVM options
   export JAVA_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC"
   ```

### Log Analysis

```bash
# View recent errors
grep -i error log/canton.log | tail -10

# Monitor logs in real-time
tail -f log/canton.log

# Check startup sequence
grep -i "starting\|started\|ready" log/canton.log
```

### Script Debugging

Enable debug output for any script:
```bash
./script-name.sh --debug
```

### Recovery Procedures

1. **Clean Restart**:
   ```bash
   pkill -f canton
   rm -f log/canton.pid
   ./start-canton-network.sh
   ```

2. **Reset Network**:
   ```bash
   ./connect-participant-domain.sh --status-only
   ```

3. **Full Environment Reset**:
   ```bash
   ./setup-canton-production.sh --setup-only --yes
   ```

## 📖 Additional Resources

- **Canton Documentation**: https://docs.daml.com/canton/
- **Configuration Reference**: `config/canton-single-participant-README.md`
- **Production Guide**: https://docs.daml.com/canton/usermanual/

## 🔒 Security Notes

- **Test Certificates**: Never use test certificates in production
- **Database Passwords**: Use strong, unique passwords
- **Network Security**: Implement proper firewall rules
- **Certificate Rotation**: Plan for regular certificate updates
- **Access Control**: Restrict access to admin APIs and certificates

## 📝 Script Maintenance

The scripts are designed to be:
- **Idempotent**: Safe to run multiple times
- **Configurable**: Via environment variables and command-line options
- **Robust**: With comprehensive error handling and validation
- **Informative**: With detailed logging and status reporting

For script updates or custom modifications, preserve the error handling patterns and validation logic.