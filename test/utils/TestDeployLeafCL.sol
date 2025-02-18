// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployLeafBaseFixture.s.sol";

contract TestDeployLeafCL is DeployLeafBaseFixture {
    constructor(DeployLeafBaseFixture.DeploymentParameters memory _params_) {
        _params = _params_;
        isTest = true;
    }

    function setUp() public override {}
}
