// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {ILeafMessageBridge} from "contracts/superchain/ILeafMessageBridge.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IXERC20} from "contracts/superchain/IXERC20.sol";

contract MockLeafMessageBridge is ILeafMessageBridge, Ownable {
    /// @inheritdoc ILeafMessageBridge
    address public immutable override xerc20;
    /// @inheritdoc ILeafMessageBridge
    address public immutable override voter;
    /// @inheritdoc ILeafMessageBridge
    address public override module;

    constructor(address _owner, address _xerc20, address _voter, address _module) Ownable() {
        xerc20 = _xerc20;
        voter = _voter;
        module = _module;
    }

    /// @inheritdoc ILeafMessageBridge
    function setModule(address _module) external override onlyOwner {
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc ILeafMessageBridge
    function mint(address _recipient, uint256 _amount) external override {
        IXERC20(xerc20).mint({_user: _recipient, _amount: _amount});
    }
}
