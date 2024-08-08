import { Fixture } from 'ethereum-waffle'
import { ethers, waffle } from 'hardhat'
import {
  ICLPool,
  ICLFactory,
  IWETH9,
  MockTimeSwapRouter,
  TestERC20,
  NonfungibleTokenPositionDescriptor,
  MockTimeNonfungiblePositionManager,
} from '../../../typechain'
import { MockVoter } from '../../../typechain/MockVoter'
import { CustomUnstakedFeeModule, MockVotingRewardsFactory } from '../../../typechain'
import { CLGaugeFactory } from '../../../typechain/CLGaugeFactory'
import { CLGauge } from '../../../typechain/CLGauge'
import { constants } from 'ethers'

import WETH9 from '../contracts/WETH9.json'

const wethFixture: Fixture<{ weth9: IWETH9 }> = async ([wallet]) => {
  const weth9 = (await waffle.deployContract(wallet, {
    bytecode: WETH9.bytecode,
    abi: WETH9.abi,
  })) as IWETH9

  return { weth9 }
}

const v3CoreFactoryFixture: Fixture<{
  factory: ICLFactory
  nft: MockTimeNonfungiblePositionManager
  weth9: IWETH9
  tokens: [TestERC20, TestERC20, TestERC20]
  nftDescriptor: NonfungibleTokenPositionDescriptor
}> = async ([wallet], provider) => {
  const { weth9 } = await wethFixture([wallet], provider)
  const tokenFactory = await ethers.getContractFactory('TestERC20')
  const rewardToken: TestERC20 = (await tokenFactory.deploy(constants.MaxUint256.div(2))) as TestERC20 // do not use maxu256 to avoid overflowing
  ;[wallet] = await (ethers as any).getSigners()

  const tokens: [TestERC20, TestERC20, TestERC20] = [
    (await tokenFactory.deploy(constants.MaxUint256.div(2))) as TestERC20, // do not use maxu256 to avoid overflowing
    (await tokenFactory.deploy(constants.MaxUint256.div(2))) as TestERC20,
    (await tokenFactory.deploy(constants.MaxUint256.div(2))) as TestERC20,
  ]

  tokens.sort((a, b) => (a.address.toLowerCase() < b.address.toLowerCase() ? -1 : 1))

  const Pool = await ethers.getContractFactory('CLPool')
  const Factory = await ethers.getContractFactory('CLFactory')
  const CustomUnstakedFeeModuleFactory = await ethers.getContractFactory('CustomUnstakedFeeModule')
  const pool = (await Pool.deploy()) as ICLPool

  const MockVoterFactory = await ethers.getContractFactory('MockVoter')
  const GaugeImplementationFactory = await ethers.getContractFactory('CLGauge')
  const GaugeFactoryFactory = await ethers.getContractFactory('CLGaugeFactory')
  const MockFactoryRegistryFactory = await ethers.getContractFactory('MockFactoryRegistry')
  const MockVotingRewardsFactoryFactory = await ethers.getContractFactory('MockVotingRewardsFactory')
  const MockVotingEscrowFactory = await ethers.getContractFactory('MockVotingEscrow')

  const positionManagerFactory = await ethers.getContractFactory('MockTimeNonfungiblePositionManager')

  // voter & gauge factory set up
  const mockVotingEscrow = await MockVotingEscrowFactory.deploy(wallet.address)
  const mockFactoryRegistry = await MockFactoryRegistryFactory.deploy()
  const mockVoter = (await MockVoterFactory.deploy(
    rewardToken.address,
    mockFactoryRegistry.address,
    mockVotingEscrow.address
  )) as MockVoter

  const factory = (await Factory.deploy(
    wallet.address,
    wallet.address,
    wallet.address,
    mockVoter.address,
    pool.address
  )) as ICLFactory
  const customUnstakedFeeModule = (await CustomUnstakedFeeModuleFactory.deploy(
    factory.address
  )) as CustomUnstakedFeeModule
  await factory.setUnstakedFeeModule(customUnstakedFeeModule.address)

  const nftDescriptorLibraryFactory = await ethers.getContractFactory('NFTDescriptor')
  const nftDescriptorLibrary = await nftDescriptorLibraryFactory.deploy()
  const nftSVGLibraryFactory = await ethers.getContractFactory('NFTSVG')
  const nftSVGLibrary = await nftSVGLibraryFactory.deploy()
  const positionDescriptorFactory = await ethers.getContractFactory('NonfungibleTokenPositionDescriptor', {
    libraries: {
      NFTDescriptor: nftDescriptorLibrary.address,
      NFTSVG: nftSVGLibrary.address,
    },
  })
  const nftDescriptor = (await positionDescriptorFactory.deploy(
    tokens[0].address,
    // 'ETH' as a bytes32 string
    '0x4554480000000000000000000000000000000000000000000000000000000000'
  )) as NonfungibleTokenPositionDescriptor

  const nft = (await positionManagerFactory.deploy(
    wallet.address,
    factory.address,
    weth9.address,
    nftDescriptor.address
  )) as MockTimeNonfungiblePositionManager

  const gaugeImplementation = (await GaugeImplementationFactory.deploy()) as CLGauge
  const gaugeFactory = (await GaugeFactoryFactory.deploy(
    wallet.address,
    mockVoter.address,
    nft.address,
    gaugeImplementation.address
  )) as CLGaugeFactory

  // approve pool factory <=> gauge factory combination
  const mockVotingRewardsFactory = (await MockVotingRewardsFactoryFactory.deploy()) as MockVotingRewardsFactory
  await mockFactoryRegistry.approve(
    factory.address,
    mockVotingRewardsFactory.address, // unused in hardhat tests
    gaugeFactory.address
  )

  // backwards compatible with v3-periphery tests
  await factory['enableTickSpacing(int24,uint24)'](10, 500)
  await factory['enableTickSpacing(int24,uint24)'](60, 3_000)
  return { factory, gaugeFactory, nft, weth9, tokens, nftDescriptor }
}

export const v3RouterFixture: Fixture<{
  weth9: IWETH9
  factory: ICLFactory
  router: MockTimeSwapRouter
  nft: MockTimeNonfungiblePositionManager
  tokens: [TestERC20, TestERC20, TestERC20]
  nftDescriptor: NonfungibleTokenPositionDescriptor
}> = async ([wallet], provider) => {
  const { factory, nft, weth9, tokens, nftDescriptor } = await v3CoreFactoryFixture([wallet], provider)

  const router = (await (await ethers.getContractFactory('MockTimeSwapRouter')).deploy(
    factory.address,
    weth9.address
  )) as MockTimeSwapRouter

  return { factory, weth9, router, nft, tokens, nftDescriptor }
}
