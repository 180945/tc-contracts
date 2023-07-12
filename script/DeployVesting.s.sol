// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/vesting/Vesting.sol";

contract VestingScript is Script {
    address upgradeAddress;
    address claimAddress;
    uint64 startTime;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        claimAddress = 0xeb69E5dD331A6ae98298dC880736Fa4E500492ED;
        startTime = 1684309920;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy vesting tc contract
        VestingWallet implContract = new VestingWallet();
        address vestingAddr = address(new TransparentUpgradeableProxy(
            address(implContract),
            upgradeAddress,
            abi.encodeWithSelector(
                VestingWallet.initialize.selector,
                claimAddress,
                startTime
            )
        ));

        console.log("=== Deployment addresses ===");
        console.log("Vesting Impl %s", address(implContract));
        console.log("Vesting Proxy  %s", vestingAddr);

        vm.stopBroadcast();
    }
}

contract UpgradeVestingScript is Script {
    address contractVesting;
    function setUp() public {
        contractVesting = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // upgrade contract
        ITransparentUpgradeableProxy vesting = ITransparentUpgradeableProxy(0x43bDa480DE297A14cec95bFb1C6A313615f809Ef);
        vesting.upgradeTo(0xe8B280Ebb57bE03adC9d87e207BCD689EfADef96);

        vm.stopBroadcast();
    }
}