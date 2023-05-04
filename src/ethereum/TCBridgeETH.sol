// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TCBridgeETH is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 constant public ETH_TOKEN = IERC20(0x0000000000000000000000000000000000000000);

    // events
    event Withdraw(IERC20[] tokens, address[] recipients, uint[] amounts);
    event Withdraw(IERC20 token, address[] recipients, uint[] amounts);
    event Deposit(IERC20 token, address sender, uint amount, address recipient);

    function initialize(address safeMultisigContractAddress) external initializer {
        _transferOwnership(safeMultisigContractAddress);
    }

    // mint
    function withdraw(IERC20[] calldata tokens, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(tokens.length == recipients.length && recipients.length == amounts.length, "TCB: invalid input data");

        for (uint i = 0; i < recipients.length; i++) {
            transferToken(tokens[i], recipients[i], amounts[i]);
        }

        emit Withdraw(tokens, recipients, amounts);
    }

    function withdraw(IERC20 token, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "TCB: invalid input data");

        for (uint i = 0; i < recipients.length; i++) {
            transferToken(token, recipients[i], amounts[i]);
        }

        emit Withdraw(token, recipients, amounts);
    }

    function deposit(address externalAddr) external payable {
        emit Deposit(ETH_TOKEN, _msgSender(), msg.value, externalAddr);
    }

    function deposit(IERC20 token, uint amount, address externalAddr) external {
        token.safeTransferFrom(_msgSender(), address(this), amount);

        emit Deposit(token, _msgSender(), amount, externalAddr);
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
