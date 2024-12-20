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
import {SlipstreamSugar} from "contracts/sugar/SlipstreamSugar.sol";
import {QuoterV2} from "contracts/periphery/lens/QuoterV2.sol";
import {SwapRouter} from "contracts/periphery/SwapRouter.sol";
import "test/BaseForkFixture.sol";

contract DeployLeafCLForkTest is BaseForkFixture {
    using stdStorage for StdStorage;

    // deployed contracts (not in BaseForkFixture)
    SlipstreamSugar public slipstreamSugar;
    MixedRouteQuoterV1 public mixedQuoter;
    QuoterV2 public quoter;
    SwapRouter public swapRouter;

    DeployLeafCL public deployLeafCLMode;
    DeployLeafCL.ModeDeploymentParameters public modeParams;

    address public constant sfs = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "mode", blockNumber: leafBlockNumber});

        deployLeafCLMode = new DeployLeafCL();
        deployLeafCLMode.setUp();

        createUsers();

        stdstore.target(address(deployLeafCLMode)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deployLeafCLMode)).sig("isTest()").checked_write(true);
    }

    function test_deployCL() public {
        deployLeafCLMode.run();

        // preload variables for convenience
        leafPoolImplementation = deployLeafCLMode.leafPoolImplementation();
        leafPoolFactory = deployLeafCLMode.leafPoolFactory();
        nft = deployLeafCLMode.nft();
        nftDescriptor = deployLeafCLMode.nftDescriptor();
        leafGaugeFactory = deployLeafCLMode.leafGaugeFactory();
        customSwapFeeModule = deployLeafCLMode.swapFeeModule();
        customUnstakedFeeModule = deployLeafCLMode.unstakedFeeModule();
        slipstreamSugar = deployLeafCLMode.slipstreamSugar();
        mixedQuoter = deployLeafCLMode.mixedQuoter();
        quoter = deployLeafCLMode.quoter();
        swapRouter = deployLeafCLMode.swapRouter();

        leafParams = deployLeafCLMode.params();
        modeParams = deployLeafCLMode.modeParams();

        assertNotEq(leafParams.weth, address(0));
        assertNotEq(leafParams.leafVoter, address(0));
        assertNotEq(leafParams.factoryV2, address(0));
        assertNotEq(leafParams.xVelo, address(0));
        assertNotEq(leafParams.messageBridge, address(0));
        assertNotEq(leafParams.poolFactoryOwner, address(0));
        assertNotEq(leafParams.feeManager, address(0));
        assertNotEq(leafParams.nftName, "");
        assertNotEq(leafParams.nftSymbol, "");

        assertNotEq(address(leafPoolImplementation), address(0));
        assertNotEq(address(leafPoolFactory), address(0));
        assertEq(address(leafPoolFactory.voter()), leafParams.leafVoter);
        assertEq(address(leafPoolFactory.poolImplementation()), address(leafPoolImplementation));
        assertEq(address(leafPoolFactory.gaugeFactory()), address(leafGaugeFactory));
        assertEq(address(leafPoolFactory.nft()), address(nft));
        assertEq(address(leafPoolFactory.owner()), leafParams.poolFactoryOwner);
        assertEq(address(leafPoolFactory.swapFeeManager()), leafParams.feeManager);
        assertEq(address(leafPoolFactory.swapFeeModule()), address(customSwapFeeModule));
        assertEq(address(leafPoolFactory.unstakedFeeManager()), leafParams.feeManager);
        assertEq(address(leafPoolFactory.unstakedFeeModule()), address(customUnstakedFeeModule));
        assertEqUint(leafPoolFactory.defaultUnstakedFee(), 100_000);
        assertEqUint(leafPoolFactory.tickSpacingToFee(1), 100);
        assertEqUint(leafPoolFactory.tickSpacingToFee(50), 500);
        assertEqUint(leafPoolFactory.tickSpacingToFee(100), 500);
        assertEqUint(leafPoolFactory.tickSpacingToFee(200), 3_000);
        assertEqUint(leafPoolFactory.tickSpacingToFee(2_000), 10_000);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).tokenId(), 587);

        assertNotEq(address(nftDescriptor), address(0));
        assertEq(nftDescriptor.WETH9(), leafParams.weth);
        assertEq(nftDescriptor.nativeCurrencyLabelBytes(), bytes32("ETH"));

        assertNotEq(address(nft), address(0));
        assertEq(nft.owner(), leafParams.team);
        assertEq(nft.tokenDescriptor(), address(nftDescriptor));
        assertEq(nft.factory(), address(leafPoolFactory));
        assertEq(nft.WETH9(), leafParams.weth);
        assertEq(nft.name(), leafParams.nftName);
        assertEq(nft.symbol(), leafParams.nftSymbol);
        assertEq(ModeFeeSharing(address(nft)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(nft)).tokenId(), 588);

        assertNotEq(address(leafGaugeFactory), address(0));
        assertEq(leafGaugeFactory.voter(), leafParams.leafVoter);
        assertEq(leafGaugeFactory.xerc20(), leafParams.xVelo);
        assertEq(leafGaugeFactory.bridge(), leafParams.messageBridge);
        assertEq(leafGaugeFactory.nft(), address(nft));

        assertNotEq(address(customSwapFeeModule), address(0));
        assertEq(customSwapFeeModule.MAX_FEE(), 30_000); // 3%, using pip denomination
        assertEq(address(customSwapFeeModule.factory()), address(leafPoolFactory));

        assertNotEq(address(customUnstakedFeeModule), address(0));
        assertEq(customUnstakedFeeModule.MAX_FEE(), 500_000); // 50%, using pip denomination
        assertEq(address(customUnstakedFeeModule.factory()), address(leafPoolFactory));

        assertNotEq(address(slipstreamSugar), address(0));

        assertNotEq(address(mixedQuoter), address(0));
        assertEq(mixedQuoter.factoryV2(), leafParams.factoryV2);
        assertEq(mixedQuoter.factory(), address(leafPoolFactory));
        assertEq(mixedQuoter.WETH9(), leafParams.weth);

        assertNotEq(address(quoter), address(0));
        assertEq(quoter.factory(), address(leafPoolFactory));
        assertEq(quoter.WETH9(), leafParams.weth);

        assertNotEq(address(swapRouter), address(0));
        assertEq(swapRouter.factory(), address(leafPoolFactory));
        assertEq(swapRouter.WETH9(), leafParams.weth);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
