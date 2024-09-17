// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

library Commands {
    uint256 public constant DEPOSIT = 0x00;
    uint256 public constant WITHDRAW = 0x01;
    uint256 public constant CREATE_GAUGE = 0x02;
    uint256 public constant GET_INCENTIVES = 0x03;
    uint256 public constant GET_FEES = 0x04;
    uint256 public constant NOTIFY = 0x05;
}
