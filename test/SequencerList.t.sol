// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SequencerList} from "../src/decentralizeNos/SequencerList.sol";
import {Sequencer, IL2OutputOracle} from "../src/decentralizeNos/Sequencer.sol";

contract L2OutputOracleMock {
    /**
     * @notice The interval in L2 blocks at which checkpoints must be submitted. Although this is
     *         immutable, it can safely be modified by upgrading the implementation contract.
     */
    uint256 public immutable SUBMISSION_INTERVAL;
    uint public latestL2BlockHeight = 10; // init at block height 10

    constructor(uint submissionInterval_) {
        SUBMISSION_INTERVAL = submissionInterval_;
    }

    function proposeL2Output(
        bytes32 _l2Output,
        uint256 _l2BlockNumber,
        bytes32 _l1Blockhash,
        uint256 _l1BlockNumber
    ) external {
        require(
            _l2BlockNumber == nextBlockNumber(),
            "L2OutputOracle: block number must be equal to next expected block number"
        );
        _l2Output;
        _l1Blockhash;
        _l1BlockNumber;

        latestL2BlockHeight =  _l2BlockNumber;
    }

    function nextBlockNumber() public view returns (uint256) {
        return  latestL2BlockHeight + SUBMISSION_INTERVAL;
    }
}

contract SequencerListTest is Test {
    address public constant UPGRADE_ADDR = address(9);
    address public constant ADMIN_ADDR = address(10);
    SequencerList public sequenceContract;
    address constant USER_1 = address(11);
    address constant USER_2 = address(12);
    address constant USER_3 = address(13);
    // init list sequencer
    address o1 = address(0x9699b31b25D71BDA4819bBe66244E9130cEE62b7);
    uint256 prv1 = uint256(0x1193a43543fc11e37daa1a026ae8fae69d84c5dd1f3f933047ff2588778c5cca);

    address o2 = address(0x54b3DBA467C9Dbb916EF4D6AedaFa19C4Fef8258);
    uint256 prv2 = uint256(0x15681448451d0a925d17408e6c3f33a3e1b5a60b89ab5096c2381a37ab58e234);

    address o3 = address(0xD7d93b7fa42b60b6076f3017fCA99b69257A912D);
    uint256 prv3 = uint256(0xaad53b70ad9ed01b75238533dd6b395f4d300427da0165aafbd42ea7a606601f);

    function setUp() public {
        address[] memory sequencers = new address[](3);
        sequencers[0] = USER_1;
        sequencers[1] = USER_2;
        sequencers[2] = USER_3;

        sequenceContract = SequencerList(payable(address(new TransparentUpgradeableProxy(
            address(new SequencerList()),
            UPGRADE_ADDR,
            abi.encodeWithSelector(
                SequencerList.initialize.selector,
                sequencers,
                ADMIN_ADDR
            )
        ))));
    }


    function testFeatures() public {
        assertEq(sequenceContract.isSequencer(address(100)), false);
        assertEq(sequenceContract.isSequencer(USER_1), true);
        assertEq(sequenceContract.isSequencer(USER_2), true);
        assertEq(sequenceContract.isSequencer(USER_3), true);

        address[] memory sequencers = new address[](3);
        sequencers[0] = USER_1;
        sequencers[1] = USER_2;
        sequencers[2] = USER_3;

        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers)));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sequenceContract.addSequencer(address(101));

        vm.prank(ADMIN_ADDR);
        sequenceContract.addSequencer(address(101));
        assertEq(sequenceContract.isSequencer(address(101)), true);

        address[] memory sequencers2 = new address[](4);
        sequencers2[0] = USER_1;
        sequencers2[1] = USER_2;
        sequencers2[2] = USER_3;
        sequencers2[3] = address(101);
        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers2)));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sequenceContract.removeSequencer(address(101));

        vm.prank(ADMIN_ADDR);
        sequenceContract.removeSequencer(address(101));
        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers)));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sequenceContract.newSequencers(sequencers2);

        vm.prank(ADMIN_ADDR);
        sequenceContract.newSequencers(sequencers2);
        assertEq(keccak256(abi.encode(sequenceContract.getSequencers())), keccak256(abi.encode(sequencers2)));
    }

    function testSequencerL1() public {
        L2OutputOracleMock l2Mock = new L2OutputOracleMock(10); // step 10 blocks

        address[] memory sequencers = new address[](2);
        sequencers[0] = o1;
        sequencers[1] = o2;

        // create sequencer contract
        Sequencer sequencer = Sequencer(payable(address(new TransparentUpgradeableProxy(
                address(new Sequencer(IL2OutputOracle(address(l2Mock)))),
                UPGRADE_ADDR,
                abi.encodeWithSelector(
                    SequencerList.initialize.selector,
                    sequencers,
                    ADMIN_ADDR
                )
            ))));

        // create test data
        bytes32 _l2Output = keccak256("test");
        uint256 _l2BlockNumber = 20;
        bytes32 _l1Blockhash = keccak256("test2");
        uint256 _l1BlockNumber = 12221;

        // sign the data
        bytes32 signData = keccak256(abi.encode(address(sequencer), block.chainid, _l2Output, _l2BlockNumber, _l1Blockhash, _l1BlockNumber));

        bytes memory signatures;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(prv1, signData);
        signatures = abi.encodePacked(signatures, r, s, v);

        (v, r, s) = vm.sign(prv2, signData);
        signatures = abi.encodePacked(signatures, r, s, v);

        sequencer.submitStateRoot(
            _l2Output, _l2BlockNumber, _l1Blockhash, _l1BlockNumber,
            signatures
        );

        // sign the data
        signData = keccak256(abi.encode(address(sequencer), block.chainid, _l2Output, _l2BlockNumber + 2, _l1Blockhash, _l1BlockNumber));

        // invalid request
        vm.expectRevert(0x58bf5274);
        sequencer.submitStateRoot(
            _l2Output, _l2BlockNumber, _l1Blockhash, _l1BlockNumber,
            signatures
        );

        assertEq(l2Mock.nextBlockNumber(), 30);

        signData = keccak256(abi.encode(address(sequencer), block.chainid, _l2Output, _l2BlockNumber + 10, _l1Blockhash, _l1BlockNumber));

        vm.expectRevert(0x274cf401);
        sequencer.submitStateRoot(
            _l2Output, _l2BlockNumber + 10, _l1Blockhash, _l1BlockNumber,
            bytes("")
        );

        vm.expectRevert(0x274cf401);
        sequencer.submitStateRoot(
            _l2Output, _l2BlockNumber + 10, _l1Blockhash, _l1BlockNumber,
            bytes("123")
        );

        // sign with key is not sequencer
    }
}
