// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@tc/NumberMath.sol";

/// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
/// @dev The `msg.value` should not be trusted for any method callable from multicall.
/// @param previousBlockhash The expected parent blockHash
/// @param data The encoded function data for each of the calls to make to this contract
/// @return results The results from each of the calls passed in via data
// function multicall(bytes32 previousBlockhash, bytes[] calldata data)
// external
// payable
// returns (bytes[] memory results);
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

interface IKey {
    function getBuyPriceAfterFeeV2(
        uint256 amountX18
    ) external view returns (uint256);

    function getProtocolFeeRatio() external view returns (uint24);

    function getPlayerFeeRatio() external view returns (uint24);
}

// key factory interface
interface IKeyFactory {
    function buyKeysForV2ByToken(
        address token,
        uint256 amountX18,
        uint256 buyPriceAfterFeeMax,
        address recipient
    ) external;

    function buyKeysV2ByToken(
        address token,
        uint256 amountX18,
        uint256 buyPriceAfterFeeMax
    ) external;

    function sellKeysForV2ByToken(
        address token,
        uint256 amountX18,
        uint256 sellPriceAfterFeeMin,
        address recipient
    ) external;

    function sellKeysV2ByToken(
        address token,
        uint256 amountX18,
        uint256 sellPriceAfterFeeMin
    ) external;
}

// dev swap v3 interface router
interface ISwapRouter2 {
    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
    function WETH9() external returns(address);
}

contract Router {
    using SafeERC20 for IERC20;
    using NumberMath for uint256;

    IKeyFactory public immutable keyFactory;
    ISwapRouter2 public immutable swapRouter;

    constructor(IKeyFactory keyFactory_, ISwapRouter2 swapRouter_) {
        keyFactory = keyFactory_;
        swapRouter = swapRouter_;
    }

    // swap from key to token
    // example: Key -> eth (key -> btc -> eth)
    function keyToToken(ExactInputSingleParams memory params, IERC20 key, uint amount, uint sellPriceAfterFeeMin) external {
        // transfer key to this account
        key.safeTransferFrom(msg.sender, address(this), amount);

        // sell key to btc
        keyFactory.sellKeysV2ByToken(
            address(key),
            amount,
            sellPriceAfterFeeMin
        );

        // swap token source to dest token
        params.amountIn = IERC20(params.tokenIn).balanceOf(address(this));
        params.recipient = msg.sender;

        // do swap
        IERC20(params.tokenIn).approve(address(swapRouter), params.amountIn);
        swapRouter.exactInputSingle(params);
    }

    // swap from token to key
    // example;  Eth -> key (eth -> btc -> key)
    function tokenToKey(ExactInputSingleParams memory params, IKey key) external {
        // transfer source token to this account
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        // set recipient to this account
        params.recipient = address(this);

        // exp: swap eth to btc
        IERC20(params.tokenIn).approve(address(swapRouter), params.amountIn);
        swapRouter.exactInputSingle(params);

        // get amount of key
        uint256 buyPriceBAfterFeeMax = IERC20(params.tokenOut).balanceOf(address(this));
        uint24 protocolFeeRatioA = key.getProtocolFeeRatio();
        uint24 playerFeeRatioA = key.getPlayerFeeRatio();
        uint256 amountA = NumberMath.getBuyAmountMaxWithCash(
            protocolFeeRatioA,
            playerFeeRatioA,
            address(key),
            buyPriceBAfterFeeMax
        );

        // buy key
        IERC20(params.tokenOut).approve(address(keyFactory), buyPriceBAfterFeeMax);
        keyFactory.buyKeysForV2ByToken(
            address(key),
            amountA,
            buyPriceBAfterFeeMax,
            msg.sender
        );

        // transfer back to user account
        uint leftBalance = IERC20(params.tokenOut).balanceOf(address(this));
        if (leftBalance > 0) {
            IERC20(params.tokenOut).safeTransfer(msg.sender, leftBalance);
        }
    }
}
