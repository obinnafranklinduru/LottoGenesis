// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LottoGenesis} from "../src/LottoGenesis.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    // Active network configuration
    NetworkConfig public activeNetworkConfig;

    // Structure to hold network configuration
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    // Constructor to set the active network configuration based on the chain ID
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = _getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = _getMainnetEthConfig();
        } else {
            activeNetworkConfig = _getOrCreateAnvilEthConfig();
        }
    }

    // Function to get the Sepolia Ethereum network configuration
    function _getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 5000000,
            link: address(0x779877A7B0D9E8603169DdbD7836e478b4624789)
        });
    }

    // Function to get the Mainnet Ethereum network configuration
    function _getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(0xD7f86b4b8Cae7D942340FF628F82735b7a20893a),
            keyHash: 0xc6bf2e7b88e5cfbb4946ff23af846494ae1f3c65270b79ee7876c9aa99d3d45f,
            subscriptionId: 0,
            callbackGasLimit: 5000000,
            link: address(0x514910771AF9Ca656af840dff83E8264EcF986CA)
        });
    }

    // Function to get or create the Anvil Ethereum network configuration
    function _getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        LinkToken linkToken = new LinkToken();

        uint96 baseFee = 0.25 ether; // 0.25LINK
        uint96 gasPriceLink = 1e9; // I gwei LIMK

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        vm.stopBroadcast();

        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            keyHash: 0xc6bf2e7b88e5cfbb4946ff23af846494ae1f3c65270b79ee7876c9aa99d3d45f,
            subscriptionId: 0,
            callbackGasLimit: 5000000,
            link: address(linkToken)
        });
    }
}
