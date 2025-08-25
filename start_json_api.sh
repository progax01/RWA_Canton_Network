#!/bin/bash

# Start Daml JSON API connecting to Canton participant with TLS
# This script starts the HTTP JSON API service version 2.10.2
# connecting to the Canton participant's Ledger API on port 5011 with TLS enabled
#
# The JSON API acts as a proxy to the Canton ledger's gRPC API, allowing
# interaction with the ledger via simple HTTP requests with JWT authentication

echo "Starting Daml JSON API service..."
echo "Connecting to Canton participant at localhost:5011 with TLS"
echo "JSON API will be available at http://0.0.0.0:7575"

# Check if http-json-2.10.2.jar exists
if [ ! -f "http-json-2.10.2.jar" ]; then
    echo "Error: http-json-2.10.2.jar not found in current directory"
    echo "Please ensure the Daml JSON API jar file is present"
    exit 1
fi

# Check if TLS root CA certificate exists
if [ ! -f "config/tls/root-ca.crt" ]; then
    echo "Error: config/tls/root-ca.crt not found"
    echo "Please ensure TLS certificates are properly configured"
    exit 1
fi

# Verify Canton participant is running (optional check)
echo "Verifying Canton participant connectivity..."
if ! nc -z localhost 5011 2>/dev/null; then
    echo "Warning: Cannot connect to Canton participant at localhost:5011"
    echo "Please ensure the Canton participant is running and accessible"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Starting JSON API with the following configuration:"
echo "  - Ledger host: localhost"
echo "  - Ledger port: 5011"
echo "  - JSON API address: 0.0.0.0"
echo "  - JSON API port: 7575"
echo "  - TLS enabled: yes"
echo "  - CA certificate: config/tls/root-ca.crt"
echo "  - Authentication: JWT required for all requests"

# Run the Daml JSON API, connecting to the Canton participant's Ledger API
# The flags are configured according to the Daml JSON API specification:
# --ledger-host: Canton participant's gRPC API host
# --ledger-port: Canton participant's Ledger API port (5011 from config)
# --address: Interface for JSON API to bind to (0.0.0.0 for external access)
# --http-port: Port for JSON API HTTP service (7575 as per Daml docs)
# --cacrt: Root CA certificate to trust the participant's TLS certificate
# --tls: Enable TLS connection to the ledger API
java -jar http-json-2.10.2.jar \
  --ledger-host localhost \
  --ledger-port 5011 \
  --address 0.0.0.0 \
  --http-port 7575 \
  --cacrt config/tls/root-ca.crt \
  --tls

echo "JSON API service started successfully"
echo "The service is now ready to accept HTTP requests with JWT authentication"
echo "Use the generated JWT tokens from jwt-tokens.json or individual *-jwt-token.txt files"