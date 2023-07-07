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
    // define which token to burn and which one to lock (origin chain)
    mapping(address => bool) public burnableToken;
    address public operator;

    // events
    event Mint(WrappedToken[] tokens, address[] recipients, uint[] amounts);
    event Mint(WrappedToken token, address[] recipients, uint[] amounts);
    event BridgeToken(WrappedToken token, address burner, uint amount, string extddr, uint destChainId);

    function initialize(address safeMultisigContractAddress, address operator_, address[] calldata tokens) external initializer {
        require(safeMultisigContractAddress != address(0) && operator_ != address(0), "Bridge: invalid address");

        _transferOwnership(safeMultisigContractAddress);
        operator = operator_;
        for (uint i = 0; i < tokens.length; i++) {
            burnableToken[tokens[i]] = true;
        }
    }

    // mint
    function mint(WrappedToken[] calldata tokens, address[] calldata recipients, uint[] calldata amounts) external onlyOwner {
        require(tokens.length == recipients.length && recipients.length == amounts.length, "Bridge: invalid input data");

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
        require(recipients.length == amounts.length, "Bridge: invalid input data");
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
        if (!burnableToken[token]) {
            IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        } else {
            WrappedToken(token).burnFrom(_msgSender(), amount);
        }
    }

    function bridgeToken(address token, uint amount, string calldata externalAddr, uint destChainId) external {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        require(chainId != destChainId, "Bridge: invalid dest chain id");
        _bridgeToken(token, amount);

        emit BridgeToken(WrappedToken(token), _msgSender(), amount, externalAddr, destChainId);
    }

    function bridgeToken(string calldata externalAddr, uint destChainId) payable external {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        require(chainId != destChainId, "Bridge: invalid dest chain id");
        emit BridgeToken(WrappedToken(address(ETH_TOKEN)), _msgSender(), msg.value, externalAddr, destChainId);
    }

    function transferToken(IERC20 token, address recipient, uint256 amount) internal {
        if (token == ETH_TOKEN) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "Bridge: transfer eth failed");
        } else {
            token.safeTransfer(recipient, amount);
        }
    }

    function updateToken(address[] calldata tokens, bool[] calldata isBurns) external {
        require(_msgSender() == operator, "Bridge: unauthorised");
        require(tokens.length == isBurns.length, "Bridge: mismatch data length");

        for (uint i = 0; i < tokens.length; i++) {
            burnableToken[tokens[i]] = isBurns[i];
        }
    }

    function transferOperator(address operator_) external {
        require(_msgSender() == operator, "Bridge: unauthorised");

        operator = operator_;
    }
}
