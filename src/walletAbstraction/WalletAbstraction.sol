// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract WalletAbstraction is EIP712Upgradeable, OwnableUpgradeable {
    using Counters for Counters.Counter;

    /**
     * @dev Guard variable for re-entrancy checks
     */
    bool internal _notEntered;

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

    bytes32 public EXECUTE_HASH = keccak256("execute");

    // @notice this balance can  do anything with it
    mapping(address => uint) public balance1;
    // @notice this one only used in whitelist contract
    mapping(address => uint) public balance2;
    // @notice this map tracking which contract used to
    mapping(address => bool) public whitelist;
    // @notice updated once user execute transaction successfully
    mapping(address => Counters.Counter) private _nonces;

    // EVENTS
    event WhiteList(address,bool);
    event Deposit(address,uint,uint);

    function initialize(address admin_) public initializer {
        __EIP712_init("abstraction", "0.1.0");
        _transferOwnership(admin_);
        _notEntered = true;
    }

    /**
     * @dev Deposit TC to the contract.
     */
    function deposit(address recipient_, uint balance1_, uint balance2_) external payable {
        require(balance1_ + balance2_ == msg.value, "Abstraction: value not match");
        balance1[recipient_] += balance1_;
        balance2[recipient_] += balance2_;

        emit Deposit(recipient_, balance1_, balance2_);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`.
     */
    function execute(
        address executor,
        uint256 nonce,
        uint256 expiry,
        bytes calldata data,
        uint256 value,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) payable public nonReentrant {
        require(block.timestamp <= expiry, "Abstraction: signature expired");
        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(EXECUTE_HASH, executor, nonce, expiry, data, value))),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "Abstraction: invalid nonce");

        // todo: uncomment validation
        // (address senderParam) = abi.decode(data, (address));
        // require(senderParam == signer, "Abstraction: mismatch sender signer");

        // execute

    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    /**
     * @dev Add/Remove whitelist contract.
     */
    function whitelistContract(address contract_, bool isWhitelist_) external onlyOwner {
        require(whitelist[contract_] != isWhitelist_, "WA: invalid input data");
        whitelist[contract_] = isWhitelist_;

        emit WhiteList(contract_, isWhitelist_);
    }
}
