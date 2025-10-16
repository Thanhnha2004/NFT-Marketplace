// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Constants {
    uint256 public constant ENTRANCE_FEE = 0.01 ether;
    uint96 public constant ROYALTY_FEE = 1000; // 5%
    uint32 public constant CALLBACK_GAS_LIMIT = 500000;
    uint256 public constant MARKETPLACE_FEE_DENOM = 1000;
    uint32 public constant AUCTION_EXTENSION = 600; // 10 phút
    uint256 public constant MIN_BID_INCREMENT_PCT = 50; // 5% increment
    uint256 public constant BID_INCREMENT_DENOM = 1000;
    uint256 public constant MAX_BATCH_SIZE = 50;

    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    uint96 public constant MOCK_VRF_BASE_FEE = 0.25 ether; // số tiền cố định phải trả khi lấy số ngẫu nhiên
    uint96 public constant MOCK_VRF_GAS_PRICE = 1e9; // gas price khi call lệnh lúc đó, mock thì set cứng
    int256 public constant MOCK_VRF_WEI_PER_UINT = 4e15; // LINK / ETH price
}