import { ethers, network, waffle } from 'hardhat'
import { BigNumber, BigNumberish, constants, Wallet } from 'ethers'
import { CoreTestERC20 } from '../../typechain/CoreTestERC20'
import { CLFactory } from '../../typechain/CLFactory'
import { MockTimeCLPool } from '../../typechain/MockTimeCLPool'
import { TestCLSwapPay } from '../../typechain/TestCLSwapPay'
import checkObservationEquals from './shared/checkObservationEquals'
import { expect } from './shared/expect'

import { poolFixture, TEST_POOL_START_TIME } from './shared/fixtures'

import {
  expandTo18Decimals,
  FeeAmount,
  getPositionKey,
  getMaxTick,
  getMinTick,
  encodePriceSqrt,
  TICK_SPACINGS,
  createPoolFunctions,
  SwapFunction,
  MintFunction,
  getMaxLiquidityPerTick,
  FlashFunction,
  MaxUint128,
  MAX_SQRT_RATIO,
  MIN_SQRT_RATIO,
  SwapToPriceFunction,
} from './shared/utilities'
import { TestCLCallee } from '../../typechain/TestCLCallee'
import { TestCLReentrantCallee } from '../../typechain/TestCLReentrantCallee'
import { TickMathTest } from '../../typechain/TickMathTest'
import { SwapMathTest } from '../../typechain/SwapMathTest'
import { MockFactoryRegistry } from '../../typechain'

const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('CLPool', () => {
  let wallet: Wallet, other: Wallet

  let token0: CoreTestERC20
  let token1: CoreTestERC20
  let token2: CoreTestERC20

  let nft: string
  let mockFactoryRegistry: MockFactoryRegistry
  let factory: CLFactory
  let pool: MockTimeCLPool

  let swapTarget: TestCLCallee

  let swapToLowerPrice: SwapToPriceFunction
  let swapToHigherPrice: SwapToPriceFunction
  let swapExact0For1: SwapFunction
  let swap0ForExact1: SwapFunction
  let swapExact1For0: SwapFunction
  let swap1ForExact0: SwapFunction

  let feeAmount: number
  let tickSpacing: number

  let minTick: number
  let maxTick: number

  let mint: MintFunction
  let flash: FlashFunction

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPool: ThenArg<ReturnType<typeof poolFixture>>['createPool']

  before('create fixture loader', async () => {
    await network.provider.request({
      method: 'hardhat_reset',
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.OPTIMISM_RPC_URL,
            blockNumber: Number(process.env.FORK_BLOCK_NUMBER),
          },
        },
      ],
    })
    ;[wallet, other] = await (ethers as any).getSigners()
    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy fixture', async () => {
    ;({
      token0,
      token1,
      token2,
      factory,
      mockFactoryRegistry,
      createPool,
      swapTargetCallee: swapTarget,
    } = await loadFixture(poolFixture))

    const oldCreatePool = createPool
    createPool = async (_feeAmount, _tickSpacing) => {
      const pool = await oldCreatePool(_feeAmount, _tickSpacing)
      ;({
        swapToLowerPrice,
        swapToHigherPrice,
        swapExact0For1,
        swap0ForExact1,
        swapExact1For0,
        swap1ForExact0,
        mint,
        flash,
      } = createPoolFunctions({
        token0,
        token1,
        swapTarget,
        pool,
      }))
      minTick = getMinTick(_tickSpacing)
      maxTick = getMaxTick(_tickSpacing)
      feeAmount = _feeAmount
      tickSpacing = _tickSpacing
      return pool
    }

    // default to the 30 bips pool
    pool = await createPool(FeeAmount.MEDIUM, TICK_SPACINGS[FeeAmount.MEDIUM])
    nft = await pool.nft()
  })

  it('constructor initializes immutables', async () => {
    expect(await pool.factory()).to.eq(factory.address)
    expect(await pool.token0()).to.eq(token0.address)
    expect(await pool.token1()).to.eq(token1.address)
    expect(await pool.maxLiquidityPerTick()).to.eq(getMaxLiquidityPerTick(tickSpacing))
  })

  describe('#initialize', () => {
    beforeEach('initialize at zero tick', async () => await pool.uninitialize())
    it('fails if already initialized', async () => {
      pool.initialize(
        factory.address,
        token0.address,
        token1.address,
        TICK_SPACINGS[FeeAmount.MEDIUM],
        encodePriceSqrt(1, 1),
        ethers.constants.AddressZero,
        ethers.constants.AddressZero
      )
      await expect(
        pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          encodePriceSqrt(1, 1),
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      ).to.be.reverted
    })
    it('fails if starting price is too low', async () => {
      await expect(
        pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          1,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith('R')
      await expect(
        pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          MIN_SQRT_RATIO.sub(1),
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith('R')
    })
    it('fails if starting price is too high', async () => {
      await expect(
        pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          MAX_SQRT_RATIO,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith('R')
      await expect(
        pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          BigNumber.from(2).pow(160).sub(1),
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith('R')
    })
    it('can be initialized at MIN_SQRT_RATIO', async () => {
      await pool.initialize(
        factory.address,
        token0.address,
        token1.address,
        TICK_SPACINGS[FeeAmount.MEDIUM],
        MIN_SQRT_RATIO,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero
      )
      expect((await pool.slot0()).tick).to.eq(getMinTick(1))
    })
    it('can be initialized at MAX_SQRT_RATIO - 1', async () => {
      await pool.initialize(
        factory.address,
        token0.address,
        token1.address,
        TICK_SPACINGS[FeeAmount.MEDIUM],
        MAX_SQRT_RATIO.sub(1),
        ethers.constants.AddressZero,
        ethers.constants.AddressZero
      )
      expect((await pool.slot0()).tick).to.eq(getMaxTick(1) - 1)
    })
    it('sets initial variables', async () => {
      const price = encodePriceSqrt(1, 2)
      await pool.initialize(
        factory.address,
        token0.address,
        token1.address,
        TICK_SPACINGS[FeeAmount.MEDIUM],
        price,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero
      )

      const { sqrtPriceX96, observationIndex } = await pool.slot0()
      expect(sqrtPriceX96).to.eq(price)
      expect(observationIndex).to.eq(0)
      expect((await pool.slot0()).tick).to.eq(-6932)
    })
    it('initializes the first observations slot', async () => {
      await pool.initialize(
        factory.address,
        token0.address,
        token1.address,
        TICK_SPACINGS[FeeAmount.MEDIUM],
        encodePriceSqrt(1, 1),
        ethers.constants.AddressZero,
        ethers.constants.AddressZero
      )

      checkObservationEquals(await pool.observations(0), {
        secondsPerLiquidityCumulativeX128: 0,
        initialized: true,
        blockTimestamp: TEST_POOL_START_TIME,
        tickCumulative: 0,
      })
    })
    it('emits a Initialized event with the input tick', async () => {
      const sqrtPriceX96 = encodePriceSqrt(1, 2)

      await expect(
        pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          sqrtPriceX96,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      )
        .to.emit(pool, 'Initialize')
        .withArgs(sqrtPriceX96, -6932)
    })
  })

  describe('#increaseObservationCardinalityNext', () => {
    it('emits an event including both old and new', async () => {
      await expect(pool.increaseObservationCardinalityNext(2))
        .to.emit(pool, 'IncreaseObservationCardinalityNext')
        .withArgs(1, 2)
    })
    it('does not emit an event for no op call', async () => {
      await pool.increaseObservationCardinalityNext(3)
      await expect(pool.increaseObservationCardinalityNext(2)).to.not.emit(pool, 'IncreaseObservationCardinalityNext')
    })
    it('does not change cardinality next if less than current', async () => {
      await pool.increaseObservationCardinalityNext(3)
      await pool.increaseObservationCardinalityNext(2)
      expect((await pool.slot0()).observationCardinalityNext).to.eq(3)
    })
    it('increases cardinality and cardinality next first time', async () => {
      await pool.increaseObservationCardinalityNext(2)
      const { observationCardinality, observationCardinalityNext } = await pool.slot0()
      expect(observationCardinality).to.eq(1)
      expect(observationCardinalityNext).to.eq(2)
    })
  })

  describe('#mint', () => {
    describe('after initialization', () => {
      beforeEach('initialize the pool at price of 10:1', async () => {
        await pool.uninitialize()
        await pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          encodePriceSqrt(1, 10),
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
        await mint(wallet.address, minTick, maxTick, 3161)
      })

      describe('failure cases', () => {
        it('fails if tickLower greater than tickUpper', async () => {
          // should be TLU but...hardhat
          await expect(mint(wallet.address, 1, 0, 1)).to.be.reverted
        })
        it('fails if tickLower less than min tick', async () => {
          // should be TLM but...hardhat
          await expect(mint(wallet.address, -887273, 0, 1)).to.be.reverted
        })
        it('fails if tickUpper greater than max tick', async () => {
          // should be TUM but...hardhat
          await expect(mint(wallet.address, 0, 887273, 1)).to.be.reverted
        })
        it('fails if amount exceeds the max', async () => {
          // these should fail with 'LO' but hardhat is bugged
          const maxLiquidityGross = await pool.maxLiquidityPerTick()
          await expect(mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, maxLiquidityGross.add(1))).to
            .be.reverted
          await expect(mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, maxLiquidityGross)).to.not.be
            .reverted
        })
        it('fails if total amount at tick exceeds the max', async () => {
          // these should fail with 'LO' but hardhat is bugged
          await mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 1000)

          const maxLiquidityGross = await pool.maxLiquidityPerTick()
          await expect(
            mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, maxLiquidityGross.sub(1000).add(1))
          ).to.be.reverted
          await expect(
            mint(wallet.address, minTick + tickSpacing * 2, maxTick - tickSpacing, maxLiquidityGross.sub(1000).add(1))
          ).to.be.reverted
          await expect(
            mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing * 2, maxLiquidityGross.sub(1000).add(1))
          ).to.be.reverted
          await expect(mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, maxLiquidityGross.sub(1000)))
            .to.not.be.reverted
        })
        it('fails if amount is 0', async () => {
          await expect(mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 0)).to.be.reverted
        })
      })

      describe('success cases', () => {
        it('initial balances', async () => {
          expect(await token0.balanceOf(pool.address)).to.eq(9996)
          expect(await token1.balanceOf(pool.address)).to.eq(1000)
        })

        it('initial tick', async () => {
          expect((await pool.slot0()).tick).to.eq(-23028)
        })

        describe('above current price', () => {
          it('transfers token0 only', async () => {
            await expect(mint(wallet.address, -22980, 0, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(wallet.address, pool.address, 21549)
              .to.not.emit(token1, 'Transfer')
            expect(await token0.balanceOf(pool.address)).to.eq(9996 + 21549)
            expect(await token1.balanceOf(pool.address)).to.eq(1000)
          })

          it('max tick with max leverage', async () => {
            await mint(wallet.address, maxTick - tickSpacing, maxTick, BigNumber.from(2).pow(102))
            expect(await token0.balanceOf(pool.address)).to.eq(9996 + 828011525)
            expect(await token1.balanceOf(pool.address)).to.eq(1000)
          })

          it('works for max tick', async () => {
            await expect(mint(wallet.address, -22980, maxTick, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(wallet.address, pool.address, 31549)
            expect(await token0.balanceOf(pool.address)).to.eq(9996 + 31549)
            expect(await token1.balanceOf(pool.address)).to.eq(1000)
          })

          it('removing works', async () => {
            await mint(wallet.address, -240, 0, 10000)
            await pool['burn(int24,int24,uint128)'](-240, 0, 10000)
            const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
              wallet.address,
              -240,
              0,
              MaxUint128,
              MaxUint128
            )
            expect(amount0, 'amount0').to.eq(120)
            expect(amount1, 'amount1').to.eq(0)
          })

          it('adds liquidity to liquidityGross', async () => {
            await mint(wallet.address, -240, 0, 100)
            expect((await pool.ticks(-240)).liquidityGross).to.eq(100)
            expect((await pool.ticks(0)).liquidityGross).to.eq(100)
            expect((await pool.ticks(tickSpacing)).liquidityGross).to.eq(0)
            expect((await pool.ticks(tickSpacing * 2)).liquidityGross).to.eq(0)
            await mint(wallet.address, -240, tickSpacing, 150)
            expect((await pool.ticks(-240)).liquidityGross).to.eq(250)
            expect((await pool.ticks(0)).liquidityGross).to.eq(100)
            expect((await pool.ticks(tickSpacing)).liquidityGross).to.eq(150)
            expect((await pool.ticks(tickSpacing * 2)).liquidityGross).to.eq(0)
            await mint(wallet.address, 0, tickSpacing * 2, 60)
            expect((await pool.ticks(-240)).liquidityGross).to.eq(250)
            expect((await pool.ticks(0)).liquidityGross).to.eq(160)
            expect((await pool.ticks(tickSpacing)).liquidityGross).to.eq(150)
            expect((await pool.ticks(tickSpacing * 2)).liquidityGross).to.eq(60)
          })

          it('removes liquidity from liquidityGross', async () => {
            await mint(wallet.address, -240, 0, 100)
            await mint(wallet.address, -240, 0, 40)
            await pool['burn(int24,int24,uint128)'](-240, 0, 90)
            expect((await pool.ticks(-240)).liquidityGross).to.eq(50)
            expect((await pool.ticks(0)).liquidityGross).to.eq(50)
          })

          it('clears tick lower if last position is removed', async () => {
            await mint(wallet.address, -240, 0, 100)
            await pool['burn(int24,int24,uint128)'](-240, 0, 100)
            const { liquidityGross, feeGrowthOutside0X128, feeGrowthOutside1X128 } = await pool.ticks(-240)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0X128).to.eq(0)
            expect(feeGrowthOutside1X128).to.eq(0)
          })

          it('clears tick upper if last position is removed', async () => {
            await mint(wallet.address, -240, 0, 100)
            await pool['burn(int24,int24,uint128)'](-240, 0, 100)
            const { liquidityGross, feeGrowthOutside0X128, feeGrowthOutside1X128 } = await pool.ticks(0)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0X128).to.eq(0)
            expect(feeGrowthOutside1X128).to.eq(0)
          })
          it('only clears the tick that is not used at all', async () => {
            await mint(wallet.address, -240, 0, 100)
            await mint(wallet.address, -tickSpacing, 0, 250)
            await pool['burn(int24,int24,uint128)'](-240, 0, 100)

            let { liquidityGross, feeGrowthOutside0X128, feeGrowthOutside1X128 } = await pool.ticks(-240)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0X128).to.eq(0)
            expect(feeGrowthOutside1X128).to.eq(0)
            ;({ liquidityGross, feeGrowthOutside0X128, feeGrowthOutside1X128 } = await pool.ticks(-tickSpacing))
            expect(liquidityGross).to.eq(250)
            expect(feeGrowthOutside0X128).to.eq(0)
            expect(feeGrowthOutside1X128).to.eq(0)
          })

          it('does not write an observation', async () => {
            checkObservationEquals(await pool.observations(0), {
              tickCumulative: 0,
              blockTimestamp: TEST_POOL_START_TIME,
              initialized: true,
              secondsPerLiquidityCumulativeX128: 0,
            })
            await pool.advanceTime(1)
            await mint(wallet.address, -240, 0, 100)
            checkObservationEquals(await pool.observations(0), {
              tickCumulative: 0,
              blockTimestamp: TEST_POOL_START_TIME,
              initialized: true,
              secondsPerLiquidityCumulativeX128: 0,
            })
          })
        })

        describe('including current price', () => {
          it('price within range: transfers current price of both tokens', async () => {
            await expect(mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 100))
              .to.emit(token0, 'Transfer')
              .withArgs(wallet.address, pool.address, 317)
              .to.emit(token1, 'Transfer')
              .withArgs(wallet.address, pool.address, 32)
            expect(await token0.balanceOf(pool.address)).to.eq(9996 + 317)
            expect(await token1.balanceOf(pool.address)).to.eq(1000 + 32)
          })

          it('initializes lower tick', async () => {
            await mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 100)
            const { liquidityGross } = await pool.ticks(minTick + tickSpacing)
            expect(liquidityGross).to.eq(100)
          })

          it('initializes upper tick', async () => {
            await mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 100)
            const { liquidityGross } = await pool.ticks(maxTick - tickSpacing)
            expect(liquidityGross).to.eq(100)
          })

          it('works for min/max tick', async () => {
            await expect(mint(wallet.address, minTick, maxTick, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(wallet.address, pool.address, 31623)
              .to.emit(token1, 'Transfer')
              .withArgs(wallet.address, pool.address, 3163)
            expect(await token0.balanceOf(pool.address)).to.eq(9996 + 31623)
            expect(await token1.balanceOf(pool.address)).to.eq(1000 + 3163)
          })

          it('removing works', async () => {
            await mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 100)
            await pool['burn(int24,int24,uint128)'](minTick + tickSpacing, maxTick - tickSpacing, 100)
            const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
              wallet.address,
              minTick + tickSpacing,
              maxTick - tickSpacing,
              MaxUint128,
              MaxUint128
            )
            expect(amount0, 'amount0').to.eq(316)
            expect(amount1, 'amount1').to.eq(31)
          })

          it('writes an observation', async () => {
            checkObservationEquals(await pool.observations(0), {
              tickCumulative: 0,
              blockTimestamp: TEST_POOL_START_TIME,
              initialized: true,
              secondsPerLiquidityCumulativeX128: 0,
            })
            await pool.advanceTime(1)
            await mint(wallet.address, minTick, maxTick, 100)
            checkObservationEquals(await pool.observations(0), {
              tickCumulative: -23028,
              blockTimestamp: TEST_POOL_START_TIME + 1,
              initialized: true,
              secondsPerLiquidityCumulativeX128: '107650226801941937191829992860413859',
            })
          })
        })

        describe('below current price', () => {
          it('transfers token1 only', async () => {
            await expect(mint(wallet.address, -46080, -23040, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(wallet.address, pool.address, 2162)
              .to.not.emit(token0, 'Transfer')
            expect(await token0.balanceOf(pool.address)).to.eq(9996)
            expect(await token1.balanceOf(pool.address)).to.eq(1000 + 2162)
          })

          it('min tick with max leverage', async () => {
            await mint(wallet.address, minTick, minTick + tickSpacing, BigNumber.from(2).pow(102))
            expect(await token0.balanceOf(pool.address)).to.eq(9996)
            expect(await token1.balanceOf(pool.address)).to.eq(1000 + 828011520)
          })

          it('works for min tick', async () => {
            await expect(mint(wallet.address, minTick, -23040, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(wallet.address, pool.address, 3161)
            expect(await token0.balanceOf(pool.address)).to.eq(9996)
            expect(await token1.balanceOf(pool.address)).to.eq(1000 + 3161)
          })

          it('removing works', async () => {
            await mint(wallet.address, -46080, -46020, 10000)
            await pool['burn(int24,int24,uint128)'](-46080, -46020, 10000)
            const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
              wallet.address,
              -46080,
              -46020,
              MaxUint128,
              MaxUint128
            )
            expect(amount0, 'amount0').to.eq(0)
            expect(amount1, 'amount1').to.eq(3)
          })

          it('does not write an observation', async () => {
            checkObservationEquals(await pool.observations(0), {
              tickCumulative: 0,
              blockTimestamp: TEST_POOL_START_TIME,
              initialized: true,
              secondsPerLiquidityCumulativeX128: 0,
            })
            await pool.advanceTime(1)
            await mint(wallet.address, -46080, -23040, 100)
            checkObservationEquals(await pool.observations(0), {
              tickCumulative: 0,
              blockTimestamp: TEST_POOL_START_TIME,
              initialized: true,
              secondsPerLiquidityCumulativeX128: 0,
            })
          })
        })
      })

      it('poke is not allowed on uninitialized position', async () => {
        await mint(other.address, minTick + tickSpacing, maxTick - tickSpacing, expandTo18Decimals(1))
        await swapExact0For1(expandTo18Decimals(1).div(10), wallet.address)
        await swapExact1For0(expandTo18Decimals(1).div(100), wallet.address)

        // missing revert reason due to hardhat
        await expect(pool['burn(int24,int24,uint128)'](minTick + tickSpacing, maxTick - tickSpacing, 0)).to.be.reverted

        await mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, 1)
        let {
          liquidity,
          feeGrowthInside0LastX128,
          feeGrowthInside1LastX128,
          tokensOwed1,
          tokensOwed0,
        } = await pool.positions(getPositionKey(wallet.address, minTick + tickSpacing, maxTick - tickSpacing))
        expect(liquidity).to.eq(1)
        expect(feeGrowthInside0LastX128).to.eq('102084710076281216349243831104605583')
        expect(feeGrowthInside1LastX128).to.eq('10208471007628121634924383110460558')
        expect(tokensOwed0, 'tokens owed 0 before').to.eq(0)
        expect(tokensOwed1, 'tokens owed 1 before').to.eq(0)

        await pool['burn(int24,int24,uint128)'](minTick + tickSpacing, maxTick - tickSpacing, 1)
        ;({
          liquidity,
          feeGrowthInside0LastX128,
          feeGrowthInside1LastX128,
          tokensOwed1,
          tokensOwed0,
        } = await pool.positions(getPositionKey(wallet.address, minTick + tickSpacing, maxTick - tickSpacing)))
        expect(liquidity).to.eq(0)
        expect(feeGrowthInside0LastX128).to.eq('102084710076281216349243831104605583')
        expect(feeGrowthInside1LastX128).to.eq('10208471007628121634924383110460558')
        expect(tokensOwed0, 'tokens owed 0 after').to.eq(3)
        expect(tokensOwed1, 'tokens owed 1 after').to.eq(0)
      })
    })
  })

  describe('#burn', () => {
    beforeEach('initialize at zero tick', () => initializeAtZeroTick(pool))

    async function checkTickIsClear(tick: number) {
      const { liquidityGross, feeGrowthOutside0X128, feeGrowthOutside1X128, liquidityNet } = await pool.ticks(tick)
      expect(liquidityGross).to.eq(0)
      expect(feeGrowthOutside0X128).to.eq(0)
      expect(feeGrowthOutside1X128).to.eq(0)
      expect(liquidityNet).to.eq(0)
    }

    async function checkTickIsNotClear(tick: number) {
      const { liquidityGross } = await pool.ticks(tick)
      expect(liquidityGross).to.not.eq(0)
    }

    it('does not clear the position fee growth snapshot if no more liquidity', async () => {
      // some activity that would make the ticks non-zero
      await pool.advanceTime(10)
      await mint(other.address, minTick, maxTick, expandTo18Decimals(1))
      await swapExact0For1(expandTo18Decimals(1), wallet.address)
      await swapExact1For0(expandTo18Decimals(1), wallet.address)
      await pool.connect(other)['burn(int24,int24,uint128)'](minTick, maxTick, expandTo18Decimals(1))
      const {
        liquidity,
        tokensOwed0,
        tokensOwed1,
        feeGrowthInside0LastX128,
        feeGrowthInside1LastX128,
      } = await pool.positions(getPositionKey(other.address, minTick, maxTick))
      expect(liquidity).to.eq(0)
      expect(tokensOwed0).to.not.eq(0)
      expect(tokensOwed1).to.not.eq(0)
      expect(feeGrowthInside0LastX128).to.eq('340282366920938463463374607431768211')
      expect(feeGrowthInside1LastX128).to.eq('340282366920938576890830247744589365')
    })

    it('clears the tick if its the last position using it', async () => {
      const tickLower = minTick + tickSpacing
      const tickUpper = maxTick - tickSpacing
      // some activity that would make the ticks non-zero
      await pool.advanceTime(10)
      await mint(wallet.address, tickLower, tickUpper, 1)
      await swapExact0For1(expandTo18Decimals(1), wallet.address)
      await pool['burn(int24,int24,uint128)'](tickLower, tickUpper, 1)
      await checkTickIsClear(tickLower)
      await checkTickIsClear(tickUpper)
    })

    it('clears only the lower tick if upper is still used', async () => {
      const tickLower = minTick + tickSpacing
      const tickUpper = maxTick - tickSpacing
      // some activity that would make the ticks non-zero
      await pool.advanceTime(10)
      await mint(wallet.address, tickLower, tickUpper, 1)
      await mint(wallet.address, tickLower + tickSpacing, tickUpper, 1)
      await swapExact0For1(expandTo18Decimals(1), wallet.address)
      await pool['burn(int24,int24,uint128)'](tickLower, tickUpper, 1)
      await checkTickIsClear(tickLower)
      await checkTickIsNotClear(tickUpper)
    })

    it('clears only the upper tick if lower is still used', async () => {
      const tickLower = minTick + tickSpacing
      const tickUpper = maxTick - tickSpacing
      // some activity that would make the ticks non-zero
      await pool.advanceTime(10)
      await mint(wallet.address, tickLower, tickUpper, 1)
      await mint(wallet.address, tickLower, tickUpper - tickSpacing, 1)
      await swapExact0For1(expandTo18Decimals(1), wallet.address)
      await pool['burn(int24,int24,uint128)'](tickLower, tickUpper, 1)
      await checkTickIsNotClear(tickLower)
      await checkTickIsClear(tickUpper)
    })
  })

  // the combined amount of liquidity that the pool is initialized with (including the 1 minimum liquidity that is burned)
  const initializeLiquidityAmount = expandTo18Decimals(2)
  async function initializeAtZeroTick(pool: MockTimeCLPool): Promise<void> {
    // pool is created and initialized at zero tick by default
    const tickSpacing = await pool.tickSpacing()
    const [min, max] = [getMinTick(tickSpacing), getMaxTick(tickSpacing)]
    await mint(wallet.address, min, max, initializeLiquidityAmount)
  }

  describe('#observe', () => {
    beforeEach(() => initializeAtZeroTick(pool))

    // zero tick
    it('current tick accumulator increases by tick over time', async () => {
      let {
        tickCumulatives: [tickCumulative],
      } = await pool.observe([0])
      expect(tickCumulative).to.eq(0)
      await pool.advanceTime(10)
      ;({
        tickCumulatives: [tickCumulative],
      } = await pool.observe([0]))
      expect(tickCumulative).to.eq(0)
    })

    it('current tick accumulator after single swap', async () => {
      // moves to tick -1
      await swapExact0For1(1000, wallet.address)
      await pool.advanceTime(4)
      let {
        tickCumulatives: [tickCumulative],
      } = await pool.observe([0])
      expect(tickCumulative).to.eq(-4)
    })

    it('current tick accumulator after two swaps', async () => {
      await swapExact0For1(expandTo18Decimals(1).div(2), wallet.address)
      expect((await pool.slot0()).tick).to.eq(-4452)
      await pool.advanceTime(4)
      await swapExact1For0(expandTo18Decimals(1).div(4), wallet.address)
      expect((await pool.slot0()).tick).to.eq(-1558)
      await pool.advanceTime(6)
      let {
        tickCumulatives: [tickCumulative],
      } = await pool.observe([0])
      // -4452*4 + -1558*6
      expect(tickCumulative).to.eq(-27156)
    })
  })

  describe('miscellaneous mint tests', () => {
    beforeEach('initialize at zero tick', async () => {
      pool = await createPool(FeeAmount.LOW, TICK_SPACINGS[FeeAmount.LOW])
      await initializeAtZeroTick(pool)
    })

    it('mint to the right of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = tickSpacing
      const upperTick = tickSpacing * 2

      const liquidityBefore = await pool.liquidity()

      const b0 = await token0.balanceOf(pool.address)
      const b1 = await token1.balanceOf(pool.address)

      await mint(wallet.address, lowerTick, upperTick, liquidityDelta)

      const liquidityAfter = await pool.liquidity()
      expect(liquidityAfter).to.be.gte(liquidityBefore)

      expect((await token0.balanceOf(pool.address)).sub(b0)).to.eq(1)
      expect((await token1.balanceOf(pool.address)).sub(b1)).to.eq(0)
    })

    it('mint to the left of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -tickSpacing * 2
      const upperTick = -tickSpacing

      const liquidityBefore = await pool.liquidity()

      const b0 = await token0.balanceOf(pool.address)
      const b1 = await token1.balanceOf(pool.address)

      await mint(wallet.address, lowerTick, upperTick, liquidityDelta)

      const liquidityAfter = await pool.liquidity()
      expect(liquidityAfter).to.be.gte(liquidityBefore)

      expect((await token0.balanceOf(pool.address)).sub(b0)).to.eq(0)
      expect((await token1.balanceOf(pool.address)).sub(b1)).to.eq(1)
    })

    it('mint within the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing

      const liquidityBefore = await pool.liquidity()

      const b0 = await token0.balanceOf(pool.address)
      const b1 = await token1.balanceOf(pool.address)

      await mint(wallet.address, lowerTick, upperTick, liquidityDelta)

      const liquidityAfter = await pool.liquidity()
      expect(liquidityAfter).to.be.gte(liquidityBefore)

      expect((await token0.balanceOf(pool.address)).sub(b0)).to.eq(1)
      expect((await token1.balanceOf(pool.address)).sub(b1)).to.eq(1)
    })

    it('cannot remove more than the entire position', async () => {
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing
      await mint(wallet.address, lowerTick, upperTick, expandTo18Decimals(1000))
      // should be 'LS', hardhat is bugged
      await expect(pool['burn(int24,int24,uint128)'](lowerTick, upperTick, expandTo18Decimals(1001))).to.be.reverted
    })

    it('collect fees within the current price after swap', async () => {
      const liquidityDelta = expandTo18Decimals(100)
      const lowerTick = -tickSpacing * 100
      const upperTick = tickSpacing * 100

      await mint(wallet.address, lowerTick, upperTick, liquidityDelta)

      const liquidityBefore = await pool.liquidity()

      const amount0In = expandTo18Decimals(1)
      await swapExact0For1(amount0In, wallet.address)

      const liquidityAfter = await pool.liquidity()
      expect(liquidityAfter, 'k increases').to.be.gte(liquidityBefore)

      const token0BalanceBeforePool = await token0.balanceOf(pool.address)
      const token1BalanceBeforePool = await token1.balanceOf(pool.address)
      const token0BalanceBeforeWallet = await token0.balanceOf(wallet.address)
      const token1BalanceBeforeWallet = await token1.balanceOf(wallet.address)

      await pool['burn(int24,int24,uint128)'](lowerTick, upperTick, 0)
      await pool['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        lowerTick,
        upperTick,
        MaxUint128,
        MaxUint128
      )

      await pool['burn(int24,int24,uint128)'](lowerTick, upperTick, 0)
      const { amount0: fees0, amount1: fees1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        lowerTick,
        upperTick,
        MaxUint128,
        MaxUint128
      )
      expect(fees0).to.be.eq(0)
      expect(fees1).to.be.eq(0)

      const token0BalanceAfterWallet = await token0.balanceOf(wallet.address)
      const token1BalanceAfterWallet = await token1.balanceOf(wallet.address)
      const token0BalanceAfterPool = await token0.balanceOf(pool.address)
      const token1BalanceAfterPool = await token1.balanceOf(pool.address)

      expect(token0BalanceAfterWallet).to.be.gt(token0BalanceBeforeWallet)
      expect(token1BalanceAfterWallet).to.be.eq(token1BalanceBeforeWallet)

      expect(token0BalanceAfterPool).to.be.lt(token0BalanceBeforePool)
      expect(token1BalanceAfterPool).to.be.eq(token1BalanceBeforePool)
    })
  })

  describe('post-initialize at medium fee', () => {
    describe('k (implicit)', () => {
      it('returns 0 before initialization', async () => {
        expect(await pool.liquidity()).to.eq(0)
      })
      describe('post initialized', () => {
        beforeEach(() => initializeAtZeroTick(pool))

        it('returns initial liquidity', async () => {
          expect(await pool.liquidity()).to.eq(expandTo18Decimals(2))
        })
        it('returns in supply in range', async () => {
          await mint(wallet.address, -tickSpacing, tickSpacing, expandTo18Decimals(3))
          expect(await pool.liquidity()).to.eq(expandTo18Decimals(5))
        })
        it('excludes supply at tick above current tick', async () => {
          await mint(wallet.address, tickSpacing, tickSpacing * 2, expandTo18Decimals(3))
          expect(await pool.liquidity()).to.eq(expandTo18Decimals(2))
        })
        it('excludes supply at tick below current tick', async () => {
          await mint(wallet.address, -tickSpacing * 2, -tickSpacing, expandTo18Decimals(3))
          expect(await pool.liquidity()).to.eq(expandTo18Decimals(2))
        })
        it('updates correctly when exiting range', async () => {
          const kBefore = await pool.liquidity()
          expect(kBefore).to.be.eq(expandTo18Decimals(2))

          // add liquidity at and above current tick
          const liquidityDelta = expandTo18Decimals(1)
          const lowerTick = 0
          const upperTick = tickSpacing
          await mint(wallet.address, lowerTick, upperTick, liquidityDelta)

          // ensure virtual supply has increased appropriately
          const kAfter = await pool.liquidity()
          expect(kAfter).to.be.eq(expandTo18Decimals(3))

          // swap toward the left (just enough for the tick transition function to trigger)
          await swapExact0For1(1, wallet.address)
          const { tick } = await pool.slot0()
          expect(tick).to.be.eq(-1)

          const kAfterSwap = await pool.liquidity()
          expect(kAfterSwap).to.be.eq(expandTo18Decimals(2))
        })
        it('updates correctly when entering range', async () => {
          const kBefore = await pool.liquidity()
          expect(kBefore).to.be.eq(expandTo18Decimals(2))

          // add liquidity below the current tick
          const liquidityDelta = expandTo18Decimals(1)
          const lowerTick = -tickSpacing
          const upperTick = 0
          await mint(wallet.address, lowerTick, upperTick, liquidityDelta)

          // ensure virtual supply hasn't changed
          const kAfter = await pool.liquidity()
          expect(kAfter).to.be.eq(kBefore)

          // swap toward the left (just enough for the tick transition function to trigger)
          await swapExact0For1(1, wallet.address)
          const { tick } = await pool.slot0()
          expect(tick).to.be.eq(-1)

          const kAfterSwap = await pool.liquidity()
          expect(kAfterSwap).to.be.eq(expandTo18Decimals(3))
        })
      })
    })
  })

  describe('limit orders', () => {
    beforeEach('initialize at tick 0', () => initializeAtZeroTick(pool))

    it('limit selling 0 for 1 at tick 0 thru 1', async () => {
      await expect(mint(wallet.address, 0, 120, expandTo18Decimals(1)))
        .to.emit(token0, 'Transfer')
        .withArgs(wallet.address, pool.address, '5981737760509663')
      // somebody takes the limit order
      await swapExact1For0(expandTo18Decimals(2), other.address)
      await expect(pool['burn(int24,int24,uint128)'](0, 120, expandTo18Decimals(1)))
        .to.emit(pool, 'Burn')
        .withArgs(wallet.address, 0, 120, expandTo18Decimals(1), 0, '6017734268818165')
        .to.not.emit(token0, 'Transfer')
        .to.not.emit(token1, 'Transfer')
      await expect(pool['collect(address,int24,int24,uint128,uint128)'](wallet.address, 0, 120, MaxUint128, MaxUint128))
        .to.emit(token1, 'Transfer')
        .withArgs(pool.address, wallet.address, BigNumber.from('6017734268818165').add('18107525382602')) // roughly 0.3% despite other liquidity
        .to.not.emit(token0, 'Transfer')
      expect((await pool.slot0()).tick).to.be.gte(120)
    })
    it('limit selling 1 for 0 at tick 0 thru -1', async () => {
      await expect(mint(wallet.address, -120, 0, expandTo18Decimals(1)))
        .to.emit(token1, 'Transfer')
        .withArgs(wallet.address, pool.address, '5981737760509663')
      // somebody takes the limit order
      await swapExact0For1(expandTo18Decimals(2), other.address)
      await expect(pool['burn(int24,int24,uint128)'](-120, 0, expandTo18Decimals(1)))
        .to.emit(pool, 'Burn')
        .withArgs(wallet.address, -120, 0, expandTo18Decimals(1), '6017734268818165', 0)
        .to.not.emit(token0, 'Transfer')
        .to.not.emit(token1, 'Transfer')
      await expect(
        pool['collect(address,int24,int24,uint128,uint128)'](wallet.address, -120, 0, MaxUint128, MaxUint128)
      )
        .to.emit(token0, 'Transfer')
        .withArgs(pool.address, wallet.address, BigNumber.from('6017734268818165').add('18107525382602')) // roughly 0.3% despite other liquidity
      expect((await pool.slot0()).tick).to.be.lt(-120)
    })
  })

  describe('#collect', () => {
    beforeEach(async () => {
      pool = await createPool(FeeAmount.LOW, TICK_SPACINGS[FeeAmount.LOW])
    })

    it('works with multiple LPs', async () => {
      await mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
      await mint(wallet.address, minTick + tickSpacing, maxTick - tickSpacing, expandTo18Decimals(2))

      await swapExact0For1(expandTo18Decimals(1), wallet.address)

      // poke positions
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      await pool['burn(int24,int24,uint128)'](minTick + tickSpacing, maxTick - tickSpacing, 0)

      const { tokensOwed0: tokensOwed0Position0 } = await pool.positions(
        getPositionKey(wallet.address, minTick, maxTick)
      )
      const { tokensOwed0: tokensOwed0Position1 } = await pool.positions(
        getPositionKey(wallet.address, minTick + tickSpacing, maxTick - tickSpacing)
      )

      expect(tokensOwed0Position0).to.be.eq('166666666666667')
      expect(tokensOwed0Position1).to.be.eq('333333333333334')
    })

    describe('works across large increases', () => {
      beforeEach(async () => {
        await mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
      })

      // type(uint128).max * 2**128 / 1e18
      // https://www.wolframalpha.com/input/?i=%282**128+-+1%29+*+2**128+%2F+1e18
      const magicNumber = BigNumber.from('115792089237316195423570985008687907852929702298719625575994')

      it('works just before the cap binds', async () => {
        await pool.setFeeGrowthGlobal0X128(magicNumber)
        await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)

        const { tokensOwed0, tokensOwed1 } = await pool.positions(getPositionKey(wallet.address, minTick, maxTick))

        expect(tokensOwed0).to.be.eq(MaxUint128.sub(1))
        expect(tokensOwed1).to.be.eq(0)
      })

      it('works just after the cap binds', async () => {
        await pool.setFeeGrowthGlobal0X128(magicNumber.add(1))
        await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)

        const { tokensOwed0, tokensOwed1 } = await pool.positions(getPositionKey(wallet.address, minTick, maxTick))

        expect(tokensOwed0).to.be.eq(MaxUint128)
        expect(tokensOwed1).to.be.eq(0)
      })

      it('works well after the cap binds', async () => {
        await pool.setFeeGrowthGlobal0X128(constants.MaxUint256)
        await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)

        const { tokensOwed0, tokensOwed1 } = await pool.positions(getPositionKey(wallet.address, minTick, maxTick))

        expect(tokensOwed0).to.be.eq(MaxUint128)
        expect(tokensOwed1).to.be.eq(0)
      })
    })

    describe('works across overflow boundaries', () => {
      beforeEach(async () => {
        await pool.setFeeGrowthGlobal0X128(constants.MaxUint256)
        await pool.setFeeGrowthGlobal1X128(constants.MaxUint256)
        await mint(wallet.address, minTick, maxTick, expandTo18Decimals(10))
      })

      it('token0', async () => {
        await swapExact0For1(expandTo18Decimals(1), wallet.address)
        await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
        const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
          wallet.address,
          minTick,
          maxTick,
          MaxUint128,
          MaxUint128
        )
        expect(amount0).to.be.eq('499999999999999')
        expect(amount1).to.be.eq(0)
      })
      it('token1', async () => {
        await swapExact1For0(expandTo18Decimals(1), wallet.address)
        await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
        const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
          wallet.address,
          minTick,
          maxTick,
          MaxUint128,
          MaxUint128
        )
        expect(amount0).to.be.eq(0)
        expect(amount1).to.be.eq('499999999999999')
      })
      it('token0 and token1', async () => {
        await swapExact0For1(expandTo18Decimals(1), wallet.address)
        await swapExact1For0(expandTo18Decimals(1), wallet.address)
        await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
        const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
          wallet.address,
          minTick,
          maxTick,
          MaxUint128,
          MaxUint128
        )
        expect(amount0).to.be.eq('499999999999999')
        expect(amount1).to.be.eq('500000000000000')
      })
    })
  })

  describe('#tickSpacing', () => {
    describe('tickSpacing = 12', () => {
      beforeEach('deploy pool', async () => {
        pool = await createPool(FeeAmount.MEDIUM, 12)
      })
      describe('post initialize', () => {
        it('mint can only be called for multiples of 12', async () => {
          await expect(mint(wallet.address, -6, 0, 1)).to.be.reverted
          await expect(mint(wallet.address, 0, 6, 1)).to.be.reverted
        })
        it('mint can be called with multiples of 12', async () => {
          await mint(wallet.address, 12, 24, 1)
          await mint(wallet.address, -144, -120, 1)
        })
        it('swapping across gaps works in 1 for 0 direction', async () => {
          const liquidityAmount = expandTo18Decimals(1).div(4)
          await mint(wallet.address, 120000, 121200, liquidityAmount)
          await swapExact1For0(expandTo18Decimals(1), wallet.address)
          await expect(pool['burn(int24,int24,uint128)'](120000, 121200, liquidityAmount))
            .to.emit(pool, 'Burn')
            .withArgs(wallet.address, 120000, 121200, liquidityAmount, '30027458295511', '996999999999999999')
            .to.not.emit(token0, 'Transfer')
            .to.not.emit(token1, 'Transfer')
          expect((await pool.slot0()).tick).to.eq(120196)
        })
        it('swapping across gaps works in 0 for 1 direction', async () => {
          const liquidityAmount = expandTo18Decimals(1).div(4)
          await mint(wallet.address, -121200, -120000, liquidityAmount)
          await swapExact0For1(expandTo18Decimals(1), wallet.address)
          await expect(pool['burn(int24,int24,uint128)'](-121200, -120000, liquidityAmount))
            .to.emit(pool, 'Burn')
            .withArgs(wallet.address, -121200, -120000, liquidityAmount, '996999999999999999', '30027458295511')
            .to.not.emit(token0, 'Transfer')
            .to.not.emit(token1, 'Transfer')
          expect((await pool.slot0()).tick).to.eq(-120197)
        })
      })
    })
  })

  // https://github.com/CLniswap-v3-core/issues/214
  it('tick transition cannot run twice if zero for one swap ends at fractional price just below tick', async () => {
    pool = await createPool(FeeAmount.MEDIUM, 1)
    await pool.uninitialize()
    const sqrtTickMath = (await (await ethers.getContractFactory('TickMathTest')).deploy()) as TickMathTest
    const swapMath = (await (await ethers.getContractFactory('SwapMathTest')).deploy()) as SwapMathTest
    const p0 = (await sqrtTickMath.getSqrtRatioAtTick(-24081)).add(1)
    // initialize at a price of ~0.3 token1/token0
    // meaning if you swap in 2 token0, you should end up getting 0 token1
    await pool.initialize(
      factory.address,
      token0.address,
      token1.address,
      1,
      p0,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero
    )
    expect(await pool.liquidity(), 'current pool liquidity is 1').to.eq(0)
    expect((await pool.slot0()).tick, 'pool tick is -24081').to.eq(-24081)

    // add a bunch of liquidity around current price
    const liquidity = expandTo18Decimals(1000)
    await mint(wallet.address, -24082, -24080, liquidity)
    expect(await pool.liquidity(), 'current pool liquidity is now liquidity + 1').to.eq(liquidity)

    await mint(wallet.address, -24082, -24081, liquidity)
    expect(await pool.liquidity(), 'current pool liquidity is still liquidity + 1').to.eq(liquidity)

    // check the math works out to moving the price down 1, sending no amount out, and having some amount remaining
    {
      const { feeAmount, amountIn, amountOut, sqrtQ } = await swapMath.computeSwapStep(
        p0,
        p0.sub(1),
        liquidity,
        3,
        FeeAmount.MEDIUM
      )
      expect(sqrtQ, 'price moves').to.eq(p0.sub(1))
      expect(feeAmount, 'fee amount is 1').to.eq(1)
      expect(amountIn, 'amount in is 1').to.eq(1)
      expect(amountOut, 'zero amount out').to.eq(0)
    }

    // swap 2 amount in, should get 0 amount out
    await expect(swapExact0For1(3, wallet.address))
      .to.emit(token0, 'Transfer')
      .withArgs(wallet.address, pool.address, 3)
      .to.not.emit(token1, 'Transfer')

    const { tick, sqrtPriceX96 } = await pool.slot0()

    expect(tick, 'pool is at the next tick').to.eq(-24082)
    expect(sqrtPriceX96, 'pool price is still on the p0 boundary').to.eq(p0.sub(1))
    expect(await pool.liquidity(), 'pool has run tick transition and liquidity changed').to.eq(liquidity.mul(2))
  })

  describe('#flash', () => {
    it('fails if no liquidity', async () => {
      await expect(flash(100, 200, other.address)).to.be.revertedWith('L')
      await expect(flash(100, 0, other.address)).to.be.revertedWith('L')
      await expect(flash(0, 200, other.address)).to.be.revertedWith('L')
    })
    describe('after liquidity added', () => {
      let balance0: BigNumber
      let balance1: BigNumber
      beforeEach('add some tokens', async () => {
        await initializeAtZeroTick(pool)
        ;[balance0, balance1] = await Promise.all([token0.balanceOf(pool.address), token1.balanceOf(pool.address)])
      })

      describe('fee off', () => {
        it('emits an event', async () => {
          await expect(flash(1001, 2001, other.address))
            .to.emit(pool, 'Flash')
            .withArgs(swapTarget.address, other.address, 1001, 2001, 4, 7)
        })

        it('transfers the amount0 to the recipient', async () => {
          await expect(flash(100, 200, other.address))
            .to.emit(token0, 'Transfer')
            .withArgs(pool.address, other.address, 100)
        })
        it('transfers the amount1 to the recipient', async () => {
          await expect(flash(100, 200, other.address))
            .to.emit(token1, 'Transfer')
            .withArgs(pool.address, other.address, 200)
        })
        it('can flash only token0', async () => {
          await expect(flash(101, 0, other.address))
            .to.emit(token0, 'Transfer')
            .withArgs(pool.address, other.address, 101)
            .to.not.emit(token1, 'Transfer')
        })
        it('can flash only token1', async () => {
          await expect(flash(0, 102, other.address))
            .to.emit(token1, 'Transfer')
            .withArgs(pool.address, other.address, 102)
            .to.not.emit(token0, 'Transfer')
        })
        it('can flash entire token balance', async () => {
          await expect(flash(balance0, balance1, other.address))
            .to.emit(token0, 'Transfer')
            .withArgs(pool.address, other.address, balance0)
            .to.emit(token1, 'Transfer')
            .withArgs(pool.address, other.address, balance1)
        })
        it('no-op if both amounts are 0', async () => {
          await expect(flash(0, 0, other.address)).to.not.emit(token0, 'Transfer').to.not.emit(token1, 'Transfer')
        })
        it('fails if flash amount is greater than token balance', async () => {
          await expect(flash(balance0.add(1), balance1, other.address)).to.be.reverted
          await expect(flash(balance0, balance1.add(1), other.address)).to.be.reverted
        })
        it('calls the flash callback on the sender with correct fee amounts', async () => {
          await expect(flash(1001, 2002, other.address)).to.emit(swapTarget, 'FlashCallback').withArgs(4, 7)
        })
        it('increases the fee growth by the expected amount', async () => {
          await flash(1001, 2002, other.address)
          expect(await pool.feeGrowthGlobal0X128()).to.eq(
            BigNumber.from(4).mul(BigNumber.from(2).pow(128)).div(expandTo18Decimals(2))
          )
          expect(await pool.feeGrowthGlobal1X128()).to.eq(
            BigNumber.from(7).mul(BigNumber.from(2).pow(128)).div(expandTo18Decimals(2))
          )
        })
        it('fails if original balance not returned in either token', async () => {
          await expect(flash(1000, 0, other.address, 999, 0)).to.be.reverted
          await expect(flash(0, 1000, other.address, 0, 999)).to.be.reverted
        })
        it('fails if underpays either token', async () => {
          await expect(flash(1000, 0, other.address, 1002, 0)).to.be.reverted
          await expect(flash(0, 1000, other.address, 0, 1002)).to.be.reverted
        })
        it('allows donating token0', async () => {
          await expect(flash(0, 0, constants.AddressZero, 567, 0))
            .to.emit(token0, 'Transfer')
            .withArgs(wallet.address, pool.address, 567)
            .to.not.emit(token1, 'Transfer')
          expect(await pool.feeGrowthGlobal0X128()).to.eq(
            BigNumber.from(567).mul(BigNumber.from(2).pow(128)).div(expandTo18Decimals(2))
          )
        })
        it('allows donating token1', async () => {
          await expect(flash(0, 0, constants.AddressZero, 0, 678))
            .to.emit(token1, 'Transfer')
            .withArgs(wallet.address, pool.address, 678)
            .to.not.emit(token0, 'Transfer')
          expect(await pool.feeGrowthGlobal1X128()).to.eq(
            BigNumber.from(678).mul(BigNumber.from(2).pow(128)).div(expandTo18Decimals(2))
          )
        })
        it('allows donating token0 and token1 together', async () => {
          await expect(flash(0, 0, constants.AddressZero, 789, 1234))
            .to.emit(token0, 'Transfer')
            .withArgs(wallet.address, pool.address, 789)
            .to.emit(token1, 'Transfer')
            .withArgs(wallet.address, pool.address, 1234)

          expect(await pool.feeGrowthGlobal0X128()).to.eq(
            BigNumber.from(789).mul(BigNumber.from(2).pow(128)).div(expandTo18Decimals(2))
          )
          expect(await pool.feeGrowthGlobal1X128()).to.eq(
            BigNumber.from(1234).mul(BigNumber.from(2).pow(128)).div(expandTo18Decimals(2))
          )
        })
      })
    })
  })

  describe('#increaseObservationCardinalityNext', () => {
    describe('after initialization', () => {
      beforeEach('initialize the pool', async () => {
        await pool.uninitialize()
        await pool.initialize(
          factory.address,
          token0.address,
          token1.address,
          TICK_SPACINGS[FeeAmount.MEDIUM],
          encodePriceSqrt(1, 1),
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        )
      })
      it('oracle starting state after initialization', async () => {
        const { observationCardinality, observationIndex, observationCardinalityNext } = await pool.slot0()
        expect(observationCardinality).to.eq(1)
        expect(observationIndex).to.eq(0)
        expect(observationCardinalityNext).to.eq(1)
        const {
          secondsPerLiquidityCumulativeX128,
          tickCumulative,
          initialized,
          blockTimestamp,
        } = await pool.observations(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
        expect(tickCumulative).to.eq(0)
        expect(initialized).to.eq(true)
        expect(blockTimestamp).to.eq(TEST_POOL_START_TIME)
      })
      it('increases observation cardinality next', async () => {
        await pool.increaseObservationCardinalityNext(2)
        const { observationCardinality, observationIndex, observationCardinalityNext } = await pool.slot0()
        expect(observationCardinality).to.eq(1)
        expect(observationIndex).to.eq(0)
        expect(observationCardinalityNext).to.eq(2)
      })
      it('is no op if target is already exceeded', async () => {
        await pool.increaseObservationCardinalityNext(5)
        await pool.increaseObservationCardinalityNext(3)
        const { observationCardinality, observationIndex, observationCardinalityNext } = await pool.slot0()
        expect(observationCardinality).to.eq(1)
        expect(observationIndex).to.eq(0)
        expect(observationCardinalityNext).to.eq(5)
      })
    })
  })

  describe('#lock', () => {
    beforeEach('initialize the pool', async () => {
      await mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
    })

    it('cannot reenter from swap callback', async () => {
      const reentrant = (await (
        await ethers.getContractFactory('TestCLReentrantCallee')
      ).deploy()) as TestCLReentrantCallee

      // the tests happen in solidity
      await expect(reentrant.swapToReenter(pool.address)).to.be.revertedWith('Unable to reenter')
    })
  })

  describe('#snapshotCumulativesInside', () => {
    const tickLower = -TICK_SPACINGS[FeeAmount.MEDIUM]
    const tickUpper = TICK_SPACINGS[FeeAmount.MEDIUM]
    const tickSpacing = TICK_SPACINGS[FeeAmount.MEDIUM]
    beforeEach(async () => {
      await mint(wallet.address, tickLower, tickUpper, 10)
    })
    it('throws if ticks are in reverse order', async () => {
      await expect(pool.snapshotCumulativesInside(tickUpper, tickLower)).to.be.reverted
    })
    it('throws if ticks are the same', async () => {
      await expect(pool.snapshotCumulativesInside(tickUpper, tickUpper)).to.be.reverted
    })
    it('throws if tick lower is too low', async () => {
      await expect(pool.snapshotCumulativesInside(getMinTick(tickSpacing) - 1, tickUpper)).be.reverted
    })
    it('throws if tick upper is too high', async () => {
      await expect(pool.snapshotCumulativesInside(tickLower, getMaxTick(tickSpacing) + 1)).be.reverted
    })
    it('throws if tick lower is not initialized', async () => {
      await expect(pool.snapshotCumulativesInside(tickLower - tickSpacing, tickUpper)).to.be.reverted
    })
    it('throws if tick upper is not initialized', async () => {
      await expect(pool.snapshotCumulativesInside(tickLower, tickUpper + tickSpacing)).to.be.reverted
    })
    it('is zero immediately after initialize', async () => {
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(0)
      expect(tickCumulativeInside).to.eq(0)
      expect(secondsInside).to.eq(0)
    })
    it('increases by expected amount when time elapses in the range', async () => {
      await pool.advanceTime(5)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(5).shl(128).div(10))
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(0)
      expect(secondsInside).to.eq(5)
    })
    it('does not account for time increase above range', async () => {
      await pool.advanceTime(5)
      await swapToHigherPrice(encodePriceSqrt(2, 1), wallet.address)
      await pool.advanceTime(7)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(5).shl(128).div(10))
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(0)
      expect(secondsInside).to.eq(5)
    })
    it('does not account for time increase below range', async () => {
      await pool.advanceTime(5)
      await swapToLowerPrice(encodePriceSqrt(1, 2), wallet.address)
      await pool.advanceTime(7)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(5).shl(128).div(10))
      // tick is 0 for 5 seconds, then not in range
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(0)
      expect(secondsInside).to.eq(5)
    })
    it('time increase below range is not counted', async () => {
      await swapToLowerPrice(encodePriceSqrt(1, 2), wallet.address)
      await pool.advanceTime(5)
      await swapToHigherPrice(encodePriceSqrt(1, 1), wallet.address)
      await pool.advanceTime(7)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(7).shl(128).div(10))
      // tick is not in range then tick is 0 for 7 seconds
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(0)
      expect(secondsInside).to.eq(7)
    })
    it('time increase above range is not counted', async () => {
      await swapToHigherPrice(encodePriceSqrt(2, 1), wallet.address)
      await pool.advanceTime(5)
      await swapToLowerPrice(encodePriceSqrt(1, 1), wallet.address)
      await pool.advanceTime(7)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(7).shl(128).div(10))
      expect((await pool.slot0()).tick).to.eq(-1) // justify the -7 tick cumulative inside value
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(-7)
      expect(secondsInside).to.eq(7)
    })
    it('positions minted after time spent', async () => {
      await pool.advanceTime(5)
      await mint(wallet.address, tickUpper, getMaxTick(tickSpacing), 15)
      await swapToHigherPrice(encodePriceSqrt(2, 1), wallet.address)
      await pool.advanceTime(8)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickUpper, getMaxTick(tickSpacing))
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(8).shl(128).div(15))
      // the tick of 2/1 is 6931
      // 8 seconds * 6931 = 55448
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(55448)
      expect(secondsInside).to.eq(8)
    })
    it('overlapping liquidity is aggregated', async () => {
      await mint(wallet.address, tickLower, getMaxTick(tickSpacing), 15)
      await pool.advanceTime(5)
      await swapToHigherPrice(encodePriceSqrt(2, 1), wallet.address)
      await pool.advanceTime(8)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(tickLower, tickUpper)
      expect(secondsPerLiquidityInsideX128).to.eq(BigNumber.from(5).shl(128).div(25))
      expect(tickCumulativeInside, 'tickCumulativeInside').to.eq(0)
      expect(secondsInside).to.eq(5)
    })
    it('relative behavior of snapshots', async () => {
      await pool.advanceTime(5)
      await mint(wallet.address, getMinTick(tickSpacing), tickLower, 15)
      const {
        secondsPerLiquidityInsideX128: secondsPerLiquidityInsideX128Start,
        tickCumulativeInside: tickCumulativeInsideStart,
        secondsInside: secondsInsideStart,
      } = await pool.snapshotCumulativesInside(getMinTick(tickSpacing), tickLower)
      await pool.advanceTime(8)
      // 13 seconds in starting range, then 3 seconds in newly minted range
      await swapToLowerPrice(encodePriceSqrt(1, 2), wallet.address)
      await pool.advanceTime(3)
      const {
        secondsPerLiquidityInsideX128,
        tickCumulativeInside,
        secondsInside,
      } = await pool.snapshotCumulativesInside(getMinTick(tickSpacing), tickLower)
      const expectedDiffSecondsPerLiquidity = BigNumber.from(3).shl(128).div(15)
      expect(secondsPerLiquidityInsideX128.sub(secondsPerLiquidityInsideX128Start)).to.eq(
        expectedDiffSecondsPerLiquidity
      )
      expect(secondsPerLiquidityInsideX128).to.not.eq(expectedDiffSecondsPerLiquidity)
      // the tick is the one corresponding to the price of 1/2, or log base 1.0001 of 0.5
      // this is -6932, and 3 seconds have passed, so the cumulative computed from the diff equals 6932 * 3
      expect(tickCumulativeInside.sub(tickCumulativeInsideStart), 'tickCumulativeInside').to.eq(-20796)
      expect(secondsInside - secondsInsideStart).to.eq(3)
      expect(secondsInside).to.not.eq(3)
    })
  })

  describe('fees overflow scenarios', async () => {
    it('up to max uint 128', async () => {
      await mint(wallet.address, minTick, maxTick, 1)
      await flash(0, 0, wallet.address, MaxUint128, MaxUint128)

      const [feeGrowthGlobal0X128, feeGrowthGlobal1X128] = await Promise.all([
        pool.feeGrowthGlobal0X128(),
        pool.feeGrowthGlobal1X128(),
      ])
      // all 1s in first 128 bits
      expect(feeGrowthGlobal0X128).to.eq(MaxUint128.shl(128))
      expect(feeGrowthGlobal1X128).to.eq(MaxUint128.shl(128))
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        minTick,
        maxTick,
        MaxUint128,
        MaxUint128
      )
      expect(amount0).to.eq(MaxUint128)
      expect(amount1).to.eq(MaxUint128)
    })

    it('overflow max uint 128', async () => {
      await mint(wallet.address, minTick, maxTick, 1)
      await flash(0, 0, wallet.address, MaxUint128, MaxUint128)
      await flash(0, 0, wallet.address, 1, 1)

      const [feeGrowthGlobal0X128, feeGrowthGlobal1X128] = await Promise.all([
        pool.feeGrowthGlobal0X128(),
        pool.feeGrowthGlobal1X128(),
      ])
      // all 1s in first 128 bits
      expect(feeGrowthGlobal0X128).to.eq(0)
      expect(feeGrowthGlobal1X128).to.eq(0)
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        minTick,
        maxTick,
        MaxUint128,
        MaxUint128
      )
      // fees burned
      expect(amount0).to.eq(0)
      expect(amount1).to.eq(0)
    })

    it('overflow max uint 128 after poke burns fees owed to 0', async () => {
      await mint(wallet.address, minTick, maxTick, 1)
      await flash(0, 0, wallet.address, MaxUint128, MaxUint128)
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      await flash(0, 0, wallet.address, 1, 1)
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)

      const { amount0, amount1 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        minTick,
        maxTick,
        MaxUint128,
        MaxUint128
      )
      // fees burned
      expect(amount0).to.eq(0)
      expect(amount1).to.eq(0)
    })

    it('two positions at the same snapshot', async () => {
      await mint(wallet.address, minTick, maxTick, 1)
      await mint(other.address, minTick, maxTick, 1)
      await flash(0, 0, wallet.address, MaxUint128, 0)
      await flash(0, 0, wallet.address, MaxUint128, 0)
      const feeGrowthGlobal0X128 = await pool.feeGrowthGlobal0X128()
      expect(feeGrowthGlobal0X128).to.eq(MaxUint128.shl(128))
      await flash(0, 0, wallet.address, 2, 0)
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      await pool.connect(other)['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      let { amount0 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        minTick,
        maxTick,
        MaxUint128,
        MaxUint128
      )
      expect(amount0, 'amount0 of wallet').to.eq(0)
      ;({ amount0 } = await pool
        .connect(other)
        .callStatic['collect(address,int24,int24,uint128,uint128)'](
          other.address,
          minTick,
          maxTick,
          MaxUint128,
          MaxUint128
        ))
      expect(amount0, 'amount0 of other').to.eq(0)
    })

    it('two positions 1 wei of fees apart overflows exactly once', async () => {
      await mint(wallet.address, minTick, maxTick, 1)
      await flash(0, 0, wallet.address, 1, 0)
      await mint(other.address, minTick, maxTick, 1)
      await flash(0, 0, wallet.address, MaxUint128, 0)
      await flash(0, 0, wallet.address, MaxUint128, 0)
      const feeGrowthGlobal0X128 = await pool.feeGrowthGlobal0X128()
      expect(feeGrowthGlobal0X128).to.eq(0)
      await flash(0, 0, wallet.address, 2, 0)
      await pool['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      await pool.connect(other)['burn(int24,int24,uint128)'](minTick, maxTick, 0)
      let { amount0 } = await pool.callStatic['collect(address,int24,int24,uint128,uint128)'](
        wallet.address,
        minTick,
        maxTick,
        MaxUint128,
        MaxUint128
      )
      expect(amount0, 'amount0 of wallet').to.eq(1)
      ;({ amount0 } = await pool
        .connect(other)
        .callStatic['collect(address,int24,int24,uint128,uint128)'](
          other.address,
          minTick,
          maxTick,
          MaxUint128,
          MaxUint128
        ))
      expect(amount0, 'amount0 of other').to.eq(0)
    })
  })

  describe('swap underpayment tests', () => {
    let underpay: TestCLSwapPay
    beforeEach('deploy swap test', async () => {
      const underpayFactory = await ethers.getContractFactory('TestCLSwapPay')
      underpay = (await underpayFactory.deploy()) as TestCLSwapPay
      await token0.approve(underpay.address, constants.MaxUint256)
      await token1.approve(underpay.address, constants.MaxUint256)
      await mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
    })

    it('underpay zero for one and exact in', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, true, MIN_SQRT_RATIO.add(1), 1000, 1, 0)
      ).to.be.revertedWith('IIA')
    })
    it('pay in the wrong token zero for one and exact in', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, true, MIN_SQRT_RATIO.add(1), 1000, 0, 2000)
      ).to.be.revertedWith('IIA')
    })
    it('overpay zero for one and exact in', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, true, MIN_SQRT_RATIO.add(1), 1000, 2000, 0)
      ).to.not.be.revertedWith('IIA')
    })
    it('underpay zero for one and exact out', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, true, MIN_SQRT_RATIO.add(1), -1000, 1, 0)
      ).to.be.revertedWith('IIA')
    })
    it('pay in the wrong token zero for one and exact out', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, true, MIN_SQRT_RATIO.add(1), -1000, 0, 2000)
      ).to.be.revertedWith('IIA')
    })
    it('overpay zero for one and exact out', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, true, MIN_SQRT_RATIO.add(1), -1000, 2000, 0)
      ).to.not.be.revertedWith('IIA')
    })
    it('underpay one for zero and exact in', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, false, MAX_SQRT_RATIO.sub(1), 1000, 0, 1)
      ).to.be.revertedWith('IIA')
    })
    it('pay in the wrong token one for zero and exact in', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, false, MAX_SQRT_RATIO.sub(1), 1000, 2000, 0)
      ).to.be.revertedWith('IIA')
    })
    it('overpay one for zero and exact in', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, false, MAX_SQRT_RATIO.sub(1), 1000, 0, 2000)
      ).to.not.be.revertedWith('IIA')
    })
    it('underpay one for zero and exact out', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, false, MAX_SQRT_RATIO.sub(1), -1000, 0, 1)
      ).to.be.revertedWith('IIA')
    })
    it('pay in the wrong token one for zero and exact out', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, false, MAX_SQRT_RATIO.sub(1), -1000, 2000, 0)
      ).to.be.revertedWith('IIA')
    })
    it('overpay one for zero and exact out', async () => {
      await expect(
        underpay.swap(pool.address, wallet.address, false, MAX_SQRT_RATIO.sub(1), -1000, 0, 2000)
      ).to.not.be.revertedWith('IIA')
    })
  })
})
