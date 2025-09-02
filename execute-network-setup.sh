#!/bin/bash

echo "🚀 Executing Canton Network Setup Commands..."

# Execute the setup script using Canton console
./bin/canton -c config/canton-production-temp.conf -f setup-production-network.canton