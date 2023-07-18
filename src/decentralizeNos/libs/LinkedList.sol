// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract LinkedListLib {
    struct Node {
        uint32 prev;
        uint32 next;
        address staker;
        uint256 amount;
    }

    struct LinkedList {
        uint32 headId;
        uint32 tailId;
        uint32 length;
    }

    error RemoveNoneExistNode();
    error UpdateNoneExistNode();
    error InvalidStaker();

    uint256 public MAX_VALIDATOR;
    mapping(uint32 => Node) public nodeList;
    mapping(address => uint32) public stakers;
    LinkedList public linkedList;

    function getNodeById(uint32 nodeId) virtual view public returns(Node memory) {
        return nodeList[nodeId];
    }

    function getNodeByAddress(address staker) virtual view public returns(Node memory) {
        uint32 nodeId = stakers[staker];
        if (nodeId == 0) {
            revert InvalidStaker();
        }
        return nodeList[nodeId];
    }

    function getIdByAddress(address staker) virtual view public returns(uint32) {
        return stakers[staker];
    }

    function removeNode(uint32 nodeId) virtual internal returns(address, uint256) {
        if (nodeList[nodeId].staker == address(0)) {
            revert RemoveNoneExistNode();
        }
        Node memory node = nodeList[nodeId];
        if (node.prev != 0) {
            nodeList[node.prev].next = node.next;
        } else {
            linkedList.headId = node.next;
        }

        if (node.next != 0) {
            nodeList[node.next].prev = node.prev;
        } else {
            linkedList.tailId = node.prev;
        }

        delete nodeList[nodeId];
        delete stakers[node.staker];
        linkedList.length -=1;

        return (node.staker, node.amount);
    }

    function updateNode(uint32 nodeId, Node memory node) virtual internal {
        if (nodeList[nodeId].staker == address(0)) {
            revert UpdateNoneExistNode();
        }
        nodeList[nodeId] = node;
    }

    event logs(address, uint64, uint64);

    // init add node
    // @notice this function assumes that input stake already sorted
    function addInitNode(address staker, uint256 amount) virtual internal {
        uint32 tailId = linkedList.tailId;
        uint32 newNodeId = tailId + 1;
        if (linkedList.length == 0) {
            // empty LinkedList
            linkedList.headId = newNodeId;
            linkedList.tailId = newNodeId;
            nodeList[newNodeId] = Node(0, 0, staker, amount);
        } else {
            linkedList.tailId = newNodeId;
            nodeList[tailId].next = newNodeId;
            nodeList[newNodeId] = Node(tailId, 0, staker, amount);
        }
        linkedList.length++;
    }

    // return address and amount removed from top
    function addNodeSorted(address staker, uint256 amount) virtual internal returns(address, uint256) {
        uint32 newNodeId = linkedList.tailId + 1;
        uint256 lastStakeAmount = amount;
        address removedAddr;
        uint256 removedAmount;
        if (linkedList.length == 0) {
            // empty LinkedList
            linkedList.headId = newNodeId;
            linkedList.tailId = newNodeId;
            linkedList.length = 1;
            nodeList[newNodeId] = Node(0, 0, staker, lastStakeAmount);
            return (removedAddr, removedAmount);
        } else if (stakers[staker] > 0) {
            // staker existed in list
            uint32 currentIndex = stakers[staker];
            if (linkedList.length == 1) {
                nodeList[currentIndex].amount += amount;
                return (removedAddr, removedAmount);
            }
            lastStakeAmount += nodeList[currentIndex].amount;
            removeNode(currentIndex);
        }

        //todo: simple search will improve with skip linkedlist
        uint32 id = linkedList.tailId;
        for (uint32 i = 0; i < linkedList.length; i++) {
            if (lastStakeAmount > nodeList[id].amount) {
                id = nodeList[id].prev;
            } else {
                break;
            }
        }
        if (id == linkedList.tailId) {
            linkedList.tailId = newNodeId;
            nodeList[id].next = newNodeId;
            nodeList[newNodeId] = Node(id, 0, staker, lastStakeAmount);
        } else if (id == 0) {
            uint32 headId = linkedList.headId;
            nodeList[headId].prev = newNodeId;
            nodeList[newNodeId] = Node(0, headId, staker, lastStakeAmount);
            linkedList.headId = newNodeId;
        } else {
            uint32 nextTemp = nodeList[id].next;
            nodeList[id].next = newNodeId;
            nodeList[nextTemp].prev = newNodeId;
            nodeList[newNodeId] = Node(id, nextTemp, staker, lastStakeAmount);
        }

        linkedList.length++;
        // remove if linkedlist reaches max number
        if (linkedList.length > MAX_VALIDATOR) {
            (removedAddr, removedAmount) = removeNode(linkedList.tailId);
        }
        return (removedAddr, removedAmount);
    }
}