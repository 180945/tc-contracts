// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/bridgeTwoWays/Bridge.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/bridgeTwoWays/Proxy.sol";
import "../src/decentralizeNos/SequencerList.sol";
import "optimism-tc/packages/contracts-bedrock/contracts/L2/SequencerFeeVault.sol";

contract TCScript is Script {
    address upgradeAddress;
    address admin;
    function setUp() public {
        upgradeAddress = 0x9699b31b25D71BDA4819bBe66244E9130cEE62b7;
        admin = 0x1554e0c159364d7f207BfB7Ed0B7Df4c86db011C;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy vesting tc contract
        address[] memory sequencers = new address[](1);
        sequencers[0] = admin;

        SequencerList sequenceContract = SequencerList(payable(address(new TransparentUpgradeableProxy(
            address(new SequencerList()),
            upgradeAddress,
            abi.encodeWithSelector(
                SequencerList.initialize.selector,
                sequencers,
                admin
            )
        ))));

        console.log("=== Deployment addresses ===");
        console.log("Deploy sequencer list at address %s", address(sequenceContract));

        vm.stopBroadcast();

    }
}
