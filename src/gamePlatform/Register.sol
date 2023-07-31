// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

interface IElo {
    function setUserElo(address tcAddr, uint40 gameType, int elo) external;
}

contract Register is OwnableUpgradeable {

    struct GamerInfo {
        string username;
    }

    // @notice this is elo contract to tracking and update user elo information
    IElo public gameBaseContract;

    // event
    // @notice this event emitted when admin register new user to the platform
    event RegisterAccount(address,uint,string,int);

    /**
      * @notice This data tracking user info which updated by admin
      * @dev tracking account => game type => gamer info
      * elo will query to
      */
    mapping(address => mapping(uint40 => GamerInfo)) public gamers;

    function initialize(address admin_) external initializer {
        _transferOwnership(admin_);
    }

    // @dev admin call this function to register user to the game platform
    function register(address tcAddr, uint40 gameType, string calldata username, int elo) external onlyOwner {
        // validate input
        require(bytes(username).length > 0 && tcAddr != address(0) && gameType > 0, "Register: invalid input data");

        // validate user exist or not
        require(!checkUserRegister(tcAddr, gameType), "Register: user registered");

        // update storage
        gamers[tcAddr][gameType].username = username;

        // request update elo to elo contract
        if (elo > 0) {
            gameBaseContract.setUserElo(tcAddr, gameType, elo);
        }

        emit RegisterAccount(tcAddr, gameType, username, elo);
    }

    // @notice this function used by internal/external contract to check user must be registered before doing anything
    function checkUserRegister(address account, uint40 gameType) public view returns(bool) {
        return bytes(gamers[account][gameType].username).length > 0;
    }

    // @notice update game base contract
    function setGameBase(IElo gameBase_) external onlyOwner {
        gameBaseContract = gameBase_;
    }

    // @notice get account info
    function getUserName(address account, uint40 gameType) public view returns(string memory) {
        return gamers[account][gameType].username;
    }

}
