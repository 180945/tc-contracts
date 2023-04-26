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
        address[] memory owners = new address[](7);
        owners[0] = address(0xF165DBE65127feca0abbD7d734B4a2a3c3C6aA84);
        owners[1] = address(0xd1950Ce1cd947B0F0378c9eB9618b705A13539A2);
        owners[2] = address(0x2150E0F033f2F8E8c13Fe2089A0cB399521604FF);
        owners[3] = address(0x9B9e024D6C2a9c3eF921497FbE53c57a851321cd);
        owners[4] = address(0xd85f5f63E83bDec8a92dd3C7f7FaEFE671024d85);
        owners[5] = address(0xD898eE20D858da55A7A58D1069BD47be234dC50f);
        owners[6] = address(0xB39310E75b773876dBa6006aDeE116BC40363994);

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
                WrappedToken.initialize.selector,
                address(tcbridge),
                "Wrapped BTC",
                "WBTC"
            )
        )));

        vm.stopBroadcast();
    }
}
