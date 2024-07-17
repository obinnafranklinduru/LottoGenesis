// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {LottoGenesis} from "../../src/LottoGenesis.sol";
import {DeployLottoGenesis} from "../../script/LottoGenesis.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract LottoGenesisTest is Test, CodeConstants {
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

    uint256 subscriptionId;
    bytes32 keyHash;
    uint256 automationUpdateInterval;
    uint256 lottoGenesisEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    function setUp() public {
        DeployLottoGenesis deployer = new DeployLottoGenesis();
        (lottoGenesis, helperConfig) = deployer.run();

        vm.deal(PLAYER, STARTING_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        automationUpdateInterval = config.automationUpdateInterval;
        lottoGenesisEntranceFee = config.lottoGenesisEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    function testLottoGenesisInitializesInOpenState() public view {
        assert(lottoGenesis.getsLottoGenesisState() == LottoGenesis.LottoGenesisState.OPEN);
    }

    function testEnterLottoGenesis() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
        address playerInContract = lottoGenesis.getPlayer(0);
        assert(playerInContract == PLAYER);
    }

    function testFailIfAlreadyEntered() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();

        vm.expectRevert(LottoGenesis.LottoGenesis_IsPlayerLottoGenesis.selector);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
    }

    function testEntranceFeeRequirement() public view {
        assert(lottoGenesisEntranceFee == lottoGenesis.getEntranceFee());
    }

    function testShouldRecordWhenTheyEnter() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
        address player = lottoGenesis.getPlayer(0);
        assert(player == PLAYER);
    }

    function testEnterLottoGenesisEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, true, false, true, address(lottoGenesis));
        emit EnteredLottoGenesis(PLAYER, lottoGenesisEntranceFee);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
    }

    function testCantEnterWhenLottoGenesisIsCalculating() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
        vm.warp(block.timestamp + lottoGenesisEntranceFee + 1);
        vm.roll(block.number + 1);
        lottoGenesis.performUpkeep("");

        vm.expectRevert(LottoGenesis.LottoGenesis_LottoGenesisNotOpen.selector);
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfIthasNoBalance() public {
        vm.warp(block.timestamp + lottoGenesisEntranceFee + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = lottoGenesis.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfLottoGenesisNotOpen() public {
        vm.prank(PLAYER);
        lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
        vm.warp(block.timestamp + lottoGenesisEntranceFee + 1);
        vm.roll(block.number + 1);
        lottoGenesis.performUpkeep("");

        (bool upkeepNeeded,) = lottoGenesis.checkUpkeep("");

        assert(upkeepNeeded == false);
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
    //     lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
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
    //     lottoGenesis.enterLottoGenesis{value: lottoGenesisEntranceFee}();
    //     uint256[] memory randomWords = new uint256[](1);
    //     randomWords[0] = 1;
    //     lottoGenesis.fulfillRandomWords(0, randomWords);
    //     assert(lottoGenesis.getRecentWinner() == PLAYER);
    //     assert(lottoGenesis.getNumberOfPlayers() == 0);
    // }
}
