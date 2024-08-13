// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "./DeployFixture.sol";

import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";

abstract contract DeployPositionDescriptorBaseFixture is DeployFixture {
    using stdJson for string;
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address weth;
        bytes32 nativeCurrencyLabelBytes;
        string outputFilename;
    }

    // deployed
    NonfungibleTokenPositionDescriptor public nftDescriptor;

    DeploymentParameters internal _params;

    /// @dev Entropy used for deterministic deployments across chains
    bytes11 public constant NFT_POSITION_DESCRIPTOR = 0x0000000000000000000003;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        // deploy nft contracts
        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: _params.weth,
            _nativeCurrencyLabelBytes: _params.nativeCurrencyLabelBytes
        });
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console2.log("Nonfungible Position Descriptor contract deployed at: ", address(nftDescriptor));
    }

    function logOutput() internal override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev Only writes to file if the key "NonFungibleTokenPositionDescriptor" is present
        vm.writeJson(vm.toString(address(nftDescriptor)), path, ".NonfungibleTokenPositionDescriptor");
    }
}
