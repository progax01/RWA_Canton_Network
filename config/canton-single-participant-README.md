# Canton Single Participant Production Configuration

This configuration file (`canton-single-participant.conf`) provides a production-ready setup for Canton with:
- **Single participant node** (`participant1`)
- **Single synchronization domain** (`mydomain`)
- **Persistent PostgreSQL storage** for both participant and domain
- **Full TLS encryption** for all APIs
- **Monitoring and health checks** enabled
- **Production security settings**

## Prerequisites

### 1. Hardware Requirements

Ensure your server meets the minimum requirements for Canton production deployment:
- **RAM**: At least 6 GB (recommended: 8+ GB)
- **CPU**: At least 4 cores (recommended: 8+ cores)
- **Disk**: SSD storage recommended for database performance
- **JVM Configuration**: Configure at least 4 GB heap size with G1 garbage collector

Example JVM settings:
```bash
export JAVA_OPTS="-Xms4g -Xmx4g -XX:+UseG1GC -XX:G1HeapRegionSize=16m"
```

### 2. PostgreSQL Database Setup

Create two separate databases:
```sql
CREATE DATABASE canton_participant;
CREATE DATABASE canton_domain;
CREATE USER canton WITH PASSWORD '<strong-password>';
GRANT ALL PRIVILEGES ON DATABASE canton_participant TO canton;
GRANT ALL PRIVILEGES ON DATABASE canton_domain TO canton;
```

Consider PostgreSQL performance tuning for production workloads:
```sql
-- Example PostgreSQL tuning parameters
ALTER SYSTEM SET shared_buffers = '2GB';
ALTER SYSTEM SET effective_cache_size = '6GB';
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET maintenance_work_mem = '512MB';
SELECT pg_reload_conf();
```

### 3. TLS Certificates

Generate or obtain the following certificates:

**For Participant:**
- `config/tls/participant-cert-chain.crt` - Participant certificate chain
- `config/tls/participant-key.pem` - Participant private key

**For Domain:**
- `config/tls/domain-cert-chain.crt` - Domain certificate chain  
- `config/tls/domain-key.pem` - Domain private key

**Root CA:**
- `config/tls/root-ca.crt` - Root Certificate Authority certificate

#### Generate Test Certificates (Development Only)

For testing purposes, you can use the provided script:
```bash
cd config/tls
./gen-test-certs.sh
```

⚠️ **Warning**: Test certificates should never be used in production environments.

## Configuration Customization

### Required Changes

Before running Canton with this configuration, update the following placeholders:

1. **Database Host**: Replace `<db-host>` with your PostgreSQL server hostname/IP
2. **Database Password**: Replace `<strong-password>` with your actual database password
3. **Certificate Paths**: Ensure all certificate file paths are correct for your environment

### Network Ports

The configuration uses the following ports by default:

| Service | Port | Description |
|---------|------|-------------|
| Participant Ledger API | 5011 | gRPC Ledger API for applications |
| Participant Admin API | 5012 | Administration interface |
| Participant Health Check | 5013 | gRPC health monitoring (if enabled) |
| Domain Public API | 5018 | Participant-to-domain communication |
| Domain Admin API | 5019 | Domain administration |
| Domain Health Check | 5014 | gRPC health monitoring (if enabled) |
| Prometheus Metrics | 9000 | Monitoring metrics endpoint (enabled by default) |

### Monitoring Configuration

The configuration includes Prometheus metrics enabled by default via `monitoring/prometheus.conf`. The gRPC health check services are configured but require the monitoring configuration to be active.

**Important Notes:**
- **Prometheus Metrics**: Enabled on port 9000 by default (can be overridden with `PROMETHEUS_PORT` environment variable)
- **gRPC Health Checks**: Configured on ports 5013 (participant) and 5014 (domain) but only active when monitoring is properly enabled
- **Features**: `enable-testing-commands = no` for production security (no development commands exposed)

### Optional Customizations

#### Environment Variables

The configuration supports environment variables for easier deployment:
- `POSTGRES_HOST` - Database host (overrides `<db-host>`)
- `POSTGRES_PORT` - Database port (default: 5432)
- `POSTGRES_USER` - Database user (overrides `canton`)
- `POSTGRES_PASSWORD` - Database password (overrides `<strong-password>`)
- `PROMETHEUS_PORT` - Prometheus metrics port (default: 9000)

#### Connection Pool Sizing

Adjust connection pool settings based on your workload:
- **Small**: 6 connections total (2,2,2 allocation)
- **Medium**: 9 connections total (3,3,3 allocation) 
- **Large**: 18 connections total (6,6,6 allocation) - Default

#### Protocol Version

The configuration uses protocol version 7, which is recommended for Canton 2.10.2+. You can adjust this in the domain configuration:
```hocon
domains.mydomain.init.domain-parameters.protocol-version = 7
```

## Running Canton

### Start Canton

```bash
./bin/canton -c config/canton-single-participant.conf
```

### Connect to Admin Console

```bash
# Connect to participant
./bin/canton -c config/canton-single-participant.conf --console
# In console:
participant1.health.status
```

## Security Considerations

This configuration follows production security best practices:

1. **TLS Everywhere**: All APIs use TLS encryption
2. **No Test Commands**: Testing commands are disabled
3. **Secure Storage**: Uses encrypted database connections
4. **Bind Configuration**: Services bind to all interfaces (0.0.0.0) - restrict if needed
5. **Certificate Validation**: Proper CA trust chains configured

### Additional Security Recommendations

1. **Firewall**: Restrict network access to Canton ports
2. **Database Security**: Use encrypted database connections
3. **Certificate Management**: Implement proper certificate rotation
4. **Monitoring**: Set up alerting for health check failures
5. **Backup**: Regular database backups of participant and domain data

## Party Management

Parties are not defined in the configuration file. Create them via Admin API:

```scala
// Connect to participant admin API
val alice = participant1.parties.enable("Alice")
val bob = participant1.parties.enable("Bob")

// Connect participant to domain
participant1.domains.connect_local(mydomain)
```

## HTTP JSON API (Optional)

The HTTP JSON API is typically run as a separate service. If needed, deploy it separately with configuration pointing to the participant's Ledger API endpoint.

## Troubleshooting

### Common Issues

1. **Database Connection**: Verify PostgreSQL is running and accessible
2. **Certificate Errors**: Check certificate paths and permissions
3. **Port Conflicts**: Ensure no other services use the configured ports
4. **Memory Settings**: Adjust JVM heap size for production loads

### Health Checks

Monitor service health via:
- gRPC health endpoints on ports 5013 (participant) and 5014 (domain)
- Prometheus metrics on port 9090
- Canton admin API status commands

### Logs

Canton logs are written to:
- `log/canton.log` - General application logs
- `log/canton_errors.log` - Error-specific logs

Configure log levels in the configuration file as needed for troubleshooting.

## Next Steps

1. **Provision databases and certificates:**

   * Use the provided SQL commands to create the `canton_participant` and `canton_domain` databases and grant privileges to the `canton` user.
   * Generate or obtain proper TLS certificates for the participant and domain (**do not** use test certificates in production). Place them in `config/tls/` and adjust the paths in the configuration.

2. **Update configuration placeholders:**

   * Replace `<db-host>` and `<strong-password>` with your actual PostgreSQL host and password, or use environment variables:
     ```bash
     export POSTGRES_HOST=your-db-host
     export POSTGRES_PASSWORD=your-strong-password
     ```
   * Confirm that all certificate file paths are correct for your environment.

3. **Configure JVM and start Canton:**

   * Set proper JVM heap size and garbage collector:
     ```bash
     export JAVA_OPTS="-Xms4g -Xmx4g -XX:+UseG1GC -XX:G1HeapRegionSize=16m"
     ```
   * Launch Canton:
     ```bash
     ./bin/canton -c config/canton-single-participant.conf
     ```

4. **Connect participant to domain:**

   **Critical Step**: The configuration alone does not establish the connection between participant and domain. You must connect them manually:

   ```bash
   # Open Canton console
   ./bin/canton -c config/canton-single-participant.conf --console
   ```
   
   In the console:
   ```scala
   // Connect participant to domain
   participant1.domains.connect_local(mydomain)
   
   // Verify connection
   participant1.domains.list_connected()
   ```

5. **Allocate parties and upload contracts:**

   * Create parties via the Admin API or console:
     ```scala
     val alice = participant1.parties.enable("Alice")
     val bob = participant1.parties.enable("Bob")
     ```
   * Upload your Daml contract DAR with automatic package vetting:
     ```scala
     participant1.dars.upload("path/to/your.dar")
     ```
   * The `synchronize-vetting-on-upload = true` setting ensures all packages are automatically vetted across all connected domains, preventing `NO_DOMAIN_FOR_SUBMISSION` errors.

6. **Integrate your application:**

   * For REST/JSON API: Deploy the HTTP JSON API as a separate service configured to connect to the participant's Ledger API (port 5011).
   * For gRPC: Connect directly to the Ledger API to create contracts, exercise choices, and query the ledger.
   * Both options support TLS and JWT authentication as configured.

**Important**: All participants in a multi-party workflow must upload and vet the same Daml packages. The automatic package vetting feature helps ensure consistency across the network.

By following these steps, you will have a robust production setup that matches Canton's official recommendations and supports enterprise-grade deployments.