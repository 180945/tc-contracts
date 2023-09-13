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
    function setUp() public {
        upgradeAddress = vm.envAddress("UPGRADE_WALLET");
        operator = vm.envAddress("OPERATOR_WALLET");
        owners = vm.envAddress("OWNERS", ",");
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
        Bridge bridge = Bridge(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                deployer,
                tokens
            )
        )));

        uint tokenCount = 2;
        string[] memory names = new string[](tokenCount);
        names[0] = "Bitcoin";
        names[1] = "Ethereum";

        string[] memory symbols = new string[](tokenCount);
        symbols[0] = "BTC";
        symbols[1] = "ETH";

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
            isBurns[0] = true;
            isBurns[1] = true;

            bridge.updateToken(results, isBurns);
        }
        bridge.transferOperator(operator);

        vm.stopBroadcast();

        {
            console.log("=== Deployment addresses ===");
            console.log("Safe address %s", address(safe));
            console.log("Bridge address  %s", address(bridge));
            for (uint i = 0; i < names.length; i++) {
                console.log("%s address  %s", symbols[i], results[i]);
            }
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
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Safe safeImp = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(new Safe()),
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

        // deploy tcbridge
        address[] memory tokens;
        Bridge bridgeImp = new Bridge();
        Bridge bridge = Bridge(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                operator,
                tokens
            )
        )));

        //// @deprecated deploy proxy
        //        ProxyBridge proxyBridge = new ProxyBridge(
        //            0x47D453f4E494Ebb7264380d98D1C61420DfBB973,
        //            0xa103f20367b18D004710141Ff505A6B63CE6885C,
        //            address(safe),
        //            address(bridge),
        //            42213
        //        );
        // console.log("Proxy address  %s", address(proxyBridge));

        vm.stopBroadcast();

        console.log("=== Deployment addresses ===");
        console.log("Safe address %s", address(safe));
        console.log("Bridge address  %s", address(bridge));
    }
}
