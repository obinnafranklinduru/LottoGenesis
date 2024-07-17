// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title LottoGenesis Smart Contract
 * @author Obinna Franklin Duru
 * @notice This contract is for creating a sample lottery contract
 * @dev This implements the Chainlink VRF Version 2
 */
contract LottoGenesis is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    // Enumeration to represent the state of the lottery
    enum LottoGenesisState {
        OPEN,
        CALCULATING
    }

    // Constants
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // Number of confirmations for VRF request
    uint32 private constant NUM_WORDS = 1; // Number of random words requested
    uint256 private constant OWNER_PERCENTAGE = 10; // Owner's share in percentage

    // Immutable variables
    uint256 private immutable i_entranceFee; // Fee to enter the lottery
    uint256 private immutable i_interval; // Time interval between lottery draws
    uint256 private immutable i_subscriptionId; // Chainlink VRF subscription ID
    uint32 private immutable i_callbackGasLimit; // Gas limit for callback function
    bytes32 private immutable i_keyHash; // Key hash for Chainlink VRF

    // State variables
    uint256 private s_lastTimeStamp; // Last time a winner was picked
    address payable[] private s_players; // Array of players in the lottery
    address payable private s_recentWinner; // Most recent winner of the lottery
    LottoGenesisState private s_lottoGenesisState; // Current state of the lottery

    // Mapping to track if an address has already entered the lottery
    mapping(address => bool) private s_isPlayer;

    // Events
    event EnteredLottoGenesis(address indexed player, uint256 amount);
    event RequestedLottoGenesisWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner, uint256 amount, uint256 timestamp);
    event WinnerWithdrawal(address indexed winner, uint256 amount, bytes data);
    event OwnerWithdrawal(address indexed owner, uint256 amount, bytes data);

    // Errors
    error LottoGenesis_TransferFailed();
    error LottoGenesis_IsPlayerLottoGenesis();
    error LottoGenesis_SendMoreToEnterLottoGenesis();
    error LottoGenesis_LottoGenesisNotOpen();
    error LottoGenesis_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 lottoGenesisState);

    /**
     * @notice Constructor to initialize the lottery contract
     * @param _entranceFee The fee to enter the lottery
     * @param _interval The time interval between lottery draws
     * @param _vrfCoordinator The address of the VRF coordinator contract
     * @param _keyHash The key hash for the VRF
     * @param _subscriptionId The subscription ID for the VRF
     * @param _callbackGasLimit The gas limit for the callback function
     */
    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_keyHash = _keyHash;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lottoGenesisState = LottoGenesisState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    /**
     * @notice Function to enter the lottery
     * @dev Players need to send enough ETH to enter the lottery
     */
    function enterLottoGenesis() public payable {
        if (msg.value < i_entranceFee) revert LottoGenesis_SendMoreToEnterLottoGenesis();
        if (s_lottoGenesisState != LottoGenesisState.OPEN) revert LottoGenesis_LottoGenesisNotOpen();
        if (s_isPlayer[msg.sender]) revert LottoGenesis_IsPlayerLottoGenesis();

        s_players.push(payable(msg.sender)); // Add the player to the players array
        s_isPlayer[msg.sender] = true; // Mark the player as entered

        emit EnteredLottoGenesis(msg.sender, msg.value);
    }

    /**
     * @notice Function to check if upkeep is needed
     * @return upkeepNeeded A boolean indicating if upkeep is needed
     * @return performData The data to perform the upkeep
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = LottoGenesisState.OPEN == s_lottoGenesisState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @notice Function to perform the upkeep
     * @dev Requests random words from the VRF coordinator
     */
    function performUpkeep(bytes calldata /* performData */ ) external override {
        // Check if upkeep is needed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert LottoGenesis_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_lottoGenesisState));
        }

        s_lottoGenesisState = LottoGenesisState.CALCULATING; // Set state to CALCULATING

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        emit RequestedLottoGenesisWinner(requestId);
    }

    /**
     * @notice Function to fulfill the random words request
     * @param randomWords The array of random words
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // This approach ensures fairness and unpredictability in selecting a winner.
        // randomWords[0] is a large random number provided by Chainlink VRF
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;

        // Reset the players array and mapping
        for (uint256 i = 0; i < s_players.length; i++) {
            delete s_isPlayer[s_players[i]];
        }
        s_players = new address payable[](0);

        s_lottoGenesisState = LottoGenesisState.OPEN;
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(recentWinner, address(this).balance, block.timestamp);

        // Calculate the owner's share
        uint256 ownerShare = (address(this).balance * OWNER_PERCENTAGE) / 100;

        // Transfer the owner's share
        (bool ownerSuccess, bytes memory ownerData) = payable(owner()).call{value: ownerShare}("");
        if (!ownerSuccess) revert LottoGenesis_TransferFailed();

        emit OwnerWithdrawal(owner(), ownerShare, ownerData);

        // Transfer the remaining balance to the winner
        (bool winnerSuccess, bytes memory winnerData) = payable(recentWinner).call{value: address(this).balance}("");
        if (!winnerSuccess) revert LottoGenesis_TransferFailed();

        emit WinnerWithdrawal(recentWinner, address(this).balance, winnerData);
    }

    // Getter functions
    function getsLottoGenesisState() public view returns (LottoGenesisState) {
        return s_lottoGenesisState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getOwnerPercentage() public pure returns (uint256) {
        return OWNER_PERCENTAGE;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
