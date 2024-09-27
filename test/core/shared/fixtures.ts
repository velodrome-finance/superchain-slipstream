import { BigNumber, BigNumberish, utils, Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { constants } from 'ethers'
import { MockTimeCLPool } from '../../../typechain/MockTimeCLPool'
import { CoreTestERC20 } from '../../../typechain/CoreTestERC20'
import { CLFactory } from '../../../typechain/CLFactory'
import { TestCLCallee } from '../../../typechain/TestCLCallee'
import { TestCLRouter } from '../../../typechain/TestCLRouter'
import { MockVoter } from '../../../typechain/MockVoter'
import { CustomUnstakedFeeModule, MockFactoryRegistry, MockVotingRewardsFactory } from '../../../typechain'
import { CLLeafGaugeFactory } from '../../../typechain/CLLeafGaugeFactory'
import { encodePriceSqrt } from './utilities'
import { Fixture } from 'ethereum-waffle'

interface FactoryFixture {
  factory: CLFactory
  mockFactoryRegistry: MockFactoryRegistry
}
interface TokensFixture {
  token0: CoreTestERC20
  token1: CoreTestERC20
  token2: CoreTestERC20
}

async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('CoreTestERC20')
  const tokenA = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as CoreTestERC20
  const tokenB = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as CoreTestERC20
  const tokenC = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as CoreTestERC20

  const [token0, token1, token2] = [tokenA, tokenB, tokenC].sort((tokenA, tokenB) =>
    tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
  )

  return { token0, token1, token2 }
}

type TokensAndFactoryFixture = FactoryFixture & TokensFixture

interface PoolFixture extends TokensAndFactoryFixture {
  swapTargetCallee: TestCLCallee
  swapTargetRouter: TestCLRouter
  createPool(
    fee: number,
    tickSpacing: number,
    firstToken?: CoreTestERC20,
    secondToken?: CoreTestERC20,
    sqrtPriceX96?: BigNumberish
  ): Promise<MockTimeCLPool>
}
// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_POOL_START_TIME = 1601906400

export const poolFixture: Fixture<PoolFixture> = async function (): Promise<PoolFixture> {
  let wallet: Wallet
  ;[wallet] = await (ethers as any).getSigners()
  const { token0, token1, token2 } = await tokensFixture()

  const MockTimeCLPoolDeployerFactory = await ethers.getContractFactory('CLFactory')
  const MockTimeCLPoolFactory = await ethers.getContractFactory('MockTimeCLPool')
  const MockVoterFactory = await ethers.getContractFactory('MockVoter')
  const GaugeFactoryFactory = await ethers.getContractFactory('CLLeafGaugeFactory')
  const MockFactoryRegistryFactory = await ethers.getContractFactory('MockFactoryRegistry')
  const MockVotingRewardsFactoryFactory = await ethers.getContractFactory('MockVotingRewardsFactory')
  const MockVotingEscrowFactory = await ethers.getContractFactory('MockVotingEscrow')
  const CustomUnstakedFeeModuleFactory = await ethers.getContractFactory('CustomUnstakedFeeModule')

  // voter & gauge factory set up
  const mockVotingEscrow = await MockVotingEscrowFactory.deploy(wallet.address)
  const mockFactoryRegistry = await MockFactoryRegistryFactory.deploy()
  const mockVoter = (await MockVoterFactory.deploy(
    token2.address,
    mockFactoryRegistry.address,
    mockVotingEscrow.address,
    constants.AddressZero // minter
  )) as MockVoter

  const mockTimePool = (await MockTimeCLPoolFactory.deploy()) as MockTimeCLPool
  const mockTimePoolDeployer = (await MockTimeCLPoolDeployerFactory.deploy(
    wallet.address,
    wallet.address,
    wallet.address,
    mockVoter.address,
    mockTimePool.address,
    constants.AddressZero, // leafGaugeFactory
    constants.AddressZero // nft
  )) as CLFactory

  const gaugeFactory = (await GaugeFactoryFactory.deploy(
    mockVoter.address,
    constants.AddressZero, //nft address
    constants.AddressZero, //xerc20 address
    constants.AddressZero //bridge address
  )) as CLLeafGaugeFactory

  const customUnstakedFeeModule = (await CustomUnstakedFeeModuleFactory.deploy(
    mockTimePoolDeployer.address
  )) as CustomUnstakedFeeModule
  await mockTimePoolDeployer.setUnstakedFeeModule(customUnstakedFeeModule.address)
  // approve pool factory <=> gauge factory combination
  const mockVotingRewardsFactory = (await MockVotingRewardsFactoryFactory.deploy()) as MockVotingRewardsFactory
  await mockFactoryRegistry.approve(
    mockTimePoolDeployer.address,
    mockVotingRewardsFactory.address, // unused in hardhat tests
    gaugeFactory.address
  )

  const calleeContractFactory = await ethers.getContractFactory('TestCLCallee')
  const routerContractFactory = await ethers.getContractFactory('TestCLRouter')

  const swapTargetCallee = (await calleeContractFactory.deploy()) as TestCLCallee
  const swapTargetRouter = (await routerContractFactory.deploy()) as TestCLRouter
  return {
    token0,
    token1,
    token2,
    factory: mockTimePoolDeployer,
    swapTargetCallee,
    swapTargetRouter,
    mockFactoryRegistry,
    createPool: async (
      fee,
      tickSpacing,
      firstToken = token0,
      secondToken = token1,
      sqrtPriceX96 = encodePriceSqrt(1, 1)
    ) => {
      // add tick spacing if not already added, backwards compatible with CL tests
      const tickSpacingFee = await mockTimePoolDeployer.tickSpacingToFee(tickSpacing)
      if (tickSpacingFee == 0) await mockTimePoolDeployer['enableTickSpacing(int24,uint24)'](tickSpacing, fee)
      const tx = await mockTimePoolDeployer['createPool(address,address,int24,uint160)'](
        firstToken.address,
        secondToken.address,
        tickSpacing,
        sqrtPriceX96
      )
      const receipt = await tx.wait()
      const poolAddress = receipt.events?.[1].args?.pool as string
      const pool = MockTimeCLPoolFactory.attach(poolAddress) as MockTimeCLPool
      await pool.advanceTime(TEST_POOL_START_TIME)
      customUnstakedFeeModule.setCustomFee(poolAddress, 420)
      return pool
    },
  }
}
