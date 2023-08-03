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
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        owner = 0x01e7663F7359698E2B1da534b478b71e4b0D50e9;
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
                GameConfig(1000, 1000, 15 * 60, 90 * 60)
            )
        )));

        register.setGameBase(IElo(address(gameBase)));

        // new game
        Chess newGame = new Chess();
        gameBase.registerGame(1, address(newGame));

//        register.register(0xbad9221EA6F733ea38B48C3FA19552755e7719e0, 1, "leon1", int(1500));
//        register.register(0xF0a391886410ecF0F03951D26f89b792cf0761Da, 1, "leon2", int(1500));
//        register.register(0x7286D69ed81DE05563264b9f4d47620B7768f318, 1, "issac", int(1500));
        // 0x9699b31b25D71BDA4819bBe66244E9130cEE62b7
//        register.register(0x9699b31b25D71BDA4819bBe66244E9130cEE62b7, 1, "issac2", int(1500));

        // init one match
//        gameBase.createMatch{value: 1e17}(1, 1000, 1e17, 1690996335);

        console.log("deploy register contract  %s", address(register));
        console.log("deploy game base implementation contract  %s", address(newGameBase));
        console.log("deploy game base contract  %s", address(gameBase));
        console.log("deploy ttt game contract  %s", address(newGame));

        vm.stopBroadcast();
    }
}

contract UpdateGameBase is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GameBase newGameBase = new GameBase();
        ITransparentUpgradeableProxy(0x60B0Bf853F406Ccfa0F95dA804eC14a5dc4C72b6).upgradeTo(address(newGameBase));

        vm.stopBroadcast();
    }
}