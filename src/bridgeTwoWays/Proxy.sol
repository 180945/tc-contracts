// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface BridgeL2 {
    function bridgeToken(address token, uint amount, string calldata externalAddr) external;
    function bridgeToken(string calldata externalAddr) payable external;
}

contract ProxyBridge {
    address constant public ETH_TOKEN = 0x0000000000000000000000000000000000000000;
    address immutable bridgeL1;
    BridgeL2 immutable bridgeL2;

    constructor(address bridgeL1_, address bridgeL2_) {
        bridgeL1 = bridgeL1_;
        bridgeL2 = BridgeL2(bridgeL2_);
    }

    // withdraw from L1 and bridge to L2
    function bridgeL1ToL2(
        bytes calldata bridge1Data,
        address[] calldata tokens,
        uint256[] calldata amounts,
        string[] calldata recipients
    ) external {
        require(tokens.length == amounts.length && recipients.length == amounts.length, "Bridge: invalid input data");

        // process withdraw from L1
        (bool success, ) = bridgeL1.call(bridge1Data);
        require(success, "Bridge: L1 executed failed");

        // process L2 data
        for (uint256 i = 0; i < tokens.length; i++) {
            if (ETH_TOKEN == tokens[i]) {
                bridgeL2.bridgeToken{value: amounts[i]}(recipients[i]);
            } else {
                if (IERC20(tokens[i]).allowance(address(this), address(bridgeL2)) < amounts[i]) {
                    IERC20(tokens[i]).approve(address(bridgeL2), type(uint256).max);
                }
                bridgeL2.bridgeToken(tokens[i], amounts[i], recipients[i]);
            }
        }
    }

    receive() external payable {}
}
