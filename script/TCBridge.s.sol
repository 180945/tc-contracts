// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/TCBridge.sol";

contract TCScript is Script {
    address upgradeAddress;
    function setUp() public {
        upgradeAddress = 0x8F6A5136F8f4674e432B63D640Da04c7DB663c06;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
        address[] memory owners = new address[](3);
        owners[0] = address(0x9699b31b25D71BDA4819bBe66244E9130cEE62b7);
        owners[1] = address(0x54b3DBA467C9Dbb916EF4D6AedaFa19C4Fef8258);
        owners[2] = address(0xD7d93b7fa42b60b6076f3017fCA99b69257A912D);

        Safe impl = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(impl),
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                2,
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
                TCBridge.initialize.selector,
                address(tcbridge)
            )
        )));

        vm.stopBroadcast();
    }
}
