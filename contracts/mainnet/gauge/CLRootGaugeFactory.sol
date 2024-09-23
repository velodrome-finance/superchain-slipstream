// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";
import {ICLRootGaugeFactory} from "contracts/mainnet/gauge/ICLRootGaugeFactory.sol";
import {IRootCLPool} from "contracts/mainnet/pool/IRootCLPool.sol";
import {CLRootGauge} from "contracts/mainnet/gauge/CLRootGauge.sol";
import {IRootBribeVotingReward} from "contracts/mainnet/interfaces/rewards/IRootBribeVotingReward.sol";
import {IRootFeesVotingReward} from "contracts/mainnet/interfaces/rewards/IRootFeesVotingReward.sol";
import {Commands} from "contracts/libraries/Commands.sol";
import {IRootMessageBridge} from "contracts/mainnet/interfaces/bridge/IRootMessageBridge.sol";

/// @notice Factory that creates root gauges on mainnet
contract CLRootGaugeFactory is ICLRootGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override xerc20;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override lockbox;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override messageBridge;

    constructor(address _voter, address _xerc20, address _lockbox, address _messageBridge) {
        voter = _voter;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        messageBridge = _messageBridge;
    }

    /// @inheritdoc ICLRootGaugeFactory
    function createGauge(address, address _pool, address _feesVotingReward, address _rewardToken, bool)
        external
        override
        returns (address gauge)
    {
        require(msg.sender == voter, "NV");
        address token0 = IRootCLPool(_pool).token0();
        address token1 = IRootCLPool(_pool).token1();
        int24 tickSpacing = IRootCLPool(_pool).tickSpacing();
        uint256 chainId = IRootCLPool(_pool).chainId();
        bytes32 salt = keccak256(abi.encodePacked(chainId, token0, token1, tickSpacing));
        bytes11 entropy = bytes11(salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(CLRootGauge).creationCode,
                abi.encode(
                    _rewardToken, // reward token
                    xerc20, // xerc20 corresponding to reward token
                    lockbox, // lockbox to convert reward token to xerc20
                    messageBridge, // bridge to communicate x-chain
                    chainId // chain id associated with gauge
                )
            )
        });

        address _bribeVotingReward = IRootFeesVotingReward(_feesVotingReward).bribeVotingReward();
        IRootFeesVotingReward(_feesVotingReward).initialize(gauge);
        IRootBribeVotingReward(_bribeVotingReward).initialize(gauge);

        bytes memory payload = abi.encode(token0, token1, tickSpacing);
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, payload);
        IRootMessageBridge(messageBridge).sendMessage({_chainid: chainId, _message: message});
    }
}
