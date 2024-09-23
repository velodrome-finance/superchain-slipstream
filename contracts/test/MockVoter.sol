// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CLRootGaugeFactory} from "../mainnet/gauge/CLRootGaugeFactory.sol";
import {IVoter} from "../core/interfaces/IVoter.sol";
import {IVotingEscrow} from "../core/interfaces/IVotingEscrow.sol";
import {IFactoryRegistry} from "../core/interfaces/IFactoryRegistry.sol";
import {IRootCLPool} from "../mainnet/pool/IRootCLPool.sol";
import {IRootCLPoolFactory} from "../mainnet/pool/IRootCLPoolFactory.sol";
import {IVotingRewardsFactory} from "../test/interfaces/IVotingRewardsFactory.sol";

contract MockVoter is IVoter {
    // mock addresses used for testing gauge creation, a copy is stored in Constants.sol
    address public forwarder = address(11);

    // Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;

    /// @dev pool => gauge
    mapping(address => address) public override gauges;
    /// @dev gauge => isAlive
    mapping(address => bool) public override isAlive;
    mapping(address => address) public override gaugeToFees;
    mapping(address => address) public override gaugeToBribes;

    IERC20 internal immutable rewardToken;
    IFactoryRegistry public immutable override factoryRegistry;
    IVotingEscrow public immutable override ve;
    address public immutable override emergencyCouncil;

    constructor(address _rewardToken, address _factoryRegistry, address _ve) {
        rewardToken = IERC20(_rewardToken);
        factoryRegistry = IFactoryRegistry(_factoryRegistry);
        ve = IVotingEscrow(_ve);
        emergencyCouncil = msg.sender;
    }

    function claimFees(address[] memory, address[][] memory, uint256) external override {}

    function claimRewards(address[] memory _gauges) external override {}

    function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external override {}

    function distribute(address[] memory) external pure override {
        revert("Not implemented");
    }

    function distribute(address gauge) external override {
        revert("Not implemented");
    }

    function createGauge(address _poolFactory, address _pool) external override returns (address) {
        require(factoryRegistry.isPoolFactoryApproved(_poolFactory));
        (address votingRewardsFactory, address gaugeFactory) = factoryRegistry.factoriesToPoolFactory(_poolFactory);

        /// @dev mimic flow in real voter, note that feesVotingReward and bribeVotingReward are unused mocks
        address[] memory rewards = new address[](2);
        rewards[0] = IRootCLPool(_pool).token0();
        rewards[1] = IRootCLPool(_pool).token1();
        (address feesVotingReward, address bribeVotingReward) =
            IVotingRewardsFactory(votingRewardsFactory).createRewards(forwarder, rewards);

        address gauge =
            CLRootGaugeFactory(gaugeFactory).createGauge(forwarder, _pool, feesVotingReward, address(rewardToken), true);

        require(IRootCLPoolFactory(_poolFactory).isPair(_pool));
        isAlive[gauge] = true;
        gauges[_pool] = gauge;
        gaugeToFees[gauge] = feesVotingReward;
        gaugeToBribes[gauge] = bribeVotingReward;
        return gauge;
    }

    function killGauge(address gauge) external override {
        isAlive[gauge] = false;
    }
}
