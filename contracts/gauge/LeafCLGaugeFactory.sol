// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "./interfaces/ILeafCLGaugeFactory.sol";
import "./LeafCLGauge.sol";

import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██╗     ███████╗ █████╗ ███████╗ ██████╗██╗      ██████╗  █████╗ ██╗   ██╗ ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝██╔════╝██║     ██╔════╝ ██╔══██╗██║   ██║██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗  ██║     ██║     ██║  ███╗███████║██║   ██║██║  ███╗█████╗
██║     ██╔══╝  ██╔══██║██╔══╝  ██║     ██║     ██║   ██║██╔══██║██║   ██║██║   ██║██╔══╝
███████╗███████╗██║  ██║██║     ╚██████╗███████╗╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝

███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
█████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝
██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝
██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝

*/

/// @title Velodrome Superchain Leaf CL Gauge Factory
/// @notice Used to deploy Leaf CL Gauge contracts for distribution of emissions
contract LeafCLGaugeFactory is ILeafCLGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc ILeafCLGaugeFactory
    uint256 public constant override MAX_BPS = 10_000;
    /// @inheritdoc ILeafCLGaugeFactory
    uint256 public constant override MAX_MIN_STAKE_TIME = 1 weeks;

    /// @inheritdoc ILeafCLGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ILeafCLGaugeFactory
    address public immutable override xerc20;
    /// @inheritdoc ILeafCLGaugeFactory
    address public immutable override bridge;
    /// @inheritdoc ILeafCLGaugeFactory
    address public immutable override nft;

    /// @inheritdoc ILeafCLGaugeFactory
    address public override gaugeStakeManager;
    /// @inheritdoc ILeafCLGaugeFactory
    uint256 public override defaultMinStakeTime;
    /// @inheritdoc ILeafCLGaugeFactory
    uint256 public override penaltyRate;

    /// @dev Per-pool minimum stake time override (0 = not set, use defaultMinStakeTime)
    mapping(address => uint256) internal _minStakeTimes;

    struct GaugeCreateX {
        uint256 chainid;
        bytes32 salt;
        address pool;
        address token0;
        address token1;
        int24 tickSpacing;
        bytes11 entropy;
    }

    constructor(address _voter, address _nft, address _xerc20, address _bridge, address _gaugeStakeManager) {
        voter = _voter;
        nft = _nft;
        xerc20 = _xerc20;
        bridge = _bridge;
        gaugeStakeManager = _gaugeStakeManager;
    }

    /// @inheritdoc ILeafCLGaugeFactory
    function minStakeTimes(address _pool) public view override returns (uint256) {
        uint256 poolMinStakeTime = _minStakeTimes[_pool];
        return poolMinStakeTime == 0 ? defaultMinStakeTime : poolMinStakeTime;
    }

    /// @inheritdoc ILeafCLGaugeFactory
    function setGaugeStakeManager(address _manager) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_manager != address(0), "ZA");
        gaugeStakeManager = _manager;
        emit SetGaugeStakeManager({_gaugeStakeManager: _manager});
    }

    /// @inheritdoc ILeafCLGaugeFactory
    function setDefaultMinStakeTime(uint256 _minStakeTime) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_minStakeTime <= MAX_MIN_STAKE_TIME, "MS");
        defaultMinStakeTime = _minStakeTime;
        emit SetDefaultMinStakeTime({_minStakeTime: _minStakeTime});
    }

    /// @inheritdoc ILeafCLGaugeFactory
    function setMinStakeTime(address _pool, uint256 _minStakeTime) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_pool != address(0), "ZA");
        require(_minStakeTime <= MAX_MIN_STAKE_TIME, "MS");
        _minStakeTimes[_pool] = _minStakeTime;
        emit SetPoolMinStakeTime({_pool: _pool, _minStakeTime: _minStakeTime});
    }

    /// @inheritdoc ILeafCLGaugeFactory
    function setPenaltyRate(uint256 _penaltyRate) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_penaltyRate <= MAX_BPS, "MR");
        penaltyRate = _penaltyRate;
        emit SetPenaltyRate({_penaltyRate: _penaltyRate});
    }

    /// @inheritdoc ILeafCLGaugeFactory
    function createGauge(address _pool, address _feesVotingReward, bool _isPool)
        external
        virtual
        override
        returns (address gauge)
    {
        require(msg.sender == voter, "NV");
        GaugeCreateX memory gcx;

        gcx.pool = _pool;

        assembly {
            let chainId := chainid()
            mstore(gcx, chainId)
        }

        gcx.token0 = ICLPool(_pool).token0();
        gcx.token1 = ICLPool(_pool).token1();
        gcx.tickSpacing = ICLPool(_pool).tickSpacing();
        gcx.salt = keccak256(abi.encodePacked(gcx.chainid, gcx.token0, gcx.token1, gcx.tickSpacing));
        gcx.entropy = bytes11(gcx.salt);

        bytes memory args = abi.encode(
            gcx.pool,
            gcx.token0,
            gcx.token1,
            gcx.tickSpacing,
            _feesVotingReward, // fee contract
            xerc20, // xerc20 corresponding to reward token
            voter, // superchain voter contract
            nft, // nft (nfpm) contract
            bridge, // bridge to communicate x-chain
            address(this), // gauge factory
            _isPool
        );

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: gcx.entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(type(LeafCLGauge).creationCode, args)
        });
    }
}
