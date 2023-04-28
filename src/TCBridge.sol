// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./WToken.sol";

contract TCBridge is OwnableUpgradeable {

    // events
    event Mint(WrappedToken[] tokens, address[] recipients, uint[] amounts);
    event Mint(WrappedToken token, address[] recipients, uint[] amounts);
    event Burn(WrappedToken token, address burner, uint amount, string btcAddr);

    function initialize(address safeMultisigContractAddress) external initializer {
        _transferOwnership(safeMultisigContractAddress);
    }

    // mint
    function mint(WrappedToken[] calldata tokens, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(tokens.length == recipients.length && recipients.length == amounts.length, "TCB: invalid input data");

        for (uint i = 0; i < recipients.length; i++) {
            tokens[i].mint(recipients[i], amounts[i]);
        }

        emit Mint(tokens, recipients, amounts);
    }

    function mint(WrappedToken token, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "TCB: invalid input data");

        for (uint i = 0; i < recipients.length; i++) {
            token.mint(recipients[i], amounts[i]);
        }

        emit Mint(token, recipients, amounts);
    }

    function burn(WrappedToken token, uint amount, string calldata externalAddr) external {
        token.burnFrom(_msgSender(), amount);

        emit Burn(token, _msgSender(), amount, externalAddr);
    }
}
