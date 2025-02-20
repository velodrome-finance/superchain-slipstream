#!/bin/bash

# Check if required arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <chain-name> [verifier-type] [additional_args]"
    echo "Example (simulation only): $0 soneium"
    echo "Example (with deployment): $0 soneium blockscout"
    echo "Example with additional args: $0 soneium blockscout \"--with-gas-price 1000000000\""
    exit 1
fi

CHAIN_NAME=$1
VERIFIER_TYPE=${2:-""} # Use empty string if no second argument provided
ADDITIONAL_ARGS=${3:-""} # Use empty string if no third argument provided

# Path to the deployment script
SCRIPT_PATH="script/deployParameters/${CHAIN_NAME}/DeployLeafCL.s.sol:DeployLeafCL"

echo "Running simulation for ${CHAIN_NAME}..."
# Run simulation first
if forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} -vvvv; then
    # If no verifier type is provided, exit after successful simulation
    if [ -z "$VERIFIER_TYPE" ]; then
        echo "Simulation completed successfully. No deployment performed (no verifier type provided)."
        exit 0
    fi

    # Set verifier arguments based on verifier type
    if [ "$VERIFIER_TYPE" = "blockscout" ]; then
        VERIFIER_ARG="--verifier blockscout"
    elif [ "$VERIFIER_TYPE" = "etherscan" ]; then
        VERIFIER_ARG="--verifier etherscan"
    else
        echo "Error: Unsupported verifier type. Use 'blockscout' or 'etherscan'"
        exit 1
    fi

    echo "Simulation successful! Proceeding with actual deployment..."
    
    # Run actual deployment with verification
    forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} --broadcast --verify ${VERIFIER_ARG} ${ADDITIONAL_ARGS} -vvvv
else
    echo "Simulation failed! Please check the output above for errors."
    exit 1
fi
