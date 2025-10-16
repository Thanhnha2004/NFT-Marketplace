// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

abstract contract NFTOffers is NFTBase, NFTStorage {

    function placeOffer(uint256 _tokenId, uint256 _price) public payable {
        address offer = msg.sender;

        if (_price == 0) {
            revert NFTMarketplace__AmountMustBeAboveZero();
        }
        if (msg.value != _price) {
            revert NFTMarketplace__IncorrectPaymentAmount();
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

    function cancelOffer(uint256 _tokenId) public {
        Offer storage offer = s_offersByToken[_tokenId][msg.sender];

        if (!offer.active) {
            revert NFTMarketplace__OfferNotActive();
        }

        offer.active = false;
        s_proceeds[msg.sender] += offer.price;

        emit Events.CancelOffer(_tokenId, msg.sender, offer.price);
    }

    function acceptOffer(uint256 _tokenId, address bidder) public {
        Offer storage offer = s_offersByToken[_tokenId][bidder];
        MarketItem storage item = s_idToMarketItem[_tokenId];
        if(!offer.active){
            revert NFTMarketplace__OfferNotActive();
        }
        if(ownerOf(_tokenId) != msg.sender){
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
