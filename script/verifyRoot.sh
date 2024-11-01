#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
ROOT_POOL_IMPLEMENTATION=
ROOT_POOL_FACTORY=
ROOT_GAUGE_FACTORY=

# V2 Constants
VOTER="0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C"
ROOT_X_VELO="0xa700b592304b69dDb70d9434F5E90877947f1f05"
ROOT_X_LOCKBOX="0xF37D648ff7ab53fBe71C4EE66c212f74372f846b"
ROOT_MESSAGE_BRIDGE="0x0b34Ec8995052783A62692B7F3fF7c856A184dDD"
ROOT_VOTING_REWARDS_FACTORY="0xEAc8b42979528447d58779A6a3CaBEb4E4aEdEC5"
POOL_FACTORY_OWNER="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
FEE_MANAGER="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
NOTIFY_ADMIN="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
EMISSION_ADMIN="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
DEFAULT_CAP=100

# ENV Variables
source .env
ETHERSCAN_API_KEY=$OPTIMISM_ETHERSCAN_API_KEY
ETHERSCAN_VERIFIER_URL=$OPTIMISM_ETHERSCAN_VERIFIER_URL
CHAIN_ID=10

# RootCLPool
forge verify-contract \
    $ROOT_POOL_IMPLEMENTATION \
    contracts/root/pool/RootCLPool.sol:RootCLPool \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor()()") \
    --compiler-version "v0.7.6" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootCLPoolFactory
forge verify-contract \
    $ROOT_POOL_FACTORY \
    contracts/root/pool/RootCLPoolFactory.sol:RootCLPoolFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address)()" $POOL_FACTORY_OWNER $ROOT_POOL_IMPLEMENTATION $ROOT_MESSAGE_BRIDGE) \
    --compiler-version "v0.7.6" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootCLGaugeFactory
forge verify-contract \
    $ROOT_GAUGE_FACTORY \
    contracts/root/gauge/RootCLGaugeFactory.sol:RootCLGaugeFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,address,address,address,uint256)()" $VOTER $ROOT_X_VELO $ROOT_X_LOCKBOX $ROOT_MESSAGE_BRIDGE $ROOT_POOL_FACTORY $ROOT_VOTING_REWARDS_FACTORY $NOTIFY_ADMIN $EMISSION_ADMIN $DEFAULT_CAP) \
    --compiler-version "v0.7.6" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL
