// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

//////////////////////////////////////////////////////////
///////////////////////  Imports  ////////////////////////
//////////////////////////////////////////////////////////
import {console} from "lib/forge-std/src/Script.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./NFTMinting.sol";
import "./NFTListing.sol";
import "./NFTBuying.sol";
import "./NFTFeeManager.sol";
import "./NFTOffers.sol";
import "./NFTAuctions.sol";
import "./NFTGetters.sol";
import "./NFTBase.sol";
import "./VRFHandler.sol";

interface IMarketplace {
    function getOwner() external view returns (address);
}

contract NFTMarketplace is
    Pausable,
    ReentrancyGuard,
    Ownable,
    NFTBase,
    NFTMinting,
    NFTListing,
    NFTBuying,
    NFTOffers,
    NFTAuctions,
    NFTGetters,
    NFTFeeManager
{

    constructor(
        uint256 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 listingFee,
        uint256 mintFee,
        uint256 marketplaceFeeBP,
        uint256 listingDelay,
        string memory baseURI
    ) ERC721("RandomNFT", "RNFT") Ownable(msg.sender) {
        // Chainlink VRF
        VRFHandler handler = new VRFHandler(
            vrfCoordinator,
            keyHash,
            subscriptionId,
            callbackGasLimit,
            address(this)
        );

        vrfHandler = address(handler);

        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;

        s_listingFee = listingFee;
        s_mintFee = mintFee;
        s_marketplaceFeeBP = marketplaceFeeBP;

        s_listingDelay = listingDelay;

        s_baseURI = baseURI;

        s_tokenId = 0;
        s_itemsSold = 0;

        // Rarity mapping
        s_rarityToString[Rarity.Common] = "Common";
        s_rarityToString[Rarity.Rare] = "Rare";
        s_rarityToString[Rarity.Legendary] = "Legendary";

        s_proceeds[msg.sender] = 0;
    }

    // NFTMinting.sol
    function mintFromMarketplace() external payable whenNotPaused nonReentrant {
        mint();
    }

    function updateBaseURIFromMarketplace(string memory _newBaseURI) external payable onlyOwner {
        updateBaseURI(_newBaseURI);
    }

    // NFTListing.sol
    function listFromMarketplace(uint256 _tokenId, uint256 _price) external payable whenNotPaused nonReentrant {
        list(_tokenId, _price);
    }

    function listBatchFromMarketplace(uint256[] calldata _tokenIds, uint256[] calldata _prices) external payable whenNotPaused nonReentrant {
        listBatch(_tokenIds, _prices);
    }

    function reSellFromMarketplace(uint256 _tokenId, uint256 _price) external payable whenNotPaused nonReentrant {
        reSell(_tokenId, _price);
    }

    function cancelListingFromMarketplace(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        cancelListing(_tokenId);
    }

    // NFTBuying.sol
    function buyFromMarketplace(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        buy(_tokenId);
    }

    function buyBatchFromMarketplace(uint256[] calldata _tokenIds) external payable whenNotPaused nonReentrant {
        buyBatch(_tokenIds);
    }

    // NFTFeeManager.sol
    function withdrawProceedsFromMarketplace() external whenNotPaused nonReentrant{
        return withdrawProceeds();
    }

    function updateListingFeeFromMarketplace(uint256 _newPrice) external onlyOwner{
        return updateListingFee(_newPrice);
    }

    function updateMintFeeFromMarketplace(uint256 _newPrice) external onlyOwner{
        return updateMintFee(_newPrice);
    }

    function updateMarketplaceFeeFromMarketplace(uint256 _newPercent) external onlyOwner{
        return updateMarketplaceFee(_newPercent);
    }

    function setTokenRoyaltyFromMarketplace(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyaltyFromMarketplace(uint256 tokenId) external onlyOwner {
        resetTokenRoyalty(tokenId);
    }

    function updateListingDelayFromMarketplace(uint256 _newDelay) external onlyOwner {
        updateListingDelay(_newDelay);
    }

    // NFTMarketplace.sol
    function getVRFHandler() public view returns (address) {
        return vrfHandler;
    }

    function getOwner() public view returns(address){
        return owner();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // NFTOffers.sol
    function placeOfferFromMarketplace(uint256 _tokenId, uint256 _price) external payable whenNotPaused nonReentrant {
        placeOffer(_tokenId, _price);
    }

    function cancelOfferFromMarketplace(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        cancelOffer(_tokenId);
    }

    function acceptOfferFromMarketplace(uint256 _tokenId, address _bidder) external payable whenNotPaused nonReentrant {
        acceptOffer(_tokenId, _bidder);
    }

    // NFTAuctions.sol
    function createAuctionFromMarketplace(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _duration
    ) external payable whenNotPaused nonReentrant {
        createAuction(_tokenId, _startingPrice, _duration);
    }

    function placeBidFromMarketplace(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        placeBid(_tokenId);
    }

    function endAuctionFromMarketplace(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        endAuction(_tokenId);
    }

    function cancelAuctionFromMarketplace(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        cancelAuction(_tokenId);
    }

    // NFTGetters.sol
    function getItemForTokenIdFromMarketplace(uint256 _tokenId) external view whenNotPaused returns(MarketItem memory) {
        return getItemForTokenId(_tokenId);
    }

    function getOfferForTokenIdFromMarketplace(uint256 _tokenId, address bidder) external view whenNotPaused returns(Offer memory) {
        return getOfferForTokenId(_tokenId, bidder);
    }

    function getAuctionForTokenIdFromMarketplace(uint256 _tokenId) external view whenNotPaused returns(Auction memory) {
        return getAuctionForTokenId(_tokenId);
    }

    function getCurrentTokenIdFromMarketplace() external view whenNotPaused returns(uint256) {
        return getCurrentTokenId();
    }

    function getItemSoldFromMarketplace() external view whenNotPaused returns(uint256) {
        return getItemSold();
    }

    function getProceedsForAddressFromMarketplace(address addr) external view whenNotPaused returns(uint256) {
        return getProceedsForAddress(addr);
    }

    function getTokenIdFromMarketplace() external view whenNotPaused returns(uint256) {
        return getTokenId();
    }

    function getListingFeeFromMarketplace() external view whenNotPaused returns(uint256) {
        return getListingFee();
    }

    function getMintFeeFromMarketplace() external view whenNotPaused returns(uint256) {
        return getMintFee();
    }

    function getListingDelayFromMarketplace() external view whenNotPaused returns(uint256) {
        return getListingDelay();
    }

    function getAllNFTsFromMarketplace(uint256 offset, uint256 limit) external view whenNotPaused returns(MarketItem[] memory) {
        return getAllNFTs(offset, limit);
    }

    function getMyNFTsFromMarketplace(uint256 offset, uint256 limit) external view whenNotPaused returns(MarketItem[] memory) {
        return getMyNFTs(offset, limit);
    }

    function getBaseURIFromMarketplace() external view whenNotPaused returns(string memory) {
        return getBaseURI();
    }

    function getHighestOfferFromMarketplace(uint256 _tokenId) external view whenNotPaused returns(Offer memory) {
        return getHighestOffer(_tokenId);
    }

    function getSenderForRequestFromMarketplace(uint256 _requestId) external view whenNotPaused returns(address) {
        return getSenderForRequest(_requestId);
    }
}
