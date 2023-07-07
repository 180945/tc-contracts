// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import { TicTacToe } from "../src/tictactoe/Tictactoe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TictoctoeScript is Script {
    address upgradeAddress;
    uint256 turnDuration;
    uint256 playerTimePool;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        turnDuration = 5 * 60;
        playerTimePool = 1000000000000;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy vesting tc contract
        TicTacToe implContract = new TicTacToe();
        address tictoctoe = address(new TransparentUpgradeableProxy(
            address(implContract),
            upgradeAddress,
            abi.encodeWithSelector(
                TicTacToe.initialize.selector,
                turnDuration,
                playerTimePool
            )
        ));

        console.log("=== Deployment addresses ===");
        console.log("Tictoctoe Impl %s", address(implContract));
        console.log("Tictoctoe Proxy  %s", tictoctoe);

        vm.stopBroadcast();
    }
}
