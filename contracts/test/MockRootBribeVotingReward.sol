// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IRootBribeVotingReward} from "contracts/mainnet/interfaces/rewards/IRootBribeVotingReward.sol";
import {IRootMessageBridge} from "contracts/mainnet/interfaces/bridge/IRootMessageBridge.sol";
import {IRootCLGauge} from "contracts/mainnet/gauge/IRootCLGauge.sol";
import {IVotingEscrow} from "contracts/core/interfaces/IVotingEscrow.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";

import {Commands} from "contracts/libraries/Commands.sol";

contract MockRootBribeVotingReward is IRootBribeVotingReward {
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

    /// @inheritdoc IRootBribeVotingReward
    function initialize(address _gauge) external override {
        require(gauge == address(0), "AI");
        gauge = _gauge;
        chainid = IRootCLGauge(_gauge).chainid();
    }

    /// @inheritdoc IRootBribeVotingReward
    function getReward(uint256 _tokenId, address[] memory _tokens) external override {
        require(IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId) || msg.sender == voter, "NA");

        address _owner = IVotingEscrow(ve).ownerOf(_tokenId);
        bytes memory payload = abi.encode(_owner, _tokenId, _tokens);
        bytes memory message = abi.encode(Commands.GET_INCENTIVES, abi.encode(gauge, payload));

        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootBribeVotingReward
    function _deposit(uint256, uint256) external override {}

    /// @inheritdoc IRootBribeVotingReward
    function _withdraw(uint256, uint256) external override {}
}
