pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/StdJson.sol";
import "../BaseFixture.sol";

import {IXERC20} from "contracts/superchain/IXERC20.sol";
import {IXERC20Lockbox} from "contracts/superchain/IXERC20Lockbox.sol";
import {IRootMessageBridge} from "contracts/mainnet/interfaces/bridge/IRootMessageBridge.sol";
import {IRootHLMessageModule} from "contracts/mainnet/interfaces/bridge/hyperlane/IRootHLMessageModule.sol";

abstract contract BaseForkFixture is BaseFixture {
    using stdJson for string;

    string public addresses;
    IERC20 public op;

    // root superchain contracts
    IXERC20 public xVelo;
    IRootMessageBridge public rootMessageBridge;
    IRootHLMessageModule public rootMessageModule;

    // root-only contracts
    IXERC20Lockbox public rootLockbox;

    function setUp() public virtual override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/fork/addresses.json"));
        addresses = vm.readFile(path);

        // set up contracts after fork
        BaseFixture.setUp();

        nftCallee = new NFTManagerCallee(address(weth), address(op), address(nft));

        deal({token: address(op), to: users.alice, give: TOKEN_1 * 100});
        deal({token: address(weth), to: users.alice, give: TOKEN_1 * 100});

        vm.startPrank(users.alice);
        op.approve(address(nftCallee), type(uint256).max);
        weth.approve(address(nftCallee), type(uint256).max);
        vm.stopPrank();
    }

    function deployDependencies() public virtual override {
        factoryRegistry = IFactoryRegistry(vm.parseJsonAddress(addresses, ".FactoryRegistry"));
        weth = IERC20(vm.parseJsonAddress(addresses, ".WETH"));
        op = IERC20(vm.parseJsonAddress(addresses, ".OP"));
        rootVoter = IVoter(vm.parseJsonAddress(addresses, ".Voter"));
        rewardToken = ERC20(vm.parseJsonAddress(addresses, ".Velo"));
        votingRewardsFactory = IVotingRewardsFactory(vm.parseJsonAddress(addresses, ".VotingRewardsFactory"));
        escrow = IVotingEscrow(vm.parseJsonAddress(addresses, ".VotingEscrow"));
        minter = IMinter(vm.parseJsonAddress(addresses, ".Minter"));

        xVelo = IXERC20(vm.parseJsonAddress(addresses, ".XVelo"));
        rootMessageBridge = IRootMessageBridge(vm.parseJsonAddress(addresses, ".MessageBridge"));
        rootMessageModule = IRootHLMessageModule(vm.parseJsonAddress(addresses, ".MessageModule"));
        rootLockbox = IXERC20Lockbox(vm.parseJsonAddress(addresses, ".Lockbox"));
    }
}
