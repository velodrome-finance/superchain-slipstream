pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {DeployLeafCL} from "script/deployParameters/mode/DeployLeafCL.s.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
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
        poolImplementation = deployCL.poolImplementation();
        poolFactory = deployCL.poolFactory();
        nftDescriptor = deployCL.nftDescriptor();
        nft = deployCL.nft();
        leafGaugeFactory = deployCL.gaugeFactory();
        customSwapFeeModule = deployCL.swapFeeModule();
        customUnstakedFeeModule = deployCL.unstakedFeeModule();
        mixedQuoter = deployCL.mixedQuoter();
        quoter = deployCL.quoter();
        swapRouter = deployCL.swapRouter();

        params = deployCL.params();

        assertNotEq(params.weth, address(0));
        assertNotEq(params.leafVoter, address(0));
        assertNotEq(params.factoryV2, address(0));
        assertNotEq(params.xVelo, address(0));
        assertNotEq(params.messageBridge, address(0));
        assertNotEq(params.poolFactoryOwner, address(0));
        assertNotEq(params.feeManager, address(0));
        assertNotEq(params.nftName, "");
        assertNotEq(params.nftSymbol, "");

        assertNotEq(address(poolImplementation), address(0));
        assertNotEq(address(poolFactory), address(0));
        assertEq(address(poolFactory.voter()), params.leafVoter);
        assertEq(address(poolFactory.poolImplementation()), address(poolImplementation));
        assertEq(address(poolFactory.gaugeFactory()), address(leafGaugeFactory));
        assertEq(address(poolFactory.nft()), address(nft));
        assertEq(address(poolFactory.owner()), params.poolFactoryOwner);
        assertEq(address(poolFactory.swapFeeManager()), params.feeManager);
        assertEq(address(poolFactory.swapFeeModule()), address(customSwapFeeModule));
        assertEq(address(poolFactory.unstakedFeeManager()), params.feeManager);
        assertEq(address(poolFactory.unstakedFeeModule()), address(customUnstakedFeeModule));
        assertEqUint(poolFactory.defaultUnstakedFee(), 100_000);
        assertEqUint(poolFactory.tickSpacingToFee(1), 100);
        assertEqUint(poolFactory.tickSpacingToFee(50), 500);
        assertEqUint(poolFactory.tickSpacingToFee(100), 500);
        assertEqUint(poolFactory.tickSpacingToFee(200), 3_000);
        assertEqUint(poolFactory.tickSpacingToFee(2_000), 10_000);

        assertNotEq(address(nftDescriptor), address(0));
        assertEq(nftDescriptor.WETH9(), params.weth);
        assertEq(nftDescriptor.nativeCurrencyLabelBytes(), bytes32("ETH"));

        assertNotEq(address(nft), address(0));
        assertEq(nft.owner(), params.team);
        assertEq(nft.tokenDescriptor(), address(nftDescriptor));
        assertEq(nft.factory(), address(poolFactory));
        assertEq(nft.WETH9(), params.weth);
        assertEq(nft.name(), params.nftName);
        assertEq(nft.symbol(), params.nftSymbol);

        assertNotEq(address(leafGaugeFactory), address(0));
        assertEq(leafGaugeFactory.voter(), params.leafVoter);
        assertEq(leafGaugeFactory.xerc20(), params.xVelo);
        assertEq(leafGaugeFactory.bridge(), params.messageBridge);
        assertEq(leafGaugeFactory.nft(), address(nft));

        assertNotEq(address(customSwapFeeModule), address(0));
        assertEq(customSwapFeeModule.MAX_FEE(), 30_000); // 3%, using pip denomination
        assertEq(address(customSwapFeeModule.factory()), address(poolFactory));

        assertNotEq(address(customUnstakedFeeModule), address(0));
        assertEq(customUnstakedFeeModule.MAX_FEE(), 500_000); // 50%, using pip denomination
        assertEq(address(customUnstakedFeeModule.factory()), address(poolFactory));

        assertNotEq(address(mixedQuoter), address(0));
        assertEq(mixedQuoter.factoryV2(), params.factoryV2);
        assertEq(mixedQuoter.factory(), address(poolFactory));
        assertEq(mixedQuoter.WETH9(), params.weth);

        assertNotEq(address(quoter), address(0));
        assertEq(quoter.factory(), address(poolFactory));
        assertEq(quoter.WETH9(), params.weth);

        assertNotEq(address(swapRouter), address(0));
        assertEq(swapRouter.factory(), address(poolFactory));
        assertEq(swapRouter.WETH9(), params.weth);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
