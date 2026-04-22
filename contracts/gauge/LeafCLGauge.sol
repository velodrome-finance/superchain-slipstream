// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ILeafCLGauge} from "contracts/gauge/interfaces/ILeafCLGauge.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";
import {ICLPool} from "contracts/gauge/interfaces/ICLPool.sol";
import {INonfungiblePositionManager} from "contracts/gauge/interfaces/INonfungiblePositionManager.sol";
import {EnumerableSet} from "contracts/libraries/EnumerableSet.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {VelodromeTimeLibrary} from "contracts/libraries/VelodromeTimeLibrary.sol";
import {IReward} from "contracts/gauge/interfaces/IReward.sol";
import {ILeafMessageBridge} from "contracts/superchain/ILeafMessageBridge.sol";
import {ILeafCLGaugeFactory} from "contracts/gauge/interfaces/ILeafCLGaugeFactory.sol";

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

*/

/// @title Velodrome Superchain Leaf CL Gauge Contracts
/// @notice Leaf gauge contract for distribution of emissions by address
contract LeafCLGauge is ILeafCLGauge, ERC721Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using SafeCast for uint128;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
    uint256 private constant MAX_BPS = 10_000;

    /// @inheritdoc ILeafCLGauge
    INonfungiblePositionManager public immutable override nft;
    /// @inheritdoc ILeafCLGauge
    IVoter public immutable override voter;
    /// @inheritdoc ILeafCLGauge
    ICLPool public immutable override pool;

    /// @inheritdoc ILeafCLGauge
    address public immutable override bridge;
    /// @inheritdoc ILeafCLGauge
    address public immutable override gaugeFactory;

    /// @inheritdoc ILeafCLGauge
    address public immutable override feesVotingReward;
    /// @inheritdoc ILeafCLGauge
    address public immutable override rewardToken;

    /// @inheritdoc ILeafCLGauge
    uint256 public override periodFinish;
    /// @inheritdoc ILeafCLGauge
    uint256 public override rewardRate;

    mapping(uint256 => uint256) public override rewardRateByEpoch; // epochStart => rewardRate
    /// @dev The set of all staked nfts for a given address
    mapping(address => EnumerableSet.UintSet) internal _stakes;
    /// @inheritdoc ILeafCLGauge
    mapping(uint256 => uint256) public override rewardGrowthInside;

    /// @inheritdoc ILeafCLGauge
    mapping(uint256 => uint256) public override rewards;
    /// @inheritdoc ILeafCLGauge
    mapping(uint256 => uint256) public override lastUpdateTime;
    /// @inheritdoc ILeafCLGauge
    mapping(uint256 => uint256) public override depositTimestamp;

    /// @inheritdoc ILeafCLGauge
    uint256 public override penaltyBuffer;

    /// @inheritdoc ILeafCLGauge
    uint256 public override fees0;
    /// @inheritdoc ILeafCLGauge
    uint256 public override fees1;
    /// @inheritdoc ILeafCLGauge
    address public immutable override token0;
    /// @inheritdoc ILeafCLGauge
    address public immutable override token1;
    /// @inheritdoc ILeafCLGauge
    int24 public immutable override tickSpacing;

    bool public immutable override isPool;

    constructor(
        address _pool,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _nft,
        address _bridge,
        address _gaugeFactory,
        bool _isPool
    ) {
        pool = ICLPool(_pool);
        token0 = _token0;
        token1 = _token1;
        tickSpacing = _tickSpacing;
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        voter = IVoter(_voter);
        nft = INonfungiblePositionManager(_nft);
        bridge = _bridge;
        gaugeFactory = _gaugeFactory;
        isPool = _isPool;
    }

    // updates the claimable rewards and lastUpdateTime for tokenId
    function _updateRewards(uint256 tokenId, int24 tickLower, int24 tickUpper) internal {
        if (lastUpdateTime[tokenId] == block.timestamp) return;
        pool.updateRewardsGrowthGlobal();
        lastUpdateTime[tokenId] = block.timestamp;
        rewards[tokenId] += _earned(tokenId);
        rewardGrowthInside[tokenId] = pool.getRewardGrowthInside(tickLower, tickUpper, 0);
    }

    /// @inheritdoc ILeafCLGauge
    function earned(address account, uint256 tokenId) external view override returns (uint256) {
        require(_stakes[account].contains(tokenId), "NA");

        uint256 claimable = rewards[tokenId] + _earned(tokenId);
        if (claimable > 0) {
            claimable -= _applyPenalty(claimable, tokenId);
        }
        return claimable;
    }

    function _earned(uint256 tokenId) internal view returns (uint256) {
        uint256 lastUpdated = pool.lastUpdated();

        uint256 timeDelta = block.timestamp - lastUpdated;

        uint256 rewardGrowthGlobalX128 = pool.rewardGrowthGlobalX128();
        uint256 rewardReserve = pool.rewardReserve();

        if (timeDelta != 0 && rewardReserve > 0 && pool.stakedLiquidity() > 0) {
            uint256 reward = rewardRate * timeDelta;
            if (reward > rewardReserve) reward = rewardReserve;

            rewardGrowthGlobalX128 += FullMath.mulDiv(reward, Q128, pool.stakedLiquidity());
        }

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = nft.positions(tokenId);

        uint256 rewardPerTokenInsideInitialX128 = rewardGrowthInside[tokenId];
        uint256 rewardPerTokenInsideX128 = pool.getRewardGrowthInside(tickLower, tickUpper, rewardGrowthGlobalX128);

        uint256 claimable = FullMath.mulDiv(rewardPerTokenInsideX128 - rewardPerTokenInsideInitialX128, liquidity, Q128);
        return claimable;
    }

    /// @inheritdoc ILeafCLGauge
    function getReward(address account) external override nonReentrant {
        require(msg.sender == address(voter), "NV");

        uint256[] memory tokenIds = _stakes[account].values();
        uint256 length = tokenIds.length;
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
        for (uint256 i = 0; i < length; i++) {
            tokenId = tokenIds[i];
            (,,,,, tickLower, tickUpper,,,,,) = nft.positions(tokenId);
            _getReward(tickLower, tickUpper, tokenId, account);
        }
    }

    /// @inheritdoc ILeafCLGauge
    function getReward(uint256 tokenId) external override nonReentrant {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nft.positions(tokenId);
        _getReward(tickLower, tickUpper, tokenId, msg.sender);
    }

    function _getReward(int24 tickLower, int24 tickUpper, uint256 tokenId, address owner) internal {
        _updateRewards(tokenId, tickLower, tickUpper);

        uint256 reward = rewards[tokenId];

        if (reward > 0) {
            delete rewards[tokenId];
            uint256 penalty = _applyPenalty(reward, tokenId);
            if (penalty > 0) {
                reward -= penalty;
                penaltyBuffer += penalty;
                emit EarlyWithdrawPenalty(owner, tokenId, penalty);
            }
            if (reward > 0) {
                IERC20(rewardToken).safeTransfer(owner, reward);
                emit ClaimRewards(owner, reward);
            }
        }
    }

    function _applyPenalty(uint256 reward, uint256 tokenId) internal view returns (uint256 penalty) {
        uint256 _penaltyRate = ILeafCLGaugeFactory(gaugeFactory).penaltyRate();
        if (
            _penaltyRate > 0
                && block.timestamp
                    < depositTimestamp[tokenId] + ILeafCLGaugeFactory(gaugeFactory).minStakeTimes(address(pool))
        ) {
            penalty = reward * _penaltyRate / MAX_BPS;
        }
    }

    /// @inheritdoc ILeafCLGauge
    function deposit(uint256 tokenId) external override nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "NA");
        require(voter.isAlive(address(this)), "GK");
        (,, address _token0, address _token1, int24 _tickSpacing, int24 tickLower, int24 tickUpper,,,,,) =
            nft.positions(tokenId);
        require(token0 == _token0 && token1 == _token1 && tickSpacing == _tickSpacing, "PM");

        // trigger update on staked position so NFT will be in sync with the pool
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _stakes[msg.sender].add(tokenId);

        (,,,,,,, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        pool.stake((uint256(liquidityToStake).toInt256()).toInt128(), tickLower, tickUpper);

        uint256 rewardGrowth = pool.getRewardGrowthInside(tickLower, tickUpper, 0);
        rewardGrowthInside[tokenId] = rewardGrowth;
        lastUpdateTime[tokenId] = block.timestamp;
        depositTimestamp[tokenId] = block.timestamp;

        emit Deposit(msg.sender, tokenId, liquidityToStake);
    }

    /// @inheritdoc ILeafCLGauge
    function withdraw(uint256 tokenId) external override nonReentrant {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        // trigger update on staked position so NFT will be in sync with the pool
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        _getReward(tickLower, tickUpper, tokenId, msg.sender);

        pool.stake(-(uint256(liquidityToStake).toInt256()).toInt128(), tickLower, tickUpper);

        _stakes[msg.sender].remove(tokenId);
        delete depositTimestamp[tokenId];
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(msg.sender, tokenId, liquidityToStake);
    }

    /// @inheritdoc ILeafCLGauge
    function stakedValues(address depositor) external view override returns (uint256[] memory staked) {
        uint256 length = _stakes[depositor].length();
        staked = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            staked[i] = _stakes[depositor].at(i);
        }
    }

    /// @inheritdoc ILeafCLGauge
    function stakedByIndex(address depositor, uint256 index) external view override returns (uint256) {
        return _stakes[depositor].at(index);
    }

    /// @inheritdoc ILeafCLGauge
    function stakedContains(address depositor, uint256 tokenId) external view override returns (bool) {
        return _stakes[depositor].contains(tokenId);
    }

    /// @inheritdoc ILeafCLGauge
    function stakedLength(address depositor) external view override returns (uint256) {
        return _stakes[depositor].length();
    }

    function left() external view override returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc ILeafCLGauge
    function notifyRewardAmount(uint256 _amount) external override nonReentrant {
        address sender = msg.sender;
        require(sender == ILeafMessageBridge(bridge).module(), "NM");
        require(_amount != 0, "ZR");
        _claimFees();
        _notifyRewardAmount(sender, _amount);
    }

    /// @inheritdoc ILeafCLGauge
    function notifyRewardWithoutClaim(uint256 _amount) external override nonReentrant {
        address sender = msg.sender;
        require(sender == ILeafMessageBridge(bridge).module(), "NM");
        require(_amount != 0, "ZR");
        _notifyRewardAmount(sender, _amount);
    }

    function _notifyRewardAmount(address _sender, uint256 _amount) internal {
        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(timestamp) - timestamp;
        pool.updateRewardsGrowthGlobal();
        uint256 nextPeriodFinish = timestamp + timeUntilNext;

        IERC20(rewardToken).safeTransferFrom(_sender, address(this), _amount);
        // rolling over stuck rewards from previous epoch (if any)
        _amount += pool.rollover();

        if (timestamp >= periodFinish) {
            // Sweep buffered penalties from early withdrawals
            uint256 _buffered = penaltyBuffer;
            if (_buffered > 0) {
                _amount += _buffered;
                delete penaltyBuffer;
            }
            rewardRate = _amount / timeUntilNext;
            pool.syncReward({rewardRate: rewardRate, rewardReserve: _amount, periodFinish: nextPeriodFinish});
        } else {
            uint256 _leftover = timeUntilNext * rewardRate;
            rewardRate = (_amount + _leftover) / timeUntilNext;
            pool.syncReward({rewardRate: rewardRate, rewardReserve: _amount + _leftover, periodFinish: nextPeriodFinish});
        }
        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(timestamp)] = rewardRate;
        require(rewardRate != 0, "ZRR");

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardRate <= balance / timeUntilNext, "RRH");

        periodFinish = nextPeriodFinish;
        emit NotifyReward(_sender, _amount);
    }

    function _claimFees() internal {
        if (!isPool) return;

        (uint256 claimed0, uint256 claimed1) = pool.collectFees();
        if (claimed0 > 0 || claimed1 > 0) {
            uint256 _fees0 = fees0 + claimed0;
            uint256 _fees1 = fees1 + claimed1;
            address _token0 = token0;
            address _token1 = token1;
            if (_fees0 > VelodromeTimeLibrary.WEEK) {
                fees0 = 0;
                IERC20(_token0).safeIncreaseAllowance(feesVotingReward, _fees0);
                IReward(feesVotingReward).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }
            if (_fees1 > VelodromeTimeLibrary.WEEK) {
                fees1 = 0;
                IERC20(_token1).safeIncreaseAllowance(feesVotingReward, _fees1);
                IReward(feesVotingReward).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }

            emit ClaimFees(msg.sender, claimed0, claimed1);
        }
    }
}
