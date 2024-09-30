// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployRootBaseFixture.s.sol";

contract DeployRootCL is DeployRootBaseFixture {
    function setUp() public override {
        _params = DeployRootBaseFixture.DeploymentParameters({
            voter: 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C,
            xVelo: 0xa700b592304b69dDb70d9434F5E90877947f1f05,
            lockbox: 0xF37D648ff7ab53fBe71C4EE66c212f74372f846b,
            messageBridge: 0x0b34Ec8995052783A62692B7F3fF7c856A184dDD,
            votingRewardsFactory: 0xEAc8b42979528447d58779A6a3CaBEb4E4aEdEC5,
            poolFactoryOwner: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            feeManager: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            notifyAdmin: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            emissionAdmin: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            outputFilename: "DeployCL-Optimism.json"
        });
    }
}
