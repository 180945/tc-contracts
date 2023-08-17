// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SequencerList} from "../src/decentralizeNos/SequencerList.sol";

contract SequencerListTest is Test {
    address public constant UPGRADE_ADDR = address(9);
    address public constant ADMIN_ADDR = address(10);
    SequencerList public sequenceContract;
    address constant USER_1 = address(11);
    address constant USER_2 = address(12);
    address constant USER_3 = address(13);

    function setUp() public {
        address[] memory sequencers = new address[](3);
        sequencers[0] = USER_1;
        sequencers[1] = USER_2;
        sequencers[2] = USER_3;

        sequenceContract = SequencerList(payable(address(new TransparentUpgradeableProxy(
            address(new SequencerList()),
            UPGRADE_ADDR,
            abi.encodeWithSelector(
                SequencerList.initialize.selector,
                sequencers,
                ADMIN_ADDR
            )
        ))));
    }


    function testFeatures() public {
        assertEq(sequenceContract.isSequencer(address(100)), false);
        assertEq(sequenceContract.isSequencer(USER_1), true);
        assertEq(sequenceContract.isSequencer(USER_2), true);
        assertEq(sequenceContract.isSequencer(USER_3), true);

        address[] memory sequencers = new address[](3);
        sequencers[0] = USER_1;
        sequencers[1] = USER_2;
        sequencers[2] = USER_3;

        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers)));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sequenceContract.addSequencer(address(101));

        vm.prank(ADMIN_ADDR);
        sequenceContract.addSequencer(address(101));
        assertEq(sequenceContract.isSequencer(address(101)), true);

        address[] memory sequencers2 = new address[](4);
        sequencers2[0] = USER_1;
        sequencers2[1] = USER_2;
        sequencers2[2] = USER_3;
        sequencers2[3] = address(101);
        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers2)));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sequenceContract.removeSequencer(address(101));

        vm.prank(ADMIN_ADDR);
        sequenceContract.removeSequencer(address(101));
        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers)));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sequenceContract.newSequencers(sequencers2);

        vm.prank(ADMIN_ADDR);
        sequenceContract.newSequencers(sequencers2);
        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers2)));
    }
}
