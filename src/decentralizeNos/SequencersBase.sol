// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract SequencersBase is OwnableUpgradeable {
    mapping(address => bool) public isSequencer;
    address[] public sequencers;

    event AddSequencer(address);
    event RemoveSequencer(address);

    function __Sequencer_Init(
        address[] calldata sequencers_,
        address admin_
    ) internal onlyInitializing {
        require(sequencers_.length > 0, "SL: invalid init value");

        for(uint i = 0; i < sequencers_.length; i++) {
            require(!isSequencer[sequencers_[i]], "SL: duplicated");
            require(sequencers_[i] != address(0), "SL: invalid sequencer");

            isSequencer[sequencers_[i]] = true;
        }

        _transferOwnership(admin_);
        sequencers = sequencers_;
    }

    function addSequencer_(address sequencer_) internal {
        require(!isSequencer[sequencer_], "SL: already added");
        require(sequencer_ != address(0), "SL: invalid sequencer");

        isSequencer[sequencer_] = true;
        sequencers.push(sequencer_);

        emit AddSequencer(sequencer_);
    }

    function addSequencer(address sequencer_) external onlyOwner {
        addSequencer_(sequencer_);
    }

    function removeSequencer_(address sequencer_) internal {
        require(isSequencer[sequencer_], "SL: not exist");

        isSequencer[sequencer_] = false;
        for (uint i; i < sequencers.length; i++) {
            if (sequencers[i] == sequencer_) {
                sequencers[i] = sequencers[sequencers.length - 1];
                sequencers.pop();
                break;
            }
        }

        emit RemoveSequencer(sequencer_);
    }

    function removeSequencer(address sequencer_) external onlyOwner {
        removeSequencer_(sequencer_);
    }

    function newSequencers(address[] calldata sequencers_) external onlyOwner {
        // remove current
        while(sequencers.length != 0) {
            removeSequencer_(sequencers[0]);
        }

        // add new
        for (uint i; i < sequencers_.length; i++) {
            addSequencer_(sequencers_[i]);
        }
    }

    function getSequencers() external view returns(address[] memory) {
        return sequencers;
    }
}
