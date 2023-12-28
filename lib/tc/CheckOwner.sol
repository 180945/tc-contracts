// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../src/WToken.sol";

library CheckOwner {
    function isOwner(WrappedToken token, address owner) view internal returns(bool) {
        (bool success, bytes memory returndatas) = address(token).staticcall(abi.encodeWithSelector(OwnableUpgradeable.owner.selector));
        if (!success || returndatas.length == 0) {
            return false;
        }

        return abi.decode(returndatas, (address)) == owner;
    }
}
