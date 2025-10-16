// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

    //////////////////////////////////////////////////////////
    ////////////////////  Custom Errors  /////////////////////
    //////////////////////////////////////////////////////////
    error NFTMarketplace__TokenDoesNotExist();
    error NFTMarketplace__AmountMustBeAboveZero();
    error NFTMarketplace__MintFeeMismatch();
    error NFTMarketplace__ListingFeeMismatch();
    error NFTMarketplace__MarketplaceFeeOutOfRange();
    error NFTMarketplace__PriceMismatch();
    error NFTMarketplace__ItemAlreadySold();
    error NFTMarketplace__TransferToSellerFailed();
    error NFTMarketplace__TransferToRoyaltyReceiverFailed();
    error NFTMarketplace__TransferToMarketplaceFailed();
    error NFTMarketplace__OnlyTokenOwnerCanResell();
    error NFTMarketplace__CallerNotOwner();
    error NFTMarketplace__CallerNotTokenOwner();
    error NFTMarketplace__NoProceeds();
    error NFTMarketplace__WithdrawProceedsFailed();
    error NFTMarketplace__InvalidMetadataURIs();
    error NFTMarketplace__InsufficientBalance();
    error NFTMarketplace__OfferNotActive();
    error NFTMarketplace__InvalidAuctionDuration();
    error NFTMarketplace__AuctionNotActive();
    error NFTMarketplace__AuctionHasEnded();
    error NFTMarketplace__AuctionStillActive();
    error NFTMarketplace__BidBelowMinimum();
    error NFTMarketplace__ArrayLengthMismatch();
    error NFTMarketplace__ListingDelayNotMet();
    error NFTMarketplace__BatchSizeExceedsLimit();
    error NFTMarketplace__IncorrectPaymentAmount();
    error NFTMarketplace__AuctionAlreadyHasBids();
    error NFTMarketplace__VRRequestFailed();
