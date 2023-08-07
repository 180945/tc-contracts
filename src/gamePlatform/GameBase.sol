// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IGamPolicy} from "./IGamPolicy.sol";
import {Register} from "./Register.sol";

contract GameBase is OwnableUpgradeable {

    uint16 constant public UPPER_BOUND = 1e4;

    // @dev events
    // @notice this event emitted when admin register new user to the platform
    event InitElo(address,uint,int);

    // @notice this event emitted when new game added by admin
    event RegisterNewGame(uint, address);

    // @notice this event emitted when admin register new user to the platform
    event UpdateGame(uint, address);

    // @notice this event emitted when admin register new user to the platform
    event NewRegister(Register, Register);

    // @notice this event emitted when admin add/remove match resolver to contract
    event UpdateResolver(address, bool);

    event NewGameConfig(GameConfig);

    // @notice emitted when new match created
    event MatchCreation(uint256 indexed matchId, address indexed player, uint gameType, uint minBet, uint maxBet, uint startTime);
    event MatchCancellation(uint256 indexed matchId, address indexed player);
    event MatchStateUpdate(uint256 indexed matchId, MatchState state);
    event JoinMatch(uint256 indexed matchId, address player, string pubkey, uint betAmount);
    event ResultSubmitted(uint256 indexed matchId, MatchResult indexed result, address player, string proofLink);
    event EloUpdate(address indexed player, int256 oldElo, int256 newElo);
    event MatchElo(uint256 indexed matchId, uint40 gameType, address player1, int256 elo1, address player2, int256 elo2);
    event MatchLiveLinkSubmitted(uint256 indexed matchId, address indexed player, string liveLink);
    event MatchInviteLinkSubmitted(uint256 indexed matchId, address indexed player, string inviteLink);
    event MatchResolved(uint256 indexed matchId, address resolver, MatchState state, Fault fault);

    // @notice emitted when game timeout with reason
    event TimeOutOccurred(uint256 indexed matchId, MatchState state);

    // @notice this event emitted when player claim their token from protocol
    event Claim(address, uint);

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
        DREW,
        PLAYER_2_WON,
        REJECT
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
        MATCH_STARTED, // A accept match and game start
        SUMMITING_RESULT, // one of player submitted result
        DISPUTE_OCCURRED, // admin jump in to resolve dispute between user
        REJECT_TO_JOIN_GAME, // 6: B reject to join game -> game draw no fee charged at this step  // end game
        PLAYER_1_TIMEOUT, // not follow game rule in time
        PLAYER_2_TIMEOUT, // not follow game rule in time
        GAME_CLOSED, // no-one join game @notice this param used in some functions, dont change the order
        PLAYER_1_WIN,
        MATCH_DRAW,
        PLAYER_2_WIN
    }

    struct Fault {
        bool detected;
        // true is player 1, false is player 2
        bool isPlayer1;
    }

    // which is submitted by player before match started
    struct DataSubmitted {
        uint betAmount;
        string player2PubKey;
        string inviteLink;
        string proofLinkP1;
        string proofLinkP2;
    }

    struct MatchData {
        address player1;
        MatchResult player1SummitResult;
        MatchResult player2SummitResult;
        uint48 startTime;
        address player2;
        uint48 lastTimestamp;
        uint40 gameType;
        MatchState matchState;
        uint128 minBet;
        uint128 maxBet;
        DataSubmitted data;
        GameConfig matchConfig;
    }

    struct PlayerData {
        // total tc balance of player
        uint balance;
        // total match joined
        uint matches;
        // tracking state of user for each game
        // game type => player game state
        mapping(uint40 => PlayerGameState) playerStates;
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

    // @dev modifier
    modifier requireMatchState(uint matchId, MatchState inputState) {
        require(matches[matchId].matchState == inputState, "GB: invalid state");
        _;
    }

    modifier mustAvailableToJoin(uint40 gameType) {
        //        require(players[msg.sender].playerStates[gameType].playerState == PlayerState.DEFAULT, "GB: player already in game");
        _;
    }

    modifier onlyPlayerOf(uint256 _matchId) {
        if (msg.sender != matches[_matchId].player1 && msg.sender != matches[_matchId].player2) {
            revert ("GB:Not Player Of The Match");
        }
        _;
    }

    function initialize(address admin_, Register register_, GameConfig calldata initConfig_) external initializer {
        require(initConfig_.serviceFee + initConfig_.faultCharge <= UPPER_BOUND, "GB: invalid config");

        _transferOwnership(admin_);
        register = register_;
        gameConfig = initConfig_;
    }

    function version() external pure returns (string memory) {
        return "0.1.0";
    }

    // @notice player call this function to create new match
    function createMatch(uint40 gameType, uint minBet, uint maxBet, uint startTime) payable external mustAvailableToJoin(gameType) {
        // check account register
        require(register.checkUserRegister(msg.sender, gameType), "GB: user not registered");

        // check elo calculation contract is set
        IGamPolicy game = IGamPolicy(games[uint(gameType)]);
        require(address(game) != address(0) && maxBet >= minBet && minBet > 0, "GB: game not exist or invalid input");
        address player = msg.sender;
        uint betAmount = msg.value + players[player].balance;
        // check attached value with input max bet
        require(betAmount >= maxBet, "GB: insufficient balance");
        // check attached value with input max bet
        require(startTime > block.timestamp, "GB: game must start in future");
        // update total match and new id
        uint256 matchId = ++totalMatch;

        // validate amount max bet user can make
        require(game.maxCanBet(player, address(0), getEloByGameType(player, gameType)) >= maxBet, "GB: exceeded max bet");

        // update user balance
        unchecked {
            players[player].balance = betAmount - maxBet;
        }

        // init player 1
        matches[matchId].player1 = player;
        matches[matchId].gameType = uint32(gameType);
        matches[matchId].minBet = uint128(minBet);
        matches[matchId].maxBet = uint128(maxBet); // fault charge included
        matches[matchId].matchState = MatchState.WAITING_OPPONENT;
        matches[matchId].matchConfig = gameConfig;
        matches[matchId].startTime = uint48(startTime);

        // update player state for this game
        // players[player].playerStates[gameType].playerState = PlayerState.PLAYING;

        emit MatchCreation(matchId, player, gameType, minBet, maxBet, startTime);
        emit MatchStateUpdate(matchId, MatchState.WAITING_OPPONENT);
    }

    // @notice player wait too long for opponent so call this function to cancel
    function cancelMatch(uint matchId, uint gameType) external requireMatchState(matchId, MatchState.WAITING_OPPONENT) {
        if (matches[matchId].player1 != msg.sender) revert("GB: must be match creator");

        // silence the warning message
        gameType;

        // close this game
        matches[matchId].matchState = MatchState.GAME_CLOSED;
        players[matches[matchId].player1].balance += matches[matchId].maxBet;

        // update player state for this game
        // players[matches[matchId].player1].playerStates[uint40(gameType)].playerState = PlayerState.DEFAULT;

        emit MatchCancellation(matchId, msg.sender);
        emit MatchStateUpdate(matchId, MatchState.GAME_CLOSED);
    }

    // @notice Player 2 request to join challenge
    // @dev The match must not started and value attached in the tx must be in range as player 1 config
    function joinMatch(uint matchId, string calldata publicKey, uint betInput)
        payable external
        requireMatchState(matchId, MatchState.WAITING_OPPONENT)
        mustAvailableToJoin(matches[matchId].gameType)
    {
        // check this game started so must it must closed
        MatchData storage matchData = matches[matchId];
        address player = msg.sender;
        // check account register
        require(register.checkUserRegister(player, matchData.gameType), "GB: user not registered");
        require(uint256(matchData.startTime) > block.timestamp, "GB: this game is timeout");
        require(player != matchData.player1, "GB: can not join as player 2");

        // check game policy
        require(IGamPolicy(games[matchData.gameType]).playersCanMakeMatch(
            matchData.player1,
            getEloByGameType(matchData.player1, matchData.gameType),
            player,
            getEloByGameType(player, matchData.gameType)
        ), "GB: can not join this match");

        // check value in tx in range
        uint betAmount = msg.value + players[player].balance;
        require(betAmount >= betInput, "GB: insufficient balance");
        require(betInput >= matchData.minBet && betInput <= matchData.maxBet, "GB: bet value out range");

        // update user balance
        unchecked {
            players[player].balance = betAmount - betInput;
        }

        // update match data
        matchData.data.betAmount = betInput;
        matchData.matchState = MatchState.WAITING_INVITATION;
        matchData.lastTimestamp = uint48(block.timestamp);
        matchData.data.player2PubKey = publicKey;
        matchData.player2 = player;

        // update player state
        // players[player].playerStates[matchData.gameType].playerState = PlayerState.PLAYING;

        // emit event before tx ended
        emit JoinMatch(matchId, player, publicKey, betAmount);
        emit MatchStateUpdate(matchId, MatchState.WAITING_INVITATION);
    }

    // @notice player 1 submit invite link for opponent
    function submitInviteLink(uint matchId, string calldata inviteLink) external requireMatchState(matchId, MatchState.WAITING_INVITATION) {
        MatchData storage matchData = matches[matchId];
        require(block.timestamp >= matchData.startTime, "GB: game not start yet");
        require(block.timestamp - uint256(matchData.startTime) <= matchData.matchConfig.timeBuffer, "GB: timeout");

        // only player 1 of this match can call this function
        require(matchData.player1 == msg.sender, "GB: unauthorized");

        // update storage
        matchData.data.inviteLink = inviteLink;
        matchData.matchState = MatchState.MATCH_STARTED;
        matchData.lastTimestamp = uint48(block.timestamp);

        emit MatchInviteLinkSubmitted(matchId, msg.sender, inviteLink);
        emit MatchStateUpdate(matchId, MatchState.MATCH_STARTED);
    }

    // @note add resolver
    function addResolver(address resolver_, bool updateFlag_) external onlyOwner {
        require(resolver_ != address(0) && resolvers[resolver_] != updateFlag_, "GB: invalid resolver");

        resolvers[resolver_] = updateFlag_;

        emit UpdateResolver(resolver_, updateFlag_);
    }

    // @notice THIS SECTION DEFINE HOW GAME END AND AMOUNT EARNED

    // @notice handle draw game internally
    function _matchDraw(MatchData memory matchData, uint serviceFee) internal {
        players[matchData.player1].balance += matchData.maxBet - serviceFee / 2;
        players[matchData.player2].balance += matchData.data.betAmount - serviceFee / 2;
        if (serviceFee > 0) {
            players[owner()].balance += serviceFee;
        }
    }
    
    // @notice internal logic to handle game result
    function _handleResult(uint matchId, MatchState matchResult, Fault memory fault) internal {
        require(uint8(matchResult) > uint8(MatchState.GAME_CLOSED) ||
            matchResult == MatchState.REJECT_TO_JOIN_GAME ||
            matchResult == MatchState.PLAYER_1_TIMEOUT ||
            matchResult == MatchState.PLAYER_2_TIMEOUT, "GB:result must be win-draw state");

        MatchData storage matchData = matches[matchId];
        uint actualAmount = matchData.data.betAmount * UPPER_BOUND / (UPPER_BOUND + matchData.matchConfig.faultCharge + matchData.matchConfig.serviceFee);
        uint penaltyAmount = actualAmount * uint(matchData.matchConfig.faultCharge) / uint(UPPER_BOUND);
        uint serviceFeeAmount = (actualAmount * uint(matchData.matchConfig.serviceFee) / uint(UPPER_BOUND)) * 2;
        if (matchResult == MatchState.PLAYER_1_WIN) {
            // update player 1 balance
            players[matchData.player2].balance += penaltyAmount;
            players[matchData.player1].balance += uint(matchData.maxBet) + matchData.data.betAmount - penaltyAmount - serviceFeeAmount;
            players[owner()].balance += serviceFeeAmount;
        } else if (matchResult == MatchState.PLAYER_2_WIN) {
            // update player 2 balance
            players[matchData.player2].balance += 2 * matchData.data.betAmount - penaltyAmount - serviceFeeAmount;
            players[matchData.player1].balance += uint(matchData.maxBet) - matchData.data.betAmount + penaltyAmount;
            players[owner()].balance += serviceFeeAmount;
        } else if (matchResult == MatchState.PLAYER_1_TIMEOUT) {
            // @notice handle timeouts
            // player who does not take action in time will be charged faulty penalty amount and service fee
            players[matchData.player2].balance += matchData.data.betAmount + penaltyAmount;
            players[matchData.player1].balance += uint(matchData.maxBet) - penaltyAmount - serviceFeeAmount / 2;
            players[owner()].balance += serviceFeeAmount / 2;
        } else if (matchResult == MatchState.PLAYER_2_TIMEOUT) {
            players[matchData.player2].balance += matchData.data.betAmount - penaltyAmount - serviceFeeAmount / 2;
            players[matchData.player1].balance += uint(matchData.maxBet) + penaltyAmount;
            players[owner()].balance += serviceFeeAmount / 2;
        } else if (matchResult == MatchState.MATCH_DRAW) {
            // game draw
            _matchDraw(matchData, serviceFeeAmount);
        } else {
            // player B reject to join
            _matchDraw(matchData, 0);
        }

        // update match players competed
        if (uint8(matchResult) > uint8(MatchState.GAME_CLOSED)) {
            players[matchData.player1].matches++;
            players[matchData.player2].matches++;

            // update player elo
            (
                int elo1,
                int elo2
            ) = IGamPolicy(games[matchData.gameType]).getNewElo(
                getEloByGameType(matchData.player1, matchData.gameType),
                getEloByGameType(matchData.player2, matchData.gameType),
                players[matchData.player1].matches,
                players[matchData.player2].matches,
                int(uint(matchResult)) - int(uint(MatchState.MATCH_DRAW))
            );

            emit MatchElo(matchId, matchData.gameType,matchData.player1, elo1, matchData.player2, elo2);
            players[matchData.player1].playerStates[matchData.gameType].elo = elo1;
            players[matchData.player2].playerStates[matchData.gameType].elo = elo2;
        }

        // check fault is detected
        if (fault.detected) {
            players[fault.isPlayer1 ? matchData.player1 : matchData.player2].balance -= penaltyAmount;
            players[!fault.isPlayer1 ? matchData.player1 : matchData.player2].balance += penaltyAmount;
        }

        // update match state
        matchData.matchState = matchResult;

        // update player state
        // players[matchData.player1].playerStates[matchData.gameType].playerState = PlayerState.DEFAULT;
        // players[matchData.player2].playerStates[matchData.gameType].playerState = PlayerState.DEFAULT;
    }

    // @notice admin resolve dispute matches
    function resolveMatch(uint matchId, MatchState matchResult, Fault calldata fault) external requireMatchState(matchId, MatchState.DISPUTE_OCCURRED) {
        require(resolvers[msg.sender], "GB: unauthorized");

        // handle internally
        _handleResult(matchId, matchResult, fault);

        emit MatchStateUpdate(matchId, matchResult);
        emit MatchResolved(matchId, msg.sender, matchResult, fault);
    }

    // @notice player submit match result
    function submitResult(uint matchId, MatchResult result, string calldata proofLink) external onlyPlayerOf(matchId) {
        require(result != MatchResult.PLAYING, "GB: invalid result");
        // point to storage
        MatchData storage matchData = matches[matchId];

        // check game state
        require(matchData.matchState == MatchState.SUMMITING_RESULT ||
            matchData.matchState == MatchState.MATCH_STARTED,"GB: invalid match state");

        // can not submit game not started
        require(block.timestamp > matchData.startTime, "GB: game not started");
        // check if user already submitted result
        if (msg.sender == matchData.player1 && matchData.player1SummitResult != MatchResult.PLAYING ||
            msg.sender == matchData.player2 && matchData.player2SummitResult != MatchResult.PLAYING) {
            revert ("GB: user submitted result");
        }

        if (msg.sender == matchData.player1) {
            matchData.data.proofLinkP1 = proofLink;
        } else {
            matchData.data.proofLinkP2 = proofLink;
        }

        // only B can submit reject match first
        // todo: handle this flow


        // check not time out
        if (matchData.player1SummitResult != MatchResult.PLAYING && matchData.player2SummitResult != MatchResult.PLAYING) {
            matchData.lastTimestamp = uint48(block.timestamp);
        } else {
            require(block.timestamp - matchData.lastTimestamp < uint(matchData.matchConfig.timeSubmitMatchResult), "GB: time out");
        }

        // update storage
        if (msg.sender == matchData.player1) {
            matchData.player1SummitResult = result;
        } else {
            matchData.player2SummitResult = result;
        }

        // handle cases based result user submitted
        Fault memory temp = Fault(false, false);
        if (matchData.player1SummitResult == MatchResult.PLAYER_2_WON &&
            (matchData.player2SummitResult == MatchResult.PLAYER_2_WON || matchData.player2SummitResult == MatchResult.PLAYING))
        {
            _handleResult(matchId, MatchState.PLAYER_2_WIN, temp);
        } else if (matchData.player2SummitResult == MatchResult.PLAYER_1_WON &&
            (matchData.player1SummitResult == MatchResult.PLAYER_1_WON || matchData.player1SummitResult == MatchResult.PLAYING))
        {
            _handleResult(matchId, MatchState.PLAYER_1_WIN, temp);
        } else if (matchData.player2SummitResult == matchData.player1SummitResult &&
            (matchData.player2SummitResult == MatchResult.DREW || matchData.player2SummitResult == MatchResult.REJECT))
        {
            _handleResult(matchId, matchData.player2SummitResult == MatchResult.DREW ? MatchState.MATCH_DRAW : MatchState.REJECT_TO_JOIN_GAME, temp);
        } else if (matchData.player2SummitResult != MatchResult.PLAYING &&
            matchData.player1SummitResult != MatchResult.PLAYING)
        {
            matchData.matchState = MatchState.DISPUTE_OCCURRED;
        }

        // emit event for 3rd party
        if (matchData.matchState == MatchState.MATCH_STARTED) {
            matchData.matchState = MatchState.SUMMITING_RESULT;
        }

        emit MatchStateUpdate(matchId, matchData.matchState);
        emit ResultSubmitted(matchId, result, msg.sender, proofLink);
    }

    // @notice match timeout so trigger this function to claim as winner (anyone can call this function)
    function processMatch(uint matchId) external {
        // point to storage
        MatchData storage matchData = matches[matchId];

        // no-one join game
        if (matchData.matchState == MatchState.WAITING_OPPONENT) {
            require(block.timestamp > uint256(matchData.startTime), "GB: 0 not timeout yet");
            matchData.matchState = MatchState.GAME_CLOSED;
            players[matchData.player1].balance += uint(matchData.maxBet);

            emit MatchStateUpdate(matchId, MatchState.GAME_CLOSED);
            return;
        }

        // do nothing when the match is not started
        if (block.timestamp <= uint256(matchData.startTime)) {
            return;
        }

        // handle case someone join game
        require(block.timestamp - uint256(matchData.lastTimestamp) > matchData.matchConfig.timeBuffer, "GB: 1 not timeout yet");

        // these are state win for B
        if (matchData.matchState == MatchState.WAITING_INVITATION) {
            require(block.timestamp - uint256(matchData.startTime) > matchData.matchConfig.timeBuffer, "GB: 1 not timeout yet");
            emit TimeOutOccurred(matchId, matchData.matchState);

            _handleResult(matchId, MatchState.PLAYER_1_TIMEOUT, Fault(false, false));

            emit MatchStateUpdate(matchId, MatchState.PLAYER_1_TIMEOUT);
            return;
        }

        // handle case submitted result
        require(block.timestamp - uint256(matchData.lastTimestamp) > matchData.matchConfig.timeSubmitMatchResult, "GB: 2 not timeout yet");
        if (matchData.matchState == MatchState.SUMMITING_RESULT &&
            uint8(matchData.player2SummitResult) * uint8(matchData.player1SummitResult) == 0 &&
            matchData.player2SummitResult != matchData.player1SummitResult
        ) {
            MatchState matchResult;
            bool isPlayer1Fault;

            // emit event with reason for tracking purpose
            emit TimeOutOccurred(matchId, matchData.matchState);

            if (matchData.player1SummitResult == MatchResult.PLAYING) {
                // player 1 did not submit result to the match
                // charge fault amount
                matchResult = MatchState(uint8(matchData.player2SummitResult) + uint8(MatchState.GAME_CLOSED));
                isPlayer1Fault = true;
            } else {
                matchResult = MatchState(uint8(matchData.player1SummitResult) + uint8(MatchState.GAME_CLOSED));
            }

            _handleResult(matchId, matchResult, Fault(true, isPlayer1Fault));
            emit MatchStateUpdate(matchId, matchResult);

            return;
        }

        revert("GB: invalid state");
    }

    // @notice player claim TC
    // claim all
    function claim(address claimer_) external {
        claim(claimer_, players[claimer_].balance);
    }

    // @notice player claim TC
    // @dev claim with input amount
    function claim(address claimer_, uint amount_) public {
        uint availableAmount = players[claimer_].balance;
        if (amount_ <= availableAmount) {
            unchecked {
                players[claimer_].balance -= amount_;
            }
            (bool success,) = claimer_.call{value: amount_}("");
            require(success, "GB: claim failed");

            emit Claim(claimer_, amount_);
        }
    }

    // @dev admin call this function to update register contract address
    function updateRegisterContract(Register newRegister) external onlyOwner {
        require(address(newRegister) != address(0), "GameBase: munst not be zero");

        // shoot event here
        emit NewRegister(register, newRegister);

        register = newRegister;
    }

    // @dev admin call this function to register game elo calculation
    function registerGame(uint gameType, address newEloCalculationContract) external onlyOwner {
        require(games[gameType] == address(0) && gameType > 0, "GameBase: game registered");

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

    // @dev new game config
    function newConfig(GameConfig calldata newConfig_) external onlyOwner {
        require(newConfig_.serviceFee + newConfig_.faultCharge <= UPPER_BOUND, "GB: invalid config");

        gameConfig = newConfig_;

        emit NewGameConfig(newConfig_);
    }

    // @dev update user elo at init. Only called by register contract
    function setUserElo(address tcAddr, uint40 gameType, int elo) external {
        require(msg.sender == address(register), "GameBase: unauthorized");

        // check user it initialized
        require(players[tcAddr].playerStates[gameType].elo == 0, "GameBase: user initialized");

        // check elo calculation contract is set
        require(games[gameType] != address(0), "GameBase: game not exist");

        // update elo
        players[tcAddr].playerStates[gameType].elo = elo;

        emit InitElo(tcAddr, gameType, elo);
    }

    // @dev return elo of user based on game type
    function getEloByGameType(address tcAddr, uint40 gameType) public view returns(int) {
        return players[tcAddr].playerStates[gameType].elo;
    }

    // @dev return gamer info
    function getAccountInfo(address tcAddr, uint40 gameType) external view returns(string memory, int, uint, bool) {
        if  (!register.checkUserRegister(tcAddr, gameType) || games[gameType] == address(0)) {
            return ("", 0, 0, false);
        }

        int playerElo = getEloByGameType(tcAddr, gameType);
        return (register.getUserName(tcAddr, gameType), playerElo, IGamPolicy(games[gameType]).maxCanBet(tcAddr, address(0), playerElo), true);
    }
}
