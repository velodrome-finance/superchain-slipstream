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

    DeployRootCL public deployRootCL_;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: blockNumber});

        deployRootCL_ = new DeployRootCL();
        deployRootCL_.setUp();

        createUsers();

        stdstore.target(address(deployRootCL_)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deployRootCL_)).sig("isTest()").checked_write(true);

        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/fork/addresses.json"));
        addresses = vm.readFile(path);
    }

    function test_deployCL() public {
        deployRootCL_.run();

        // preload variables for convenience
        rootPoolImplementation = deployRootCL_.rootPoolImplementation();
        rootPoolFactory = deployRootCL_.rootPoolFactory();
        rootGaugeFactory = deployRootCL_.rootGaugeFactory();

        rootParams = deployRootCL_.params();

        assertNotEq(rootParams.voter, address(0));
        assertNotEq(rootParams.xVelo, address(0));
        assertNotEq(rootParams.lockbox, address(0));
        assertNotEq(rootParams.messageBridge, address(0));
        assertNotEq(rootParams.votingRewardsFactory, address(0));
        assertNotEq(rootParams.poolFactoryOwner, address(0));
        assertNotEq(rootParams.notifyAdmin, address(0));
        assertNotEq(rootParams.emissionAdmin, address(0));

        assertNotEq(address(rootPoolImplementation), address(0));
        assertNotEq(address(rootPoolFactory), address(0));
        assertEq(address(rootPoolFactory.implementation()), address(rootPoolImplementation));
        assertEq(address(rootPoolFactory.bridge()), rootParams.messageBridge);
        assertEq(address(rootPoolFactory.owner()), rootParams.poolFactoryOwner);
        assertEqUint(rootPoolFactory.tickSpacingToFee(1), 100);
        assertEqUint(rootPoolFactory.tickSpacingToFee(50), 500);
        assertEqUint(rootPoolFactory.tickSpacingToFee(100), 500);
        assertEqUint(rootPoolFactory.tickSpacingToFee(200), 3_000);
        assertEqUint(rootPoolFactory.tickSpacingToFee(2_000), 10_000);

        assertNotEq(address(rootGaugeFactory), address(0));
        assertEq(rootGaugeFactory.rewardToken(), vm.parseJsonAddress(addresses, ".Velo"));
        assertEq(rootGaugeFactory.minter(), vm.parseJsonAddress(addresses, ".Minter"));
        assertEq(rootGaugeFactory.voter(), rootParams.voter);
        assertEq(rootGaugeFactory.xerc20(), rootParams.xVelo);
        assertEq(rootGaugeFactory.lockbox(), rootParams.lockbox);
        assertEq(rootGaugeFactory.messageBridge(), rootParams.messageBridge);
        assertEq(rootGaugeFactory.poolFactory(), address(rootPoolFactory));
        assertEq(rootGaugeFactory.votingRewardsFactory(), rootParams.votingRewardsFactory);
        assertEq(rootGaugeFactory.emissionAdmin(), rootParams.emissionAdmin);
        assertEqUint(rootGaugeFactory.defaultCap(), 150);
        assertEq(rootGaugeFactory.notifyAdmin(), rootParams.notifyAdmin);
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
