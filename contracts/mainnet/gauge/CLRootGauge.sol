// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {ICLRootGauge} from "contracts/mainnet/gauge/ICLRootGauge.sol";
import {IXERC20Lockbox} from "contracts/superchain/IXERC20Lockbox.sol";
import {IBridge} from "contracts/superchain/IBridge.sol";

/// @notice RootGauge that forward emissions to the corresponding LeafGauge on the leaf chain
contract CLRootGauge is ICLRootGauge {
    using SafeERC20 for IERC20;

    /// @inheritdoc ICLRootGauge
    address public immutable override rewardToken;
    /// @inheritdoc ICLRootGauge
    address public immutable override xerc20;
    /// @inheritdoc ICLRootGauge
    address public immutable override lockbox;
    /// @inheritdoc ICLRootGauge
    address public immutable override bridge;
    /// @inheritdoc ICLRootGauge
    uint256 public immutable override chainid;

    constructor(address _rewardToken, address _xerc20, address _lockbox, address _bridge, uint256 _chainid) {
        rewardToken = _rewardToken;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        bridge = _bridge;
        chainid = _chainid;
    }

    /// @inheritdoc ICLRootGauge
    function left() external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc ICLRootGauge
    function notifyRewardAmount(uint256 _amount) external override {
        IERC20(rewardToken).transferFrom(msg.sender, address(this), _amount);

        IERC20(rewardToken).safeIncreaseAllowance({spender: lockbox, value: _amount});
        IXERC20Lockbox(lockbox).deposit({_amount: _amount});

        IERC20(xerc20).safeIncreaseAllowance({spender: bridge, value: _amount});
        IBridge(bridge).sendToken({_amount: _amount, _chainid: uint32(chainid)});

        emit NotifyReward({_sender: msg.sender, _amount: _amount});
    }
}
