pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {DeployLeafCL} from "script/deployParameters/mode/DeployLeafCL.s.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {ModeFeeSharing} from "contracts/extensions/ModeFeeSharing.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {LeafCLGauge} from "contracts/gauge/LeafCLGauge.sol";
import {LeafCLGaugeFactory} from "contracts/gauge/LeafCLGaugeFactory.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {MixedRouteQuoterV1} from "contracts/periphery/lens/MixedRouteQuoterV1.sol";
import {QuoterV2} from "contracts/periphery/lens/QuoterV2.sol";
import {SwapRouter} from "contracts/periphery/SwapRouter.sol";
import "test/BaseForkFixture.sol";

contract DeployLeafCLForkTest is BaseForkFixture {
    using stdStorage for StdStorage;

    DeployLeafCL public deployCL;

    DeployLeafCL.DeploymentParameters public params;
    DeployLeafCL.ModeDeploymentParameters public modeParams;

    // deployed contracts (not in BaseForkFixture)
    MixedRouteQuoterV1 public mixedQuoter;
    QuoterV2 public quoter;
    SwapRouter public swapRouter;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "mode", blockNumber: leafBlockNumber});

        deployCL = new DeployLeafCL();
        deployCL.setUp();

        createUsers();

        stdstore.target(address(deployCL)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deployCL)).sig("isTest()").checked_write(true);
    }

    function test_deployCL() public {
        deployCL.run();

        // preload variables for convenience
        leafPoolImplementation = deployCL.leafPoolImplementation();
        leafPoolFactory = deployCL.leafPoolFactory();
        nft = deployCL.nft();
        nftDescriptor = deployCL.nftDescriptor();
        leafGaugeFactory = deployCL.leafGaugeFactory();
        customSwapFeeModule = deployCL.swapFeeModule();
        customUnstakedFeeModule = deployCL.unstakedFeeModule();
        mixedQuoter = deployCL.mixedQuoter();
        quoter = deployCL.quoter();
        swapRouter = deployCL.swapRouter();

        params = deployCL.params();
        modeParams = deployCL.modeParams();

        assertNotEq(params.weth, address(0));
        assertNotEq(params.leafVoter, address(0));
        assertNotEq(params.factoryV2, address(0));
        assertNotEq(params.xVelo, address(0));
        assertNotEq(params.messageBridge, address(0));
        assertNotEq(params.poolFactoryOwner, address(0));
        assertNotEq(params.feeManager, address(0));
        assertNotEq(params.nftName, "");
        assertNotEq(params.nftSymbol, "");

        assertNotEq(address(leafPoolImplementation), address(0));
        assertNotEq(address(leafPoolFactory), address(0));
        assertEq(address(leafPoolFactory.voter()), params.leafVoter);
        assertEq(address(leafPoolFactory.poolImplementation()), address(leafPoolImplementation));
        assertEq(address(leafPoolFactory.gaugeFactory()), address(leafGaugeFactory));
        assertEq(address(leafPoolFactory.nft()), address(nft));
        assertEq(address(leafPoolFactory.owner()), params.poolFactoryOwner);
        assertEq(address(leafPoolFactory.swapFeeManager()), params.feeManager);
        assertEq(address(leafPoolFactory.swapFeeModule()), address(customSwapFeeModule));
        assertEq(address(leafPoolFactory.unstakedFeeManager()), params.feeManager);
        assertEq(address(leafPoolFactory.unstakedFeeModule()), address(customUnstakedFeeModule));
        assertEqUint(leafPoolFactory.defaultUnstakedFee(), 100_000);
        assertEqUint(leafPoolFactory.tickSpacingToFee(1), 100);
        assertEqUint(leafPoolFactory.tickSpacingToFee(50), 500);
        assertEqUint(leafPoolFactory.tickSpacingToFee(100), 500);
        assertEqUint(leafPoolFactory.tickSpacingToFee(200), 3_000);
        assertEqUint(leafPoolFactory.tickSpacingToFee(2_000), 10_000);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).tokenId(), 565);

        assertNotEq(address(nftDescriptor), address(0));
        assertEq(nftDescriptor.WETH9(), params.weth);
        assertEq(nftDescriptor.nativeCurrencyLabelBytes(), bytes32("ETH"));

        assertNotEq(address(nft), address(0));
        assertEq(nft.owner(), params.team);
        assertEq(nft.tokenDescriptor(), address(nftDescriptor));
        assertEq(nft.factory(), address(leafPoolFactory));
        assertEq(nft.WETH9(), params.weth);
        assertEq(nft.name(), params.nftName);
        assertEq(nft.symbol(), params.nftSymbol);
        assertEq(ModeFeeSharing(address(nft)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(nft)).tokenId(), 566);

        assertNotEq(address(leafGaugeFactory), address(0));
        assertEq(leafGaugeFactory.voter(), params.leafVoter);
        assertEq(leafGaugeFactory.xerc20(), params.xVelo);
        assertEq(leafGaugeFactory.bridge(), params.messageBridge);
        assertEq(leafGaugeFactory.nft(), address(nft));

        assertNotEq(address(customSwapFeeModule), address(0));
        assertEq(customSwapFeeModule.MAX_FEE(), 30_000); // 3%, using pip denomination
        assertEq(address(customSwapFeeModule.factory()), address(leafPoolFactory));

        assertNotEq(address(customUnstakedFeeModule), address(0));
        assertEq(customUnstakedFeeModule.MAX_FEE(), 500_000); // 50%, using pip denomination
        assertEq(address(customUnstakedFeeModule.factory()), address(leafPoolFactory));

        assertNotEq(address(mixedQuoter), address(0));
        assertEq(mixedQuoter.factoryV2(), params.factoryV2);
        assertEq(mixedQuoter.factory(), address(leafPoolFactory));
        assertEq(mixedQuoter.WETH9(), params.weth);

        assertNotEq(address(quoter), address(0));
        assertEq(quoter.factory(), address(leafPoolFactory));
        assertEq(quoter.WETH9(), params.weth);

        assertNotEq(address(swapRouter), address(0));
        assertEq(swapRouter.factory(), address(leafPoolFactory));
        assertEq(swapRouter.WETH9(), params.weth);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
