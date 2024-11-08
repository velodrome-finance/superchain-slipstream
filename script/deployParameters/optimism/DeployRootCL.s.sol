// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployRootBaseFixture.s.sol";

contract DeployRootCL is DeployRootBaseFixture {
    function setUp() public override {
        _params = DeployRootBaseFixture.DeploymentParameters({
            voter: 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C,
            xVelo: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81,
            lockbox: 0x12B64dF29590b4F0934070faC96e82e580D60232,
            messageBridge: 0xF278761576f45472bdD721EACA19317cE159c011,
            votingRewardsFactory: 0x7dc9fd82f91B36F416A89f5478375e4a79f4Fb2F,
            poolFactoryOwner: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            notifyAdmin: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            emissionAdmin: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            emissionCap: 150,
            outputFilename: "DeployCL-Optimism.json"
        });
    }
}
