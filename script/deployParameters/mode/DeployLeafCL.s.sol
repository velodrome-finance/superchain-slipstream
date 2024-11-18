// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "script/01_DeployLeafBaseFixture.s.sol";
import {ModeCLPool} from "contracts/core/extensions/ModeCLPool.sol";
import {ModeCLFactory} from "contracts/core/extensions/ModeCLFactory.sol";
import {ModeSwapRouter} from "contracts/periphery/extensions/ModeSwapRouter.sol";
import {ModeLeafCLGaugeFactory} from "contracts/gauge/extensions/ModeLeafCLGaugeFactory.sol";
import {ModeNonfungiblePositionManager} from "contracts/periphery/extensions/ModeNonfungiblePositionManager.sol";

contract DeployLeafCL is DeployLeafBaseFixture {
    using CreateXLibrary for bytes11;

    struct ModeDeploymentParameters {
        address recipient;
    }

    ModeDeploymentParameters internal _modeParams;

    function setUp() public override {
        _params = DeployLeafBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            leafVoter: 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123,
            factoryV2: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            xVelo: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81,
            messageBridge: 0xF278761576f45472bdD721EACA19317cE159c011,
            team: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            poolFactoryOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            feeManager: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            nftName: "Slipstream Position NFT v1.2",
            nftSymbol: "VELO-CL-POS",
            outputFilename: "mode.json"
        });

        _modeParams = ModeDeploymentParameters({recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3});
    }

    function deploy() internal virtual override {
        address _deployer = deployer;

        leafPoolImplementation = ModeCLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(ModeCLPool).creationCode)
            })
        );
        checkAddress({_entropy: CL_POOL_ENTROPY, _output: address(leafPoolImplementation)});

        leafGaugeFactory =
            ModeLeafCLGaugeFactory(CL_GAUGE_FACTORY_ENTROPY.computeCreate3Address({_deployer: _deployer}));
        nft = ModeNonfungiblePositionManager(payable(NFT_POSITION_MANAGER.computeCreate3Address({_deployer: deployer})));

        leafPoolFactory = ModeCLFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeCLFactory).creationCode,
                    abi.encode(
                        _params.poolFactoryOwner, // owner
                        _deployer, // swapFeeManager
                        _deployer, // unstakedFeeManager
                        _params.leafVoter, // voter
                        address(leafPoolImplementation), // pool implementation
                        address(leafGaugeFactory), // gauge factory
                        address(nft), // nft
                        _modeParams.recipient // sfs nft recipient
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

        nft = ModeNonfungiblePositionManager(
            payable(
                cx.deployCreate3({
                    salt: NFT_POSITION_MANAGER.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(ModeNonfungiblePositionManager).creationCode,
                        abi.encode(
                            _params.team, // owner
                            address(leafPoolFactory), // pool factory
                            _params.weth, // WETH9
                            address(nftDescriptor), // token descriptor
                            _params.nftName, // name
                            _params.nftSymbol, // symbol
                            _modeParams.recipient // sfs nft recipient
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: NFT_POSITION_MANAGER, _output: address(nft)});

        leafGaugeFactory = ModeLeafCLGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeLeafCLGaugeFactory).creationCode,
                    abi.encode(
                        _params.leafVoter, // voter
                        address(nft), // nft (nfpm)
                        _params.xVelo, // xerc20
                        _params.messageBridge // bridge
                    )
                )
            })
        );
        checkAddress({_entropy: CL_GAUGE_FACTORY_ENTROPY, _output: address(leafGaugeFactory)});

        // deploy fee modules
        swapFeeModule = new CustomSwapFeeModule({_factory: address(leafPoolFactory)});
        unstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(leafPoolFactory)});
        leafPoolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        leafPoolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissions
        leafPoolFactory.setSwapFeeManager(_params.feeManager);
        leafPoolFactory.setUnstakedFeeManager(_params.feeManager);

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
        swapRouter = ModeSwapRouter(
            payable(
                cx.deployCreate3({
                    salt: SWAP_ROUTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(ModeSwapRouter).creationCode,
                        abi.encode(
                            address(leafPoolFactory), // pool factory
                            _params.weth // WETH9
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: SWAP_ROUTER_ENTROPY, _output: address(swapRouter)});
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
