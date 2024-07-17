// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LottoGenesis} from "../src/LottoGenesis.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

// DeployLottoGenesis contract inherits from Script, which provides useful methods for deployment and interaction with contracts
contract DeployLottoGenesis is Script {
    // Main function that deploys LottoGenesis and HelperConfig contracts
    function run() external returns (LottoGenesis, HelperConfig) {
        // Create a new instance of the HelperConfig contract
        HelperConfig helperConfig = new HelperConfig();
        // Create a new instance of the AddConsumer contract
        AddConsumer addConsumer = new AddConsumer();
        // Get network configuration from HelperConfig
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Check if a Chainlink VRF subscription is needed
        if (config.subscriptionId == 0) {
            // Create a new subscription if one does not exist
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5, config.account);

            // Fund the newly created subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );
        }

        // Start broadcasting transactions from the specified account
        vm.startBroadcast(config.account);
        // Deploy the LottoGenesis contract with parameters from the network configuration
        LottoGenesis lottoGenesis = new LottoGenesis(
            config.lottoGenesisEntranceFee,
            config.automationUpdateInterval,
            config.vrfCoordinatorV2_5,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );
        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Add the LottoGenesis contract as a consumer to the Chainlink VRF subscription
        addConsumer.addConsumer(address(lottoGenesis), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);

        // Return the deployed LottoGenesis and HelperConfig contracts
        return (lottoGenesis, helperConfig);
    }
}
