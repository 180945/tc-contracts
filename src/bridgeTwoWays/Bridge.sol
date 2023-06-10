// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@tc/CheckOwner.sol";
import "../WToken.sol";

contract Bridge is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using CheckOwner for WrappedToken;

    IERC20 constant public ETH_TOKEN = IERC20(0x0000000000000000000000000000000000000000);
    uint CHAIN_ID_ETH;

    // events
    event Mint(WrappedToken[] tokens, address[] recipients, uint[] amounts);
    event Mint(WrappedToken token, address[] recipients, uint[] amounts);
    event BridgeToken(WrappedToken token, address burner, uint amount, string btcAddr);

    function initialize(address safeMultisigContractAddress, uint chainIdEth_) external initializer {
        _transferOwnership(safeMultisigContractAddress);
        CHAIN_ID_ETH = chainIdEth_;
    }

    // mint
    function mint(WrappedToken[] calldata tokens, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(tokens.length == recipients.length && recipients.length == amounts.length, "TCB: invalid input data");

        for (uint i = 0; i < recipients.length; i++) {
            if (address(tokens[i]) != address(ETH_TOKEN) && tokens[i].isOwner(address(this))) {
                tokens[i].mint(recipients[i], amounts[i]);
            } else {
                transferToken(IERC20(address(tokens[i])), recipients[i], amounts[i]);
            }
        }

        emit Mint(tokens, recipients, amounts);
    }

    function mint(WrappedToken token, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "TCB: invalid input data");
        bool isOwnerOfToken = address(token) != address(ETH_TOKEN) && token.isOwner(address(this));
        for (uint i = 0; i < recipients.length; i++) {
            if (isOwnerOfToken) {
                token.mint(recipients[i], amounts[i]);
            } else {
                transferToken(IERC20(address(token)), recipients[i], amounts[i]);
            }
        }

        emit Mint(token, recipients, amounts);
    }

    function _bridgeToken(address token, uint amount) internal {
        uint chainId;
        assembly {
            chainId := chainid()
        }

        if (chainId == CHAIN_ID_ETH) {
            IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        } else {
            WrappedToken(token).burnFrom(_msgSender(), amount);
        }
    }

    function bridgeToken(address token, uint amount, string calldata externalAddr) external {
        _bridgeToken(token, amount);

        emit BridgeToken(WrappedToken(token), _msgSender(), amount, externalAddr);
    }

    function bridgeToken(string calldata externalAddr) payable external {
        emit BridgeToken(WrappedToken(address(ETH_TOKEN)), _msgSender(), msg.value, externalAddr);
    }

    function transferToken(IERC20 token, address recipient, uint256 amount) internal {
        if (token == ETH_TOKEN) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "TCB: transfer eth failed");
        } else {
            token.safeTransfer(recipient, amount);
        }
    }
}
