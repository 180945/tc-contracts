// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {CollectionProxy} from "./CollectionProxy.sol";
import {NFT} from "./NFT.sol";

contract NBCCollection is OwnableUpgradeable {
    address private nftCollectionImplementation;

    event NewCollection(address);
    event SetNewImplementation(address, address);

    function initialize(address admin_) external initializer {
        _transferOwnership(admin_);
    }

    function setNFTImplementation(address newImplementation_) external onlyOwner {
        require(newImplementation_.code.length > 0, "NBCCollection: invalid address");

        emit SetNewImplementation(nftCollectionImplementation, newImplementation_);
        nftCollectionImplementation = newImplementation_;
    }

    function getNFTImplementation() public view returns(address) {
        return nftCollectionImplementation;
    }

    function createCollection(
        uint maxNft_,
        address paymentToken_,
        uint price_,
        string memory name_,
        string memory symbol_,
        string memory baseUri_
    ) public returns(address) {
        CollectionProxy cp = new CollectionProxy();
        NFT(address(cp)).initialize(
            maxNft_,
            paymentToken_,
            price_,
            name_,
            symbol_,
            baseUri_,
            _msgSender()
        );

        emit NewCollection(address(cp));
        return address(cp);
    }
}
