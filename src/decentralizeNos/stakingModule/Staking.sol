// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {LinkedListLib} from "../libs/LinkedList.sol";
import {IL2OutputOracle} from "./IL2OutputOracle.sol";

contract StakingModule is OwnableUpgradeable, LinkedListLib {

    IL2OutputOracle private l2OutputOracle;
    uint public minStakeAmount;
    mapping(address => uint256) public stakedNotInTopList;

    // staking balance

    // @dev event section
    event UpdateNumbOfValidator(uint value);

    // @dev error section
    error InvalidStakingAmount();
    error InvalidNumbOfValidator();
    error InvalidInitValidatorData();
    error ValidatorValueMustNotZero();
    error DuplicatedValidator();
    error AmountNotSorted();
    error StakeAmountNotEqualMsgValue();

    function initialize(
        uint256 minStakeAmount_,
        uint maxValidator_,
        address[] calldata initValidators_,
        uint[] calldata amounts_
    ) payable external initializer {
        // the number of init validators must equal to stake amount data size
        // init data must not be empty
        // number of validators must not be greater than max configuration
        if (initValidators_.length != amounts_.length || initValidators_.length == 0 || initValidators_.length > maxValidator_) {
            revert InvalidInitValidatorData();
        }

        // add to stake list
        uint totalStaked;
        uint lastStakeAmount;
        for (uint i = 0; i < initValidators_.length; i++) {
            uint stakeAmount = amounts_[i];
            if (initValidators_[i] == address(0) || stakeAmount == 0) {
                revert ValidatorValueMustNotZero();
            }

            // init data must not be sorted
            if (lastStakeAmount < stakeAmount) {
                revert AmountNotSorted();
            }

            // check duplicate
            if (getIdByAddress(initValidators_[i]) != 0) {
                revert DuplicatedValidator();
            }

            // add to stake list
            addInitNode(initValidators_[i], stakeAmount);
            totalStaked += stakeAmount;
            lastStakeAmount = stakeAmount;
        }

        // total stake must equal msg.value
        if (totalStaked != msg.value) {
            revert StakeAmountNotEqualMsgValue();
        }

        // the total staked in data must equal to the msg.value
        __Ownable_init();
        MAX_VALIDATOR = uint16(maxValidator_);
        minStakeAmount = minStakeAmount_;
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the CToken
     * @dev User call function to stake their fund into staking pool
     * staking amount must > Y TC tokens
     * update user will be validator at the next chunk if reach condition
     * - stake amount in top N
     * - state root has 2/3 to re-update committee
     */
    function staking() payable external {
        // check if stake amount is greater than minimum
        if (msg.value < minStakeAmount) {
            revert InvalidStakingAmount();
        }

        // update stake amount
        uint256 stakeAmount = msg.value;
        address staker = msg.sender;
        if (stakedNotInTopList[staker] > 0) {
            stakeAmount += stakedNotInTopList[staker];
            stakedNotInTopList[staker] = 0;
        }
        (address removedAddr, uint256 removedAmount) = addNodeSorted(staker, stakeAmount);
        if (removedAddr != address(0)) {
            stakedNotInTopList[removedAddr] = removedAmount;
        }

        // determine last block request staked

        // determine
    }

    /**
     * @notice Validator withdraw their staked token
     * @dev
     */
    function unstaking(uint unstakeAmount_) payable external {

    }

    /**
     * @dev update contract address
     */
    function updateL2Output(address l2OutputOracle_) external onlyOwner {

    }

    /**
     * @dev update number of validators
     */
    function updateNumbOfValidators(uint numbOfValidators_) external onlyOwner {
        if (numbOfValidators_ == 0) {
            revert InvalidNumbOfValidator();
        }
        MAX_VALIDATOR = numbOfValidators_;

        emit UpdateNumbOfValidator(numbOfValidators_);
    }


    // @dev getter functions


    /**
     * @dev to query and get latest and next block height
     */
    function isValidatorAtHeight(address validator_, uint blockHeight_) external returns(bool) {
        return true;
    }

    /**
     * @dev list validator
     */
    function getValidators(uint blockHeight_) external returns(address[] memory) {
        return new address[](1);
    }

    /**
     * @dev to query balance validator staked
     */
    function getStakeBalance(address validator_) external returns(uint) {
         return 0;
    }

    /**
     * @dev to query and get latest and next block height
     * @return (unstake amount, claimable at time)
     */
    function getUnstakeInfo(address validator_) external returns(uint, uint) {
        return (0, 0);
    }
}
