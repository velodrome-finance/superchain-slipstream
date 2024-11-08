// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ICreateX} from "contracts/libraries/ICreateX.sol";

import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";

abstract contract DeployFixture is Script {
    using stdJson for string;
    using CreateXLibrary for bytes11;

    // error InvalidAddress(address expected, address output);
    string public constant INVALID_ADDRESS = "DeployFixture: INVALID_ADDRESS";

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    string public jsonConstants;

    /// @dev used by tests to disable logging of output
    bool public isTest;

    function setUp() public virtual;

    function run() external {
        vm.startBroadcast(deployer);
        verifyCreate3();

        deploy();
        logParams();
        logOutput();

        vm.stopBroadcast();
    }

    function deploy() internal virtual;

    function logParams() internal view virtual;

    function logOutput() internal virtual;

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes11 _entropy, address _output) internal view {
        address computedAddress = _entropy.computeCreate3Address({_deployer: deployer});
        require(computedAddress == _output, INVALID_ADDRESS);
    }

    function verifyCreate3() internal view {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        /// if not run locally
        if (chainId != 31337) {
            uint256 size;
            address contractAddress = address(cx);
            assembly {
                size := extcodesize(contractAddress)
            }

            bytes memory bytecode = new bytes(size);
            assembly {
                extcodecopy(contractAddress, add(bytecode, 32), 0, size)
            }

            require(
                keccak256(bytecode) == bytes32(0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f),
                "Verify Create3 failed"
            );
        }
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
