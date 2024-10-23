// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IRootFeesVotingReward} from "contracts/root/interfaces/rewards/IRootFeesVotingReward.sol";
import {IRootMessageBridge} from "contracts/root/interfaces/bridge/IRootMessageBridge.sol";
import {IRootCLGauge} from "contracts/root/interfaces/gauge/IRootCLGauge.sol";
import {IVotingEscrow} from "contracts/test/MockVotingEscrow.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";

import {Commands} from "contracts/libraries/Commands.sol";

contract MockRootFeesVotingReward is IRootFeesVotingReward {
    /// @inheritdoc IRootFeesVotingReward
    address public immutable override bridge;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable override voter;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable override ve;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable override incentiveVotingReward;
    /// @inheritdoc IRootFeesVotingReward
    address public override gauge;
    /// @inheritdoc IRootFeesVotingReward
    uint256 public override chainid;

    constructor(address _bridge, address _voter, address _incentiveVotingReward, address[] memory _rewards) {
        voter = _voter;
        bridge = _bridge;
        ve = address(IVoter(_voter).ve());
        incentiveVotingReward = _incentiveVotingReward;
    }

    /// @inheritdoc IRootFeesVotingReward
    function initialize(address _gauge) external override {
        require(gauge == address(0), "AI");
        gauge = _gauge;
        chainid = IRootCLGauge(_gauge).chainid();
    }

    /// @inheritdoc IRootFeesVotingReward
    function _deposit(uint256 _amount, uint256 _tokenId) external override {
        require(msg.sender == voter, "NV");

        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), gauge, _amount, _tokenId);
        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootFeesVotingReward
    function _withdraw(uint256 _amount, uint256 _tokenId) external override {
        require(msg.sender == voter, "NA");

        bytes memory message = abi.encodePacked(uint8(Commands.WITHDRAW), gauge, _amount, _tokenId);
        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootFeesVotingReward
    function getReward(uint256 _tokenId, address[] memory _tokens) external override {
        require(IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId) || msg.sender == voter, "NA");

        address _owner = IVotingEscrow(ve).ownerOf(_tokenId);
        bytes memory message = abi.encodePacked(uint8(Commands.GET_FEES), gauge, _owner, _tokenId, _tokens);

        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }
}
