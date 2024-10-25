// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "../interfaces/ICLPool.sol";
import "../interfaces/fees/ICustomFeeModule.sol";

contract CustomUnstakedFeeModule is ICustomFeeModule {
    /// @inheritdoc IFeeModule
    ICLFactory public immutable override factory;
    /// @inheritdoc ICustomFeeModule
    mapping(address => uint24) public override customFee;

    uint256 public constant MAX_FEE = 500_000; // 50%
    // Override to indicate there is custom 0% fee - as a 0 value in the customFee mapping indicates
    // that no custom fee rate has been set
    uint256 public constant ZERO_FEE_INDICATOR = 420;

    constructor(address _factory) {
        factory = ICLFactory(_factory);
    }

    /// @inheritdoc ICustomFeeModule
    function setCustomFee(address pool, uint24 fee) external override {
        require(msg.sender == factory.unstakedFeeManager());
        require(fee <= MAX_FEE || fee == ZERO_FEE_INDICATOR);
        require(factory.isPair(pool));

        customFee[pool] = fee;
        emit SetCustomFee(pool, fee);
    }

    /// @inheritdoc IFeeModule
    function getFee(address pool) external view override returns (uint24) {
        uint24 fee = customFee[pool];
        return fee == ZERO_FEE_INDICATOR ? 0 : fee != 0 ? fee : 100_000; // Default fee is 10%
    }
}
