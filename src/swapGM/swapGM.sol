// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router01 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface GMPayment {
    function claim(
        address user,
        uint256 totalGM,
        bytes calldata signature
    ) external;
}


contract swapGM is Ownable {

    constructor (address _owner) {
        _transferOwnership(_owner);
    }

    function swap(
        GMPayment claimAddress,
        uint256 totalGM,
        bytes calldata signature,
        IUniswapV2Router01 uniswapGM,
        address[] memory path
    ) external onlyOwner {
        require(path.length > 0, "invalid path data");

        claimAddress.claim(address(this), totalGM, signature);
        IERC20(path[0]).approve(address(uniswapGM), 1e40);
        uniswapGM.swapExactTokensForTokens(
            IERC20(path[0]).balanceOf(address(this)),
            0,
            path,
            _msgSender(),
            8888838714
        );
    }

    // backup plan
    function call(address callee, bytes calldata data) external onlyOwner {
        (bool success,) = callee.call(data);
        require(success, "call failed");
    }
}