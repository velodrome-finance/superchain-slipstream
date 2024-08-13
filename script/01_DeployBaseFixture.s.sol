// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "./DeployFixture.sol";

import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {MixedRouteQuoterV1} from "contracts/periphery/lens/MixedRouteQuoterV1.sol";
import {QuoterV2} from "contracts/periphery/lens/QuoterV2.sol";
import {SwapRouter} from "contracts/periphery/SwapRouter.sol";
import {Constants} from "script/constants/Constants.sol";

abstract contract DeployBaseFixture is DeployFixture, Constants {
    using stdJson for string;
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address team;
        address weth;
        address voter;
        address poolFactoryOwner;
        address feeManager;
        address notifyAdmin;
        address factoryV2;
        string nftName;
        string nftSymbol;
        string outputFilename;
    }

    // deployed
    CLPool public poolImplementation;
    CLFactory public poolFactory;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGauge public gaugeImplementation;
    CLGaugeFactory public gaugeFactory;
    CustomSwapFeeModule public swapFeeModule;
    CustomUnstakedFeeModule public unstakedFeeModule;
    MixedRouteQuoterV1 public mixedQuoter;
    QuoterV2 public quoter;
    SwapRouter public swapRouter;

    DeploymentParameters internal _params;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        poolImplementation = CLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(CLPool).creationCode)
            })
        );
        checkAddress({_entropy: CL_POOL_ENTROPY, _output: address(poolImplementation)});

        poolFactory = CLFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(CLFactory).creationCode,
                    abi.encode(
                        _deployer, // owner
                        _deployer, // swapFeeManager
                        _deployer, // unstakedFeeManager
                        _params.voter, // voter
                        address(poolImplementation) // pool implementation
                    )
                )
            })
        );
        checkAddress({_entropy: CL_POOL_FACTORY_ENTROPY, _output: address(poolFactory)});

        // deploy nft contracts
        nftDescriptor =
            new NonfungibleTokenPositionDescriptor({_WETH9: _params.weth, _nativeCurrencyLabelBytes: bytes32("ETH")});

        nft = NonfungiblePositionManager(
            payable(
                cx.deployCreate3({
                    salt: NFT_POSITION_MANAGER.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(NonfungiblePositionManager).creationCode,
                        abi.encode(
                            _params.team, // owner
                            address(poolFactory), // pool factory
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

        // deploy gauges
        gaugeImplementation = CLGauge(
            cx.deployCreate3({
                salt: CL_GAUGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(CLGauge).creationCode)
            })
        );
        checkAddress({_entropy: CL_GAUGE_ENTROPY, _output: address(gaugeImplementation)});
        gaugeFactory = CLGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(CLGaugeFactory).creationCode,
                    abi.encode(
                        _params.notifyAdmin, // notifyAdmin
                        _params.voter, // voter
                        address(nft), // nft (nfpm)
                        address(gaugeImplementation) // gauge implementation
                    )
                )
            })
        );
        checkAddress({_entropy: CL_GAUGE_FACTORY_ENTROPY, _output: address(gaugeFactory)});

        // deploy fee modules
        swapFeeModule = new CustomSwapFeeModule({_factory: address(poolFactory)});
        unstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(poolFactory)});
        poolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissions
        poolFactory.setOwner(_params.poolFactoryOwner);
        poolFactory.setSwapFeeManager(_params.feeManager);
        poolFactory.setUnstakedFeeManager(_params.feeManager);

        //deploy quoter and router
        mixedQuoter = MixedRouteQuoterV1(
            cx.deployCreate3({
                salt: MIXED_QUOTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(MixedRouteQuoterV1).creationCode,
                    abi.encode(
                        address(poolFactory), // pool factory
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
                        address(poolFactory), // pool factory
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
                            address(poolFactory), // pool factory
                            _params.weth // WETH9
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: SWAP_ROUTER_ENTROPY, _output: address(swapRouter)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console2.log("poolImplementation: ", address(poolImplementation));
        console2.log("poolFactory: ", address(poolFactory));
        console2.log("nftDescriptor: ", address(nftDescriptor));
        console2.log("nft: ", address(nft));
        console2.log("gaugeImplementation: ", address(gaugeImplementation));
        console2.log("gaugeFactory: ", address(gaugeFactory));
        console2.log("swapFeeModule: ", address(swapFeeModule));
        console2.log("unstakedFeeModule: ", address(unstakedFeeModule));
        console2.log("mixedQuoter: ", address(mixedQuoter));
        console2.log("quoter: ", address(quoter));
        console2.log("swapRouter: ", address(swapRouter));
    }

    function logOutput() internal override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(
            path,
            string(
                abi.encodePacked(
                    stdJson.serialize("", "poolImplementation", address(poolImplementation)),
                    stdJson.serialize("", "poolFactory", address(poolFactory)),
                    stdJson.serialize("", "nftDescriptor", address(nftDescriptor)),
                    stdJson.serialize("", "nft", address(nft)),
                    stdJson.serialize("", "gaugeImplementation", address(gaugeImplementation)),
                    stdJson.serialize("", "gaugeFactory", address(gaugeFactory)),
                    stdJson.serialize("", "swapFeeModule", address(swapFeeModule)),
                    stdJson.serialize("", "unstakedFeeModule", address(unstakedFeeModule)),
                    stdJson.serialize("", "mixedQuoter", address(mixedQuoter)),
                    stdJson.serialize("", "quoter", address(quoter)),
                    stdJson.serialize("", "swapRouter", address(swapRouter))
                )
            )
        );
    }
}
