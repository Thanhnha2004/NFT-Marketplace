// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "../core/NFTMarketplace.sol";

abstract contract NFTStorage {
    //////////////////////////////////////////////////////////
    ////////////////  Type Declarations  /////////////////////
    //////////////////////////////////////////////////////////
    struct MarketItem {
        uint256 tokenId;
        address payable owner;
        address payable lister;
        uint256 price;
        bool sold;
        uint256 startTime;
    }

    struct Offer {
        uint256 tokenId;
        address payable bidder;
        uint256 price;
        bool active;
    }

    struct Auction {
        uint256 tokenId;
        address payable lister;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool active;
    }

    receive() external payable {}

    fallback() external payable {}

    //////////////////////////////////////////////////////////
    ////////////////  Storage Variables  /////////////////////
    //////////////////////////////////////////////////////////
    uint256 internal s_tokenId;
    uint256 internal s_itemsSold;
    uint256 internal s_listingFee;
    uint256 internal s_mintFee;
    uint256 internal s_marketplaceFeeBP; 

    mapping(uint256 tokenId => MarketItem) internal s_idToMarketItem;

    mapping(address => uint256) internal s_proceeds;

    uint256 internal s_listingDelay; 

    mapping(uint256 => mapping(address => Offer)) internal s_offersByToken;
    mapping(uint256 => Offer) internal s_highestOffer;

    mapping(uint256 => Auction) internal s_auctions; 

    // Chainlink VRF
    uint256 internal immutable i_subscriptionId;
    bytes32 internal immutable i_keyHash;
    uint32 internal immutable i_callbackGasLimit;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;
    uint32 internal constant NUM_WORDS = 1;
    mapping(uint256 => address) public s_requestToSender;
    mapping(uint256 => uint256) public s_requestToTokenId;

    // Metadata URIs
    string internal s_baseURI = "ipfs://"; // mặc định IPFS
    enum Rarity { Common, Rare, Legendary }
    mapping(uint256 => Rarity) internal s_tokenRarity;
    mapping(Rarity => string) internal s_rarityToString;
}