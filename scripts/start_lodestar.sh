#!/usr/bin/env bash
set -eu

genesisHash=$(curl -s http://localhost:8545 \
    -X POST \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc": "2.0", "id": "1", "method": "eth_getBlockByNumber","params": ["0x0", false]}' | jq -r '.result.hash')
echo "genesisHash: $genesisHash"

#timestamp=$(date -d'+10second' +%s)
timestamp=$(date -v+10S '+%s')

genesisHash=$genesisHash timestamp=$timestamp docker compose up lodestar
