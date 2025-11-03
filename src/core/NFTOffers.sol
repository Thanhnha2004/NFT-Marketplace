// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

/// @title NFT Offers Module
/// @notice Handles bidding system for listed NFTs
abstract contract NFTOffers is NFTBase, NFTStorage {

    /// @notice Place an offer on an NFT
    /// @param _tokenId Token ID to bid on
    /// @param _price Offer amount in wei
    function placeOffer(uint256 _tokenId, uint256 _price) public payable {
        address offer = msg.sender;

        if (_price == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }
        if (msg.value != _price) {
            revert NFTMarketplace__IncorrectPaymentAmount();
        }

        MarketItem storage item = s_idToMarketItem[_tokenId];
        if(item.lister == address(0) || item.sold) {
            revert NFTMarketplace__ItemNotListed();
        }

        Offer storage existingOffer = s_offersByToken[_tokenId][offer];
        if (existingOffer.active) {
            s_proceeds[offer] += existingOffer.price;
        }

        s_offersByToken[_tokenId][offer] =
            Offer({tokenId: _tokenId, bidder: payable(offer), price: _price, active: true});

        Offer storage current = s_highestOffer[_tokenId];
        if (!current.active || _price > current.price) {
            s_highestOffer[_tokenId] = Offer({
                tokenId: _tokenId,
                bidder: payable(offer),
                price: _price,
                active: true
            });
        }

        emit Events.PlaceOffer(_tokenId, msg.sender, _price);
    }

    /// @notice Cancel your active offer
    /// @param _tokenId Token ID to cancel offer for
    function cancelOffer(uint256 _tokenId) public {
        Offer storage offer = s_offersByToken[_tokenId][msg.sender];

        if (!offer.active) {
            revert NFTMarketplace__OfferNotActive();
        }

        offer.active = false;
        s_proceeds[msg.sender] += offer.price;

        emit Events.CancelOffer(_tokenId, msg.sender, offer.price);
    }

    /// @notice Accept an offer on your listed NFT
    /// @param _tokenId Token ID
    /// @param bidder Address of the bidder
    function acceptOffer(uint256 _tokenId, address bidder) public {
        Offer storage offer = s_offersByToken[_tokenId][bidder];
        MarketItem storage item = s_idToMarketItem[_tokenId];
        if(!offer.active){
            revert NFTMarketplace__OfferNotActive();
        }
        if(item.lister != msg.sender){
            revert NFTMarketplace__CallerNotTokenOwner();
        }

        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(_tokenId, offer.price);

        uint256 feeMarketAmount = (offer.price * s_marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;

        address lister = s_idToMarketItem[_tokenId].lister;
        uint256 priceHaveRoyalty = offer.price - royaltyAmount - feeMarketAmount;

        IMarketplace m = IMarketplace(address(this));
        s_proceeds[royaltyReceiver] += royaltyAmount;
        s_proceeds[m.getOwner()] += feeMarketAmount;
        s_proceeds[lister] += priceHaveRoyalty;

        offer.active = false;
        item.owner = payable(offer.bidder);
        item.sold = true;
        s_itemsSold += 1;

        _transfer(address(this), bidder, _tokenId);

        emit Events.AcceptOffer(_tokenId, lister, bidder, offer.price);
    }
}
