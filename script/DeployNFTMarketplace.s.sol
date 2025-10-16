// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "lib/forge-std/src/Script.sol";
import {NFTMarketplace} from "src/core/NFTMarketplace.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Constants} from "src/utils/Constants.sol";

contract DeployNFTMarketplace is Script {
    function run() external returns(NFTMarketplace, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig(block.chainid);
        vm.startBroadcast();
        NFTMarketplace nftMarketplace = new NFTMarketplace(
            networkConfig.subscriptionId,
            networkConfig.vrfCoordinator,
            networkConfig.keyHash,
            Constants.CALLBACK_GAS_LIMIT,
            networkConfig.listingFee,
            networkConfig.mintFee,
            networkConfig.marketplaceFeeBP,
            networkConfig.listingDelay,
            networkConfig.baseURI
        );
        vm.stopBroadcast();
        return (nftMarketplace, helperConfig);
    }
}
