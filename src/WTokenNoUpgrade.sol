
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WrappedToken is Ownable, ERC20Burnable, ERC20Permit {
    constructor(address bridgeContract, string memory name, string memory symbol, uint initSupply) ERC20(name, symbol) ERC20Permit(name) {
        _transferOwnership(bridgeContract);
        if (initSupply > 0) {
            _mint(_msgSender(), initSupply);
        }
    }

    function mint(address account, uint amount) external onlyOwner {
        _mint(account, amount);
    }
}