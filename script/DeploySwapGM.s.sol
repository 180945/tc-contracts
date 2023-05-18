// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/swapGM/swapGM.sol";

contract SwapScript is Script {

    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // todo: add owner here
        address[] memory owners = new address[](3);
        owners[0] = 0x1062bBEd226D063475fdf272a282ff72cAdfd35A;
        owners[1] = 0x154883f0944CeFeAF1692bEF4d8841b975150790;
        owners[2] = 0xDEE87DEd717242Ba1298Ba602D491cE617864528;

        // deploy vesting tc contract
        console.log("=== Deployment addresses ===");
        for (uint i = 0; i < owners.length; i++) {
            swapGM sgm = new swapGM(owners[i]);
            console.log("New swap contract  %s", address(sgm));
            console.log("Owner  %s", sgm.owner());
        }

        vm.stopBroadcast();
    }
}