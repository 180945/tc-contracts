// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Router.sol";

contract TCScript is Script {
    address keyFactory;
    address routerContract;
    function setUp() public {
        keyFactory = vm.envAddress("KEY_FACTORY");
        routerContract = vm.envAddress("ROUTER_CONTRACT");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);

        // deploy route contract
        Router rt = new Router(
            IKeyFactory(keyFactory), ISwapRouter2(routerContract)
        );

        console.log("Deployer  %s", deployer);
        console.log("Router Address  %s", address(rt));

        vm.stopBroadcast();
    }
}

