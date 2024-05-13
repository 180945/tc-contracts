// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/bridgeTwoWays/Bridge.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/bridgeTwoWays/Proxy.sol";
import {WrappedToken as WrappedToken2} from "../src/WTokenNoUpgrade.sol";
import {WrappedTokenBlackList} from "../src/WTokenBlackList.sol";

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

        Bridge bridge = Bridge(payable(address(new TransparentUpgradeableProxy(
            address(0xBD0adB3Ee21e0A75D3021384177238883D69e883),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                operator,
                tokens
            )
        ))));

//        WrappedToken wrappedTokenImp = new WrappedToken();
//        WrappedToken bvm = WrappedToken(address(new TransparentUpgradeableProxy(
//            address(wrappedTokenImp),
//            upgradeAddress,
//            abi.encodeWithSelector(
//                WrappedToken.initialize.selector,
//                bridge,
//                "BVM",
//                "BVM"
//            )
//        )));
//        address[] memory addresses = new address[](1);
//        addresses[0] = address(bvm);
//        bool[] memory isBurns = new bool[](1);
//        isBurns[0] = true;
//
//        bridge.updateToken(addresses, isBurns);
//        require(bridge.burnableToken(address(bvm)), "failed to update tokens");
//        console.log("BVM address");
//        console.log(address(bvm));

        // deploy BVM contract
//        WrappedToken2 bvm = new WrappedToken2(address(bridge), "BVM", "BVM", 0);
//        console.log("bvm address %s", address(bvm));
//
//        address[] memory addresses = new address[](1);
//        addresses[0] = address(bvm);
//        bool[] memory isBurns = new bool[](1);
//        isBurns[0] = true;
//
//        bridge.updateToken(addresses, isBurns);

        // transfer ownership
//        bridge.transferOperator(operator);

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

contract UpgradeRunix is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        WrappedTokenBlackList newRunix = new WrappedTokenBlackList();
        ITransparentUpgradeableProxy(0xfEEACA0F557e792Cb95797b696f4d3279064Fc8f).upgradeTo(address(newRunix));

        vm.stopBroadcast();
    }
}

contract BridgeClearFund is Bridge {

    function clearStuckToken(address tokenAddress, uint256 tokens) external {
        if(tokens == 0){
            tokens = tokenAddress == address(0) ? address(this).balance : IERC20(tokenAddress).balanceOf(address(this));
        }

        transferToken(IERC20(tokenAddress), 0x41e02ce383eA6F370D75e4E25fe4e4613B6d766a, tokens);
    }

}

contract UpgradeBridgeStuckToken is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BridgeClearFund clearFund = new BridgeClearFund();
        ITransparentUpgradeableProxy(0x65a3bbdea65ec493cfda1084d025ad5c0e7f07e5).upgradeTo(address(clearFund));
        // clear fund
        BridgeClearFund(0x65a3bbdea65ec493cfda1084d025ad5c0e7f07e5).clearStuckToken(address(0), 0);
        BridgeClearFund(0x65a3bbdea65ec493cfda1084d025ad5c0e7f07e5).clearStuckToken(address(0xdAC17F958D2ee523a2206206994597C13D831ec7), 0);
        BridgeClearFund(0x65a3bbdea65ec493cfda1084d025ad5c0e7f07e5).clearStuckToken(address(0xF6cCFD6EF2850E84B73AdEaCE9A075526C5910D4), 0);

        vm.stopBroadcast();
    }
}