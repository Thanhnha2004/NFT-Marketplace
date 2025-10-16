// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "lib/forge-std/src/Script.sol";
import "../storage/NFTStorage.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";
import "../utils/Constants.sol";
import "./NFTBase.sol";
import "./NFTMarketplace.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

abstract contract NFTMinting is NFTBase, NFTStorage {
    using Strings for uint256;

    address public vrfHandler;

    function mint() public payable {
        IMarketplace m = IMarketplace(address(this));

        if (msg.value != s_mintFee) {
            revert NFTMarketplace__MintFeeMismatch();
        }

        uint256 currentId = s_tokenId;
        s_tokenId++;

        (bool success, bytes memory data) = vrfHandler.call(
            abi.encodeWithSignature("requestRandomWords()")
        );
        if(!success){
            revert NFTMarketplace__VRRequestFailed();
        }
        uint256 requestId = abi.decode(data, (uint256));
        
        s_proceeds[m.getOwner()] += msg.value;
        s_requestToSender[requestId] = msg.sender;
        s_requestToTokenId[requestId] = currentId;

        emit Events.Mint(requestId, currentId, msg.sender);
    }

    function fulfillRandomMint(uint256 requestId, uint256[] calldata randomWords) external {
        address nftOwner = s_requestToSender[requestId];
        uint256 tokenId = s_requestToTokenId[requestId];

        _mint(nftOwner, tokenId);

        // Chọn rarity dựa trên randomWords[0] % 100
        uint256 rand = randomWords[0] % 100;
        Rarity rarity;

        if (rand < 70) {
            rarity = Rarity.Common; // 70% 
        } else if (rand < 95) {
            rarity = Rarity.Rare; // 25% 
        } else {
            rarity = Rarity.Legendary; // 5% 
        }

        s_tokenRarity[tokenId] = rarity;

        string memory finalURI = string(
            abi.encodePacked(s_baseURI, rarityToString(rarity), "/", tokenId.toString(), ".json")
        );

        _setTokenURI(tokenId, finalURI);

        s_idToMarketItem[tokenId] = MarketItem({
            tokenId: tokenId,
            owner: payable(nftOwner),
            lister: payable(address(0)),
            price: 0,
            sold: false,
            startTime: 0
        });

        _setTokenRoyalty(tokenId, nftOwner, Constants.ROYALTY_FEE); 

        emit Events.RandomNFT(nftOwner, tokenId, tokenURI(tokenId));
    }

    function updateBaseURI(string memory newBaseURI) public {
        s_baseURI = newBaseURI;
        emit Events.BaseURIUpdated(newBaseURI);
    }

    function rarityToString(Rarity rarity) public view returns (string memory) {
        return s_rarityToString[rarity];
    }
}
