// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/NFT.sol";
import "../src/NBCCollection.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract NFTCollection is Script {
    address collectionAdmin;
    address upgradeAddress;

    function setUp() public {
        collectionAdmin = vm.envAddress("ADMIN");
        upgradeAddress= vm.envAddress("UPGRADE_WALLET");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy nft implementation
        NFT nftImp = new NFT();
        NBCCollection collectionFactory = NBCCollection(address(new TransparentUpgradeableProxy(
            address(new NBCCollection()),
            upgradeAddress,
            abi.encodeWithSelector(
                NBCCollection.initialize.selector,
                vm.addr(deployerPrivateKey)
            )
        )));
        collectionFactory.setNFTImplementation(address(nftImp));
        collectionFactory.transferOwnership(collectionAdmin);

        vm.stopBroadcast();

        console.log("=== Deployment addresses ===");
        console.log("nftImp %s", address(nftImp));
        console.log("collectionFactory  %s", address(collectionFactory));
    }
}