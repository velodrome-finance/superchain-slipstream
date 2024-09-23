// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {ICLRootGauge} from "contracts/mainnet/gauge/ICLRootGauge.sol";
import {ICLRootGaugeFactory} from "contracts/mainnet/gauge/ICLRootGaugeFactory.sol";

import {VelodromeTimeLibrary} from "contracts/libraries/VelodromeTimeLibrary.sol";
import {IXERC20Lockbox} from "contracts/superchain/IXERC20Lockbox.sol";
import {IBridge} from "contracts/superchain/IBridge.sol";
import {IRootMessageBridge} from "contracts/mainnet/interfaces/bridge/IRootMessageBridge.sol";
import {Commands} from "contracts/libraries/Commands.sol";

/// @notice RootGauge that forward emissions to the corresponding LeafGauge on the leaf chain
contract CLRootGauge is ICLRootGauge {
    using SafeERC20 for IERC20;

    /// @inheritdoc ICLRootGauge
    address public immutable override gaugeFactory;
    /// @inheritdoc ICLRootGauge
    address public immutable override rewardToken;
    /// @inheritdoc ICLRootGauge
    address public immutable override xerc20;
    /// @inheritdoc ICLRootGauge
    address public immutable override voter;
    /// @inheritdoc ICLRootGauge
    address public immutable override lockbox;
    /// @inheritdoc ICLRootGauge
    address public immutable override bridge;
    /// @inheritdoc ICLRootGauge
    uint256 public immutable override chainid;

    constructor(
        address _gaugeFactory,
        address _rewardToken,
        address _xerc20,
        address _lockbox,
        address _bridge,
        address _voter,
        uint256 _chainid
    ) {
        gaugeFactory = _gaugeFactory;
        rewardToken = _rewardToken;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        bridge = _bridge;
        voter = _voter;
        chainid = _chainid;
    }

    /// @inheritdoc ICLRootGauge
    function left() external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc ICLRootGauge
    function notifyRewardAmount(uint256 _amount) external override {
        require(msg.sender == voter, "NV");
        _notify({_command: Commands.NOTIFY, _amount: _amount});
    }

    /// @inheritdoc ICLRootGauge
    function notifyRewardWithoutClaim(uint256 _amount) external override {
        require(msg.sender == ICLRootGaugeFactory(gaugeFactory).notifyAdmin(), "NA");
        require(_amount >= VelodromeTimeLibrary.WEEK, "ZRR");
        _notify({_command: Commands.NOTIFY_WITHOUT_CLAIM, _amount: _amount});
    }

    function _notify(uint256 _command, uint256 _amount) internal {
        IERC20(rewardToken).transferFrom(msg.sender, address(this), _amount);

        IERC20(rewardToken).safeIncreaseAllowance({spender: lockbox, value: _amount});
        IXERC20Lockbox(lockbox).deposit({_amount: _amount});

        IERC20(xerc20).safeIncreaseAllowance({spender: bridge, value: _amount});

        bytes memory payload = abi.encode(address(this), _amount);
        bytes memory message = abi.encode(_command, payload);
        IRootMessageBridge(bridge).sendMessage({_chainid: uint32(chainid), _message: message});

        emit NotifyReward({from: msg.sender, amount: _amount});
    }
}
