// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {CLFactory} from "contracts/core/CLFactory.sol";
import {CLLeafGaugeFactory} from "contracts/gauge/CLLeafGaugeFactory.sol";
import {ILeafVoter} from "./interfaces/ILeafVoter.sol";
import {IVotingEscrow} from "contracts/core/interfaces/IVotingEscrow.sol";
import {IFactoryRegistry} from "contracts/core/interfaces/IFactoryRegistry.sol";
import {ICLLeafGauge} from "contracts/gauge/interfaces/ICLLeafGauge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {IVotingRewardsFactory} from "contracts/test/interfaces/IVotingRewardsFactory.sol";

// TODO: WIP copied from MockVoter, needs to be refined
contract LeafVoter is ILeafVoter {
    // mock addresses used for testing gauge creation, a copy is stored in Constants.sol
    address public forwarder = address(11);

    // Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;

    /// @dev pool => gauge
    mapping(address => address) public override gauges;
    /// @dev gauge => isAlive
    mapping(address => bool) public override isAlive;
    mapping(address => address) public override gaugeToFees;
    mapping(address => address) public override gaugeToBribe;

    address public immutable override factoryRegistry;

    address public immutable override emergencyCouncil;
    address public immutable override messageBridge;

    constructor(address _factoryRegistry, address _emergencyCouncil, address _messageBridge) {
        factoryRegistry = _factoryRegistry;
        emergencyCouncil = _emergencyCouncil;
        messageBridge = _messageBridge;
    }

    function createGauge(address _poolFactory, address _pool) external override returns (address) {
        require(IFactoryRegistry(factoryRegistry).isPoolFactoryApproved(_poolFactory));
        (address votingRewardsFactory, address gaugeFactory) =
            IFactoryRegistry(factoryRegistry).factoriesToPoolFactory(_poolFactory);

        /// @dev mimic flow in real voter, note that feesVotingReward and bribeVotingReward are unused mocks
        address[] memory rewards = new address[](2);
        rewards[0] = ICLPool(_pool).token0();
        rewards[1] = ICLPool(_pool).token1();
        (address feesVotingReward, address bribeVotingReward) =
            IVotingRewardsFactory(votingRewardsFactory).createRewards(forwarder, rewards);

        address gauge = CLLeafGaugeFactory(gaugeFactory).createGauge({
            _token0: rewards[0],
            _token1: rewards[1],
            _tickSpacing: ICLPool(_pool).tickSpacing(),
            _feesVotingReward: feesVotingReward,
            _isPool: true
        });
        require(CLFactory(_poolFactory).isPair(_pool));
        isAlive[gauge] = true;
        gauges[_pool] = gauge;
        gaugeToFees[gauge] = feesVotingReward;
        gaugeToBribe[gauge] = bribeVotingReward;
        return gauge;
    }

    function killGauge(address gauge) external override {
        isAlive[gauge] = false;
    }

    function claimRewards(address[] memory _gauges) external override {
        uint256 _length = _gauges.length;
        for (uint256 i = 0; i < _length; i++) {
            ICLLeafGauge(_gauges[i]).getReward(msg.sender);
        }
    }
}
