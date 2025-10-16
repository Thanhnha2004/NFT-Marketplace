// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Events {

    event List(uint256 indexed tokenId, address indexed lister, uint256 price);
    event Buy(uint256 indexed tokenId, address indexed lister, uint256 price);
    event Mint(uint256 indexed  requestId, uint256 indexed tokenId, address indexed owner);
    event ReturnedRandomness(uint256[] randomWords);
    event ReSell(uint256 indexed tokenId, address indexed lister, uint256 price);
    event RandomNFT(address indexed owner, uint256 indexed tokenId, string tokenURI);
    event ListingFeeUpdated(uint256 price);
    event MintFeeUpdated(uint256 price);
    event Withdraw(address indexed withdrawer);
    event BaseURIUpdated(string newBaseURI);
    event URIsUpdated(string common, string rare, string legendary);
    event CancelListing(uint256 indexed tokenId, address indexed lister);
    event MarketplaceFeeUpdate(uint256 indexed newPercent);
    event PlaceOffer(uint256 indexed tokenId, address indexed bidder, uint256 price);
    event Refund(address indexed bidder, uint256 price);
    event CancelOffer(uint256 indexed tokenId, address indexed bidder, uint256 price);
    event AcceptOffer(uint256 indexed tokenId, address indexed lister, address indexed bidder, uint256 price);
    event CreateAuction(uint256 indexed tokenId, address indexed lister, uint256 startingPrice, uint256 duration);
    event PlaceBid(uint256 indexed tokenId, address indexed bidder, uint256 highestBid);
    event EndAuction(uint256 indexed tokenId, address indexed highestBidder, uint256 highestBid);
    event CancelAuction(uint256 indexed tokenId, address indexed lister);
    event AuctionExtended(uint256 indexed tokenId, uint256 newEndTime);
    event ListingDelayUpdated(uint256 newDelay);
}