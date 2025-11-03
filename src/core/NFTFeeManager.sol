// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

/// @title NFT Fee Manager Module
/// @notice Manages fees, royalties, and proceeds withdrawal
abstract contract NFTFeeManager is NFTBase, NFTStorage {

    /// @notice Withdraw accumulated proceeds
    function withdrawProceeds() public {
        uint256 amount = s_proceeds[msg.sender];
        if(amount == 0) {
            revert NFTMarketplace__NoProceeds();
        }

        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if(!success){
            revert NFTMarketplace__WithdrawProceedsFailed();
        }

        emit Events.Withdraw(msg.sender);
    }
    
    /// @notice Update the listing fee
    /// @param _newPrice New listing fee in wei
    function updateListingFee(uint256 _newPrice) public {
        if (_newPrice == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }

        s_listingFee = _newPrice;

        emit Events.ListingFeeUpdated(_newPrice);
    }

    /// @notice Update the mint fee
    /// @param _newPrice New mint fee in wei
    function updateMintFee(uint256 _newPrice) public {
        if (_newPrice == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }

        s_mintFee = _newPrice;

        emit Events.MintFeeUpdated(_newPrice);
    }

    /// @notice Update the marketplace fee percentage
    /// @param _newPercent New fee in basis points (max 100 = 10%)
    function updateMarketplaceFee(uint256 _newPercent) public {
        if(_newPercent <= 0 || _newPercent > 100){ // Max: 10%
            revert NFTMarketplace__MarketplaceFeeOutOfRange();
        }

        s_marketplaceFeeBP = _newPercent;

        emit Events.MarketplaceFeeUpdate(_newPercent);
    }

    /// @notice Set token-specific royalty
    /// @param tokenId Token ID
    /// @param receiver Royalty receiver address
    /// @param feeNumerator Royalty percentage in basis points
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) public {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /// @notice Reset token royalty to default
    /// @param tokenId Token ID
    function resetTokenRoyalty(uint256 tokenId) public {
        _resetTokenRoyalty(tokenId);
    }

    /// @notice Update the listing delay period
    /// @param _newDelay New delay in seconds
    function updateListingDelay(uint256 _newDelay) public {
        s_listingDelay = _newDelay;
        emit Events.ListingDelayUpdated(_newDelay);
    }
}
