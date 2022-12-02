#!/usr/bin/env bash
set -e

source .env

# Deploy the AlETHRouter using the first anvil account.
forge script script/DeployAlETHRouter.s.sol:DeployAlETHRouter \
    -f "http://localhost:8545" \
    --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
    --broadcast

# Generate a Hardhat-like deployment file.
./tasks/generate-router-deployment-file.sh
