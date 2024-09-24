pragma solidity ^0.7.6;
pragma abicoder v2;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import "forge-std/Test.sol";

import {CLFactory} from "contracts/core/CLFactory.sol";
import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";
import {ICreateX} from "contracts/libraries/ICreateX.sol";
import {ICLPool, CLPool} from "contracts/core/CLPool.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {
    INonfungiblePositionManager, NonfungiblePositionManager
} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLLeafGaugeFactory} from "contracts/gauge/CLLeafGaugeFactory.sol";
import {CLLeafGauge} from "contracts/gauge/CLLeafGauge.sol";
import {MockWETH} from "contracts/test/MockWETH.sol";
import {ILeafVoter, LeafVoter} from "contracts/test/LeafVoter.sol";
import {IVoter, MockVoter} from "contracts/test/MockVoter.sol";
import {IVotingEscrow, MockVotingEscrow} from "contracts/test/MockVotingEscrow.sol";
import {IFactoryRegistry, MockFactoryRegistry} from "contracts/test/MockFactoryRegistry.sol";
import {IVotingRewardsFactory, MockVotingRewardsFactory} from "contracts/test/MockVotingRewardsFactory.sol";
import {TestConstants} from "./utils/TestConstants.sol";
import {Events} from "./utils/Events.sol";
import {PoolUtils} from "./utils/PoolUtils.sol";
import {Users} from "./utils/Users.sol";
import {SafeCast} from "contracts/gauge/libraries/SafeCast.sol";
import {TestCLCallee} from "contracts/core/test/TestCLCallee.sol";
import {NFTManagerCallee} from "contracts/periphery/test/NFTManagerCallee.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {IMinter} from "contracts/core/interfaces/IMinter.sol";
import {ILpMigrator, LpMigrator} from "contracts/periphery/LpMigrator.sol";
import {VelodromeTimeLibrary} from "contracts/libraries/VelodromeTimeLibrary.sol";

import {Constants} from "script/constants/Constants.sol";

import {IXERC20} from "contracts/superchain/IXERC20.sol";
import {IXERC20Lockbox} from "contracts/superchain/IXERC20Lockbox.sol";
import {IChainRegistry} from "contracts/mainnet/interfaces/bridge/IChainRegistry.sol";
import {IRootMessageBridge} from "contracts/mainnet/interfaces/bridge/IRootMessageBridge.sol";
import {IRootHLMessageModule} from "contracts/mainnet/interfaces/bridge/hyperlane/IRootHLMessageModule.sol";
import {RootCLPool} from "contracts/mainnet/pool/RootCLPool.sol";
import {RootCLPoolFactory} from "contracts/mainnet/pool/RootCLPoolFactory.sol";
import {ICLRootGaugeFactory, CLRootGaugeFactory} from "contracts/mainnet/gauge/CLRootGaugeFactory.sol";
import {ICLRootGauge, CLRootGauge} from "contracts/mainnet/gauge/CLRootGauge.sol";
import {
    IRootVotingRewardsFactory, MockRootVotingRewardsFactory
} from "contracts/test/MockRootVotingRewardsFactory.sol";
import {ILeafMessageBridge, MockLeafMessageBridge} from "contracts/test/MockLeafMessageBridge.sol";
import {IMailbox} from "contracts/test/interfaces/IMailbox.sol";

import {TestERC20} from "contracts/periphery/test/TestERC20.sol";

abstract contract BaseForkFixture is Test, TestConstants, Events, PoolUtils {
    using CreateXLibrary for bytes11;
    using SafeCast for uint256;

    //TODO: to avoid leaf gauge factory collision.
    //Should be removed once the test refactor is setup in correct root/leaf chains
    bytes11 public constant CL_LEAF_GAUGE_FACTORY_ENTROPY = 0x0000000000000000000040;

    string public addresses;

    /// @dev Fixed fee used for x-chain message quotes
    uint256 public constant MESSAGE_FEE = 1 ether / 10_000; // 0.0001 ETH

    // root variables
    uint32 public rootChainId = 10; // root chain id
    uint256 public rootId; // root fork id (used by foundry)
    uint256 public rootStartTime; // root fork start time (set to start of epoch for simplicity)

    //leaf variables
    uint32 public leaf = 34443; // leaf chain id
    // uint256 public leafId; // root fork id (used by foundry)
    // uint256 public leafStartTime; // root fork start time (set to start of epoch for simplicity)

    // root superchain contracts
    IXERC20 public xVelo;
    IRootMessageBridge public rootMessageBridge;
    IRootHLMessageModule public rootMessageModule;

    // root-only contracts
    IXERC20Lockbox public rootLockbox;
    RootCLPoolFactory public rootPoolFactory;
    RootCLPool public rootPoolImplementation;
    CLRootGaugeFactory public rootGaugeFactory;

    // leaf contracts
    CLFactory public poolFactory;
    CLPool public poolImplementation;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLLeafGaugeFactory public leafGaugeFactory;
    CLLeafGauge public gaugeImplementation;
    LpMigrator public lpMigrator;

    // root mocks
    IVoter public rootVoter;
    IRootVotingRewardsFactory public rootVotingRewardsFactory;

    /// @dev mocks
    IFactoryRegistry public factoryRegistry;
    ILeafVoter public leafVoter;
    IVotingEscrow public escrow;
    IMinter public minter;
    IERC20 public weth;
    IVotingRewardsFactory public votingRewardsFactory;
    IMailbox public rootMailbox;

    ILeafMessageBridge public leafMessageBridge;
    address public leafMessageModule; // used for test purposes

    ERC20 public rewardToken;

    ERC20 public token0;
    ERC20 public token1;

    IERC20 public op;

    Users internal users;

    TestCLCallee public clCallee;
    NFTManagerCallee public nftCallee;
    NFTManagerCallee public e2eNftCallee;

    CustomSwapFeeModule public customSwapFeeModule;
    CustomUnstakedFeeModule public customUnstakedFeeModule;

    string public nftName = "Slipstream Position NFT v1";
    string public nftSymbol = "CL-POS";

    /// mocks
    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    uint256 public blockNumber = vm.envUint("FORK_BLOCK_NUMBER");

    function setUp() public virtual {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/fork/addresses.json"));
        addresses = vm.readFile(path);

        //createX block is 113736815
        require(blockNumber >= 113736816, "BlockNumber too low");

        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: blockNumber});

        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        createUsers();

        rewardToken = new ERC20("", "");

        setUpDependencyForks();
        deployRootDependencies();
        setUpRootChain();
        deployDependencies();

        // approve gauge in factory registry
        vm.prank(Ownable(address(factoryRegistry)).owner());
        factoryRegistry.approve({
            poolFactory: address(rootPoolFactory),
            votingRewardsFactory: address(rootVotingRewardsFactory),
            gaugeFactory: address(rootGaugeFactory)
        });

        // mock calls to dispatch
        vm.mockCall({
            callee: address(rootMailbox),
            data: abi.encode(bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes)"))),
            returnData: abi.encode(MESSAGE_FEE)
        });

        leafMessageModule = makeAddr({name: "LeafMessageModule"});
        leafMessageBridge = ILeafMessageBridge(
            new MockLeafMessageBridge(users.owner, address(xVelo), address(leafVoter), leafMessageModule)
        ); // TODO: for now it is mock, later it should be from a fork

        leafVoter = ILeafVoter(
            new LeafVoter({
                _factoryRegistry: address(factoryRegistry),
                _emergencyCouncil: users.owner, // emergency council
                _messageBridge: address(leafMessageBridge) // message bridge
            })
        );

        address deployer = users.deployer;
        poolImplementation = CLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(type(CLPool).creationCode)
            })
        );

        vm.prank(deployer);
        leafGaugeFactory =
            CLLeafGaugeFactory(CL_LEAF_GAUGE_FACTORY_ENTROPY.computeCreate3Address({_deployer: deployer}));
        nft = NonfungiblePositionManager(payable(NFT_POSITION_MANAGER.computeCreate3Address({_deployer: deployer})));

        poolFactory = CLFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(
                    type(CLFactory).creationCode,
                    abi.encode(
                        users.owner, // owner
                        users.owner, // swap fee manager
                        users.owner, // unstaked fee manager
                        address(leafVoter), // leaf voter
                        address(poolImplementation), // pool implementation
                        address(leafGaugeFactory),
                        address(nft)
                    )
                )
            })
        );
        vm.startPrank(users.owner);
        // backward compatibility with the original uniV3 fee structure and tick spacing
        poolFactory.enableTickSpacing(10, 500);
        poolFactory.enableTickSpacing(60, 3_000);
        // 200 tick spacing fee is manually overriden in tests as it is part of default settings
        vm.stopPrank();

        vm.startPrank(deployer);

        // deploy nft contracts
        nftDescriptor = NonfungibleTokenPositionDescriptor(
            cx.deployCreate3({
                salt: NFT_POSITION_DESCRIPTOR.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(
                    type(NonfungibleTokenPositionDescriptor).creationCode,
                    abi.encode(
                        address(weth), // WETH9
                        0x4554480000000000000000000000000000000000000000000000000000000000 // nativeCurrencyLabelBytes
                    )
                )
            })
        );
        nft = NonfungiblePositionManager(
            payable(
                cx.deployCreate3({
                    salt: NFT_POSITION_MANAGER.calculateSalt({_deployer: deployer}),
                    initCode: abi.encodePacked(
                        type(NonfungiblePositionManager).creationCode,
                        abi.encode(
                            users.owner, // owner
                            address(poolFactory), // pool factory
                            address(weth), // WETH9
                            address(nftDescriptor), // nft descriptor
                            nftName, // name
                            nftSymbol // symbol
                        )
                    )
                })
            )
        );

        // deploy gauges
        leafGaugeFactory = CLLeafGaugeFactory(
            cx.deployCreate3({
                salt: CL_LEAF_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(
                    type(CLLeafGaugeFactory).creationCode,
                    abi.encode(
                        address(leafVoter), // voter
                        address(nft), // nft (nfpm)
                        address(xVelo), // xerc20
                        address(leafMessageBridge) // bridge
                    )
                )
            })
        );

        lpMigrator = new LpMigrator();

        vm.stopPrank();

        // approve gauge in factory registry
        vm.prank(Ownable(address(factoryRegistry)).owner());
        factoryRegistry.approve({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory)
        });

        // transfer residual permissions
        vm.startPrank(users.owner);
        poolFactory.setOwner(users.owner);
        poolFactory.setSwapFeeManager(users.feeManager);
        poolFactory.setUnstakedFeeManager(users.feeManager);
        vm.stopPrank();

        customSwapFeeModule = new CustomSwapFeeModule(address(poolFactory));
        customUnstakedFeeModule = new CustomUnstakedFeeModule(address(poolFactory));
        vm.startPrank(users.feeManager);
        poolFactory.setSwapFeeModule(address(customSwapFeeModule));
        poolFactory.setUnstakedFeeModule(address(customUnstakedFeeModule));
        vm.stopPrank();

        ERC20 tokenA = new ERC20("", "");
        ERC20 tokenB = new ERC20("", "");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        clCallee = new TestCLCallee();
        nftCallee = new NFTManagerCallee(address(token0), address(token1), address(nft));

        deal({token: address(token0), to: users.alice, give: TOKEN_1 * 100});
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 100});
        deal({token: address(token0), to: users.charlie, give: TOKEN_1 * 100});
        deal({token: address(token1), to: users.charlie, give: TOKEN_1 * 100});

        // e2e specific setup
        e2eNftCallee = new NFTManagerCallee(address(weth), address(op), address(nft));

        deal({token: address(op), to: users.alice, give: TOKEN_1 * 100});
        deal({token: address(weth), to: users.alice, give: TOKEN_1 * 100});

        vm.startPrank(users.alice);
        op.approve(address(e2eNftCallee), type(uint256).max);
        weth.approve(address(e2eNftCallee), type(uint256).max);
        // e2e specific setup

        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        token0.approve(address(clCallee), type(uint256).max);
        token1.approve(address(clCallee), type(uint256).max);
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);
        vm.startPrank(users.charlie);
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        vm.stopPrank();

        labelContracts();
    }

    function setUpDependencyForks() public virtual {
        xVelo = IXERC20(vm.parseJsonAddress(addresses, ".XVelo"));
        rootMessageBridge = IRootMessageBridge(vm.parseJsonAddress(addresses, ".MessageBridge"));
        rootMessageModule = IRootHLMessageModule(vm.parseJsonAddress(addresses, ".MessageModule"));
        rootLockbox = IXERC20Lockbox(vm.parseJsonAddress(addresses, ".Lockbox"));
        rootMailbox = IMailbox(vm.parseJsonAddress(addresses, ".Mailbox"));

        factoryRegistry = IFactoryRegistry(vm.parseJsonAddress(addresses, ".FactoryRegistry"));
        weth = IERC20(vm.parseJsonAddress(addresses, ".WETH"));
        op = IERC20(vm.parseJsonAddress(addresses, ".OP"));
        rootVoter = IVoter(vm.parseJsonAddress(addresses, ".Voter"));
        rewardToken = ERC20(vm.parseJsonAddress(addresses, ".Velo"));
        escrow = IVotingEscrow(vm.parseJsonAddress(addresses, ".VotingEscrow"));
        minter = IMinter(vm.parseJsonAddress(addresses, ".Minter"));

        // set root message bridge limits
        setLimits(type(uint112).max, 0);
    }

    function deployRootDependencies() public virtual {
        // deploy root mocks
        rootVotingRewardsFactory =
            IRootVotingRewardsFactory(new MockRootVotingRewardsFactory(address(rootMessageBridge)));
    }

    function setUpRootChain() public virtual {
        vm.startPrank(users.deployer);
        rootPoolImplementation = new RootCLPool();
        rootPoolFactory = RootCLPoolFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: CL_POOL_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootCLPoolFactory).creationCode,
                    abi.encode(
                        users.owner,
                        address(rootPoolImplementation), // root pool implementation
                        address(rootMessageBridge) // message bridge
                    )
                )
            })
        );

        rootGaugeFactory = CLRootGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(CLRootGaugeFactory).creationCode,
                    abi.encode(
                        address(rootVoter), // root voter
                        address(xVelo), // xerc20
                        address(rootLockbox), // lockbox
                        address(rootMessageBridge), // message bridge
                        address(rootPoolFactory), // pool factory
                        address(rootVotingRewardsFactory), // voting rewards factory
                        users.owner // notify admin
                    )
                )
            })
        );
        vm.stopPrank();
    }

    /// @dev Deploys mocks of external dependencies
    ///      Override if using a fork test
    function deployDependencies() public virtual {
        votingRewardsFactory = IVotingRewardsFactory(new MockVotingRewardsFactory());
    }

    /// @dev Helper utility to forward time to next week
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 offset) public {
        uint256 ts = block.timestamp;
        uint256 nextEpoch = ts - (ts % (1 weeks)) + (1 weeks);
        vm.warp(nextEpoch + offset);
        vm.roll(block.number + 1);
    }

    /// @dev Helper function to add rewards to gauge from voter
    function addRewardToGauge(address _voter, address _gauge, uint256 _amount) internal {
        deal(address(xVelo), leafMessageModule, _amount);
        vm.startPrank(leafMessageModule);
        // do not overwrite approvals if already set
        if (xVelo.allowance(leafMessageModule, _gauge) < _amount) {
            xVelo.approve(_gauge, _amount);
        }
        CLLeafGauge(_gauge).notifyRewardAmount(_amount);
        vm.stopPrank();
    }

    /// @dev Use only with test addresses
    function createAndCheckPool(
        CLFactory factory,
        address token0,
        address token1,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) internal returns (address _pool) {
        address create2Addr =
            computeAddress({factory: address(factory), tokenA: token0, tokenB: token1, tickSpacing: tickSpacing});

        vm.expectEmit(true, true, true, true, address(factory));
        emit PoolCreated({token0: TEST_TOKEN_0, token1: TEST_TOKEN_1, tickSpacing: tickSpacing, pool: create2Addr});

        CLPool pool = CLPool(factory.createPool(token0, token1, tickSpacing, sqrtPriceX96));
        (uint160 _sqrtPriceX96,,,,,) = pool.slot0();

        assertGt(factory.allPoolsLength(), 0);
        assertEq(factory.allPools(factory.allPoolsLength() - 1), create2Addr);
        assertEq(factory.getPool(token0, token1, tickSpacing), create2Addr);
        assertEq(factory.getPool(token1, token0, tickSpacing), create2Addr);
        assertEq(factory.isPair(create2Addr), true);
        assertEq(pool.factory(), address(factory));
        assertEq(pool.token0(), TEST_TOKEN_0);
        assertEq(pool.token1(), TEST_TOKEN_1);
        assertEq(pool.tickSpacing(), tickSpacing);
        assertEq(ICLPool(pool).nft(), address(nft));

        //NOTE: vm.chainId(rootChainId) is not working to set the correct chainId for chainid()
        bytes32 salt = keccak256(abi.encodePacked(uint256(0), TEST_TOKEN_0, TEST_TOKEN_1, tickSpacing));
        bytes11 entropy = bytes11(salt);
        address expectedGauge = entropy.computeCreate3Address({_deployer: address(leafGaugeFactory)});

        assertEq(pool.gauge(), expectedGauge);
        assertEq(uint256(_sqrtPriceX96), uint256(sqrtPriceX96));

        return address(pool);
    }

    function labelContracts() internal virtual {
        vm.label({account: address(weth), newLabel: "WETH"});
        vm.label({account: address(leafVoter), newLabel: "Leaf Voter"});
        vm.label({account: address(nftDescriptor), newLabel: "NFT Descriptor"});
        vm.label({account: address(nft), newLabel: "NFT Manager"});
        vm.label({account: address(poolImplementation), newLabel: "Pool Implementation"});
        vm.label({account: address(poolFactory), newLabel: "Pool Factory"});
        vm.label({account: address(token0), newLabel: "Token 0"});
        vm.label({account: address(token1), newLabel: "Token 1"});
        vm.label({account: address(rewardToken), newLabel: "Reward Token"});
        vm.label({account: address(leafGaugeFactory), newLabel: "Leaf Gauge Factory"});
        vm.label({account: address(customSwapFeeModule), newLabel: "Custom Swap FeeModule"});
        vm.label({account: address(customUnstakedFeeModule), newLabel: "Custom Unstaked Fee Module"});
        vm.label({account: address(lpMigrator), newLabel: "Lp Migrator"});
        vm.label({account: address(cx), newLabel: "Create X"});
        vm.label({account: address(rootPoolFactory), newLabel: "Root Pool Factory"});
        vm.label({account: address(rootPoolImplementation), newLabel: "Root Pool Implementation"});
        vm.label({account: address(rootGaugeFactory), newLabel: "Root Gauge Factory"});
        vm.label({account: address(rootVotingRewardsFactory), newLabel: "Root Voting Rewards Factory"});

        vm.label({account: address(xVelo), newLabel: "Root xVelo"});
        vm.label({account: address(rootMessageBridge), newLabel: "Root Message Bridge"});
        vm.label({account: address(rootMessageModule), newLabel: "Root Message Module"});
        vm.label({account: address(rootLockbox), newLabel: "Root Lockbox"});

        vm.label({account: address(leafMessageBridge), newLabel: "Leaf Message Bridge"});
        vm.label({account: address(leafMessageModule), newLabel: "Leaf Message Module"});
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }

    function createUsers() internal {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie"),
            deployer: createUser("Deployer")
        });
    }

    /// @dev Helper function that adds root & leaf bridge limits
    function setLimits(uint256 _rootBufferCap, uint256 _leafBufferCap) internal {
        vm.stopPrank();
        // uint256 activeFork = vm.activeFork();
        //
        vm.startPrank(Ownable(address(rootMessageBridge)).owner());
        // vm.selectFork({forkId: rootId});

        uint112 rootBufferCap = uint112(_rootBufferCap);
        // replenish limits in 1 day, avoid max rate limit per second
        uint128 rps = uint128(Math.min((rootBufferCap / 2) / DAY, xVelo.maxRateLimitPerSecond()));
        // xVelo.addBridge(
        //     MintLimits.RateLimitMidPointInfo({
        //         bufferCap: rootBufferCap,
        //         bridge: address(rootTokenBridge),
        //         rateLimitPerSecond: rps
        //     })
        // );
        xVelo.addBridge(
            IXERC20.RateLimitMidPointInfo({
                bufferCap: rootBufferCap,
                bridge: address(rootMessageBridge),
                rateLimitPerSecond: rps
            })
        );

        // vm.selectFork({forkId: leafId});
        // uint112 leafBufferCap = _leafBufferCap.toUint112();
        // // replenish limits in 1 day, avoid max rate limit per second
        // rps = Math.min((leafBufferCap / 2) / DAY, leafXVelo.maxRateLimitPerSecond()).toUint128();
        // leafXVelo.addBridge(
        //     MintLimits.RateLimitMidPointInfo({
        //         bufferCap: leafBufferCap,
        //         bridge: address(leafTokenBridge),
        //         rateLimitPerSecond: rps
        //     })
        // );
        // leafXVelo.addBridge(
        //     MintLimits.RateLimitMidPointInfo({
        //         bufferCap: leafBufferCap,
        //         bridge: address(leafMessageBridge),
        //         rateLimitPerSecond: rps
        //     })
        // );
        //
        // vm.selectFork({forkId: activeFork});
        vm.stopPrank();
    }
}
