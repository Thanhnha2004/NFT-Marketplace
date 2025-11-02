// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {console} from "lib/forge-std/src/Script.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

abstract contract NFTListing is NFTBase, NFTStorage {
    
    function list(uint256 _tokenId, uint256 _price) public payable {
        if (_price == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }
        if (msg.value != s_listingFee) {
            revert NFTMarketplace__ListingFeeMismatch();
        }
        if (ownerOf(_tokenId) != msg.sender) {
            revert NFTMarketplace__CallerNotTokenOwner();
        }

        _transfer(msg.sender, address(this), _tokenId);

        IMarketplace m = IMarketplace(address(this));
        s_proceeds[m.getOwner()] += msg.value;

        MarketItem storage marketItem = s_idToMarketItem[_tokenId];
        marketItem.owner = payable(address(this));
        marketItem.lister = payable(msg.sender);
        marketItem.price = _price;
        marketItem.startTime = block.timestamp + s_listingDelay;

        emit Events.List(_tokenId, msg.sender, _price);
    }

    function listBatch(uint256[] calldata _tokenIds, uint256[] calldata _prices) public payable {
        uint256 length = _tokenIds.length;
        address owner = msg.sender;
        
        if(length == 0){
            revert NFTMarketplace__ArrayLengthMismatch();
        }
        if(length > Constants.MAX_BATCH_SIZE){
            revert NFTMarketplace__BatchSizeExceedsLimit();
        }
        uint256 totalListingFee = s_listingFee * length;
        if (msg.value != totalListingFee) {
            revert NFTMarketplace__ListingFeeMismatch();
        }

        IMarketplace m = IMarketplace(address(this));
        s_proceeds[m.getOwner()] += msg.value;

        for(uint256 i = 0; i < length; ){
            uint256 tokenId = _tokenIds[i];
            uint256 price = _prices[i];

            if (price == 0) {
                revert NFTMarketplace__AmountMustBeAboveZero();
            }
            if (ownerOf(tokenId) != owner) {
                revert NFTMarketplace__CallerNotTokenOwner();
            }

            _transfer(owner, address(this), tokenId);

            MarketItem storage marketItem = s_idToMarketItem[tokenId];
            marketItem.owner = payable(address(this));
            marketItem.lister = payable(owner);
            marketItem.price = price;
            marketItem.startTime = block.timestamp + s_listingDelay;

            emit Events.List(tokenId, owner, price);

            unchecked { ++i; }
        }
    }

    function reSell(uint256 _tokenId, uint256 _price) public payable {
        address payable owner = payable(msg.sender);
        if(ownerOf(_tokenId) != owner){
            revert NFTMarketplace__OnlyTokenOwnerCanResell();
        }
        if (_price == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }
        if (msg.value != s_listingFee) {
            revert NFTMarketplace__ListingFeeMismatch();
        }

        IMarketplace m = IMarketplace(address(this));
        s_proceeds[m.getOwner()] += msg.value;

        MarketItem storage item = s_idToMarketItem[_tokenId];
        item.sold = false;
        item.lister = owner;
        item.price = _price;
        item.owner = payable(address(this));
        item.startTime = block.timestamp + s_listingDelay;

        if (s_itemsSold > 0) {
            s_itemsSold -= 1;
        }

        _transfer(msg.sender, address(this), _tokenId);

        emit Events.ReSell(_tokenId, owner, _price);
    }

    function cancelListing(uint256 _tokenId) public {
        MarketItem storage marketItem = s_idToMarketItem[_tokenId];
        if(marketItem.lister != msg.sender){
            revert NFTMarketplace__CallerNotOwner();
        }

        _transfer(address(this), msg.sender, _tokenId);

        marketItem.owner = payable(msg.sender);
        marketItem.price = 0;

        emit Events.CancelListing(_tokenId, msg.sender);
    }
}
