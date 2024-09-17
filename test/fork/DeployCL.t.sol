// pragma solidity ^0.7.6;
// pragma abicoder v2;

// import "forge-std/Test.sol";
// import "forge-std/StdJson.sol";

// import {DeployCL} from "script/deployParameters/optimism/DeployCL.s.sol";
// import {CLPool} from "contracts/core/CLPool.sol";
// import {CLFactory} from "contracts/core/CLFactory.sol";
// import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
// import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
// import {CLLeafGauge} from "contracts/gauge/CLLeafGauge.sol";
// import {CLLeafGaugeFactory} from "contracts/gauge/CLLeafGaugeFactory.sol";
// import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
// import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
// import "test/fork/BaseForkFixture.sol";

// contract DeployCLForkTest is BaseForkFixture {
//     using stdJson for string;

//     DeployCL public deployCL;

//     string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
//     string public jsonConstants;

//     // loaded variables
//     address public team;
//     address public poolFactoryOwner;
//     address public feeManager;
//     address public notifyAdmin;

//     // deployed contracts
//     CustomSwapFeeModule public swapFeeModule;
//     CustomUnstakedFeeModule public unstakedFeeModule;

//     function setUp() public override {
//         BaseForkFixture.setUp();

//         deployCL = new DeployCL();
//         deployCL.setUp();

//         string memory root = vm.projectRoot();
//         string memory path = concat(root, "/script/constants/");
//         path = concat(path, constantsFilename);
//         jsonConstants = vm.readFile(path);

//         team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
//         weth = IERC20(abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address)));
//         voter = IVoter(abi.decode(vm.parseJson(jsonConstants, ".Voter"), (address)));
//         factoryRegistry = IFactoryRegistry(abi.decode(vm.parseJson(jsonConstants, ".FactoryRegistry"), (address)));
//         poolFactoryOwner = abi.decode(vm.parseJson(jsonConstants, ".poolFactoryOwner"), (address));
//         feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));
//         notifyAdmin = abi.decode(vm.parseJson(jsonConstants, ".notifyAdmin"), (address));
//         nftName = abi.decode(vm.parseJson(jsonConstants, ".nftName"), (string));
//         nftSymbol = abi.decode(vm.parseJson(jsonConstants, ".nftSymbol"), (string));
//     }

//     function test_deployCL() public {
//         deployCL.run();

//         // preload variables for convenience
//         poolImplementation = deployCL.poolImplementation();
//         poolFactory = deployCL.poolFactory();
//         nftDescriptor = deployCL.nftDescriptor();
//         nft = deployCL.nft();
//         // gaugeImplementation = deployCL.gaugeImplementation();
//         gaugeFactory = deployCL.gaugeFactory();
//         swapFeeModule = deployCL.swapFeeModule();
//         unstakedFeeModule = deployCL.unstakedFeeModule();

//         assertTrue(address(poolImplementation) != address(0));
//         assertTrue(address(poolFactory) != address(0));
//         assertEq(address(poolFactory.voter()), address(voter));
//         assertEq(address(poolFactory.poolImplementation()), address(poolImplementation));
//         assertEq(address(poolFactory.factoryRegistry()), address(factoryRegistry));
//         assertEq(address(poolFactory.owner()), poolFactoryOwner);
//         assertEq(address(poolFactory.swapFeeModule()), address(swapFeeModule));
//         assertEq(address(poolFactory.swapFeeManager()), feeManager);
//         assertEq(address(poolFactory.unstakedFeeModule()), address(unstakedFeeModule));
//         assertEq(address(poolFactory.unstakedFeeManager()), feeManager);
//         assertEqUint(poolFactory.defaultUnstakedFee(), 100_000);
//         assertEqUint(poolFactory.tickSpacingToFee(1), 100);
//         assertEqUint(poolFactory.tickSpacingToFee(50), 500);
//         assertEqUint(poolFactory.tickSpacingToFee(100), 500);
//         assertEqUint(poolFactory.tickSpacingToFee(200), 3_000);
//         assertEqUint(poolFactory.tickSpacingToFee(2_000), 10_000);

//         assertTrue(address(nftDescriptor) != address(0));
//         assertEq(nftDescriptor.WETH9(), address(weth));
//         assertEq(nftDescriptor.nativeCurrencyLabelBytes(), bytes32("ETH"));

//         assertTrue(address(nft) != address(0));
//         assertEq(nft.factory(), address(poolFactory));
//         assertEq(nft.WETH9(), address(weth));
//         assertEq(nft.owner(), team);
//         assertEq(nft.name(), nftName);
//         assertEq(nft.symbol(), nftSymbol);

//         // assertTrue(address(gaugeImplementation) != address(0));
//         assertTrue(address(gaugeFactory) != address(0));
//         assertEq(gaugeFactory.voter(), address(voter));
//         // assertEq(gaugeFactory.implementation(), address(gaugeImplementation));
//         assertEq(gaugeFactory.nft(), address(nft));
//         // assertEq(gaugeFactory.notifyAdmin(), notifyAdmin);

//         assertTrue(address(swapFeeModule) != address(0));
//         assertEq(swapFeeModule.MAX_FEE(), 30_000); // 3%, using pip denomination
//         assertEq(address(swapFeeModule.factory()), address(poolFactory));

//         assertTrue(address(unstakedFeeModule) != address(0));
//         assertEq(unstakedFeeModule.MAX_FEE(), 500_000); // 50%, using pip denomination
//         assertEq(address(unstakedFeeModule.factory()), address(poolFactory));
//     }

//     function concat(string memory a, string memory b) internal pure returns (string memory) {
//         return string(abi.encodePacked(a, b));
//     }
// }
