pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {DeployRootCL} from "script/deployParameters/optimism/DeployRootCL.s.sol";
import {RootCLPool} from "contracts/root/pool/RootCLPool.sol";
import {RootCLPoolFactory} from "contracts/root/pool/RootCLPoolFactory.sol";
import {RootCLGaugeFactory} from "contracts/root/gauge/RootCLGaugeFactory.sol";
import "test/BaseForkFixture.sol";

contract DeployRootCLForkTest is BaseForkFixture {
    using stdStorage for StdStorage;

    DeployRootCL public deployCL;

    DeployRootCL.DeploymentParameters public params;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: blockNumber});

        deployCL = new DeployRootCL();
        deployCL.setUp();

        createUsers();

        stdstore.target(address(deployCL)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deployCL)).sig("isTest()").checked_write(true);

        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/fork/addresses.json"));
        addresses = vm.readFile(path);
    }

    function test_deployCL() public {
        deployCL.run();

        // preload variables for convenience
        rootPoolImplementation = deployCL.rootPoolImplementation();
        rootPoolFactory = deployCL.rootPoolFactory();
        rootGaugeFactory = deployCL.rootGaugeFactory();

        params = deployCL.params();

        assertNotEq(params.voter, address(0));
        assertNotEq(params.xVelo, address(0));
        assertNotEq(params.lockbox, address(0));
        assertNotEq(params.messageBridge, address(0));
        assertNotEq(params.votingRewardsFactory, address(0));
        assertNotEq(params.poolFactoryOwner, address(0));
        assertNotEq(params.feeManager, address(0));
        assertNotEq(params.notifyAdmin, address(0));
        assertNotEq(params.emissionAdmin, address(0));

        assertNotEq(address(rootPoolImplementation), address(0));
        assertNotEq(address(rootPoolFactory), address(0));
        assertEq(address(rootPoolFactory.implementation()), address(rootPoolImplementation));
        assertEq(address(rootPoolFactory.bridge()), params.messageBridge);
        assertEq(address(rootPoolFactory.owner()), params.poolFactoryOwner);
        assertEqUint(rootPoolFactory.tickSpacingToFee(1), 100);
        assertEqUint(rootPoolFactory.tickSpacingToFee(50), 500);
        assertEqUint(rootPoolFactory.tickSpacingToFee(100), 500);
        assertEqUint(rootPoolFactory.tickSpacingToFee(200), 3_000);
        assertEqUint(rootPoolFactory.tickSpacingToFee(2_000), 10_000);

        assertNotEq(address(rootGaugeFactory), address(0));
        assertEq(rootGaugeFactory.rewardToken(), vm.parseJsonAddress(addresses, ".Velo"));
        assertEq(rootGaugeFactory.minter(), vm.parseJsonAddress(addresses, ".Minter"));
        assertEq(rootGaugeFactory.voter(), params.voter);
        assertEq(rootGaugeFactory.xerc20(), params.xVelo);
        assertEq(rootGaugeFactory.lockbox(), params.lockbox);
        assertEq(rootGaugeFactory.messageBridge(), params.messageBridge);
        assertEq(rootGaugeFactory.poolFactory(), address(rootPoolFactory));
        assertEq(rootGaugeFactory.votingRewardsFactory(), params.votingRewardsFactory);
        assertEq(rootGaugeFactory.emissionAdmin(), params.emissionAdmin);
        assertEqUint(rootGaugeFactory.defaultCap(), 100);
        assertEq(rootGaugeFactory.notifyAdmin(), params.notifyAdmin);
        assertEqUint(rootGaugeFactory.weeklyEmissions(), 0);
        assertEqUint(rootGaugeFactory.activePeriod(), 0);
        assertEqUint(rootGaugeFactory.MAX_BPS(), 10_000);
        assertEqUint(rootGaugeFactory.WEEKLY_DECAY(), 9_900);
        assertEqUint(rootGaugeFactory.TAIL_START_TIMESTAMP(), 1743638400);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
