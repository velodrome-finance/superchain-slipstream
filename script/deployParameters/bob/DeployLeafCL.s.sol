// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployLeafBaseFixture.s.sol";

contract DeployLeafCL is DeployLeafBaseFixture {
    function setUp() public override {
        _params = DeployLeafBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            leafVoter: 0xa0eD3C12C6FD753220b584b6790162f2Cbc81d13,
            factoryV2: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            xVelo: 0xa700b592304b69dDb70d9434F5E90877947f1f05,
            messageBridge: 0x0b34Ec8995052783A62692B7F3fF7c856A184dDD,
            team: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            poolFactoryOwner: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            feeManager: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            nftName: "Slipstream Position NFT v1.2",
            nftSymbol: "VELO-CL-POS",
            outputFilename: "DeployCL-Bob.json"
        });
    }
}
