#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# MixedRouteQuoterV2 address (deterministic deployment across all chains)
# This will be the same address on all chains due to CREATE3 deployment
MIXED_ROUTE_QUOTER_V2_ADDRESS="0x846b5cec4b4c3f7b95b3321d01e38a72d358f5c0" # TODO: Update with actual deployed address

# Factory addresses (same for all chains being verified)
FACTORY="0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F"
FACTORY_V2="0x31832f2a97Fd20664D76Cc421207669b55CE4BC0"

# WETH9 address (same for all chains being verified)
WETH9="0x4200000000000000000000000000000000000006"

# Constructor arguments (same for all chains)
CONSTRUCTOR_ARGS="$FACTORY $FACTORY_V2 $WETH9"

# Function to verify MixedRouteQuoterV2 contract
verify_mixed_route_quoter_v2() {
    local chain_name=$1
    local chain_id=$2
    
    # Get verifier URL for this chain (convert to uppercase)
    local verifier_url_var=$(echo "${chain_name}_VERIFIER_URL" | tr '[:lower:]' '[:upper:]')
    local verifier_url=$(eval echo \$${verifier_url_var})
    
    if [ -z "$verifier_url" ]; then
        echo "❌ Verifier URL not found for $chain_name (${verifier_url_var})"
        echo "   Make sure you have ${verifier_url_var} set in your .env file"
        return 1
    fi
    
    echo "🔍 Verifying MixedRouteQuoterV2 on $chain_name (Chain ID: $chain_id)"
    echo "   Address: $MIXED_ROUTE_QUOTER_V2_ADDRESS"
    echo "   Constructor Args: $CONSTRUCTOR_ARGS"
    echo "   Verifier URL: $verifier_url"
    
    forge verify-contract $MIXED_ROUTE_QUOTER_V2_ADDRESS \
        contracts/periphery/lens/MixedRouteQuoterV2.sol:MixedRouteQuoterV2 \
        --chain-id $chain_id \
        --verifier blockscout \
        --verifier-url $verifier_url \
        --constructor-args $(cast abi-encode "constructor(address,address,address)" $CONSTRUCTOR_ARGS) \
        --watch
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully verified MixedRouteQuoterV2 on $chain_name"
    else
        echo "❌ Failed to verify MixedRouteQuoterV2 on $chain_name"
    fi
    
    echo ""
}

# Function to process a chain
process_chain() {
    local chain_name=$1
    local chain_id=$2
    
    echo "🌐 Processing $chain_name (Chain ID: $chain_id)"
    echo "============================================"
    
    verify_mixed_route_quoter_v2 "$chain_name" "$chain_id"
    
    echo "============================================"
    echo ""
}

# Main verification loop
echo "🚀 Starting MixedRouteQuoterV2 verification on multiple chains..."
echo "📋 Contract to verify:"
echo "   - MixedRouteQuoterV2: $MIXED_ROUTE_QUOTER_V2_ADDRESS"
echo ""
echo "ℹ️  Note: Optimism, Base, Celo, and Fraxtal are excluded (already verified)"
echo ""

# Chains with blockscout verifiers that need verification
process_chain "ink" "57073"
process_chain "lisk" "1135"
process_chain "metal" "1750"
process_chain "mode" "34443"
process_chain "soneium" "1868"
process_chain "superseed" "5330"
process_chain "swell" "1923"
process_chain "unichain" "130"

echo "🎉 MixedRouteQuoterV2 verification process completed!" 