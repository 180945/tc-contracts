// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@tc/NumberMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/Path.sol";

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
}

struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct ExactOutputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
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

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    function WETH9() external returns(address);
}

contract Router {
    using SafeERC20 for IERC20;
    using NumberMath for uint256;
    using Path for bytes;

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

        // balance before
        uint tokenInBalance = IERC20(params.tokenIn).balanceOf(msg.sender);

        // sell key to btc
        keyFactory.sellKeysForV2ByToken(
            address(key),
            amount,
            sellPriceAfterFeeMin,
            msg.sender
        );

        // swap token source to dest token
        params.amountIn = IERC20(params.tokenIn).balanceOf(msg.sender) - tokenInBalance;
        params.recipient = msg.sender;

        // transfer source token to this account
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

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

    // swap from token to exact key
    // example;  Eth -> key (eth -> btc -> key)
    function tokenToExactKey(ExactOutputSingleParams memory params, IKey key, uint keyExactAmount) external {
        // transfer source token to this account
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountInMaximum);

        // get buy price after fee v2
        params.amountOut = key.getBuyPriceAfterFeeV2(keyExactAmount);

        // set recipient to this account
        params.recipient = address(this);

        // exp: swap eth to btc
        IERC20(params.tokenIn).approve(address(swapRouter), params.amountInMaximum);
        swapRouter.exactOutputSingle(params);

        // buy key
        IERC20(params.tokenOut).approve(address(keyFactory), params.amountOut);
        keyFactory.buyKeysForV2ByToken(
            address(key),
            keyExactAmount,
            params.amountOut,
            msg.sender
        );

        // transfer back to user account
        uint leftBalance = IERC20(params.tokenIn).balanceOf(address(this));
        if (leftBalance > 0) {
            IERC20(params.tokenIn).safeTransfer(msg.sender, leftBalance);
        }
    }

    // @dev swap cross pairs
    function keyToTokenCrossPair(ExactInputParams memory params, IERC20 key, uint amount, uint sellPriceAfterFeeMin) external {
        // transfer key to this account
        key.safeTransferFrom(msg.sender, address(this), amount);

        (address tokenIn,,) = params.path.decodeFirstPool();

        // balance before
        uint tokenInBalance = IERC20(tokenIn).balanceOf(msg.sender);

        // sell key to btc
        keyFactory.sellKeysForV2ByToken(
            address(key),
            amount,
            sellPriceAfterFeeMin,
            msg.sender
        );

        // swap token source to dest token
        params.amountIn = IERC20(tokenIn).balanceOf(msg.sender) - tokenInBalance;
        params.recipient = msg.sender;

        // transfer source token to this account
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        // do swap
        IERC20(tokenIn).approve(address(swapRouter), params.amountIn);
        swapRouter.exactInput(params);
    }

    function tokenToExactKeyCrossPair(ExactOutputParams memory params, IKey key, uint keyExactAmount) external {
        (address tokenIn,,) = params.path.decodeFirstPool();
        address tokenOut;
        bytes memory tempPath = params.path;
        while (true) {
            bool hasMultiplePools = tempPath.hasMultiplePools();
            // decide whether to continue or terminate
            if (hasMultiplePools) {
                tempPath = tempPath.skipToken();
            } else {
                (,tokenOut,) = tempPath.decodeFirstPool();
                break;
            }
        }

        // transfer source token to this account
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), params.amountInMaximum);

        // get buy price after fee v2
        params.amountOut = key.getBuyPriceAfterFeeV2(keyExactAmount);

        // set recipient to this account
        params.recipient = address(this);

        // exp: swap eth to btc
        IERC20(tokenIn).approve(address(swapRouter), params.amountInMaximum);
        swapRouter.exactOutput(params);

        // buy key
        IERC20(tokenOut).approve(address(keyFactory), params.amountOut);
        keyFactory.buyKeysForV2ByToken(
            address(key),
            keyExactAmount,
            params.amountOut,
            msg.sender
        );

        // transfer back to user account
        uint leftBalance = IERC20(tokenIn).balanceOf(address(this));
        if (leftBalance > 0) {
            IERC20(tokenIn).safeTransfer(msg.sender, leftBalance);
        }
    }
}
