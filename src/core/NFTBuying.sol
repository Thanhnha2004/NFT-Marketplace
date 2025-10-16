// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import {NFTMarketplace} from "./NFTMarketplace.sol";

abstract contract NFTBuying is NFTBase, NFTStorage {
    
    // function buy(uint256 _tokenId) external payable {
    //     uint256 price = s_idToMarketItem[_tokenId].price;
    //     if(msg.value != price){
    //         revert NFTMarketplace__PriceMismatch();
    //     }
    //     bool sold = s_idToMarketItem[_tokenId].sold;
    //     if(sold){
    //         revert NFTMarketplace__ItemAlreadySold();
    //     }

    //     (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(_tokenId, price);
    //     (bool sentToReceiver, ) = payable(royaltyReceiver).call{value: royaltyAmount}("");
    //     if(!sentToReceiver){
    //         revert NFTMarketplace__TransferToRoyaltyReceiverFailed();
    //     }

    //     uint256 feeMarketAmount = (price * s_marketplaceFeeBP) / MARKETPLACE_FEE_DENOM;
    //     (bool sentToMarketplace, ) = payable(getOwner()).call{value: feeMarketAmount}("");
    //     if(!sentToMarketplace){
    //         revert NFTMarketplace__TransferToMarketplaceFailed();
    //     }

    //     address lister = s_idToMarketItem[_tokenId].lister;
    //     uint256 priceHaveRoyalty = price - royaltyAmount - feeMarketAmount;
    //     (bool sentToLister, ) = payable(lister).call{value: priceHaveRoyalty}("");
    //     if(!sentToLister){
    //         revert NFTMarketplace__TransferToSellerFailed();
    //     }

    //     s_idToMarketItem[_tokenId].owner = payable(msg.sender);
    //     s_idToMarketItem[_tokenId].sold = true;
    //     s_itemsSold += 1;

    //     _transfer(address(this), msg.sender, _tokenId);

    //     emit Buy(_tokenId, msg.sender, priceHaveRoyalty);
    // }

    function buy(uint256 _tokenId) public payable {
        MarketItem storage item = s_idToMarketItem[_tokenId];
        uint256 price = s_idToMarketItem[_tokenId].price;
        if(msg.value != price){
            revert NFTMarketplace__PriceMismatch();
        }
        if(block.timestamp < item.startTime){
            revert NFTMarketplace__ListingDelayNotMet();
        }
        bool sold = s_idToMarketItem[_tokenId].sold;
        if(sold){
            revert NFTMarketplace__ItemAlreadySold();
        }

        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(_tokenId, price);
        uint256 feeMarketAmount = (price * s_marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;
        address lister = item.lister;
        uint256 priceHaveRoyalty = price - royaltyAmount - feeMarketAmount;

        item.owner = payable(msg.sender);
        item.sold = true;
        s_itemsSold += 1;
IMarketplace m = IMarketplace(address(this));
        s_proceeds[royaltyReceiver] += royaltyAmount;
        s_proceeds[m.getOwner()] += feeMarketAmount;
        s_proceeds[lister] += priceHaveRoyalty;

        _transfer(address(this), msg.sender, _tokenId);

        emit Events.Buy(_tokenId, msg.sender, price);
    }

    function buyBatch(uint256[] calldata _tokenIds) public payable {
        uint256 length = _tokenIds.length;
        uint256 totalPrice;
        address buyer = msg.sender;
        IMarketplace m = IMarketplace(address(this));
        address marketplaceOwner = m.getOwner();

        if(length == 0){
            revert NFTMarketplace__ArrayLengthMismatch();
        }
        if(length > Constants.MAX_BATCH_SIZE){
            revert NFTMarketplace__BatchSizeExceedsLimit();
        }
        for (uint256 i = 0; i < length; ) {
            uint256 tokenId = _tokenIds[i];
            MarketItem storage item = s_idToMarketItem[tokenId];

            if(block.timestamp < item.startTime){
                revert NFTMarketplace__ListingDelayNotMet();
            }
            if(item.sold){
               revert NFTMarketplace__ItemAlreadySold();
            }

            totalPrice += item.price;

            unchecked { ++i; }
        }

        if (msg.value != totalPrice) {
            revert NFTMarketplace__PriceMismatch();
        }

        for (uint256 i = 0; i < length; ) {
            uint256 tokenId = _tokenIds[i];
            uint256 price = s_idToMarketItem[tokenId].price;

            (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, price);

            uint256 feeMarketAmount = (price * s_marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;

            address lister = s_idToMarketItem[tokenId].lister;
            uint256 priceHaveRoyalty = price - royaltyAmount - feeMarketAmount;

            s_idToMarketItem[tokenId].owner = payable(buyer);
            s_idToMarketItem[tokenId].sold = true;
            unchecked { s_itemsSold++; }

            s_proceeds[royaltyReceiver] += royaltyAmount;
            s_proceeds[marketplaceOwner] += feeMarketAmount;
            s_proceeds[lister] += priceHaveRoyalty;

            _transfer(address(this), buyer, tokenId);

            emit Events.Buy(tokenId, buyer, priceHaveRoyalty);

            unchecked { ++i; }
        }
    }
}
