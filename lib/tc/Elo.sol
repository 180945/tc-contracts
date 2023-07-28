// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { SD59x18, sd } from "@prb-math/src/SD59x18.sol";

library Elo {
    uint8 constant public K_FACTOR_LOW_ELO = 30;
    uint8 constant public K_FACTOR_HIGH_ELO = 20;

    function getExpectedScore(int256 _currentElo, int256 _opponentElo) private pure returns (SD59x18) {
        int256 difference = _opponentElo - _currentElo;
        SD59x18 exp = sd(difference * 1e18 / 400);
        SD59x18 result = (sd(1e18).add(sd(10 * 1e18).pow(exp))).inv();
        return result;
    }

    function getNewElo(
        int256 _elo1,
        int256 _elo2,
        uint256 _matchCount1,
        uint256 _matchCount2,
        int256 _matchResult
    ) public pure returns (int256, int256) {
        (SD59x18 score1, SD59x18 score2) = getScore(_matchResult);

        return getNewElo(_elo1, _elo2, _matchCount1, _matchCount2, score1, score2);
    }

    function getScore(int256 _matchResult) internal pure returns(SD59x18, SD59x18) {
        SD59x18 score1;
        SD59x18 score2;
        if (_matchResult < 0) {
            score1 = sd(1e18);
            score2 = sd(0);
        } else if (_matchResult > 0) {
            score1 = sd(0);
            score2 = sd(1e18);
        } else {
            score1 = sd(5e17);
            score2 = sd(5e17);
        }

        return (score1, score2);
    }

    function getNewElo(
        int256 _elo1,
        int256 _elo2,
        uint256 _matchCount1,
        uint256 _matchCount2,
        SD59x18 score1,
        SD59x18 score2
    ) internal pure returns(int256, int256) {
        SD59x18 expectedScore1 = getExpectedScore(_elo1, _elo2);
        SD59x18 expectedScore2 = getExpectedScore(_elo2, _elo1);

        uint8 kFactor1 = (_elo1 < 2000 || _matchCount1 < 30) ? K_FACTOR_LOW_ELO : K_FACTOR_HIGH_ELO;
        uint8 kFactor2 = (_elo2 < 2000 || _matchCount2 < 30) ? K_FACTOR_LOW_ELO : K_FACTOR_HIGH_ELO;

        SD59x18 eloChange1 = sd(int256(uint256(kFactor1)) * 1e18).mul(score1.sub(expectedScore1));
        SD59x18 eloChange2 = sd(int256(uint256(kFactor2)) * 1e18).mul(score2.sub(expectedScore2));

        int256 newElo1 = _elo1 + int256(eloChange1.unwrap() / 1e18);
        int256 newElo2 = _elo2 + int256(eloChange2.unwrap() / 1e18);

        if (newElo1 < 1) {
            newElo1 = 1;
        }

        if (newElo2 < 1) {
            newElo2 = 1;
        }
        return (newElo1, newElo2);
    }
}
