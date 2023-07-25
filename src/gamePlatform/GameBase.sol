// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IGamPolicy} from "./IGamPolicy.sol";
import {Register} from "./Register.sol";

contract GameBase is OwnableUpgradeable {

    uint16 constant public UPPER_BOUND = 1e4;

    // @dev events
    // @notice this event emitted when admin register new user to the platform
    event InitElo(address,uint,uint);

    // @notice this event emitted when new game added by admin
    event RegisterNewGame(uint, address);

    // @notice this event emitted when admin register new user to the platform
    event UpdateGame(uint, address);

    // @notice this event emitted when admin register new user to the platform
    event NewRegister(address, address);

    // STORAGE LAYOUT

    // @notice contract register address for new gamer
    Register public register;

    // @notice game config data
    struct GameConfig {
        uint16 faultCharge; // 2 bytes range 0 - 10000
        uint16 serviceFee; // 2 bytes range 0 - 10000
        uint40 timeBuffer; // 5 bytes if the opponent does not submit in time so the game will end
        uint40 timeSubmitMatchResult; // 5 bytes
    }

    // @notice admin who can resolve disputes
    mapping(address => bool) public resolvers;

    // @notice game config data
    GameConfig public gameConfig;

    /**
      * @notice This data tracking game contract logic
      * @dev tracking game type => contract address
      */
    mapping(uint => address) public games;

    // @notice result of the game
    enum MatchResult {
        PLAYING,
        PLAYER_1_WON,
        PLAYER_2_WON,
        DREW
    }

    enum PlayerState {
        DEFAULT,
        PLAYING
    }

    // @notice player state
    struct PlayerGameState {
        uint128 matchId;
        PlayerState playerState;
        int256 elo;
    }

    enum MatchState {
        EMPTY, // A create match
        WAITING_OPPONENT, // waiting B join match
        WAITING_INVITATION, // waiting A submit invite link
        WAITING_CONFIRM_JOIN, // waiting B confirm reject/join match with link live
        REJECT_TO_JOIN_GAME, // B reject to join game -> game draw no fee charged at this step
        LINK_LIVE_SUBMITTED, // B submit link live and wait A confirm link is valid
        ACCEPT_MATCH, // A accept match and game start
        DISPUTE_OCCURRED, // admin jump in to resolve dispute between user
        GAME_CLOSED
    }

    struct MatchData {
        address player1;
        MatchResult player1SummitResult;
        MatchResult player2SummitResult;
        uint48 startTime;
        address player2;
        uint48 lastTimestamp;
        MatchResult result;
        uint32 gameType;
        MatchState matchState;
        uint128 minBet;
        uint128 maxBet;
        uint betAmount;
        string player2PubKey;
        string inviteLink;
        string liveLink;
        GameConfig matchConfig;
    }

    struct PlayerData {
        // total tc balance of player
        uint balance;
        // tracking state of user for each game
        // game type => player game state
        mapping(uint32 => PlayerGameState) playerStates;
    }

    // @notice total match created - for tracking and create match id purpose
    uint256 public totalMatch;
    // @notice tracking match data. (match id => match data)
    mapping(uint256 => MatchData) public matches;
    /**
      * @notice This data tracking user info which updated by admin
      * @dev tracking account => game type => player data
      */
    mapping(address => PlayerData) public players;

    // END STORAGE LAYOUT

    // @notice Event section here
    event MatchCreation(uint256 indexed matchId, address indexed player, uint gameType, uint minBet, uint maxBet, uint startTime);
    event MatchCancellation(uint256 indexed matchId, address indexed player);
    event MatchStateUpdate(uint256 indexed matchId, MatchState state);
    event JoinMatch(uint256 indexed matchId, address player, string pubkey);
    event MatchEnd(uint256 indexed matchId, MatchResult indexed result);
    event EloUpdate(address indexed player, int256 oldElo, int256 newElo);

    // @dev modifier
    modifier requireMatchState(uint matchId, MatchState inputState) {
        require(matches[matchId].matchState == inputState, "GB: invalid state");
        _;
    }

    modifier registered(uint gameType) {
        require(register.checkUserRegister(msg.sender, gameType), "GB: user not registered");
        _;
    }

    modifier onlyPlayerOf(uint256 _matchId) {
        if (msg.sender != matches[_matchId].player1 && msg.sender != matches[_matchId].player2) {
            revert NotPlayerOfTheMatch();
        }
        _;
    }

    modifier mustAvailableToJoin(uint gameType) {
        require(players[msg.sender].playerStates[gameType].playerState == PlayerState.DEFAULT, "GB: player already in game");
        _;
    }

    function initialize(address admin_, address register_) external initializer {
        _transferOwnership(admin_);
        register = register_;
    }

    function version() external pure returns (string memory) {
        return "0.1.0";
    }

    // @notice player call this function to create new match
    function createMatch(uint gameType, uint minBet, uint maxBet, uint startTime) payable external mustAvailableToJoin(gameType) {
        // check elo calculation contract is set
        require(games[gameType] != address(0) && maxBet >= minBet, "GameBase: game not exist or invalid input");
        // check attached value with input max bet
        require(msg.value == maxBet, "GameBase: value can't exceed max bet");
        // check attached value with input max bet
        require(startTime > block.timestamp, "GameBase: game must start in future");
        // update total match and new id
        uint256 matchId = ++totalMatch;

        address player = msg.sender;
        // init player 1
        matches[matchId].player1 = player;
        matches[matchId].gameType = uint32(gameType);
        matches[matchId].minBet = uint128(minBet);
        matches[matchId].maxBet = uint128(maxBet); // fault charge included
        matches[matchId].matchState = MatchState.WAITING_OPPONENT;
        matches[matchId].matchConfig = gameConfig;
        matches[matchId].startTime = uint48(startTime);
        // update player state for this game
        players[player].playerStates[gameType].playerState = PlayerState.PLAYING;

        emit MatchCreation(matchId, player, gameType, minBet, maxBet, startTime);
    }

    // @notice Player 2 request to join challenge
    // @dev The match must not started and value attached in the tx must be in range as player 1 config
    function joinMatch(uint matchId, string calldata publicKey) payable external requireMatchState(matchId, MatchState.WAITING_OPPONENT) mustAvailableToJoin(matches[matchId].gameType) {
        // check this game started so must it must closed
        MatchData storage matchData = matches[matchId];
        require(uint256(matchData.startTime) > block.timestamp, "GameBase: this game started");
        require(msg.sender != matchData.player1, "GB: can not join as player 2");

        // check value in tx in range
        require(msg.value >= matchData.minBet && msg.value <= matchData.maxBet, "GameBase: bet value out range");

        // update match data
        matchData.betAmount = msg.value;
        matchData.matchState = MatchState.WAITING_INVITATION;
        matchData.lastTimestamp = uint48(block.timestamp);
        matchData.player2PubKey = publicKey;
        matchData.player2 = msg.sender;

        // update player state
        players[msg.sender].playerStates[gameType].playerState = PlayerState.PLAYING;

        // emit event before tx ended
        emit JoinMatch(matchId, msg.sender, publicKey);
        emit MatchState(matchId, MatchState.WAITING_INVITATION);
    }

    // @notice player 1 submit invite link for opponent
    function submitInviteLink(uint matchId, string calldata inviteLink) external requireMatchState(matchId, MatchState.WAITING_INVITATION) {
        // check this game started so must it must closed
        MatchData storage matchData = matches[matchId];
        require(block.timestamp - uint256(matchData.lastTimestamp) <= matchData.matchConfig.timeBuffer, "GameBase: timeout");

        // only player 1 of this match can call this function
        require(matchData.player1 == msg.sender, "GB: unauthorized");

        // update storage
        matchData.inviteLink = inviteLink;
        matchData.matchState = MatchState.WAITING_CONFIRM_JOIN;

        emit MatchState(matchId, MatchState.WAITING_CONFIRM_JOIN);
    }

    // @notice player 2 submit reject match
    function rejectMatch(uint matchId, string calldata inviteLink) external requireMatchState(matchId, MatchState.WAITING_CONFIRM_JOIN) {
        // check this game started so must it must closed
        MatchData storage matchData = matches[matchId];
        require(block.timestamp - uint256(matchData.lastTimestamp) <= matchData.matchConfig.timeBuffer, "GameBase: timeout");

        // only player 1 of this match can call this function
        require(matchData.player2 == msg.sender, "GB: unauthorized");

        // update storage
        matchData.matchState = MatchState.REJECT_TO_JOIN_GAME;
        players[matchData.player1].balance += matchData.maxBet;
        players[matchData.player2].balance += matchData.betAmount;
        players[player1].playerStates[gameType].playerState = PlayerState.DEFAULT;
        players[player1].playerStates[gameType].playerState = PlayerState.DEFAULT;

        emit MatchState(matchId, MatchState.REJECT_TO_JOIN_GAME);
    }

    // @notice join match

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

    function affirmTimeOut(uint256 _matchId)
    virtual external {
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

    // @dev admin call this function to update register contract address
    function updateRegisterContract(uint newRegister) external onlyOwner {
        require(newRegister != address(0), "GameBase: munst not be zero");

        // shoot event here
        emit NewRegister(register, newRegister);

        register = newRegister;
    }

    // @dev admin call this function to register game elo calculation
    function registerGame(uint gameType, address newEloCalculationContract) external onlyOwner {
        require(games[gameType] == address(0), "GameBase: game registered");

        // sanity check
        IGamPolicy(newEloCalculationContract).getNewElo(0, 0, 0, 0, 0);

        // store new game
        games[gameType] = newEloCalculationContract;

        emit RegisterNewGame(gameType, newEloCalculationContract);
    }

    // @dev update game elo calculation contract. Only admin can trigger this function
    function updateGame(uint gameType, address newEloCalculationContract) external onlyOwner {
        require(games[gameType] != address(0), "GameBase: game not registered before");

        // sanity check
        IGamPolicy(newEloCalculationContract).getNewElo(0, 0, 0, 0, 0);

        // store new game
        games[gameType] = newEloCalculationContract;

        emit UpdateGame(gameType, newEloCalculationContract);
    }

    // @dev update user elo at init. Only called by register contract
    function setUserElo(address tcAddr, uint gameType, uint elo) external {
        require(msg.sender == register, "GameBase: unauthorized");

        // check user it initialized
        require(players[tcAddr].playerStates[gameType].elo == 0, "GameBase: user initialized");

        // check elo calculation contract is set
        require(games[gameType] != address(0), "GameBase: game not exist");

        // update elo
        players[tcAddr].playerStates[gameType].elo = elo;

        emit InitElo(tcAddr, gameType, elo);
    }


    // Getters

    // @dev return elo of user based on game type
    function getEloByGameType(address tcAddr, uint gameType) external view returns(int) {
        return players[tcAddr].playerStates[gameType].elo;
    }
}
