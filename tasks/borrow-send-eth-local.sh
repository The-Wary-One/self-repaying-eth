#!/usr/bin/env bash
set -e

source .env

owner="0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
recipient="0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc"
amount=1000000000000000000

# Borrow and send ETH.
forge script script/Toolbox.s.sol:Toolbox \
    -f "http://localhost:8545" \
    --private-key "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" \
    -s "borrowAndSendETHFrom(address,address,uint256)" \
    "$owner" "$recipient" "$amount" \
    --skip-simulation \
    --broadcast
