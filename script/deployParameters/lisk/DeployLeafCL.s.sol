// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployLeafBaseFixture.s.sol";

contract DeployLeafCL is DeployLeafBaseFixture {
    function setUp() public override {
        _params = DeployLeafBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            leafVoter: 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123,
            factoryV2: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            xVelo: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81,
            messageBridge: 0xF278761576f45472bdD721EACA19317cE159c011,
            team: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            poolFactoryOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            feeManager: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            nftName: "Slipstream Position NFT v1.2",
            nftSymbol: "VELO-CL-POS",
            outputFilename: "lisk.json"
        });
    }
}
