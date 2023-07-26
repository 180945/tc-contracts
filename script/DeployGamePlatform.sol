// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/gamePlatform/Register.sol";
import "../src/gamePlatform/GameBase.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/gamePlatform/ttt/ttt.sol";

contract DeployGameBase is Script {
    address upgradeAddress;
    address owner;

    // @notice game config data
    struct GameConfig {
        uint16 faultCharge; // 2 bytes range 0 - 10000
        uint16 serviceFee; // 2 bytes range 0 - 10000
        uint40 timeBuffer; // 5 bytes if the opponent does not submit in time so the game will end
        uint40 timeSubmitMatchResult; // 5 bytes
    }

    function setUp() public {
        upgradeAddress = 0x637249dBbAE73035C26F267572a5454d8E2a20B3;
        owner = 0x7286D69ed81DE05563264b9f4d47620B7768f318;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy vesting tc contract
        console.log("=== Deployment addresses ===");
        Register newRegister = new Register();
        GameBase newGameBase = new GameBase();

        Register register = Register(address(new TransparentUpgradeableProxy(
            address(newRegister),
            upgradeAddress,
            abi.encodeWithSelector(
                Register.initialize.selector,
                owner
            )
        )));

        // function initialize(address admin_, Register register_, GameConfig calldata initConfig_)
        GameBase gameBase = GameBase(address(new TransparentUpgradeableProxy(
            address(newGameBase),
            upgradeAddress,
            abi.encodeWithSelector(
                GameBase.initialize.selector,
                owner,
                register,
                GameConfig(1000, 500, 15 * 3600, 90 * 3600)
            )
        )));

        register.setGameBase(IElo(address(gameBase)));

        // new game
        TTT newGame = new TTT();
        gameBase.registerGame(0, address(newGame));

        console.log("deploy register contract  %s", address(register));
        console.log("deploy game base contract  %s", address(gameBase));
        console.log("deploy ttt game contract  %s", address(newGame));

        vm.stopBroadcast();
    }
}