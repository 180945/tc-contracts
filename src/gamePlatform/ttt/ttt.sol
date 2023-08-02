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
    //>= 2000: Expert: 6.4 ($80)
    //1800–1999: Class A: 3.2 ($40)
    //1600–1799: Class B: 1.6 ($20)
    //1400–1599: Class C: 0,8 ($10)
    //1200–1399: Class D: 0,4 ($5)
    //1000–1199: Class E: 0,2 ($2.5)
    function maxCanBet(address player, address token, int elo) external pure returns(uint) {
        player;
        token;

        uint max;
        if (elo >= 1000 && elo < 1200) {
            max = 2 * 1e17;
        } else if (elo >= 1200 && elo < 1400) {
            max = 4 * 1e17;
        } else if (elo >= 1400 && elo < 1600) {
            max = 8 * 1e17;
        } else if (elo >= 1600 && elo < 1800) {
            max = 16 * 1e17;
        } else if (elo >= 1800 && elo < 2000) {
            max = 32 * 1e17;
        } else if (max >= 2000) {
            max = 64 * 1e17;
        }

        return max;
    }

}
