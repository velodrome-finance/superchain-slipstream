// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.7.6;
pragma abicoder v2;

interface IMultichainMockMailbox {
    function setDomainForkId(uint32 _domain, uint256 _forkId) external;

    function addRemoteMailbox(uint32 _domain, address _mailbox) external;

    function processNextInboundMessage() external;
}
