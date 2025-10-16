// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from
    "lib/chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from
    "lib/chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "../storage/NFTStorage.sol";
import {console} from "lib/forge-std/src/Script.sol";

interface IMintCallback {
    function fulfillRandomMint(uint256 requestId, uint256[] calldata randomWords) external;
}

contract VRFHandler is VRFConsumerBaseV2Plus, NFTStorage {
    // marketplace là địa chỉ có quyền yêu cầu random
    bytes32 public keyHash;
    uint256 public subId;
    uint32 public callbackGasLimit;
    address public marketplace;

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subId,
        uint32 _callbackGasLimit,
        address _marketplace
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        keyHash = _keyHash;
        subId = _subId;
        callbackGasLimit = _callbackGasLimit;
        marketplace = _marketplace;
    }

    function requestRandomWords() external returns (uint256) {
        // require(msg.sender == address(marketplace), "Only marketplace");
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        internal
        override
    {
        IMintCallback(marketplace).fulfillRandomMint(requestId, randomWords);
    }
}
