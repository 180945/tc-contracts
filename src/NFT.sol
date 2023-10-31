// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC721Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFT is OwnableUpgradeable, ERC721Upgradeable {
    using SafeERC20 for IERC20;

    /// @dev Current supply
    uint public currentSupply;

    /// @dev Define max nft can be minted
    uint public maxTotalSupply;

    /// @dev Floor price to mint NFT
    uint public unitPrice;

    /// @dev Token to pay for NFT
    address public paymentToken;

    /// @dev baseUri
    string private _baseUri;

    function initialize(
        uint maxNft_,
        address paymentToken_,
        uint price_,
        string memory name_,
        string memory symbol_,
        string memory baseUri_,
        address owner_
    ) external initializer {
        require(maxNft_ > 0, "maxTotalSupply must be greater than 0");

        maxTotalSupply = maxNft_;
        unitPrice = price_;
        paymentToken = paymentToken_;
        __ERC721_init_unchained(name_, symbol_);
        _baseUri = baseUri_;
        _transferOwnership(owner_);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    function mint(uint amount) external payable {
        require(amount > 0 && amount + currentSupply <= maxTotalSupply, "invalid amount");
        uint paymentAmount = unitPrice * amount;
        if (paymentAmount > 0) {
            if (paymentToken == address(0)) {
                require(paymentAmount == msg.value, "invalid native token amount");
                (bool success,) = owner().call{value: paymentAmount}("");
                require(success, "payment request failed");
            } else {
                IERC20(paymentToken).safeTransferFrom(_msgSender(), owner(), paymentAmount);
            }
        }

        for (uint i = 0; i < amount; i++) {
            _mint(msg.sender, ++currentSupply);
        }
    }
}
