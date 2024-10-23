// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IRootIncentiveVotingReward} from "contracts/root/interfaces/rewards/IRootIncentiveVotingReward.sol";
import {IRootMessageBridge} from "contracts/root/interfaces/bridge/IRootMessageBridge.sol";
import {IRootCLGauge} from "contracts/root/interfaces/gauge/IRootCLGauge.sol";
import {IVotingEscrow} from "contracts/core/interfaces/IVotingEscrow.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";

import {Commands} from "contracts/libraries/Commands.sol";

contract MockRootIncentiveVotingReward is IRootIncentiveVotingReward {
    address public immutable override bridge;
    address public immutable override voter;
    address public immutable override ve;
    address public override gauge;
    uint256 public override chainid;

    constructor(address _bridge, address _voter, address[] memory _rewards) {
        voter = _voter;
        bridge = _bridge;
        ve = address(IVoter(_voter).ve());
    }

    /// @inheritdoc IRootIncentiveVotingReward
    function initialize(address _gauge) external override {
        require(gauge == address(0), "AI");
        gauge = _gauge;
        chainid = IRootCLGauge(_gauge).chainid();
    }

    /// @inheritdoc IRootIncentiveVotingReward
    function getReward(uint256 _tokenId, address[] memory _tokens) external override {
        require(IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId) || msg.sender == voter, "NA");

        address _owner = IVotingEscrow(ve).ownerOf(_tokenId);
        bytes memory message = abi.encodePacked(uint8(Commands.GET_INCENTIVES), gauge, _owner, _tokenId, _tokens);

        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootIncentiveVotingReward
    function _deposit(uint256, uint256) external override {}

    /// @inheritdoc IRootIncentiveVotingReward
    function _withdraw(uint256, uint256) external override {}
}
