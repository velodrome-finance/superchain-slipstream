// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/DeployPositionDescriptorBaseFixture.s.sol";

contract DeployPositionDescriptor is DeployPositionDescriptorBaseFixture {
    function setUp() public override {
        _params = DeployPositionDescriptorBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000, // 'ETH' as bytes32 string
            outputFilename: "DeployCL-Mode.json"
        });
    }
}
