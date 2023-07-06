// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { TurnBasedGame } from "@tc/TurnBasedGame.sol";

uint constant BOARD_SIZE = 15;
uint constant WIN_IN_ROW = 5;

// TicTacToe is a solidity implementation of the tic tac toe game.
// You can find the rules at https://en.wikipedia.org/wiki/Tic-tac-toe
contract TicTacToe is TurnBasedGame {

    // Players enumerates all possible players
    enum Players { None, PlayerOne, PlayerTwo }
    // Winners enumerates all possible winners
    enum Winners { None, PlayerOne, PlayerTwo, Draw }

    // Game stores the state of a round of tic tac toe.
    // As long as `winner` is `None`, the game is not over.
    // `playerTurn` defines who may go next.
    // Player one must make the first move.
    // The `board` has the size 3x3 and in each cell, a player
    // can be listed. Initializes as `None` player, as that is the
    // first element in the enumeration.
    // That means that players are free to fill in any cell at the
    // start of the game.
    struct Game {
        uint16 totalMoved;
        Players[BOARD_SIZE][BOARD_SIZE] board;
    }

    // games stores all the games.
    // Games that are already over as well as games that are still running.
    // It is possible to iterate over all games, as the keys of the mapping
    // are known to be the integers from `1` to `nrOfGames`.
    mapping(uint256 => Game) public games;

    function initialize(
        uint256 _turnDuration,
        uint256 _playerTimePool
    ) external initializer {
        __TurnBaseGame_init(_turnDuration, _playerTimePool);
    }

    // makeMove inserts a player on the game board.
    // The player is identified as the sender of the message.
    function makeMove(uint256 _matchId, uint _xCoordinate, uint _yCoordinate) external notTimeOutMatch(_matchId) notEndedMatch(_matchId) {
        Game storage game = games[_matchId];
        bool p1Turn = matches[_matchId].turn;

        if (game.board[_xCoordinate][_yCoordinate] != Players.None) {
            revert MoveProhibited();
        }

        unchecked {
            uint128 timeUsed = uint128(block.timestamp - matches[_matchId].turnTimePivot);

            if (p1Turn) {
                if (msg.sender != matches[_matchId].player1) revert MoveProhibited();
                matches[_matchId].player1TimePool -= timeUsed;
                game.board[_xCoordinate][_yCoordinate] = Players.PlayerOne;
            } else {
                if (msg.sender != matches[_matchId].player2) revert MoveProhibited();
                matches[_matchId].player2TimePool -= timeUsed;
                game.board[_xCoordinate][_yCoordinate] = Players.PlayerTwo;
            }
            game.totalMoved++;
            matches[_matchId].turn = !p1Turn;
            matches[_matchId].turnTimePivot = block.timestamp;

            emit Move(_matchId, msg.sender, uint8(_xCoordinate), uint8(_yCoordinate), timeUsed);

            Winners winner = calculateWinner(_matchId, _xCoordinate, _yCoordinate);
            if (winner != Winners.None) {
                MatchResult result = MatchResult(uint8(winner));
                endGame(_matchId, result);
            }
        }
    }

    // calculateWinner returns the winner on the given board.
    // The returned winner can be `None` in which case there is no winner and no draw.
    function calculateWinner(uint256 _gameId, uint256 _xCoordinate, uint256 _yCoordinate) private view returns (Winners winner) {
        // First we check if there is a victory in a row.
        // If so, convert `Players` to `Winners`
        // Subsequently we do the same for columns and diagonals.
        Players[BOARD_SIZE][BOARD_SIZE] memory _board = games[_gameId].board;
        Players player = winnerInRow(_board, _xCoordinate, _yCoordinate);
        if (player == Players.PlayerOne) {
            return Winners.PlayerOne;
        }
        if (player == Players.PlayerTwo) {
            return Winners.PlayerTwo;
        }

        player = winnerInColumn(_board, _xCoordinate, _yCoordinate);
        if (player == Players.PlayerOne) {
            return Winners.PlayerOne;
        }
        if (player == Players.PlayerTwo) {
            return Winners.PlayerTwo;
        }

        player = winnerInDiagonal(_board, _xCoordinate, _yCoordinate);
        if (player == Players.PlayerOne) {
            return Winners.PlayerOne;
        }
        if (player == Players.PlayerTwo) {
            return Winners.PlayerTwo;
        }

        // If there is no winner and no more space on the board,
        // then it is a draw.
        if (games[_gameId].totalMoved == uint16(BOARD_SIZE * BOARD_SIZE)) {
            return Winners.Draw;
        }

        return Winners.None;
    }

    // winnerInRow returns the player that wins in any row.
    // To win in a row, all cells in the row must belong to the same player
    // and that player must not be the `None` player.
    function winnerInRow(Players[BOARD_SIZE][BOARD_SIZE] memory _board, uint256 _xCoordinate, uint256 _yCoordinate) private pure returns (Players winner) {
        uint totalInRow = 1;
        Players player = _board[_xCoordinate][_yCoordinate];
        // count on the right
        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_xCoordinate < i) {
                break;
            }
            if (_board[_xCoordinate - i][_yCoordinate] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        // count on the left
        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_xCoordinate + i >= BOARD_SIZE) {
                break;
            }
            if (_board[_xCoordinate + i][_yCoordinate] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        // total to determine winner
        if (totalInRow >= WIN_IN_ROW) {
            return player;
        }

        return Players.None;
    }

    // winnerInColumn returns the player that wins in any column.
    // To win in a column, all cells in the column must belong to the same player
    // and that player must not be the `None` player.
    function winnerInColumn(Players[BOARD_SIZE][BOARD_SIZE] memory _board, uint256 _xCoordinate, uint256 _yCoordinate) private pure returns (Players winner) {
        uint totalInRow = 1;
        Players player = _board[_xCoordinate][_yCoordinate];
        // count above
        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_yCoordinate < i) {
                break;
            }
            if (_board[_xCoordinate][_yCoordinate - i] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        // count below
        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_yCoordinate + i >= BOARD_SIZE) {
                break;
            }
            if (_board[_xCoordinate][_yCoordinate + i] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        // total to determine winner
        if (totalInRow >= WIN_IN_ROW) {
            return player;
        }

        return Players.None;
    }

    // winnerInDiagoral returns the player that wins in any diagonal.
    // To win in a diagonal, all cells in the diaggonal must belong to the same player
    // and that player must not be the `None` player.
    function winnerInDiagonal(Players[BOARD_SIZE][BOARD_SIZE] memory _board, uint256 _xCoordinate, uint256 _yCoordinate) private pure returns (Players winner) {
        uint totalInRow = 1;
        Players player = _board[_xCoordinate][_yCoordinate];
        // back cross
        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_xCoordinate < i || _yCoordinate < i) {
                break;
            }
            if (_board[_xCoordinate - i][_yCoordinate - i] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_xCoordinate + i >= BOARD_SIZE || _yCoordinate + i >= BOARD_SIZE) {
                break;
            }
            if (_board[_xCoordinate + i][_yCoordinate + i] == player) {
                totalInRow++;
            } else {
                break;
            }

        }
        // total to determine winner
        if (totalInRow >= WIN_IN_ROW) {
            return player;
        }

        totalInRow = 1;

        // fordward cross
        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_xCoordinate < i || _yCoordinate + i >= BOARD_SIZE) {
                break;
            }
            if (_board[_xCoordinate - i][_yCoordinate + i] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        for (uint i = 1; i < WIN_IN_ROW; i++) {
            if (_xCoordinate + i >= BOARD_SIZE || _yCoordinate < i) {
                break;
            }
            if (_board[_xCoordinate + i][_yCoordinate - i] == player) {
                totalInRow++;
            } else {
                break;
            }

        }

        // total to determine winner
        if (totalInRow >= WIN_IN_ROW) {
            return player;
        }

        return Players.None;
    }

    function getGameState(uint gameId) public view returns(Players[BOARD_SIZE][BOARD_SIZE] memory) {
        return games[gameId].board;
    }

    function version() override external pure returns (string memory) {
        return "1.0.0";
    }
}