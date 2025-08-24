#!/bin/bash
# Start JSON API service for RWA Platform with production configuration

echo "🚀 Starting RWA Platform JSON API service..."
echo "📋 Configuration:"
echo "   - Using config: config/json-api-production.conf"
echo "   - Ledger Host: localhost (TLS enabled)"
echo "   - Ledger Port: 5011"
echo "   - HTTP Port: 7575"
echo "   - JWT Authentication: Enabled"
echo "   - PostgreSQL Query Store: Enabled"
echo

# Set environment variables for JSON API database
export JSON_API_DB_USER=json_api
export JSON_API_DB_PASSWORD=json_api_password

# Start the JSON API using the production configuration file with insecure tokens for testing
java -jar http-json-2.10.2.jar \
  --config config/json-api-production.conf \
  --allow-insecure-tokens