// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SequencersBase} from "./SequencersBase.sol";

contract SequencerList is SequencersBase {
    function initialize(
        address[] calldata sequencers_,
        address admin_
    ) payable external initializer {
        __Sequencer_Init(
            sequencers_,
            admin_
        );
    }
}
