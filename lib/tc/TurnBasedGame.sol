// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { SD59x18, sd } from "@prb-math/src/SD59x18.sol";

import { Elo } from "@tc/Elo.sol";
import { Set } from "@tc/Set.sol";

abstract contract TurnBasedGame is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Set for Set.Uint256Set;

    enum DrawOfferState {
        NO_DRAW_OFFER,
        OFFERED_BY_PLAYER_1,
        OFFERED_BY_PLAYER_2
    }

    enum MatchResult {
        PLAYING,
        PLAYER_1_WON,
        PLAYER_2_WON,
        DREW
    }

    enum PlayerState {
        DEFAULT,
        FINDING,
        PLAYING
    }

    struct MatchData {
        address player1;
        uint40 turnTimePivot;
        /*
           1 - Player 1
           0 - Player 2
        */
        bool turn;
        DrawOfferState drawOffer;
        MatchResult result;
        uint16 totalMoved;
        address player2;
        uint40 player1TimePool;
        uint40 player2TimePool;
    }

    struct PlayerData {
        uint256[] matches;
        int256 elo;
        PlayerState state;
    }

    int256 constant public DEFAULT_ELO = 1500;
    uint8 constant public K_FACTOR_LOW_ELO = 30;
    uint8 constant public K_FACTOR_HIGH_ELO = 20;

    uint256 public matchNumber;

    uint256 public turnDuration;
    uint256 public playerTimePool;

    uint256 public pendingMatch;
    Set.Uint256Set private playingMatches;
    mapping(uint256 => MatchData) public matches;
    mapping(address => PlayerData) public players;

    event DrawCancellation(uint256 indexed matchId, address indexed player);
    event DrawOffer(uint256 indexed matchId, address indexed player);
    event DrawRejection(uint256 indexed matchId, address indexed player);
    event MatchCreation(uint256 indexed matchId, address indexed player);
    event MatchCancellation(uint256 indexed matchId, address indexed player);
    event MatchStart(uint256 indexed matchId, address indexed player1, address indexed player2);
    event MatchEnd(uint256 indexed matchId, MatchResult indexed result);
    event Move(uint256 indexed matchId, address indexed player, uint8 from, uint8 to, uint256 time);
    event PlayerTimePoolUpdate(uint256 newValue);
    event Resignation(uint256 indexed matchId, address indexed player);
    event TurnDurationUpdate(uint256 newValue);
    event EloUpdate(address indexed player, int256 oldElo, int256 newElo);

    error InvalidDrawAccepting();
    error InvalidDrawCancelling();
    error InvalidDrawOffering();
    error InvalidDrawRejecting();
    error InvalidMatchFinding();
    error InvalidMatchCancelling();
    error InvalidVictoryClaiming();
    error MatchTimeOut();
    error MatchNotTimeOut();
    error MatchEnded();
    error MoveProhibited();
    error NotPlayerOfTheMatch();

    modifier onlyPlayerOf(uint256 _matchId) {
        if (msg.sender != matches[_matchId].player1 && msg.sender != matches[_matchId].player2) {
            revert NotPlayerOfTheMatch();
        }
        _;
    }

    modifier notTimeOutMatch(uint256 _matchId) {
        unchecked {
            uint256 timeUsed = block.timestamp - matches[_matchId].turnTimePivot;

            if (timeUsed > turnDuration) revert MatchTimeOut();
            if (matches[_matchId].turn) {
                if (timeUsed > matches[_matchId].player1TimePool) revert MatchTimeOut();
            } else {
                if (timeUsed > matches[_matchId].player2TimePool) revert MatchTimeOut();
            }
        }
        _;
    }

    modifier notEndedMatch(uint256 _matchId) {
        if (matches[_matchId].result != MatchResult.PLAYING) revert MatchEnded();
        _;
    }

    function __TurnBaseGame_init(
        uint256 _turnDuration,
        uint256 _playerTimePool
    ) internal onlyInitializing {
        __Ownable_init();
        __Pausable_init();
        turnDuration = _turnDuration;
        playerTimePool = _playerTimePool;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function version() virtual external pure returns (string memory);

    function updateTurnDuration(uint256 _turnDuration) external onlyOwner {
        turnDuration = _turnDuration;
        emit TurnDurationUpdate(_turnDuration);
    }

    function updatePlayerTimePool(uint256 _playerTimePool) external onlyOwner {
        playerTimePool = _playerTimePool;
        emit PlayerTimePoolUpdate(_playerTimePool);
    }

    function getPlayingMatches() external view returns (uint256[] memory) {
        return playingMatches.values;
    }

    function getMatchesOfPlayer(address _player) external view returns (uint256[] memory) {
        return players[_player].matches;
    }

    function getPlayingMatchOfPlayer(address _player) external view returns (uint256) {
        if (players[_player].state != PlayerState.PLAYING) return 0;
        uint256[] memory matchesOfPlayer = players[_player].matches;
        return matchesOfPlayer[matchesOfPlayer.length - 1];
    }

    function getTurn(uint256 _matchId) public view returns (bool, int256, int256) {
        int256 timeUsed = int256(block.timestamp) - int256(uint256(matches[_matchId].turnTimePivot));
        return (
            matches[_matchId].turn,
            int256(turnDuration) - timeUsed,
            int256(uint256(matches[_matchId].turn ?
                matches[_matchId].player1TimePool :
                matches[_matchId].player2TimePool)) - timeUsed
        );
    }

    function createMatch() virtual internal {
        uint256 matchId = ++matchNumber;

        matches[matchId].player1 = msg.sender;
        matches[matchId].player1TimePool = uint40(playerTimePool);
        matches[matchId].player2TimePool = uint40(playerTimePool);
        matches[matchId].turn = true;
        pendingMatch = matchId;

        players[msg.sender].matches.push(matchId);
        players[msg.sender].state = PlayerState.FINDING;

        emit MatchCreation(matchId, msg.sender);
    }

    function joinMatch() virtual internal {
        uint256 matchId = pendingMatch;
        matches[matchId].turnTimePivot = uint40(block.timestamp);
        address matchCreator = matches[matchId].player1;
        if ((block.number + block.timestamp) & 1 == 0) {
            matches[matchId].player2 = msg.sender;
            emit MatchStart(matchId, matchCreator, msg.sender);
        } else {
            matches[matchId].player2 = matchCreator;
            matches[matchId].player1 = msg.sender;
            emit MatchStart(matchId, msg.sender, matchCreator);
        }
        pendingMatch = 0;
        players[matchCreator].state = PlayerState.PLAYING;
        players[msg.sender].state = PlayerState.PLAYING;
        players[msg.sender].matches.push(matchId);
        playingMatches.insert(matchId);
    }

    function findMatch() virtual external whenNotPaused {
        if (players[msg.sender].state != PlayerState.DEFAULT) revert InvalidMatchFinding();
        if (players[msg.sender].elo == 0) players[msg.sender].elo = DEFAULT_ELO;
        if (pendingMatch == 0) createMatch();
        else joinMatch();
    }

    function cancelMatch() virtual external {
        uint256 matchId = pendingMatch;
        if (matches[matchId].player1 != msg.sender) revert InvalidMatchCancelling();
        players[msg.sender].matches.pop();
        pendingMatch = 0;
        players[msg.sender].state = PlayerState.DEFAULT;
        emit MatchCancellation(matchId, msg.sender);
    }

    function endGame(uint256 _matchId, MatchResult _result) virtual internal {
        matches[_matchId].result = _result;
        playingMatches.erase(_matchId);

        address player1 = matches[_matchId].player1;
        address player2 = matches[_matchId].player2;

        players[player1].state = PlayerState.DEFAULT;
        players[player2].state = PlayerState.DEFAULT;

        int256 elo1 = players[player1].elo;
        int256 elo2 = players[player2].elo;

        uint256 matchCount1 = players[player1].matches.length;
        uint256 matchCount2 = players[player2].matches.length;

        int256 matchResult;
        if (_result == MatchResult.PLAYER_1_WON) matchResult = -1;
        else if (_result == MatchResult.PLAYER_2_WON) matchResult = 1;

        (int256 newElo1, int256 newElo2) = Elo.getNewElo(
            elo1,
            elo2,
            matchCount1,
            matchCount2,
            matchResult
        );

        emit EloUpdate(player1, elo1, newElo1);
        emit EloUpdate(player2, elo2, newElo2);

        emit MatchEnd(_matchId, _result);
    }

    function resign(uint256 _matchId)
    virtual external
    onlyPlayerOf(_matchId)
    notEndedMatch(_matchId) {
        MatchResult matchResult = msg.sender == matches[_matchId].player2 ?
            MatchResult.PLAYER_1_WON :
            MatchResult.PLAYER_2_WON;
        emit Resignation(_matchId, msg.sender);
        endGame(_matchId, matchResult);
    }

    function affirmTimeOut(uint256 _matchId)
    virtual external
    notEndedMatch(_matchId) {
        unchecked {
            uint256 timeUsed = block.timestamp - matches[_matchId].turnTimePivot;

            MatchResult matchResult;
            if (matches[_matchId].turn) {
                if (timeUsed < turnDuration && timeUsed < matches[_matchId].player1TimePool) {
                    revert MatchNotTimeOut();
                }
                matchResult = MatchResult.PLAYER_2_WON;
            } else {
                if (timeUsed < turnDuration && timeUsed < matches[_matchId].player2TimePool) {
                    revert MatchNotTimeOut();
                }
                matchResult = MatchResult.PLAYER_1_WON;
            }
            endGame(_matchId, matchResult);
        }
    }

    function offerDraw(uint256 _matchId) virtual external notEndedMatch(_matchId) {
        if (msg.sender == matches[_matchId].player1) {
            if (matches[_matchId].drawOffer != DrawOfferState.NO_DRAW_OFFER) revert InvalidDrawOffering();
            matches[_matchId].drawOffer = DrawOfferState.OFFERED_BY_PLAYER_1;
        } else if (msg.sender == matches[_matchId].player2) {
            if (matches[_matchId].drawOffer != DrawOfferState.NO_DRAW_OFFER) revert InvalidDrawOffering();
            matches[_matchId].drawOffer = DrawOfferState.OFFERED_BY_PLAYER_2;
        } else revert NotPlayerOfTheMatch();
        emit DrawOffer(_matchId, msg.sender);
    }

    function cancelDraw(uint256 _matchId) virtual external notEndedMatch(_matchId) {
        if (msg.sender == matches[_matchId].player1) {
            if (matches[_matchId].drawOffer != DrawOfferState.OFFERED_BY_PLAYER_1) revert InvalidDrawCancelling();
        } else if (msg.sender == matches[_matchId].player2) {
            if (matches[_matchId].drawOffer != DrawOfferState.OFFERED_BY_PLAYER_2) revert InvalidDrawCancelling();
        } else revert NotPlayerOfTheMatch();
        matches[_matchId].drawOffer = DrawOfferState.NO_DRAW_OFFER;
        emit DrawCancellation(_matchId, msg.sender);
    }

    function rejectDraw(uint256 _matchId) virtual external notEndedMatch(_matchId) {
        if (msg.sender == matches[_matchId].player1) {
            if (matches[_matchId].drawOffer != DrawOfferState.OFFERED_BY_PLAYER_2) revert InvalidDrawRejecting();
        } else if (msg.sender == matches[_matchId].player2) {
            if (matches[_matchId].drawOffer != DrawOfferState.OFFERED_BY_PLAYER_1) revert InvalidDrawRejecting();
        } else revert NotPlayerOfTheMatch();
        matches[_matchId].drawOffer = DrawOfferState.NO_DRAW_OFFER;
        emit DrawRejection(_matchId, msg.sender);
    }

    function acceptDraw(uint256 _matchId) virtual external notEndedMatch(_matchId) {
        if (msg.sender == matches[_matchId].player1) {
            if (matches[_matchId].drawOffer == DrawOfferState.OFFERED_BY_PLAYER_2) endGame(_matchId, MatchResult.DREW);
            else revert InvalidDrawAccepting();
        } else if (msg.sender == matches[_matchId].player2) {
            if (matches[_matchId].drawOffer == DrawOfferState.OFFERED_BY_PLAYER_1) endGame(_matchId, MatchResult.DREW);
            else revert InvalidDrawAccepting();
        } else revert NotPlayerOfTheMatch();
    }
}
