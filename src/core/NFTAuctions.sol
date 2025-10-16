// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

abstract contract NFTAuctions is NFTBase, NFTStorage {

    function createAuction(uint256 _tokenId, uint256 _startingPrice, uint256 _duration) public payable {
        MarketItem storage item = s_idToMarketItem[_tokenId];
        if (_startingPrice == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }
        if (_duration <= 0) {
            revert NFTMarketplace__InvalidAuctionDuration();
        }
        if (ownerOf(_tokenId) != msg.sender) {
            revert NFTMarketplace__CallerNotTokenOwner();
        }
        if (msg.value != s_listingFee) {
            revert NFTMarketplace__ListingFeeMismatch();
        }

        _transfer(msg.sender, address(this), _tokenId);
IMarketplace m = IMarketplace(address(this));
        s_proceeds[m.getOwner()] += msg.value;

        item.owner = payable(address(this));
        item.lister = payable(msg.sender);
        item.price = 0;

        s_auctions[_tokenId] = Auction({
            tokenId: _tokenId,
            lister: payable(msg.sender),
            highestBid: _startingPrice,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + _duration,
            active: true
        });

        emit Events.CreateAuction(_tokenId, msg.sender, _startingPrice, block.timestamp + _duration);
    }

    function placeBid(uint256 _tokenId) public payable {
        Auction storage auction = s_auctions[_tokenId];
        if(!auction.active){
            revert NFTMarketplace__AuctionNotActive();
        }
        if(block.timestamp >= auction.endTime){
            revert NFTMarketplace__AuctionHasEnded();
        }

        if (auction.highestBidder != address(0)) {
            uint256 minRequired = auction.highestBid + (auction.highestBid * Constants.MIN_BID_INCREMENT_PCT) / Constants.BID_INCREMENT_DENOM;
            if (msg.value < minRequired) {
                revert NFTMarketplace__BidBelowMinimum();
            }

            s_proceeds[auction.highestBidder] += auction.highestBid;

        } else {
            if (msg.value < auction.highestBid) {
                revert NFTMarketplace__BidBelowMinimum();
            }
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        // Anti-sniping
        if(block.timestamp >= auction.endTime - Constants.AUCTION_EXTENSION){
            auction.endTime += Constants.AUCTION_EXTENSION;

            emit Events.AuctionExtended(_tokenId, auction.endTime);
        }

        emit Events.PlaceBid(_tokenId, msg.sender, msg.value);
    }

    function endAuction(uint256 _tokenId) public {
        Auction storage auction = s_auctions[_tokenId];
        MarketItem storage item = s_idToMarketItem[_tokenId];
        if(!auction.active){
            revert NFTMarketplace__AuctionNotActive();
        }
        if(block.timestamp < auction.endTime){
            revert NFTMarketplace__AuctionStillActive();
        }

        auction.active = false;

        if(auction.highestBidder != address(0)){
            (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(_tokenId, auction.highestBid);
            uint256 feeMarketAmount = (auction.highestBid * s_marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;
            uint256 priceHaveRoyalty = auction.highestBid - royaltyAmount - feeMarketAmount;

            item.owner = payable(auction.highestBidder);
            item.sold = true;
            item.price = auction.highestBid;
            s_itemsSold += 1;
IMarketplace m = IMarketplace(address(this));
            s_proceeds[royaltyReceiver] += royaltyAmount;
            s_proceeds[m.getOwner()] += feeMarketAmount;
            s_proceeds[auction.lister] += priceHaveRoyalty;

            _transfer(address(this), auction.highestBidder, _tokenId);

            emit Events.EndAuction(_tokenId, auction.highestBidder, auction.highestBid);
        } else {
            item.owner = payable(item.lister);
            item.sold = false;
            item.price = 0;

            _transfer(address(this), auction.lister, _tokenId);

            emit Events.EndAuction(_tokenId, address(0), 0);
        }
    }

    function cancelAuction(uint256 _tokenId) public{
        Auction storage auction = s_auctions[_tokenId];
        if(!auction.active) {
            revert NFTMarketplace__AuctionNotActive();
        }
        if(ownerOf(_tokenId) != msg.sender) {
            revert NFTMarketplace__CallerNotTokenOwner();
        }
        if (auction.highestBidder != address(0)) {
            revert NFTMarketplace__AuctionAlreadyHasBids();
        }

        auction.active = false;

        _transfer(address(this), auction.lister, _tokenId);

        emit Events.CancelAuction(_tokenId, msg.sender);
    }
}
