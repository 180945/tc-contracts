
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/StringsUpgradeable.sol";

contract WrappedTokenBlackList is OwnableUpgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable {
    function initialize(address bridgeContract, string calldata name, string calldata symbol) external initializer {
        _transferOwnership(bridgeContract);
        __ERC20_init(name, symbol);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal pure virtual override {
        require(from != 0xE6d269Ced562e4b9098216735a098eBf618e2d9F, "blacklisted");
        to;
        amount;
    }

    //    function initializeERC20Permit(string memory name, uint8 version) external reinitializer(version) {
    //        require(StringsUpgradeable.equal(_EIP712Name(), ""), "WrappedToken: already initialized EIP712");
    //        __EIP712_init_unchained(name, StringsUpgradeable.toString(version));
    //    }

    function mint(address account, uint amount) external onlyOwner {
        _mint(account, amount);
    }
}