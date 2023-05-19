// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface GMPayment {
    function claim(
        address user,
        uint256 totalGM,
        bytes calldata signature
    ) external;
}


contract claimGM is Ownable {

    constructor (address _owner) {
        _transferOwnership(_owner);
    }

    function claim(
        GMPayment claimAddress,
        uint256 totalGM,
        bytes calldata signature,
        IERC20 gm
    ) external onlyOwner {
        claimAddress.claim(address(this), totalGM, signature);
        gm.transfer(_msgSender(), gm.balanceOf(address(this)));
    }

    // backup plan
    function call(address callee, bytes calldata data) external onlyOwner {
        (bool success,) = callee.call(data);
        require(success, "call failed");
    }
}