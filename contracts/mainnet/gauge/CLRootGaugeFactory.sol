// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CreateXLibrary} from "../../libraries/CreateXLibrary.sol";
import {ICLRootGaugeFactory} from "../../mainnet/gauge/ICLRootGaugeFactory.sol";
import {IRootCLPool} from "../../mainnet/pool/IRootCLPool.sol";
import {CLRootGauge} from "../../mainnet/gauge/CLRootGauge.sol";
import {IRootBribeVotingReward} from "../../mainnet/interfaces/rewards/IRootBribeVotingReward.sol";
import {IRootFeesVotingReward} from "../../mainnet/interfaces/rewards/IRootFeesVotingReward.sol";
import {Commands} from "../../libraries/Commands.sol";
import {IRootMessageBridge} from "../../mainnet/interfaces/bridge/IRootMessageBridge.sol";
import {IVoter} from "../../core/interfaces/IVoter.sol";
import {IMinter} from "../../core/interfaces/IMinter.sol";

/// @notice Factory that creates root gauges on mainnet
contract CLRootGaugeFactory is ICLRootGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override rewardToken;
    /// @inheritdoc ICLRootGaugeFactory
    address public override minter;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override xerc20;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override lockbox;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override messageBridge;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override poolFactory;
    /// @inheritdoc ICLRootGaugeFactory
    address public immutable override votingRewardsFactory;
    /// @inheritdoc ICLRootGaugeFactory
    address public override emissionAdmin;
    /// @inheritdoc ICLRootGaugeFactory
    uint256 public override defaultCap;
    /// @inheritdoc ICLRootGaugeFactory
    address public override notifyAdmin;
    /// @inheritdoc ICLRootGaugeFactory
    uint256 public override weeklyEmissions;
    /// @inheritdoc ICLRootGaugeFactory
    uint256 public override activePeriod;

    // @notice Emission cap for each gauge
    mapping(address => uint256) internal _emissionCaps;

    /// @inheritdoc ICLRootGaugeFactory
    uint256 public constant override MAX_BPS = 10_000;
    /// @inheritdoc ICLRootGaugeFactory
    uint256 public constant override WEEKLY_DECAY = 9_900;
    /// @inheritdoc ICLRootGaugeFactory
    uint256 public constant override TAIL_START_TIMESTAMP = 1743638400;

    constructor(
        address _voter,
        address _xerc20,
        address _lockbox,
        address _messageBridge,
        address _poolFactory,
        address _votingRewardsFactory,
        address _notifyAdmin,
        address _emissionAdmin,
        uint256 _defaultCap
    ) {
        voter = _voter;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        messageBridge = _messageBridge;
        poolFactory = _poolFactory;
        votingRewardsFactory = _votingRewardsFactory;
        notifyAdmin = _notifyAdmin;
        emissionAdmin = _emissionAdmin;
        defaultCap = _defaultCap;
        minter = IVoter(_voter).minter();
        rewardToken = IMinter(minter).velo();
    }

    /// @inheritdoc ICLRootGaugeFactory
    function emissionCaps(address _gauge) public view override returns (uint256) {
        uint256 emissionCap = _emissionCaps[_gauge];
        return emissionCap == 0 ? defaultCap : emissionCap;
    }

    /// @inheritdoc ICLRootGaugeFactory
    function setNotifyAdmin(address _admin) external override {
        require(notifyAdmin == msg.sender, "NA");
        require(_admin != address(0), "ZA");
        notifyAdmin = _admin;
        emit SetNotifyAdmin({notifyAdmin: _admin});
    }

    /// @inheritdoc ICLRootGaugeFactory
    function createGauge(address, address _pool, address _feesVotingReward, address _rewardToken, bool)
        external
        override
        returns (address gauge)
    {
        require(msg.sender == voter, "NV");
        address token0 = IRootCLPool(_pool).token0();
        address token1 = IRootCLPool(_pool).token1();
        int24 tickSpacing = IRootCLPool(_pool).tickSpacing();
        uint256 chainId = IRootCLPool(_pool).chainId();
        bytes32 salt = keccak256(abi.encodePacked(chainId, token0, token1, tickSpacing));
        bytes11 entropy = bytes11(salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(CLRootGauge).creationCode,
                abi.encode(
                    address(this), // gauge factory
                    _rewardToken, // reward token
                    xerc20, // xerc20 corresponding to reward token
                    lockbox, // lockbox to convert reward token to xerc20
                    messageBridge, // bridge to communicate x-chain
                    voter, // voter contract
                    chainId // chain id associated with gauge
                )
            )
        });

        address _bribeVotingReward = IRootFeesVotingReward(_feesVotingReward).bribeVotingReward();
        IRootFeesVotingReward(_feesVotingReward).initialize(gauge);
        IRootBribeVotingReward(_bribeVotingReward).initialize(gauge);

        bytes memory payload = abi.encode(votingRewardsFactory, address(this), token0, token1, uint24(tickSpacing));
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, abi.encode(poolFactory, payload));
        IRootMessageBridge(messageBridge).sendMessage({_chainid: chainId, _message: message});
    }

    /// @inheritdoc ICLRootGaugeFactory
    function calculateMaxEmissions(address _gauge) external override returns (uint256) {
        uint256 _activePeriod = IMinter(minter).activePeriod();
        uint256 maxRate = emissionCaps({_gauge: _gauge});

        if (activePeriod != _activePeriod) {
            uint256 _weeklyEmissions;
            if (_activePeriod < TAIL_START_TIMESTAMP) {
                // @dev Calculate weekly emissions before decay
                _weeklyEmissions = (IMinter(minter).weekly() * MAX_BPS) / WEEKLY_DECAY;
            } else {
                // @dev Calculate tail emissions
                // Tail emissions are slightly inflated since `totalSupply` includes this week's emissions
                // The difference is negligible as weekly emissions are a small percentage of `totalSupply`
                uint256 totalSupply = IERC20(rewardToken).totalSupply();
                _weeklyEmissions = (totalSupply * IMinter(minter).tailEmissionRate()) / MAX_BPS;
            }

            activePeriod = _activePeriod;
            weeklyEmissions = _weeklyEmissions;
            return (_weeklyEmissions * maxRate) / MAX_BPS;
        } else {
            return (weeklyEmissions * maxRate) / MAX_BPS;
        }
    }

    /// @inheritdoc ICLRootGaugeFactory
    function setEmissionAdmin(address _admin) external override {
        require(msg.sender == emissionAdmin, "NA");
        require(_admin != address(0), "ZA");
        emissionAdmin = _admin;
        emit SetEmissionAdmin({emissionAdmin: _admin});
    }

    /// @inheritdoc ICLRootGaugeFactory
    function setEmissionCap(address _gauge, uint256 _emissionCap) external override {
        require(msg.sender == emissionAdmin, "NA");
        require(_gauge != address(0), "ZA");
        _emissionCaps[_gauge] = _emissionCap;
        emit SetEmissionCap({gauge: _gauge, newEmissionCap: _emissionCap});
    }

    /// @inheritdoc ICLRootGaugeFactory
    function setDefaultCap(uint256 _defaultCap) external override {
        require(msg.sender == emissionAdmin, "NA");
        require(_defaultCap != 0, "ZDC");
        defaultCap = _defaultCap;
        emit SetDefaultCap({newDefaultCap: _defaultCap});
    }
}
