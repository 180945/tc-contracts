// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/l2Metadata/L2Metadata.sol";

contract L2MetadataScript is Script {
    address upgradeAddress;
    address admin;

    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        admin = 0x6aCC6cE760177cFc8410622DA3daA2d6f14AC8b1;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy vesting tc contract
        L2Metadata implContract = new L2Metadata();
        address l2Metadata = address(new TransparentUpgradeableProxy(
            address(implContract),
            upgradeAddress,
            abi.encodeWithSelector(
                L2Metadata.initialize.selector,
                admin
            )
        ));

        console.log("=== Deployment addresses ===");
        console.log("L2Metadata Impl %s", address(implContract));
        console.log("L2Metadata Proxy  %s", l2Metadata);

        vm.stopBroadcast();
    }
}
