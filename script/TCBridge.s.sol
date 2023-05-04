// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/TCBridge.sol";
import "../src/ethereum/TCBridgeETH.sol";

contract TCScript is Script {
    address upgradeAddress;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
        address[] memory owners = new address[](7);
        owners[0] = address(0x142d09aCeA7b067639c8Dc4CF55fe907c5706c80);
        owners[1] = address(0x48519f5d37d4acE18011b5470EaaFDAf400079Cb);
        owners[2] = address(0x6c4ABD94C6eF3A8B092a673bE7D069F6A3a0c764);
        owners[3] = address(0xa32D154D0824C4d898b5A3b054E4aa0346322724);
        owners[4] = address(0x2550f37641FFB5e4928052aDDD788Cd8514d16a7);
        owners[5] = address(0xe64F53d154A25498870202aceff40A4344385a18);
        owners[6] = address(0x7d32913ad31Cdd2DAfA4eB024eF8fa0A3E6F9D95);

        Safe impl = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(impl),
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
        TCBridge tcImpl = new TCBridge();
        TCBridge tcbridge = TCBridge(address(new TransparentUpgradeableProxy(
            address(tcImpl),
            upgradeAddress,
            abi.encodeWithSelector(
                TCBridge.initialize.selector,
                address(safe)
            )
        )));

        // deploy wrapped token
        WrappedToken wbrcImpl = new WrappedToken();
        WrappedToken wbtc = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wbrcImpl),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                address(tcbridge),
                "Wrapped BTC",
                "WBTC"
            )
        )));
        vm.stopBroadcast();
    }
}

contract TCETHScript is Script {
    address upgradeAddress;
    function setUp() public {
        upgradeAddress = 0xD7d93b7fa42b60b6076f3017fCA99b69257A912D;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
//        address[] memory owners = new address[](7);
//        owners[0] = address(0x142d09aCeA7b067639c8Dc4CF55fe907c5706c80);
//        owners[1] = address(0x48519f5d37d4acE18011b5470EaaFDAf400079Cb);
//        owners[2] = address(0x6c4ABD94C6eF3A8B092a673bE7D069F6A3a0c764);
//        owners[3] = address(0xa32D154D0824C4d898b5A3b054E4aa0346322724);
//        owners[4] = address(0x2550f37641FFB5e4928052aDDD788Cd8514d16a7);
//        owners[5] = address(0xe64F53d154A25498870202aceff40A4344385a18);
//        owners[6] = address(0x7d32913ad31Cdd2DAfA4eB024eF8fa0A3E6F9D95);
//
//        Safe impl = new Safe();
//        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
//            address(impl),
//            upgradeAddress,
//            abi.encodeWithSelector(
//                Safe.setup.selector,
//                owners,
//                5,
//                address(0x0),
//                bytes(""),
//                address(0x0),
//                address(0x0),
//                0,
//                address(0)
//            )
//        ))));

        // deploy tcbridge
        TCBridgeETH tcImpl = new TCBridgeETH();
        TCBridgeETH tcbridge = TCBridgeETH(address(new TransparentUpgradeableProxy(
            address(tcImpl),
            upgradeAddress,
            abi.encodeWithSelector(
                TCBridgeETH.initialize.selector,
                address(0x29987AC0BDF17f5134D240FA799A8612B0374968)
            )
        )));

        vm.stopBroadcast();
    }
}