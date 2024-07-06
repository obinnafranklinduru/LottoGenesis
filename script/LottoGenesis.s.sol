// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LottoGenesis} from "../src/LottoGenesis.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployLottoGenesis is Script {
    function run() external returns (LottoGenesis, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 keyHash,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            /* address link */
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.run();
            console.log("first subId: ", subscriptionId);
            // subscriptionId = createSubscription.createSubscription(vrfCoordinator);
            console.log("second subId: ", createSubscription.createSubscription(vrfCoordinator));

            //Fund it
            FundSubscription fundSubscription = new FundSubscription();
            

        }

        vm.startBroadcast();
        LottoGenesis lottoGenesis =
            new LottoGenesis(entranceFee, interval, vrfCoordinator, keyHash, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();

        return (lottoGenesis, helperConfig);
    }
}
