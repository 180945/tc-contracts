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
    function playersCanMakeMatch(address player1, int elo1, address player2, int elo2) external view returns(bool);

    // @notice this function evaluate the TC max match creator can bet
    // address 0x00 for native token
    function maxCanBet(address player, address token, int elo) external view returns(bool);
}