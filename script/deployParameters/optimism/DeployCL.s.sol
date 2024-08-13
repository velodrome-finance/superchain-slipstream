// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployBaseFixture.s.sol";

contract DeployCL is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            team: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            weth: 0x4200000000000000000000000000000000000006,
            voter: 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C,
            poolFactoryOwner: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            feeManager: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            notifyAdmin: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            factoryV2: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a,
            nftName: "Slipstream Position NFT v1.2",
            nftSymbol: "VELO-CL-POS",
            outputFilename: "DeployCL-Optimism.json"
        });
    }
}
