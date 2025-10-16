// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

abstract contract NFTGetters is NFTBase, NFTStorage {

    function getItemForTokenId(uint256 _tokenId) public view returns(MarketItem memory){
        return s_idToMarketItem[_tokenId];
    }

    function getOfferForTokenId(uint256 _tokenId, address bidder) public view returns(Offer memory){
        return s_offersByToken[_tokenId][bidder];
    }

    function getAuctionForTokenId(uint256 _tokenId) public view returns(Auction memory){
        return s_auctions[_tokenId];
    }

    function getCurrentTokenId() public view returns(uint256){
        return s_tokenId;
    }

    function getItemSold() public view returns(uint256){
        return s_itemsSold;
    }

    function getProceedsForAddress(address addr) public view returns(uint256){
        return s_proceeds[addr];
    }

    function getTokenId() public view returns(uint256){
        return s_tokenId;
    }

    function getListingFee() public view returns(uint256){
        return s_listingFee;
    }

    function getMintFee() public view returns(uint256){
        return s_mintFee;
    }

    function getListingDelay() public view returns(uint256){
        return s_listingDelay;
    }

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
        for (uint256 i = 0; i < length && added < count; ) {
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

    function getBaseURI() public view returns (string memory) {
        return s_baseURI;
    }

    function getHighestOffer(uint256 _tokenId) public view returns (Offer memory) {
        return s_highestOffer[_tokenId];
    }

    function getSenderForRequest(uint256 _requestId) public view returns (address) {
        return s_requestToSender[_requestId];
    }
}
