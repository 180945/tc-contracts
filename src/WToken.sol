// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract WrappedToken is OwnableUpgradeable, ERC20BurnableUpgradeable {

    function initialize(address bridgeContract) external initializer {
        _transferOwnership(bridgeContract);
    }

    function mint(address account, uint amount) external onlyOwner {
        _mint(account, amount);
    }
}
