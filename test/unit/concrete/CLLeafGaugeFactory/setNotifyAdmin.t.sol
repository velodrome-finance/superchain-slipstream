pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLLeafGaugeFactory.t.sol";

contract SetNotifyAdminTest is CLLeafGaugeFactoryTest {
    event SetNotifyAdmin(address indexed notifyAdmin);

    // function test_RevertIf_NotNotifyAdmin() public {
    //     vm.startPrank({msgSender: users.alice});
    //     vm.expectRevert(abi.encodePacked("NA"));
    //     leafGaugeFactory.setNotifyAdmin({_admin: users.alice});
    // }
    //
    // function test_RevertIf_ZeroAddress() public {
    //     vm.startPrank({msgSender: users.owner});
    //     vm.expectRevert(abi.encodePacked("ZA"));
    //     leafGaugeFactory.setNotifyAdmin({_admin: address(0)});
    // }
    //
    // function test_SetNotifyAdmin() public {
    //     vm.prank({msgSender: users.owner});
    //     vm.expectEmit(true, false, false, false, address(leafGaugeFactory));
    //     emit SetNotifyAdmin(users.alice);
    //     leafGaugeFactory.setNotifyAdmin({_admin: users.alice});
    //
    //     assertEq(leafGaugeFactory.notifyAdmin(), address(users.alice));
    // }
}
