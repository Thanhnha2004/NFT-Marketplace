// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

/// @title NFT Getters Module
/// @notice View functions for querying marketplace state
abstract contract NFTGetters is NFTBase, NFTStorage {

    /// @notice Get market item details
    /// @param _tokenId Token ID
    /// @return MarketItem struct
    function getItemForTokenId(uint256 _tokenId) public view returns(MarketItem memory){
        return s_idToMarketItem[_tokenId];
    }

    /// @notice Get offer details for a specific bidder
    /// @param _tokenId Token ID
    /// @param bidder Bidder address
    /// @return Offer struct
    function getOfferForTokenId(uint256 _tokenId, address bidder) public view returns(Offer memory){
        return s_offersByToken[_tokenId][bidder];
    }

    /// @notice Get auction details
    /// @param _tokenId Token ID
    /// @return Auction struct
    function getAuctionForTokenId(uint256 _tokenId) public view returns(Auction memory){
        return s_auctions[_tokenId];
    }

    /// @notice Get current token ID counter
    /// @return Current token ID
    function getCurrentTokenId() public view returns(uint256){
        return s_tokenId;
    }

    /// @notice Get total items sold
    /// @return Number of sold items
    function getItemSold() public view returns(uint256){
        return s_itemsSold;
    }

    /// @notice Get proceeds balance for an address
    /// @param addr Address to query
    /// @return Proceeds amount in wei
    function getProceedsForAddress(address addr) public view returns(uint256){
        return s_proceeds[addr];
    }

    /// @notice Get token ID counter
    /// @return Token ID
    function getTokenId() public view returns(uint256){
        return s_tokenId;
    }

    /// @notice Get listing fee
    /// @return Fee in wei
    function getListingFee() public view returns(uint256){
        return s_listingFee;
    }

    /// @notice Get mint fee
    /// @return Fee in wei
    function getMintFee() public view returns(uint256){
        return s_mintFee;
    }

    /// @notice Get listing delay
    /// @return Delay in seconds
    function getListingDelay() public view returns(uint256){
        return s_listingDelay;
    }

    /// @notice Get all NFTs with pagination
    /// @param offset Starting index
    /// @param limit Number of items
    /// @return Array of MarketItem structs
    function getAllNFTs(uint256 offset, uint256 limit) public view returns (MarketItem[] memory) {
        uint256 total = s_tokenId;
        if(offset >= total){
            return new MarketItem[](0);
        }

        uint256 end = offset + limit;
        if(end > total){
            end = total;
        }

        uint256 length = end - offset;
        MarketItem[] memory items = new MarketItem[](length);

        for (uint256 i = 0; i < length; ) {
            items[i] = s_idToMarketItem[offset + i];
            unchecked { ++i; }
        }

        return items;
    }

    /// @notice Get caller's NFTs with pagination
    /// @param offset Starting index
    /// @param limit Number of items
    /// @return Array of MarketItem structs
    function getMyNFTs(uint256 offset, uint256 limit) public view returns(MarketItem[] memory) {
        uint256 count = 0;
        uint256 total = s_tokenId;
        address owner = msg.sender;

        for(uint256 i = 0; i < total; ){
            if(s_idToMarketItem[i].owner == owner){
                count++;
            }
            unchecked { ++i; }
        }

        if (offset >= count) {
            return new MarketItem[](0);
        }

        uint256 end = offset + limit;
        if (end > count) {
            end = count;
        }

        uint256 length = end - offset;
        MarketItem[] memory items = new MarketItem[](length);

        uint256 index = 0;
        uint256 added = 0;
        for (uint256 i = 0; i < total && added < length; ) {
            if (s_idToMarketItem[i].owner == owner) {
                if (index >= offset && index < end) {
                    items[added] = s_idToMarketItem[i];
                    added++;
                }
                index++;
            }
        unchecked { ++i; }
        }

        return items;
    }

    /// @notice Get base URI
    /// @return Base URI string
    function getBaseURI() public view returns (string memory) {
        return s_baseURI;
    }

    /// @notice Get highest offer for a token
    /// @param _tokenId Token ID
    /// @return Offer struct
    function getHighestOffer(uint256 _tokenId) public view returns (Offer memory) {
        return s_highestOffer[_tokenId];
    }

    /// @notice Get sender for VRF request
    /// @param _requestId Request ID
    /// @return Sender address
    function getSenderForRequest(uint256 _requestId) public view returns (address) {
        return s_requestToSender[_requestId];
    }
}
