// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "contracts/core/interfaces/ICLPool.sol";
import "contracts/core/libraries/FixedPoint128.sol";
import "contracts/core/libraries/FullMath.sol";

import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/INonfungibleTokenPositionDescriptor.sol";
import "./libraries/PositionKey.sol";
import "./libraries/PoolAddress.sol";
import "./base/LiquidityManagement.sol";
import "./base/PeripheryImmutableState.sol";
import "./base/Multicall.sol";
import "./base/ERC721Permit.sol";
import "./base/PeripheryValidation.sol";
import "./base/SelfPermit.sol";

import {EnumerableSet as IterableEnumerableSet} from "contracts/libraries/EnumerableSet.sol";

/// @title NFT positions
/// @notice Wraps CL positions in the ERC721 non-fungible token interface
contract NonfungiblePositionManager is
    INonfungiblePositionManager,
    Multicall,
    ERC721Permit,
    PeripheryImmutableState,
    LiquidityManagement,
    PeripheryValidation,
    SelfPermit
{
    using IterableEnumerableSet for IterableEnumerableSet.UintSet;

    struct Position {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address operator;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 tickLower;
        int24 tickUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }
    /// @dev Revert String Annotations:
    /// NE - ERC721: approved query for nonexistent token
    /// PS - Price slippage check
    /// ID - Invalid token ID
    /// ZA - Zero Address
    /// NA - Not approved
    /// NC - Not cleared
    /// NO - Not Owner

    /// @dev IDs of pools assigned by this contract
    mapping(address => uint80) private _poolIds;

    /// @dev Pool keys by pool ID, to save on SSTOREs for position data
    mapping(uint80 => PoolAddress.PoolKey) private _poolIdToPoolKey;

    /// @dev The token ID position data
    mapping(uint256 => Position) private _positions;

    mapping(address => mapping(address => IterableEnumerableSet.UintSet)) internal _userPositions;

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    uint80 private _nextPoolId = 1;

    /// @inheritdoc INonfungiblePositionManager
    address public override owner;

    /// @inheritdoc INonfungiblePositionManager
    address public override tokenDescriptor;

    /// @dev Prevents calling a function from anyone except owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(
        address _owner,
        address _factory,
        address _WETH9,
        address _tokenDescriptor,
        string memory name,
        string memory symbol
    ) ERC721Permit(name, symbol, "1") PeripheryImmutableState(_factory, _WETH9) {
        owner = _owner;
        tokenDescriptor = _tokenDescriptor;
    }

    /// @inheritdoc INonfungiblePositionManager
    function positions(uint256 tokenId)
        external
        view
        override
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        require(position.poolId != 0);
        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        return (
            position.nonce,
            position.operator,
            poolKey.token0,
            poolKey.token1,
            poolKey.tickSpacing,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    /// @dev Caches a pool key
    function cachePoolKey(address pool, PoolAddress.PoolKey memory poolKey) private returns (uint80 poolId) {
        poolId = _poolIds[pool];
        if (poolId == 0) {
            _poolIds[pool] = (poolId = _nextPoolId++);
            _poolIdToPoolKey[poolId] = poolKey;
        }
    }

    /// @inheritdoc INonfungiblePositionManager
    function mint(MintParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        if (params.sqrtPriceX96 != 0) {
            ICLFactory(factory).createPool({
                tokenA: params.token0,
                tokenB: params.token1,
                tickSpacing: params.tickSpacing,
                sqrtPriceX96: params.sqrtPriceX96
            });
        }
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, tickSpacing: params.tickSpacing});

        ICLPool pool = ICLPool(PoolAddress.computeAddress(factory, poolKey));

        (liquidity, amount0, amount1) = addLiquidity(
            AddLiquidityParams({
                poolAddress: address(pool),
                poolKey: poolKey,
                recipient: address(this),
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        _mint(params.recipient, (tokenId = _nextId++));

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,,) =
            pool.positions(PositionKey.compute(address(this), params.tickLower, params.tickUpper));

        // idempotent set
        uint80 poolId = cachePoolKey(address(pool), poolKey);

        _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            poolId: poolId,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        _userPositions[params.recipient][address(pool)].add(tokenId);

        refundETH();

        emit IncreaseLiquidity(tokenId, liquidity, amount0, amount1);
    }

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId));
        _;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
        require(_exists(tokenId));
        return INonfungibleTokenPositionDescriptor(tokenDescriptor).tokenURI(this, tokenId);
    }

    // save bytecode by removing implementation of unused method
    function baseURI() public pure override returns (string memory) {}

    /// @inheritdoc INonfungiblePositionManager
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        Position storage position = _positions[params.tokenId];

        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];

        ICLPool pool = ICLPool(PoolAddress.computeAddress(factory, poolKey));
        require(ownerOf(params.tokenId) != pool.gauge());

        (liquidity, amount0, amount1) = addLiquidity(
            AddLiquidityParams({
                poolAddress: address(pool),
                poolKey: poolKey,
                tickLower: position.tickLower,
                tickUpper: position.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: address(this)
            })
        );

        // this is now updated to the current transaction
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,,) =
            pool.positions(PositionKey.compute(address(this), position.tickLower, position.tickUpper));

        position.tokensOwed0 += uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128, position.liquidity, FixedPoint128.Q128
            )
        );
        position.tokensOwed1 += uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128, position.liquidity, FixedPoint128.Q128
            )
        );

        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        position.liquidity += liquidity;

        refundETH();

        emit MetadataUpdate(params.tokenId);
        emit IncreaseLiquidity(params.tokenId, liquidity, amount0, amount1);
    }

    /// @inheritdoc INonfungiblePositionManager
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        override
        isAuthorizedForToken(params.tokenId)
        checkDeadline(params.deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.liquidity > 0);
        Position storage position = _positions[params.tokenId];

        uint128 positionLiquidity = position.liquidity;
        require(positionLiquidity >= params.liquidity);

        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        ICLPool pool = ICLPool(PoolAddress.computeAddress(factory, poolKey));

        (amount0, amount1) = pool.burn(position.tickLower, position.tickUpper, params.liquidity);

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min);

        // this is now updated to the current transaction
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,,) =
            pool.positions(PositionKey.compute(address(this), position.tickLower, position.tickUpper));

        /// @dev Casting to u128 and the sum of tokensOwed overflow can cause a loss to users.
        /// @dev This is more probable for tokens that have very high decimals.
        /// @dev The amount of tokens necessary for the loss is: 3.4028237e+38.
        position.tokensOwed0 += uint128(amount0);
        position.tokensOwed1 += uint128(amount1);

        position.tokensOwed0 += uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128, positionLiquidity, FixedPoint128.Q128
            )
        );
        position.tokensOwed1 += uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128, positionLiquidity, FixedPoint128.Q128
            )
        );

        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        // subtraction is safe because we checked positionLiquidity is gte params.liquidity
        position.liquidity = positionLiquidity - params.liquidity;

        emit MetadataUpdate(params.tokenId);
        emit DecreaseLiquidity(params.tokenId, params.liquidity, amount0, amount1);
    }

    /// @inheritdoc INonfungiblePositionManager
    function collect(CollectParams calldata params)
        external
        payable
        override
        isAuthorizedForToken(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.amount0Max > 0 || params.amount1Max > 0);
        // allow collecting to the nft position manager address with address 0
        address recipient = params.recipient == address(0) ? address(this) : params.recipient;

        Position storage position = _positions[params.tokenId];

        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];

        ICLPool pool = ICLPool(PoolAddress.computeAddress(factory, poolKey));

        (uint128 tokensOwed0, uint128 tokensOwed1) = (position.tokensOwed0, position.tokensOwed1);

        address gauge = pool.gauge();
        bool isStaked = ownerOf(params.tokenId) == gauge;

        // trigger an update of the position fees owed and fee growth snapshots if it has any liquidity
        if (position.liquidity > 0) {
            uint256 feeGrowthInside0LastX128;
            uint256 feeGrowthInside1LastX128;
            if (!isStaked) {
                pool.burn(position.tickLower, position.tickUpper, 0);

                (, feeGrowthInside0LastX128, feeGrowthInside1LastX128,,) =
                    pool.positions(PositionKey.compute(address(this), position.tickLower, position.tickUpper));

                tokensOwed0 += uint128(
                    FullMath.mulDiv(
                        feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                        position.liquidity,
                        FixedPoint128.Q128
                    )
                );
                tokensOwed1 += uint128(
                    FullMath.mulDiv(
                        feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                        position.liquidity,
                        FixedPoint128.Q128
                    )
                );
            } else {
                pool.burn(position.tickLower, position.tickUpper, 0, gauge);

                (, feeGrowthInside0LastX128, feeGrowthInside1LastX128,,) =
                    pool.positions(PositionKey.compute(gauge, position.tickLower, position.tickUpper));
            }

            position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        }

        // compute the arguments to give to the pool#collect method
        (uint128 amount0Collect, uint128 amount1Collect) = (
            params.amount0Max > tokensOwed0 ? tokensOwed0 : params.amount0Max,
            params.amount1Max > tokensOwed1 ? tokensOwed1 : params.amount1Max
        );

        // the actual amounts collected are returned
        if (!isStaked) {
            (amount0, amount1) =
                pool.collect(recipient, position.tickLower, position.tickUpper, amount0Collect, amount1Collect);
        } else {
            (amount0, amount1) =
                pool.collect(recipient, position.tickLower, position.tickUpper, amount0Collect, amount1Collect, gauge);
        }

        // sometimes there will be a few less wei than expected due to rounding down in core, but we just subtract the full amount expected
        // instead of the actual amount so we can burn the token
        (position.tokensOwed0, position.tokensOwed1) = (tokensOwed0 - amount0Collect, tokensOwed1 - amount1Collect);

        emit MetadataUpdate(params.tokenId);
        emit Collect(params.tokenId, recipient, amount0Collect, amount1Collect);
    }

    /// @inheritdoc INonfungiblePositionManager
    function burn(uint256 tokenId) external payable override isAuthorizedForToken(tokenId) {
        Position storage position = _positions[tokenId];
        require(position.liquidity == 0 && position.tokensOwed0 == 0 && position.tokensOwed1 == 0);

        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        address pool = PoolAddress.computeAddress(factory, poolKey);
        _userPositions[ownerOf(tokenId)][pool].remove(tokenId);

        delete _positions[tokenId];
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721) {
        /// @dev This hook should not run during mint / burn
        if (from == address(0) || to == address(0)) return;
        address pool = PoolAddress.computeAddress(factory, _poolIdToPoolKey[_positions[tokenId].poolId]);

        _userPositions[from][pool].remove(tokenId);
        _userPositions[to][pool].add(tokenId);
    }

    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return uint256(_positions[tokenId].nonce++);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {
        require(_exists(tokenId));

        return _positions[tokenId].operator;
    }

    /// @dev Overrides _approve to use the operator in the position, which is packed with the position permit nonce
    function _approve(address to, uint256 tokenId) internal override(ERC721) {
        _positions[tokenId].operator = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /// @inheritdoc INonfungiblePositionManager
    function setTokenDescriptor(address _tokenDescriptor) external override onlyOwner {
        require(_tokenDescriptor != address(0));
        tokenDescriptor = _tokenDescriptor;
        emit BatchMetadataUpdate(0, type(uint256).max);
        emit TokenDescriptorChanged(_tokenDescriptor);
    }

    /// @inheritdoc INonfungiblePositionManager
    function setOwner(address _owner) external override onlyOwner {
        require(_owner != address(0));
        owner = _owner;
        emit TransferOwnership(_owner);
    }

    function userPositions(address user, address pool) external view override returns (uint256[] memory) {
        return _userPositions[user][pool].values();
    }
}
