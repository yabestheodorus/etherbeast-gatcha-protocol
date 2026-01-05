// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title HelperConfig.s
 * @author Yabes Theodorus
 * @notice Short description of contract
 * @dev Created 2025
 */

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address vrfCoordinatorAddress;
        address priceFeedAddress;
        bytes32 keyHash;
        uint256 subsId;
        address account;
        address linkToken;
    }

    mapping(uint256 chainid => NetworkConfig) public networkConfigs;
    NetworkConfig public localNetworkConfig;

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    bytes32 public constant SEPOLIA_VRF_KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address public constant SEPOLIA_VRF_COORDINATOR_ADDRESS = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 public constant SEPOLIA_VRF_SUBSCRIPTION_ID =
        13074068587117050620781944959623479184386631213452623555274303699555248223233;
    address public constant SEPOLIA_PRICE_FEED_ADDRESS = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant SEPOLIA_LINK_TOKEN_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    /* VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH Price
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].vrfCoordinatorAddress != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            vrfCoordinatorAddress: SEPOLIA_VRF_COORDINATOR_ADDRESS,
            priceFeedAddress: SEPOLIA_PRICE_FEED_ADDRESS,
            keyHash: SEPOLIA_VRF_KEY_HASH,
            subsId: SEPOLIA_VRF_SUBSCRIPTION_ID,
            account: 0x0F2c9d22e0CEdA6A4Fc22bF2642C3397994222db,
            linkToken: SEPOLIA_LINK_TOKEN_ADDRESS
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // check to see if we set an active network config
        if (localNetworkConfig.vrfCoordinatorAddress != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            vrfCoordinatorAddress: address(vrfCoordinatorMock),
            priceFeedAddress: address(ethUsdPriceFeed),
            keyHash: bytes32(0),
            subsId: 0,
            // account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            linkToken: address(linkToken)
        });

        return localNetworkConfig;
    }
}
