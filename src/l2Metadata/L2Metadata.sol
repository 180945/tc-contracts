// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/CountersUpgradeable.sol";

contract L2Metadata is OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter public total;
    mapping(uint => string) public metadata;

    event NewMetdata(uint, string);
    event UpdateMetdata(uint, string, string);

    function initialize(address admin) external initializer {
        _transferOwnership(admin);
    }

    function create(string calldata newMetadata) external onlyOwner {
        require(bytes(newMetadata).length != 0, "L2M: invalid metdatadata");

        metadata[total.current()] = newMetadata;
        emit NewMetdata(total.current(), newMetadata);
        total.increment();
    }

    function update(uint id, string calldata newMetadata) external onlyOwner {
        require(id < total.current(), "L2M: invalid id");

        emit UpdateMetdata(id, metadata[id], newMetadata);
        metadata[id] = newMetadata;
    }

    function metadatas(uint start, uint end) external view returns(string[] memory) {
        if (end <= start || start > total.current()) {
            return new string[](0);
        }

        if (end > total.current()) {
            end = total.current();
        }

        uint j;
        string[] memory temp = new string[](end - start);
        for (uint i = start; i < end; i++) {
            temp[j++] = metadata[i];
        }

        return temp;
    }
}
