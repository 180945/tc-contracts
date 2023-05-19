// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./claimGM.sol";

contract deployMultiClaim {
    function deployClaim(address[] memory owners) external {
        for (uint i = 0; i < owners.length; i++) {
            new claimGM(owners[i]);
        }
    }
}
