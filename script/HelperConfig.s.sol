// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "lib/forge-std/src/Script.sol";
import {Constants} from "src/utils/Constants.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "lib/chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 subscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        address linkToken;

        uint256 listingFee;         
        uint256 mintFee;            
        uint256 marketplaceFeeBP;   
        uint256 listingDelay;        
        string baseURI;  
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public s_networkConfigs;

    constructor() {
        s_networkConfigs[Constants.BASE_SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getNetworkConfig(block.chainid);
    }

    function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            subscriptionId: 89326579730262994489337811002733937432071033134851243132570825425457199230002,
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE,
            keyHash: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            linkToken: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,

            listingFee: 0.001 ether,
            mintFee: 0.001 ether,
            marketplaceFeeBP: 30, // 3% (30 / 1000)
            listingDelay: 30, // 30 giây
            baseURI: "ipfs://"
        });
    }

    function getLocalNetworkConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            Constants.MOCK_VRF_BASE_FEE,
            Constants.MOCK_VRF_GAS_PRICE,
            Constants.MOCK_VRF_WEI_PER_UINT
        );
        uint256 newSubscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        MockLinkToken linkToken = new MockLinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: newSubscriptionId,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            keyHash: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            linkToken: address(linkToken),

            listingFee: 0.001 ether,
            mintFee: 0.001 ether,
            marketplaceFeeBP: 30,
            listingDelay: 30,
            baseURI: "ipfs://"
        });

        return localNetworkConfig;
    }

    function getNetworkConfig(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == Constants.BASE_SEPOLIA_CHAIN_ID) {
            return s_networkConfigs[chainId];
        } else if (chainId == Constants.ANVIL_CHAIN_ID) {
            return getLocalNetworkConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }
}
