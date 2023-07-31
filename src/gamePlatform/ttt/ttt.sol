// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Elo } from "@tc/Elo.sol";

contract TTT {
    /**
     * @notice Input the current elo and game result will get new output elo
     * @return
     * - new elo of player1
     * - new elo of player2
     */
    function getNewElo(
        int256 _elo1,
        int256 _elo2,
        uint256 _matchCount1,
        uint256 _matchCount2,
        int256 _matchResult
    ) external pure returns (int256, int256) {
       return Elo.getNewElo(
           _elo1,
           _elo2,
           _matchCount1,
           _matchCount2,
           _matchResult
        );
    }

    // @notice this function check how
    function playersCanMakeMatch(address player1, int elo1, address player2, int elo2) external pure returns(bool) {
        // silence warning
        player1;
        player2;

        int eloGap = elo1 - elo2;
        if (eloGap <  0) {
            eloGap = -eloGap;
        }

        return eloGap < int(200);
    }

    // @notice this function evaluate the TC max match creator can bet
    // address 0x00 for native token
    function maxCanBet(address player, address token, int elo) external pure returns(uint) {
        player;
        token;

        uint max;
        if (elo >= 500 && elo < 1000) {
            max = 50 ether;
        } else if (elo >= 1000 && elo < 2000) {
            max = 100 ether;
        } else if (max >= 2000) {
            max = type(uint256).max;
        }

        return max;
    }

}
