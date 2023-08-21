// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SequencersBase} from "./SequencersBase.sol";
import {IL2OutputOracle} from "./helper/IL2OutputOracle.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";

contract Sequencer is SequencersBase {
    IL2OutputOracle public immutable l2OutputOracle;
    uint16 public quorum; // range 0 - 1e4

    struct VotingData {
        mapping(address => bool) voted;
        uint totalVote;
    }
    // tracking vote of state root
    mapping(bytes32 => VotingData) public votes;

    // error code
    error InvalidNextRoot();
    error NotSequencer();
    error SequencerVoted();
    error InvalidSignatures();
    error InvalidNewQuorum();

    // @notice event section
    event SubmittedVote(bytes32, bytes, uint);
    event NewQuorum(uint16, uint16);

    constructor(IL2OutputOracle l2OutputOracle_) {
        l2OutputOracle = l2OutputOracle_;

        // sanity check
        l2OutputOracle.nextBlockNumber();
    }

    function initialize(
        address[] calldata sequencers_,
        address admin_
    ) payable external initializer {
        __Sequencer_Init(
            sequencers_,
            admin_
        );

        // init with 2/3 quorum
        quorum = 6667;
    }

    // @notice cast vote and submit state root if reach quorum
    function submitStateRoot(
        bytes32 _l2Output,
        uint256 _l2BlockNumber,
        bytes32 _l1Blockhash,
        uint256 _l1BlockNumber,
        bytes calldata signatures
    ) external {
        if (_l2BlockNumber != l2OutputOracle.nextBlockNumber()) {
            revert InvalidNextRoot();
        }

        if (signatures.length == 0 || signatures.length % 65 != 0) {
            revert InvalidSignatures();
        }
        // create sign data from input params
        bytes32 signData = keccak256(abi.encode(address(this), block.chainid, _l2Output, _l2BlockNumber, _l1Blockhash, _l1BlockNumber));

        // loop through signature to verify signer and quorum reached
        for (uint i; i < signatures.length / 65; i++) {
            address recoverSequencer = ECDSAUpgradeable.recover(
                signData,
                signatures[i * 65: (i + 1) * 65]
            );

            // not current sequencer
            if (!isSequencer[recoverSequencer]) {
                revert NotSequencer();
            }

            // revert if this validator voted
            if (votes[signData].voted[recoverSequencer]) {
                revert SequencerVoted();
            }

            votes[signData].voted[recoverSequencer] = true;
            votes[signData].totalVote++;
        }

        // total vote > 2/3 sequencers
        if (votes[signData].totalVote >= (sequencers.length * quorum / 1e4)) {
            // quorum reached then trigger update state root
            l2OutputOracle.proposeL2Output(
                _l2Output,
                _l2BlockNumber,
                _l1Blockhash,
                _l1BlockNumber
            );
        }

        emit SubmittedVote(signData, signatures, votes[signData].totalVote);
    }

    // @notice update quorum value
    function updateQuorum(uint16 newQuorum_) external onlyOwner {
        if (newQuorum_ == 0 || newQuorum_ > 1e4) {
            revert InvalidNewQuorum();
        }

        emit NewQuorum(quorum, newQuorum_);
        quorum = newQuorum_;
    }

    // @notice check sequencer is voted or not
    function getVoted(bytes32 signData_, address sequencer_) external view returns(bool) {
        return votes[signData_].voted[sequencer_];
    }
}