#!/usr/bin/env bash
set -e

source .env

# Check anvil is running
echo "👮 Check if anvil is running a mainnet fork..."
if [[ $(cast chain-id) -ne 1 ]]
then
    echo "🔴 Anvil must run a mainnet fork!"
    exit 1
fi

# Deploy AlETHRouter locally
echo "🚀 Deploy the AlETHRouter contract..."
./tasks/deploy-router-local.sh > /dev/null

# Whitelist AlETHRouter
echo "📝 Add it to alchemist's whitelist..."
./tasks/whitelist-router-local.sh > /dev/null

echo "✅ Done!"
