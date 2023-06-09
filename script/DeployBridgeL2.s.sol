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
//    address wrappedTokenImp;
//    address safeImp;
//    address bridgeImp;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
//        wrappedTokenImp = 0x79DD392A7c352f0C47fB452c036EF08A1DA148C6;
//        safeImp = 0x47D453f4E494Ebb7264380d98D1C61420DfBB973;
//        bridgeImp = 0xa103f20367b18D004710141Ff505A6B63CE6885C;
        operator = 0x01e7663F7359698E2B1da534b478b71e4b0D50e9;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
        address[] memory owners = new address[](7);
        owners[0] = address(0x2736d9488022C760Bad8f1FDcc156CEAF2fF3bF0);
        owners[1] = address(0x63cA329bD5743cFB8Ee01fAb22b29A4ef00B0F97);
        owners[2] = address(0xc78980C8a6042cc947e238053BCB3544d8726DF3);
        owners[3] = address(0xbd3f547B7E10d0bA899873CC59FDA8c09804BBbc);
        owners[4] = address(0xE62c762B706e1394181dCA2313cB03862737CADE);
        owners[5] = address(0x85c7ecA3257614A6389fDb58ab0a89563f107B14);
        owners[6] = address(0xf4add02D3355f8ff6411018892D67Bd5dA887f51);

        Safe safeImp = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(safeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                5,
                address(0x0),
                bytes(""),
                address(0x0),
                address(0x0),
                0,
                address(0)
            )
        ))));

        address[] memory tokens = new address[](0);

        // deploy tcbridge
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

        uint tokenCount = 5;
        string[] memory names = new string[](tokenCount);
        names[0] = "Bitcoin";
        names[1] = "Ethereum";
        names[2] = "USDC";
        names[3] = "PEPE";
        names[4] = "Tether";

        string[] memory symbols = new string[](tokenCount);
        symbols[0] = "BTC";
        symbols[1] = "ETH";
        symbols[2] = "USDC";
        symbols[3] = "PEPE";
        symbols[4] = "USDT";

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
            isBurns[2] = true;
            isBurns[3] = true;
            isBurns[4] = true;
            bridge.updateToken(results, isBurns);
        }
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
    address safeImp;
    address operator;
    //    address wrappedTokenImp;
    //    address bridgeImp;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        safeImp = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
        operator = 0x01e7663F7359698E2B1da534b478b71e4b0D50e9;
        //        wrappedTokenImp = 0x79DD392A7c352f0C47fB452c036EF08A1DA148C6;
        //        bridgeImp = 0xa103f20367b18D004710141Ff505A6B63CE6885C;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
        address[] memory owners = new address[](7);
        owners[0] = address(0x2736d9488022C760Bad8f1FDcc156CEAF2fF3bF0);
        owners[1] = address(0x63cA329bD5743cFB8Ee01fAb22b29A4ef00B0F97);
        owners[2] = address(0xc78980C8a6042cc947e238053BCB3544d8726DF3);
        owners[3] = address(0xbd3f547B7E10d0bA899873CC59FDA8c09804BBbc);
        owners[4] = address(0xE62c762B706e1394181dCA2313cB03862737CADE);
        owners[5] = address(0x85c7ecA3257614A6389fDb58ab0a89563f107B14);
        owners[6] = address(0xf4add02D3355f8ff6411018892D67Bd5dA887f51);

        // Safe safeImp = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            safeImp,
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                5,
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

        // deploy proxy
        ProxyBridge proxyBridge = new ProxyBridge(
            0x47D453f4E494Ebb7264380d98D1C61420DfBB973,
            0xa103f20367b18D004710141Ff505A6B63CE6885C,
            address(safe),
            address(bridge),
            42213
        );

        vm.stopBroadcast();

        console.log("=== Deployment addresses ===");
        console.log("Safe address %s", address(safe));
        console.log("Bridge address  %s", address(bridge));
        console.log("Proxy address  %s", address(proxyBridge));
    }
}
