// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IMessageRecipient {
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable;
}
