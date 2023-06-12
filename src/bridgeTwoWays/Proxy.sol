// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBridgeL2 {
    function bridgeToken(address token, uint amount, string calldata externalAddr, uint destChainId) external;
    function bridgeToken(string calldata externalAddr, uint destChainId) payable external;
}

interface IBridgeL1 {
    function deposit(address externalAddr) payable external;
    function deposit(address token, uint amount, address externalAddr) external;
}

contract ProxyBridge {
    address constant public ETH_TOKEN = 0x0000000000000000000000000000000000000000;
    address immutable  safeL1;
    IBridgeL1 immutable bridgeL1;

    address immutable  safeL2;
    IBridgeL2 immutable bridgeL2;
    uint immutable chainIdL2;

    constructor(
        address safeL1_,
        address bridgeL1_,
        address safeL2_,
        address bridgeL2_,
        uint chainIdL2_
    ) {
        safeL1 = safeL1_;
        bridgeL1 = IBridgeL1(bridgeL1_);
        safeL2 = safeL2_;
        bridgeL2 = IBridgeL2(bridgeL2_);
        chainIdL2 = chainIdL2_;
    }

    // withdraw from L1 and bridge to L2
    function bridgeL1ToL2(
        bytes calldata bridge1CallData,
        address[] calldata tokens,
        uint256[] calldata amounts,
        string[] calldata recipients
    ) external {
        require(tokens.length == amounts.length && recipients.length == amounts.length, "Bridge: invalid input data");

        // process withdraw from L1
        (bool success, ) = safeL1.call(bridge1CallData);
        require(success, "Bridge: L1 executed failed");

        // process L2 data
        for (uint256 i = 0; i < tokens.length; i++) {
            if (ETH_TOKEN == tokens[i]) {
                bridgeL2.bridgeToken{value: amounts[i]}(recipients[i], chainIdL2);
            } else {
                if (IERC20(tokens[i]).allowance(address(this), address(bridgeL2)) < amounts[i]) {
                    IERC20(tokens[i]).approve(address(bridgeL2), type(uint256).max);
                }
                bridgeL2.bridgeToken(tokens[i], amounts[i], recipients[i], chainIdL2);
            }
        }
    }

    // withdraw from L2 and bridge to L1
    function bridgeL2ToL1(
        bytes calldata bridge2CallData,
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata recipients
    ) external {
        require(tokens.length == amounts.length && recipients.length == amounts.length, "Bridge: invalid input data");

        // process withdraw from L1
        (bool success, ) = safeL2.call(bridge2CallData);
        require(success, "Bridge: L2 executed failed");

        // process L2 data
        for (uint256 i = 0; i < tokens.length; i++) {
            if (ETH_TOKEN == tokens[i]) {
                bridgeL1.deposit{value: amounts[i]}(recipients[i]);
            } else {
                if (IERC20(tokens[i]).allowance(address(this), address(bridgeL1)) < amounts[i]) {
                    IERC20(tokens[i]).approve(address(bridgeL1), type(uint256).max);
                }
                bridgeL1.deposit(tokens[i], amounts[i], recipients[i]);
            }
        }
    }

    receive() external payable {}
}
