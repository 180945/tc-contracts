// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Bridge.sol";

contract BridgeL2 is Bridge {
    event BridgeTokenToETH(WrappedToken token, address burner, uint amount, string btcAddr);

    function bridgeTokenToETH(address token, uint amount, string calldata externalAddr) external {
        _bridgeToken(token, amount);

        emit BridgeTokenToETH(WrappedToken(token), _msgSender(), amount, externalAddr);
    }

    function bridgeTokenToETH(string calldata externalAddr) payable external {
        emit BridgeTokenToETH(WrappedToken(address(ETH_TOKEN)), _msgSender(), msg.value, externalAddr);
    }

}
