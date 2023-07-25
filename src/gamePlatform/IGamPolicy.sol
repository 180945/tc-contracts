// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGamPolicy {
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
    ) external pure returns (int256, int256);

    // @notice this function check how
    function playersCanMakeMatch(address player1, address player2) external view returns(bool);

    // @notice this function evaluate the
}