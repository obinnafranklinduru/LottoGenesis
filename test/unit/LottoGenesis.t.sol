// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LottoGenesis} from "../../src/LottoGenesis.sol";
import {DeployLottoGenesis} from "../../script/LottoGenesis.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract LottoGenesisTest is Test {
    LottoGenesis lottoGenesis;
    HelperConfig helperConfig;

    // Events
    event EnteredLottoGenesis(address indexed player, uint256 amount);
    event RequestedLottoGenesisWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed winner, uint256 amount, bytes data);

    address PLAYER = makeAddr("player");
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    // Setup function to deploy the EthFund contract and provide initial balances
    function setUp() public {
        DeployLottoGenesis deployLottoGenesis = new DeployLottoGenesis();
        (lottoGenesis, helperConfig) = deployLottoGenesis.run();

        vm.deal(PLAYER, STARTING_BALANCE);

        (
            entranceFee,
            interval,
            vrfCoordinator,
            keyHash,
            subscriptionId,
            callbackGasLimit,
            /* link */
        ) = helperConfig.activeNetworkConfig();
    }

    function testLottoGenesisInitializesInOpenState() public view {
        assert(lottoGenesis.getsLottoGenesisState() == LottoGenesis.LottoGenesisState.OPEN);
    }

    function testEnterLottoGenesis() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();
        address playerInContract = lottoGenesis.getPlayer(0);
        assert(playerInContract == PLAYER);
    }

    function testFailIfAlreadyEntered() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();

        vm.expectRevert(LottoGenesis.LottoGenesis_IsPlayerLottoGenesis.selector);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();
    }

    function testEntranceFeeRequirement() public view {
        assert(entranceFee == lottoGenesis.getEntranceFee());
    }

    function testShouldRecordWhenTheyEnter() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();
        address player = lottoGenesis.getPlayer(0);
        assert(player == PLAYER);
    }

    function testEnterLottoGenesisEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, true, false, true, address(lottoGenesis));
        emit EnteredLottoGenesis(PLAYER, entranceFee);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();
    }

    function testCantEnterWhenLottoGenesisIsCalculating() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottoGenesis.performUpkeep("");

        vm.expectRevert(LottoGenesis.LottoGenesis_LottoGenesisNotOpen.selector);
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: entranceFee}();
    }

    // function testWinnerSelectionAndPayout() public {
    //     vm.prank(PLAYER);
    //     uint256[] memory randomWords = new uint256[](1);
    //     randomWords[0] = 1;
    //     lottoGenesis.fulfillRandomWords(0, randomWords);
    //     assert(lottoGenesis.getRecentWinner() == PLAYER);
    // }

    // function testUpkeepNeeded() public {
    //     vm.prank(PLAYER);
    //     lottoGenesis.enterLottoGenesis{value: entranceFee}();
    //     bool upkeepNeeded;
    //     (upkeepNeeded, ) = lottoGenesis.checkUpkeep("");
    //     assert(upkeepNeeded == true);
    // }

    // function testUpkeepNotNeeded() public {
    //     vm.prank(PLAYER);
    //     bool upkeepNeeded;
    //     (upkeepNeeded, ) = lottoGenesis.checkUpkeep("");
    //     assert(upkeepNeeded == false);
    // }

    // function testFulfillRandomWords() public {
    //     vm.prank(PLAYER);
    //     lottoGenesis.enterLottoGenesis{value: entranceFee}();
    //     uint256[] memory randomWords = new uint256[](1);
    //     randomWords[0] = 1;
    //     lottoGenesis.fulfillRandomWords(0, randomWords);
    //     assert(lottoGenesis.getRecentWinner() == PLAYER);
    //     assert(lottoGenesis.getNumberOfPlayers() == 0);
    // }
}
