// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {LottoGenesis} from "../src/LottoGenesis.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CodeConstants} from "./HelperConfig.s.sol";

// CreateSubscription contract is responsible for creating a new Chainlink VRF subscription
contract CreateSubscription is Script {
    // Function to create a subscription using configuration from HelperConfig
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainId(block.chainid).account;

        return createSubscription(vrfCoordinatorV2_5, account);
    }

    // Function to create a subscription given a VRF coordinator address and account
    function createSubscription(address _vrfCoordinatorV2_5, address _account) public returns (uint256, address) {
        console.log("Creating Subscription on ChainId: ", block.chainid);

        vm.startBroadcast(_account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();

        console.log("subId: ", subId);
        return (subId, _vrfCoordinatorV2_5);
    }

    // Main function that runs the createSubscriptionUsingConfig function
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

// AddConsumer contract is responsible for adding a consumer to an existing Chainlink VRF subscription
contract AddConsumer is Script {
    // Function to add a consumer given a contract address, VRF coordinator address, subscription ID, and account
    function addConsumer(address _contractToAddToVrf, address _vrfCoordinator, uint256 _subId, address _account) public {
        console.log("Adding consumer contract: ", _contractToAddToVrf);
        console.log("Using vrfCoordinator: ", _vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(_account);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _contractToAddToVrf);
        vm.stopBroadcast();
    }

    // Function to add a consumer using configuration from HelperConfig and the most recently deployed contract address
    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;

        addConsumer(_mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    // Main function that runs the addConsumerUsingConfig function
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("LottoGenesis", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

// FundSubscription contract is responsible for funding a Chainlink VRF subscription
contract FundSubscription is CodeConstants, Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    // Function to fund a subscription using configuration from HelperConfig
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVRFv2;
            console.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinatorV2_5);
        }

        fundSubscription(vrfCoordinatorV2_5, subId, link, account);
    }

    // Function to fund a subscription given a VRF coordinator address, subscription ID, Link token address, and account
    function fundSubscription(address _vrfCoordinatorV2_5, uint256 _subId, address _link, address _account) public {
        console.log("Funding subscription: ", _subId);
        console.log("Using vrfCoordinator: ", _vrfCoordinatorV2_5);
        console.log("On ChainID: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(_account);
            VRFCoordinatorV2_5Mock(_vrfCoordinatorV2_5).fundSubscription(_subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(_link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(_link).balanceOf(address(this)));
            console.log(address(this));

            vm.startBroadcast(_account);
            LinkToken(_link).transferAndCall(_vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(_subId));
            vm.stopBroadcast();
        }
    }

    // Main function that runs the fundSubscriptionUsingConfig function
    function run() external {
        fundSubscriptionUsingConfig();
    }
}