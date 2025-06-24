// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {MixedRouteQuoterV2} from "contracts/periphery/lens/MixedRouteQuoterV2.sol";
import {ICreateX} from "contracts/libraries/ICreateX.sol";
import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";
import {Constants} from "script/constants/Constants.sol";

contract DeployMixedRouteQuoterV2 is Script, Constants {
    using CreateXLibrary for bytes11;

    address public mixedRouteQuoterV2;

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    bool public isTest = false;

    // Common factory addresses for all chains except optimism and base
    address public constant FACTORY = 0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F;
    address public constant FACTORY_V2 = 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0;

    // Optimism-specific factory addresses
    address public constant FACTORY_OPTIMISM = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
    address public constant FACTORY_V2_OPTIMISM = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

    // Base-specific factory addresses
    address public constant FACTORY_BASE = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address public constant FACTORY_V2_BASE = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // Standard OP Stack WETH9 address used by most chains
    address public constant WETH9_STANDARD = 0x4200000000000000000000000000000000000006;

    // Chain-specific WETH9 addresses
    address public constant WETH9_FRAXTAL = 0xFc00000000000000000000000000000000000002;
    address public constant WETH9_CELO = address(0);

    // All chains from deployment parameters except bob
    string[] public chains = [
        "base",
        "celo",
        "fraxtal",
        "ink",
        "lisk",
        "metal",
        "mode",
        "optimism",
        "soneium",
        "superseed",
        "swell",
        "unichain"
    ];

    function run() external {
        // Deploy to all chains
        for (uint256 i = 0; i < chains.length; i++) {
            string memory chainName = chains[i];
            console2.log("Deploying to chain:", chainName);

            vm.createSelectFork(chainName);
            vm.startBroadcast(deployer);

            deployMixedRouteQuoterV2(chainName);

            vm.stopBroadcast();

            logOutput(chainName);
        }
    }

    function deployMixedRouteQuoterV2(string memory chainName) internal virtual {
        address weth9 = getWETH9ForChain(chainName);
        (address factory, address factoryV2) = getFactoryAddressesForChain(chainName);

        mixedRouteQuoterV2 = cx.deployCreate3({
            salt: MIXED_QUOTER_V2_ENTROPY.calculateSalt({_deployer: deployer}),
            initCode: abi.encodePacked(type(MixedRouteQuoterV2).creationCode, abi.encode(factory, factoryV2, weth9))
        });

        checkAddress({_entropy: MIXED_QUOTER_V2_ENTROPY, _output: mixedRouteQuoterV2});

        console2.log("MixedRouteQuoterV2 deployed at:", mixedRouteQuoterV2);
        console2.log("Factory:", factory);
        console2.log("FactoryV2:", factoryV2);
        console2.log("WETH9:", weth9);
    }

    function getWETH9ForChain(string memory chainName) internal pure returns (address) {
        bytes32 chainHash = keccak256(bytes(chainName));

        if (chainHash == keccak256(bytes("fraxtal"))) {
            return WETH9_FRAXTAL;
        } else if (chainHash == keccak256(bytes("celo"))) {
            return WETH9_CELO;
        } else {
            return WETH9_STANDARD;
        }
    }

    function getFactoryAddressesForChain(string memory chainName)
        internal
        pure
        returns (address factory, address factoryV2)
    {
        bytes32 chainHash = keccak256(bytes(chainName));

        if (chainHash == keccak256(bytes("optimism"))) {
            return (FACTORY_OPTIMISM, FACTORY_V2_OPTIMISM);
        } else if (chainHash == keccak256(bytes("base"))) {
            return (FACTORY_BASE, FACTORY_V2_BASE);
        } else {
            return (FACTORY, FACTORY_V2);
        }
    }

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes11 _entropy, address _output) internal view {
        address computedAddress = _entropy.computeCreate3Address({_deployer: deployer});
        require(computedAddress == _output, "Invalid address");
    }

    function logOutput(string memory _chainName) internal {
        if (isTest) return;
        string memory filename = string(abi.encodePacked(_chainName, ".json"));
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", filename));
        require(keccak256(bytes(filename)) != keccak256(bytes("")), "Invalid output filename");

        vm.writeJson(vm.serializeAddress("", "MixedRouteQuoterV2", mixedRouteQuoterV2), path);

        console2.log("Deployment addresses written to:", path);
    }
}
