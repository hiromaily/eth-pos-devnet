#!/usr/bin/env bash
set -eu

# geth
docker compose up geth-genesis geth-account1 geth-account2 geth
