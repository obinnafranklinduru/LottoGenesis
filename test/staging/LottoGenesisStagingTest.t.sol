// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployLottoGenesis} from "../../script/LottoGenesis.s.sol";
import {LottoGenesis} from "../../src/LottoGenesis.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription} from "../../script/Interaction.s.sol";

contract LottoGenesisTest is StdCheats, Test {
    event EnteredLottoGenesis(address indexed player, uint256 amount);
    event RequestedLottoGenesisWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner, uint256 amount, uint256 timestamp);

    LottoGenesis public lottoGenesis;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 keyHash;
    uint256 automationUpdateInterval;
    uint256 lottoGenesisEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployLottoGenesis deployer = new DeployLottoGenesis();
        (lottoGenesis, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        automationUpdateInterval = config.automationUpdateInterval;
        lottoGenesisEntranceFee = config.lottoGenesisEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
    }

    modifier lottoGenesisEntered() {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier onlyOnDeployedContracts() {
        if (block.chainid == 31337) {
            return;
        }
        try vm.activeFork() returns (uint256) {
            return;
        } catch {
            _;
        }
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        lottoGenesisEntered
        onlyOnDeployedContracts
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(0, address(lottoGenesis));

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(1, address(lottoGenesis));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        lottoGenesisEntered
        onlyOnDeployedContracts
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
        }

        uint256 startingTimeStamp = lottoGenesis.getLastTimeStamp();

        // Act
        vm.recordLogs();
        lottoGenesis.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(lottoGenesis));

        // Assert
        address recentWinner = lottoGenesis.getRecentWinner();
        LottoGenesis.LottoGenesisState lottoGenesisState = lottoGenesis.getsLottoGenesisState();
        uint256 endingTimeStamp = lottoGenesis.getLastTimeStamp();

        assert(recentWinner == expectedWinner);
        assert(uint256(lottoGenesisState) == 0);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
