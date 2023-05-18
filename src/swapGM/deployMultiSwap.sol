// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./swapGM.sol";

contract deployMultiSwap {
    function deploySwap(address[] memory owners) external {
        address[] memory createdAddress = new address[](owners.length);
        for (uint i = 0; i < owners.length; i++) {
            new swapGM(owners[i]);
        }
    }
}
