// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LottoGenesis} from "../src/LottoGenesis.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (,, address vrfCoordinator,,,,) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address _vrfCoordinator) public returns (uint64) {
        console.log("Creating Subscription on ChainId: ", block.chainid);

        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("subId: ", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        (,, address vrfCoordinator,, uint64 subscriptionId,, address link) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subscriptionId, link);
    }

    function fundSubscription(address _vrfCoordinator, uint64 _subscriptionId, address _link) public {
        console.log("funding Subscription on ChainId: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(_vrfCoordinator).fundSubscription(_subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(_link).transferAndCall(_vrfCoordinator, FUND_AMOUNT, abi.encode(_subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address _lottoGenesis) public {
        HelperConfig helperConfig = new HelperConfig();

        (,, address vrfCoordinator,, uint64 subscriptionId,,) = helperConfig.activeNetworkConfig();

        addConsumer(_lottoGenesis, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address _lottoGenesis, address _vrfCoordinator, uint64 _subscriptionId) public {
        console.log("Adding a Consumer on ChainId: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2Mock(_vrfCoordinator).addConsumer(_subscriptionId, _lottoGenesis);
        vm.stopBroadcast();
    }

    function run() external {
        address lottoGenesis = DevOpsTools.get_most_recent_deployment("LottoGenesis", block.chainid);

        addConsumerUsingConfig(lottoGenesis);
    }
}
