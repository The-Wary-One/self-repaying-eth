#!/usr/bin/env bash
set -e

source .env

abi=$(jq -c "{abi: .abi}" ./out/AlETHRouter.sol/AlETHRouter.json)
address=$(jq -c \
    "{address: .transactions[0].contractAddress}" \
    ./broadcast/DeployAlETHRouter.s.sol/1/run-latest.json)
blocknumberhex=$(jq -rc \
    ".receipts[0].blockNumber" \
    ./broadcast/DeployAlETHRouter.s.sol/1/run-latest.json)
blocknumber=$(cast --to-base $blocknumberhex 10)
echo "$abi $address {\"blockNumber\": $blocknumber}" | jq -s add > ./deployments/AlETHRouter.json
