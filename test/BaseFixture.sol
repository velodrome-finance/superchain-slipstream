pragma solidity ^0.7.6;
pragma abicoder v2;

import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";
import {ICreateX} from "contracts/libraries/ICreateX.sol";

import "forge-std/Test.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {ICLPool, CLPool} from "contracts/core/CLPool.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {
    INonfungiblePositionManager, NonfungiblePositionManager
} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {MockWETH} from "contracts/test/MockWETH.sol";
import {IVoter, MockVoter} from "contracts/test/MockVoter.sol";
import {IVotingEscrow, MockVotingEscrow} from "contracts/test/MockVotingEscrow.sol";
import {IFactoryRegistry, MockFactoryRegistry} from "contracts/test/MockFactoryRegistry.sol";
import {IVotingRewardsFactory, MockVotingRewardsFactory} from "contracts/test/MockVotingRewardsFactory.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
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

abstract contract BaseFixture is Test, TestConstants, Events, PoolUtils {
    using CreateXLibrary for bytes11;

    CLFactory public poolFactory;
    CLPool public poolImplementation;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGaugeFactory public gaugeFactory;
    CLGauge public gaugeImplementation;
    LpMigrator public lpMigrator;

    /// @dev mocks
    IFactoryRegistry public factoryRegistry;
    IVoter public voter;
    IVotingEscrow public escrow;
    IMinter public minter;
    IERC20 public weth;
    IVotingRewardsFactory public votingRewardsFactory;

    ERC20 public rewardToken;

    ERC20 public token0;
    ERC20 public token1;

    Users internal users;

    TestCLCallee public clCallee;
    NFTManagerCallee public nftCallee;

    CustomSwapFeeModule public customSwapFeeModule;
    CustomUnstakedFeeModule public customUnstakedFeeModule;

    string public nftName = "Slipstream Position NFT v1";
    string public nftSymbol = "CL-POS";

    /// mocks
    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    uint256 public blockNumber = 113736816;

    function setUp() public virtual {
        //createX block is 113736815
        require(blockNumber >= 113736816, "BlockNumber too low");

        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: blockNumber});

        createUsers();

        rewardToken = new ERC20("", "");

        deployDependencies();

        address deployer = users.deployer;
        poolImplementation = CLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(type(CLPool).creationCode)
            })
        );

        poolFactory = CLFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(
                    type(CLFactory).creationCode,
                    abi.encode(
                        users.owner, // owner
                        users.owner, // swap fee manager
                        users.owner, // unstaked fee manager
                        address(voter), // voter
                        address(poolImplementation) // pool implementation
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
        gaugeImplementation = CLGauge(
            cx.deployCreate3({
                salt: CL_GAUGE_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(type(CLGauge).creationCode)
            })
        );
        gaugeFactory = CLGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: deployer}),
                initCode: abi.encodePacked(
                    type(CLGaugeFactory).creationCode,
                    abi.encode(
                        users.owner, // notifyAdmin
                        address(voter), // voter
                        address(nft), // nft (nfpm)
                        address(gaugeImplementation) // gauge implementation
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
            gaugeFactory: address(gaugeFactory)
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

        vm.startPrank(users.alice);
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

    /// @dev Deploys mocks of external dependencies
    ///      Override if using a fork test
    function deployDependencies() public virtual {
        factoryRegistry = IFactoryRegistry(new MockFactoryRegistry());
        votingRewardsFactory = IVotingRewardsFactory(new MockVotingRewardsFactory());
        weth = IERC20(address(new MockWETH()));
        escrow = IVotingEscrow(new MockVotingEscrow(users.owner));
        voter = IVoter(
            new MockVoter({
                _rewardToken: address(rewardToken),
                _factoryRegistry: address(factoryRegistry),
                _ve: address(escrow)
            })
        );
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
        deal(address(rewardToken), _voter, _amount);
        vm.startPrank(_voter);
        // do not overwrite approvals if already set
        if (rewardToken.allowance(_voter, _gauge) < _amount) {
            rewardToken.approve(_gauge, _amount);
        }
        CLGauge(_gauge).notifyRewardAmount(_amount);
        vm.stopPrank();
    }

    function labelContracts() internal virtual {
        vm.label({account: address(weth), newLabel: "WETH"});
        vm.label({account: address(voter), newLabel: "Voter"});
        vm.label({account: address(nftDescriptor), newLabel: "NFT Descriptor"});
        vm.label({account: address(nft), newLabel: "NFT Manager"});
        vm.label({account: address(poolImplementation), newLabel: "Pool Implementation"});
        vm.label({account: address(poolFactory), newLabel: "Pool Factory"});
        vm.label({account: address(token0), newLabel: "Token 0"});
        vm.label({account: address(token1), newLabel: "Token 1"});
        vm.label({account: address(rewardToken), newLabel: "Reward Token"});
        vm.label({account: address(gaugeFactory), newLabel: "Gauge Factory"});
        vm.label({account: address(customSwapFeeModule), newLabel: "Custom Swap FeeModule"});
        vm.label({account: address(customUnstakedFeeModule), newLabel: "Custom Unstaked Fee Module"});
        vm.label({account: address(lpMigrator), newLabel: "Lp Migrator"});
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
}
