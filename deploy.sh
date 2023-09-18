#!/bin/bash
cd "$(dirname "$(realpath -- "$0")")";
# Deploy bridge contract
PRIVATE_KEY=$1 OWNERS=$2 UPGRADE_WALLET=$3 OPERATOR_WALLET=$4 TOKENS=$5 forge script script/DeployBridgeL2.s.sol:TCScript --rpc-url $6 --broadcast -vvv --legacy
PRIVATE_KEY=$1 OWNERS=$2 UPGRADE_WALLET=$3 OPERATOR_WALLET=$4 MAINNET=$8 forge script script/DeployBridgeL2.s.sol:TCScriptOnETH --rpc-url $7 --broadcast -vvv --legacy