pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/StdJson.sol";
import "../BaseFixture.sol";

abstract contract BaseForkFixture is BaseFixture {
    using stdJson for string;

    IERC20 public op;

    function setUp() public virtual override {
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
    }
}
