// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

// Define an abstract contract to hold common constants
abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

// Define the HelperConfig contract which provides network configurations based on chain ID
contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 keyHash;
        uint256 automationUpdateInterval;
        uint256 lottoGenesisEntranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2_5;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }

    // Function to get the configuration based on the current chain ID
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    // Function to get the configuration based on a specified chain ID
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    // Function to get the mainnet Ethereum configuration
    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            subscriptionId: 0,
            keyHash: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            automationUpdateInterval: 30,
            lottoGenesisEntranceFee: 0.01 ether,
            callbackGasLimit: 500000,
            vrfCoordinatorV2_5: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D
        });
    }

    // Function to get the Sepolia Ethereum configuration
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            subscriptionId: 0,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            automationUpdateInterval: 30,
            lottoGenesisEntranceFee: 0.01 ether,
            callbackGasLimit: 500000,
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D
        });
    }

    // Function to get or create the local Anvil Ethereum configuration
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) return localNetworkConfig;

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);

        LinkToken link = new LinkToken();
        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: subscriptionId,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            automationUpdateInterval: 30,
            lottoGenesisEntranceFee: 0.01 ether,
            callbackGasLimit: 500000,
            vrfCoordinatorV2_5: address(vrfCoordinatorV2_5Mock),
            link: address(link),
            account: FOUNDRY_DEFAULT_SENDER
        });
        vm.deal(localNetworkConfig.account, 100 ether);
        return localNetworkConfig;
    }
}