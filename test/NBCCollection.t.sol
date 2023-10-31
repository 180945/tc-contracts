// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WToken.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/NFT.sol";
import "../src/NBCCollection.sol";

contract NBCCollection_Test is Test {
    address public constant ADMIN_ADDR = address(10);
    WrappedToken public wbtc;
    NBCCollection collectionFactory;

    address constant USER_1 = address(11);
    address constant USER_2 = address(12);
    address constant USER_3 = address(13);

    function setUp() public {
        // deploy wbtc token
        wbtc = new WrappedToken();
        wbtc.initialize(ADMIN_ADDR, "wbtc", "wbtc");

        // deploy nft implementation
        NFT nftImp = new NFT();
        collectionFactory = new NBCCollection();
        collectionFactory.initialize(ADMIN_ADDR);

        vm.prank(ADMIN_ADDR);
        collectionFactory.setNFTImplementation(address(nftImp));
    }

    function testMintNFT() public {
        // create nft pay by native token
        vm.startPrank(USER_1);
        NFT newNftToken = NFT(collectionFactory.createCollection(
            10,
            address(0),
            1e18,
            'NFT',
            'NFT',
            'https://testcollection/'
        ));
        vm.stopPrank();

        // create nft pay by token
        vm.startPrank(USER_2);
        NFT newNftToken2 = NFT(collectionFactory.createCollection(
            10,
            address(wbtc),
            1e18,
            'NFT',
            'NFT',
            'https://testcollection/'
        ));
        vm.stopPrank();
        vm.deal(USER_2, 10 ether);

        vm.prank(ADMIN_ADDR);
        wbtc.mint(USER_1, 10e18);

        // test mint
        vm.startPrank(USER_1);
        wbtc.approve(address(newNftToken2), 10 ether);
        newNftToken2.mint(2);
        assertEq(wbtc.balanceOf(USER_1), 8 ether);
        assertEq(newNftToken2.ownerOf(1), USER_1);
        assertEq(newNftToken2.ownerOf(2), USER_1);
        assertEq(newNftToken2.tokenURI(1), 'https://testcollection/1');
        vm.stopPrank();

        vm.startPrank(USER_2);
        newNftToken.mint{value: 3 ether}(11);
        assertEq(USER_2.balance, 7 ether);
        assertEq(newNftToken.ownerOf(1), USER_2);
        assertEq(newNftToken.ownerOf(2), USER_2);
        assertEq(newNftToken.tokenURI(1), 'https://testcollection/1');
        vm.stopPrank();
    }
}
