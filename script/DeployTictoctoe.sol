// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
//import "../src/tictactoe/Tictactoe.sol";

contract TictoctoeScript is Script {
    address upgradeAddress;
    uint256 turnDuration;
    uint256 playerTimePool;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        turnDuration = 5 * 60;
        playerTimePool = 1000000000000;
    }
//
//    function run() public {
//        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//        vm.startBroadcast(deployerPrivateKey);
//
//        // deploy vesting tc contract
//        VestingWallet implContract = new VestingWallet();
//        address vestingAddr = address(new TicTacToe(
//            address(implContract),
//            upgradeAddress,
//            abi.encodeWithSelector(
//                VestingWallet.initialize.selector,
//                claimAddress,
//                startTime
//            )
//        ));
//
//        console.log("=== Deployment addresses ===");
//        console.log("Vesting Impl %s", address(implContract));
//        console.log("Vesting Proxy  %s", vestingAddr);
//
//        vm.stopBroadcast();
//    }
}
