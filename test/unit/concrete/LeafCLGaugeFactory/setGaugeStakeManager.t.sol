pragma solidity ^0.7.6;
pragma abicoder v2;

import "./LeafCLGaugeFactory.t.sol";

contract SetGaugeStakeManagerTest is LeafCLGaugeFactoryTest {
    function test_RevertIf_NotGaugeStakeManager() public {
        vm.startPrank({msgSender: users.alice});
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setGaugeStakeManager({_manager: users.alice});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.startPrank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("ZA"));
        leafGaugeFactory.setGaugeStakeManager({_manager: address(0)});
    }

    function test_SetGaugeStakeManager() public {
        vm.prank({msgSender: users.owner});
        vm.expectEmit(true, false, false, false, address(leafGaugeFactory));
        emit SetGaugeStakeManager(users.alice);
        leafGaugeFactory.setGaugeStakeManager({_manager: users.alice});

        assertEq(leafGaugeFactory.gaugeStakeManager(), users.alice);
    }

    function test_TransferredManagerCanSetNewManager() public {
        vm.prank({msgSender: users.owner});
        leafGaugeFactory.setGaugeStakeManager({_manager: users.alice});

        vm.prank({msgSender: users.alice});
        leafGaugeFactory.setGaugeStakeManager({_manager: users.bob});

        assertEq(leafGaugeFactory.gaugeStakeManager(), users.bob);
    }

    function test_OldManagerCannotSetAfterTransfer() public {
        vm.prank({msgSender: users.owner});
        leafGaugeFactory.setGaugeStakeManager({_manager: users.alice});

        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setGaugeStakeManager({_manager: users.bob});
    }
}
