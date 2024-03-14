// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/bridgeTwoWays/Bridge.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/bridgeTwoWays/Proxy.sol";

contract TCScript is Script {
    address upgradeAddress;
    address operator;
    address[] owners;
    string[] tokenNames;
    function setUp() public {
        upgradeAddress = vm.envAddress("UPGRADE_WALLET");
        operator = vm.envAddress("OPERATOR_WALLET");
        owners = vm.envAddress("OWNERS", ",");
        tokenNames = vm.envString("TOKENS", ",");

        require(tokenNames.length % 2 == 0, "invalid tokens param");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);

        Safe safeImp = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(safeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                2 * owners.length / 3 + 1,
                address(0x0),
                bytes(""),
                address(0x0),
                address(0x0),
                0,
                address(0)
            )
        ))));

        address[] memory tokens = new address[](0);

        // deploy TC bridge
        Bridge bridgeImp = new Bridge();
        Bridge bridge = Bridge(payable(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                deployer,
                tokens
            )
        ))));

        uint tokenCount = tokenNames.length / 2;
        string[] memory names = new string[](tokenCount);
        for (uint i = 0; i < names.length; i++) {
            names[i] = tokenNames[i * 2];
        }

        string[] memory symbols = new string[](tokenCount);
        for (uint i = 0; i < symbols.length; i++) {
            symbols[i] = tokenNames[i * 2 + 1];
        }

        address[] memory results = new address[](tokenCount);
        WrappedToken wrappedTokenImp = new WrappedToken();
        // deploy wrapped token
        for (uint i = 0; i < names.length; i++) {
            results[i] = address(new TransparentUpgradeableProxy(
                address(wrappedTokenImp),
                upgradeAddress,
                abi.encodeWithSelector(
                    WrappedToken.initialize.selector,
                    bridge,
                    names[i],
                    symbols[i]
                )
            ));
        }
        {
            bool[] memory isBurns = new bool[](tokenCount);
            for (uint i = 0; i < tokenCount; i++) {
                isBurns[i] = true;
            }

            bridge.updateToken(results, isBurns);
        }
        bridge.transferOperator(operator);

        vm.stopBroadcast();

        {
            string memory result = '{ "multisig":';
            console.log("=== Deployment addresses ===");
            console.log("Safe address %s", address(safe));
            result = string.concat(result, '"');
            result = string.concat(result, vm.toString(address(safe)));
            result = string.concat(result, '"');
            result = string.concat(result, ",");
            result = string.concat(result, '"bridge":');
            console.log("Bridge address  %s", address(bridge));
            result = string.concat(result, '"');
            result = string.concat(result, vm.toString(address(bridge)));
            result = string.concat(result, '"');
            result = string.concat(result, ",");
            for (uint i = 0; i < names.length; i++) {
                console.log("%s", results[i]);
                result = string.concat(result, '"');
                result = string.concat(result, symbols[i]);
                result = string.concat(result, '"');
                result = string.concat(result, ':');
                result = string.concat(result, '"');
                result = string.concat(result, vm.toString(results[i]));
                result = string.concat(result, '"');
                if (i != names.length - 1) {
                    result = string.concat(result, ',');
                }
            }
            result = string.concat(result, "}");
            vm.writeFile("deployL2.json", result);
        }
    }
}

contract TCScriptOnETH is Script {
    address upgradeAddress;
    address operator;
    address[] owners;

    function setUp() public {
        upgradeAddress = vm.envAddress("UPGRADE_WALLET");
        operator = vm.envAddress("OPERATOR_WALLET");
        owners = vm.envAddress("OWNERS", ",");
        if (owners.length == 0) {
            owners = Safe(payable(0x5b6e24479811E7edac7A5dBbE115E5c0b5D8effB)).getOwners();
            require(owners.length > 0);
        }
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Safe safeImp = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552),
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                2 * owners.length / 3 + 1,
                address(0x0),
                bytes(""),
                address(0x0),
                address(0x0),
                0,
                address(0)
            )
        ))));

        // deploy tc_bridge
        address[] memory tokens;
        Bridge bridgeImp = new Bridge();
        Bridge bridge = Bridge(payable(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                operator,
                tokens
            )
        ))));

        WrappedToken wrappedTokenImp = new WrappedToken();
        WrappedToken bvm = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wrappedTokenImp),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                bridge,
                "BVM",
                "BVM"
            )
        )));
        address[] memory addresses = new address[](1);
        addresses[0] = address(bvm);
        bool[] memory isBurns = new bool[](1);
        isBurns[0] = true;

        bridge.updateToken(addresses, isBurns);
        require(bridge.burnableToken(address(bvm)), "failed to update tokens");
        console.log("BVM address");
        console.log(address(bvm));

        vm.stopBroadcast();

        string memory result = '{ "multisig":';
        console.log("=== Deployment addresses ===");
        console.log("Safe address %s", address(safe));
        result = string.concat(result, '"');
        result = string.concat(result, vm.toString(address(safe)));
        result = string.concat(result, '"');
        result = string.concat(result, ",");
        result = string.concat(result, '"bridge":');
        console.log("Bridge address  %s", address(bridge));
        result = string.concat(result, '"');
        result = string.concat(result, vm.toString(address(bridge)));
        result = string.concat(result, '"');
        result = string.concat(result, "}");
        vm.writeFile("deployETH.json", result);
    }
}

contract SetAmin is Script {
    address upgradeAddress;
    function setUp() public {
        upgradeAddress = vm.envAddress("UPGRADE_WALLET");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("new upgrade address: %s", upgradeAddress);
        ITransparentUpgradeableProxy(0x111808AbE352c8003e0eFfcc04998EaB26Cebe3c).changeAdmin(address(upgradeAddress));

        vm.stopBroadcast();
    }
}

contract TCDeployTokenScript is Script {
    function setUp() public {}

    function run() public {
        address upgradeAddress = vm.envAddress("UPGRADE_WALLET");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address payable bridgeAddress = payable(0x03261A78402c139dc73346F13Cd2CB301105EFa3);

        WrappedToken wrappedTokenImp = new WrappedToken();
        WrappedToken bvm = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wrappedTokenImp),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                bridgeAddress,
                "BVM",
                "BVM"
            )
        )));
        address[] memory addresses = new address[](1);
        addresses[0] = address(bvm);
        bool[] memory isBurns = new bool[](1);
        isBurns[0] = true;

        Bridge(bridgeAddress).updateToken(addresses, isBurns);
        require(Bridge(bridgeAddress).burnableToken(address(bvm)), "failed to update tokens");

        console.log("BVM address");
        console.log(address(bvm));

        vm.stopBroadcast();
    }
}

contract UpdateProxyAdmin is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ITransparentUpgradeableProxy(0x069d89974f4edaBde69450f9cF5CF7D8Cbd2568D).changeAdmin(address(0x000000000000000000000000000000000000dEaD));

        vm.stopBroadcast();
    }
}