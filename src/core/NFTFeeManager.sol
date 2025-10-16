// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

abstract contract NFTFeeManager is NFTBase, NFTStorage {

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
    
    function updateListingFee(uint256 _newPrice) public {
        if (_newPrice == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }

        s_listingFee = _newPrice;

        emit Events.ListingFeeUpdated(_newPrice);
    }

    function updateMintFee(uint256 _newPrice) public {
        if (_newPrice == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }

        s_mintFee = _newPrice;

        emit Events.MintFeeUpdated(_newPrice);
    }

    function updateMarketplaceFee(uint256 _newPercent) public {
        if(_newPercent <= 0 || _newPercent > 100){ // Max: 10%
            revert NFTMarketplace__MarketplaceFeeOutOfRange();
        }

        s_marketplaceFeeBP = _newPercent;

        emit Events.MarketplaceFeeUpdate(_newPercent);
    }

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) public {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) public {
        _resetTokenRoyalty(tokenId);
    }

    function updateListingDelay(uint256 _newDelay) public {
        if(_newDelay < 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }

        s_listingDelay = _newDelay;
        emit Events.ListingDelayUpdated(_newDelay);
    }
}
