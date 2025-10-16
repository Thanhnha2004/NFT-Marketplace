// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Contract giả lập việc từ chối nhận ETH — dùng để test lệnh call{value: x} thất bại
contract MocksTransferFailed {
    receive() external payable {
        revert("ETH transfer failed");
    }
}
