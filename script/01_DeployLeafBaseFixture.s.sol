// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "./DeployFixture.sol";

import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {LeafCLGauge} from "contracts/gauge/LeafCLGauge.sol";
import {LeafCLGaugeFactory} from "contracts/gauge/LeafCLGaugeFactory.sol";
import {DynamicSwapFeeModule} from "contracts/core/fees/DynamicSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {MixedRouteQuoterV1} from "contracts/periphery/lens/MixedRouteQuoterV1.sol";
import {MixedRouteQuoterV2} from "contracts/periphery/lens/MixedRouteQuoterV2.sol";
import {MixedRouteQuoterV3} from "contracts/periphery/lens/MixedRouteQuoterV3.sol";
import {SlipstreamSugar} from "contracts/sugar/SlipstreamSugar.sol";
import {QuoterV2} from "contracts/periphery/lens/QuoterV2.sol";
import {SwapRouter} from "contracts/periphery/SwapRouter.sol";
import {LpMigrator} from "contracts/periphery/LpMigrator.sol";
import {Constants} from "script/constants/Constants.sol";

abstract contract DeployLeafBaseFixture is DeployFixture, Constants {
    using stdJson for string;
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address weth;
        address leafVoter;
        address factoryV2;
        address xVelo;
        address messageBridge;
        address legacyCLFactory;
        address team;
        address poolFactoryOwner;
        address feeManager;
        string nftName;
        string nftSymbol;
        string outputFilename;
    }

    // leaf slipstream contracts
    CLPool public leafPoolImplementation;
    CLFactory public leafPoolFactory;
    CLPool public leafPool;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    LeafCLGaugeFactory public leafGaugeFactory;

    DynamicSwapFeeModule public swapFeeModule;
    CustomUnstakedFeeModule public unstakedFeeModule;
    SlipstreamSugar public slipstreamSugar;
    MixedRouteQuoterV1 public mixedQuoter;
    MixedRouteQuoterV2 public mixedQuoterV2;
    MixedRouteQuoterV3 public mixedQuoterV3;
    QuoterV2 public quoter;
    SwapRouter public swapRouter;
    LpMigrator public lpMigrator;

    DeploymentParameters internal _params;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        leafPoolImplementation = CLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(CLPool).creationCode)
            })
        );
        checkAddress({_entropy: CL_POOL_ENTROPY, _output: address(leafPoolImplementation)});

        leafGaugeFactory = LeafCLGaugeFactory(CL_GAUGE_FACTORY_ENTROPY.computeCreate3Address({_deployer: _deployer}));
        nft = NonfungiblePositionManager(payable(NFT_POSITION_MANAGER.computeCreate3Address({_deployer: deployer})));

        leafPoolFactory = CLFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(CLFactory).creationCode,
                    abi.encode(
                        _params.poolFactoryOwner, // owner
                        _deployer, // swapFeeManager
                        _deployer, // unstakedFeeManager
                        _params.leafVoter, // voter
                        address(leafPoolImplementation), // pool implementation
                        address(leafGaugeFactory), // gauge factory
                        address(nft) // nft
                    )
                )
            })
        );
        checkAddress({_entropy: CL_POOL_FACTORY_ENTROPY, _output: address(leafPoolFactory)});

        // deploy nft contracts
        nftDescriptor = NonfungibleTokenPositionDescriptor(
            cx.deployCreate3({
                salt: NFT_POSITION_DESCRIPTOR.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(NonfungibleTokenPositionDescriptor).creationCode,
                    abi.encode(
                        _params.weth, // WETH9
                        0x4554480000000000000000000000000000000000000000000000000000000000 // nativeCurrencyLabelBytes
                    )
                )
            })
        );
        checkAddress({_entropy: NFT_POSITION_DESCRIPTOR, _output: address(nftDescriptor)});

        nft = NonfungiblePositionManager(
            payable(
                cx.deployCreate3({
                    salt: NFT_POSITION_MANAGER.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(NonfungiblePositionManager).creationCode,
                        abi.encode(
                            _params.team, // owner
                            address(leafPoolFactory), // pool factory
                            _params.weth, // WETH9
                            address(nftDescriptor), // token descriptor
                            _params.nftName, // name
                            _params.nftSymbol // symbol
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: NFT_POSITION_MANAGER, _output: address(nft)});

        leafGaugeFactory = LeafCLGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafCLGaugeFactory).creationCode,
                    abi.encode(
                        _params.leafVoter, // voter
                        address(nft), // nft (nfpm)
                        _params.xVelo, // xerc20
                        _params.messageBridge, // bridge
                        _deployer // gauge stake manager (deployer initially, transferred below)
                    )
                )
            })
        );
        checkAddress({_entropy: CL_GAUGE_FACTORY_ENTROPY, _output: address(leafGaugeFactory)});

        // configure gauge stake settings (matching Aerodrome/Base)
        leafGaugeFactory.setDefaultMinStakeTime(10);
        leafGaugeFactory.setPenaltyRate(10_000);
        leafGaugeFactory.setGaugeStakeManager(_params.team);

        // deploy fee modules
        swapFeeModule = new DynamicSwapFeeModule({
            _factory: address(leafPoolFactory),
            _defaultScalingFactor: 0,
            _defaultFeeCap: 30_000,
            _pools: new address[](0),
            _fees: new uint24[](0)
        });
        unstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(leafPoolFactory)});
        leafPoolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        leafPoolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissions
        leafPoolFactory.setSwapFeeManager(_params.feeManager);
        leafPoolFactory.setUnstakedFeeManager(_params.feeManager);

        // deploy slipstream sugar
        slipstreamSugar = new SlipstreamSugar();

        //deploy quoter and router
        mixedQuoter = MixedRouteQuoterV1(
            cx.deployCreate3({
                salt: MIXED_QUOTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(MixedRouteQuoterV1).creationCode,
                    abi.encode(
                        address(leafPoolFactory), // pool factory
                        _params.factoryV2, // factory v2
                        _params.weth // WETH9
                    )
                )
            })
        );
        checkAddress({_entropy: MIXED_QUOTER_ENTROPY, _output: address(mixedQuoter)});
        quoter = QuoterV2(
            cx.deployCreate3({
                salt: QUOTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(QuoterV2).creationCode,
                    abi.encode(
                        address(leafPoolFactory), // pool factory
                        _params.weth // WETH9
                    )
                )
            })
        );
        checkAddress({_entropy: QUOTER_ENTROPY, _output: address(quoter)});
        swapRouter = SwapRouter(
            payable(
                cx.deployCreate3({
                    salt: SWAP_ROUTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(SwapRouter).creationCode,
                        abi.encode(
                            address(leafPoolFactory), // pool factory
                            _params.weth // WETH9
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: SWAP_ROUTER_ENTROPY, _output: address(swapRouter)});

        mixedQuoterV2 = MixedRouteQuoterV2(
            cx.deployCreate3({
                salt: MIXED_QUOTER_V2_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(MixedRouteQuoterV2).creationCode,
                    abi.encode(
                        address(leafPoolFactory), // pool factory
                        _params.factoryV2, // factory v2
                        _params.weth // WETH9
                    )
                )
            })
        );
        checkAddress({_entropy: MIXED_QUOTER_V2_ENTROPY, _output: address(mixedQuoterV2)});

        mixedQuoterV3 = MixedRouteQuoterV3(
            cx.deployCreate3({
                salt: MIXED_QUOTER_V3_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(MixedRouteQuoterV3).creationCode,
                    abi.encode(
                        address(leafPoolFactory), // pool factory
                        _params.legacyCLFactory, // legacy CL factory
                        address(0), // legacy CL factory 2 (unused)
                        _params.factoryV2, // factory v2
                        _params.weth // WETH9
                    )
                )
            })
        );
        checkAddress({_entropy: MIXED_QUOTER_V3_ENTROPY, _output: address(mixedQuoterV3)});

        lpMigrator = LpMigrator(
            cx.deployCreate3({
                salt: LP_MIGRATOR_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(LpMigrator).creationCode)
            })
        );
        checkAddress({_entropy: LP_MIGRATOR_ENTROPY, _output: address(lpMigrator)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        if (isTest) return;
        console2.log("leafPoolImplementation: ", address(leafPoolImplementation));
        console2.log("leafPoolFactory: ", address(leafPoolFactory));
        console2.log("nftDescriptor: ", address(nftDescriptor));
        console2.log("nft: ", address(nft));
        console2.log("leafGaugeFactory: ", address(leafGaugeFactory));
        console2.log("swapFeeModule: ", address(swapFeeModule));
        console2.log("unstakedFeeModule: ", address(unstakedFeeModule));
        console2.log("slipstreamSugar: ", address(slipstreamSugar));
        console2.log("mixedQuoter: ", address(mixedQuoter));
        console2.log("mixedQuoterV2: ", address(mixedQuoterV2));
        console2.log("mixedQuoterV3: ", address(mixedQuoterV3));
        console2.log("quoter: ", address(quoter));
        console2.log("swapRouter: ", address(swapRouter));
        console2.log("lpMigrator: ", address(lpMigrator));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress("", "leafPoolImplementation: ", address(leafPoolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "leafPoolFactory: ", address(leafPoolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "nftDescriptor: ", address(nftDescriptor)), path);
        vm.writeJson(vm.serializeAddress("", "nft: ", address(nft)), path);
        vm.writeJson(vm.serializeAddress("", "leafGaugeFactory: ", address(leafGaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "swapFeeModule: ", address(swapFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "unstakedFeeModule: ", address(unstakedFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "slipstreamSugar", address(slipstreamSugar)), path);
        vm.writeJson(vm.serializeAddress("", "mixedQuoter: ", address(mixedQuoter)), path);
        vm.writeJson(vm.serializeAddress("", "mixedQuoterV2: ", address(mixedQuoterV2)), path);
        vm.writeJson(vm.serializeAddress("", "mixedQuoterV3: ", address(mixedQuoterV3)), path);
        vm.writeJson(vm.serializeAddress("", "quoter: ", address(quoter)), path);
        vm.writeJson(vm.serializeAddress("", "swapRouter: ", address(swapRouter)), path);
        vm.writeJson(vm.serializeAddress("", "lpMigrator: ", address(lpMigrator)), path);
    }
}
