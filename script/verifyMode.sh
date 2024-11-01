#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
LEAF_POOL_IMPLEMENTATION=
LEAF_POOL_FACTORY=
NFT_DESCRIPTOR=
NFT=
LEAF_GAUGE_FACTORY=

MIXED_QUOTER=
QUOTER=
SWAP_ROUTER=

NFT_DESCRIPTOR_LIBRARY=
NFTSVG_LIBRARY=

# V2 Constants
WETH="0x4200000000000000000000000000000000000006"
LEAF_VOTER="0xa0eD3C12C6FD753220b584b6790162f2Cbc81d13"
FACTORY_V2="0x31832f2a97Fd20664D76Cc421207669b55CE4BC0"
LEAF_X_VELO="0xa700b592304b69dDb70d9434F5E90877947f1f05"
MESSAGE_BRIDGE="0x0b34Ec8995052783A62692B7F3fF7c856A184dDD"
TEAM="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
POOL_FACTORY_OWNER="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
FEE_MANAGER="0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5"
NFT_NAME="Slipstream Position NFT v1.2"
NFT_SYMBOL="VELO-CL-POS"
ETH_32BYTES="0x4554480000000000000000000000000000000000000000000000000000000000"
RECIPIENT="0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3"
DEPLOYER="0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2"

# ENV Variables
source .env
ETHERSCAN_API_KEY=$MODE_ETHERSCAN_API_KEY
ETHERSCAN_VERIFIER_URL=$MODE_ETHERSCAN_VERIFIER_URL
CHAIN_ID=34443

# ModeCLPool
forge verify-contract \
    $LEAF_POOL_IMPLEMENTATION \
    contracts/core/extensions/ModeCLPool.sol:ModeCLPool \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor()()") \
    --compiler-version "v0.7.6"

# ModeCLFactory
forge verify-contract \
    $LEAF_POOL_FACTORY \
    contracts/core/extensions/ModeCLFactory.sol:ModeCLFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,address,address,address)()" $POOL_FACTORY_OWNER $DEPLOYER $DEPLOYER $LEAF_VOTER $LEAF_POOL_IMPLEMENTATION $LEAF_GAUGE_FACTORY $NFT $RECIPIENT) \
    --compiler-version "v0.7.6"

# NonfungibleTokenPositionDescriptor
forge verify-contract \
    $NFT_DESCRIPTOR \
    contracts/periphery/NonfungibleTokenPositionDescriptor.sol:NonfungibleTokenPositionDescriptor \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,bytes32)()" $WETH $ETH_32BYTES) \
    --compiler-version "v0.7.6" \
    --libraries contracts/periphery/libraries/NFTDescriptor.sol:NFTDescriptor:$NFT_DESCRIPTOR_LIBRARY \
    --libraries contracts/periphery/libraries/NFTSVG.sol:NFTSVG:$NFTSVG_LIBRARY

# ModeNonfungiblePositionManager
forge verify-contract \
    $NFT \
    contracts/periphery/extensions/ModeNonfungiblePositionManager.sol:ModeNonfungiblePositionManager \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,string,string,address)()" $TEAM $POOL_FACTORY_OWNER $WETH $NFT_DESCRIPTOR $NFT_NAME $NFT_SYMBOL $RECIPIENT) \
    --compiler-version "v0.7.6"

# ModeLeafCLGaugeFactory
forge verify-contract \
    $LEAF_GAUGE_FACTORY \
    contracts/gauge/extensions/ModeLeafCLGaugeFactory.sol:ModeLeafCLGaugeFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $LEAF_VOTER $NFT $LEAF_X_VELO $MESSAGE_BRIDGE) \
    --compiler-version "v0.7.6"

# MixedRouteQuoterV1
forge verify-contract \
    $MIXED_QUOTER \
    contracts/periphery/lens/MixedRouteQuoterV1.sol:MixedRouteQuoterV1 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address)()" $LEAF_POOL_FACTORY $FACTORY_V2 $WETH) \
    --compiler-version "v0.7.6"

# QuoterV2
forge verify-contract \
    $QUOTER \
    contracts/periphery/lens/QuoterV2.sol:QuoterV2 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $LEAF_POOL_FACTORY $WETH) \
    --compiler-version "v0.7.6"

# ModeSwapRouter
forge verify-contract \
    $SWAP_ROUTER \
    contracts/periphery/extensions/ModeSwapRouter.sol:ModeSwapRouter \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $LEAF_POOL_FACTORY $WETH) \
    --compiler-version "v0.7.6"
