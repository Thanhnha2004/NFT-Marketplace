// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "lib/forge-std/src/Script.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {NFTMarketplace} from "src/core/NFTMarketplace.sol";
import {DeployNFTMarketplace} from "script/DeployNFTMarketplace.s.sol";
import {MocksTransferFailed} from "test/mocks/MocksTransferFailed.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Constants} from "src/utils/Constants.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "lib/chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";
import "../src/utils/Events.sol";
import "../src/utils/Constants.sol";
import "../src/utils/Errors.sol";
import "../src/storage/NFTStorage.sol";

contract NFTMarketplaceTest is Test, NFTStorage {
    NFTMarketplace public nftMarketplace;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;
    MockLinkToken public linkToken;

    address public constant USER1 = address(1);
    address public constant USER2 = address(2);
    address public constant USER3 = address(3);
    uint256 public constant INITIAL_BALANCE = 10 ether;

    function setUp() external {
        DeployNFTMarketplace deployer = new DeployNFTMarketplace();
        (nftMarketplace, helperConfig) = deployer.run();
        config = helperConfig.getConfig();
        linkToken = MockLinkToken(config.linkToken);

        vm.deal(USER1, INITIAL_BALANCE);
        vm.deal(USER2, INITIAL_BALANCE);
        vm.deal(USER3, INITIAL_BALANCE);

        if (block.chainid == Constants.ANVIL_CHAIN_ID) {
            vm.startPrank(msg.sender); // Default sender
            linkToken.setBalance(msg.sender, 1000 ether);
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).fundSubscription(config.subscriptionId, 10000 ether);
            // VRFCoordinatorV2_5Mock(config.vrfCoordinator).addConsumer(config.subscriptionId, address(nftMarketplace));
            address vrfHandlerAddress = nftMarketplace.getVRFHandler();
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).addConsumer(config.subscriptionId, vrfHandlerAddress);
            vm.stopPrank();
        }
    }

    //////////////////////////////////////////////////////////
    ////////////////      Mint Tests       ///////////////////
    //////////////////////////////////////////////////////////
    function test_revert_mint() public {
        vm.startPrank(USER1);
        vm.expectRevert(NFTMarketplace__MintFeeMismatch.selector);
        nftMarketplace.mintFromMarketplace{value: 0}();
        vm.stopPrank();
    }

    function test_mint() public {
        Vm.Log[] memory logs;
        bytes32 requestIdBytes; // nếu requestId là indexed
        uint256 requestId;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.startPrank(USER1);

        vm.recordLogs();
        nftMarketplace.mintFromMarketplace{value: mintFee}();
        logs = vm.getRecordedLogs();

        // Lấy requestId từ log
        requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
        requestId = uint256(requestIdBytes);

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, nftMarketplace.getVRFHandler());

        address owner = nftMarketplace.getSenderForRequestFromMarketplace(requestId);

        assertEq(owner, USER1);
        assertEq(address(nftMarketplace).balance, mintFee);
        assertEq(nftMarketplace.balanceOf(USER1), 1);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    /////////////////     List Tests      ////////////////////
    //////////////////////////////////////////////////////////
    modifier mint() {
        Vm.Log[] memory logs;
        bytes32 requestIdBytes; // nếu requestId là indexed
        uint256 requestId;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.startPrank(USER1);

        vm.recordLogs();
        nftMarketplace.mintFromMarketplace{value: mintFee}();
        logs = vm.getRecordedLogs();

        // Lấy requestId từ log
        requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
        requestId = uint256(requestIdBytes);

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, nftMarketplace.getVRFHandler());

        vm.stopPrank();

        _;
    }

//     modifier mintBatch(uint256 amount) {
//         vm.startPrank(USER1);
//         uint256 mintFee = nftMarketplace.getMintFee();

//         for(uint256 i = 0; i < amount; i++){
//             vm.recordLogs();
//             nftMarketplace.mint{value: mintFee}();
//             Vm.Log[] memory logs = vm.getRecordedLogs();

//             // Lấy requestId từ log
//             bytes32 requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
//             uint256 requestId = uint256(requestIdBytes);

//             VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, address(nftMarketplace));
//         }
    
//         vm.stopPrank();
//         _;
//     }

    function test_revert_list() public mint {
        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        vm.startPrank(USER1);

        vm.expectRevert(NFTMarketplace__AmountMustBeAboveZero.selector);
        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, 0);

        vm.expectRevert(NFTMarketplace__ListingFeeMismatch.selector);
        nftMarketplace.listFromMarketplace{value: 0}(tokenId, price);

        vm.stopPrank();

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__CallerNotTokenOwner.selector);
        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, price);

        vm.stopPrank();
    }

    function test_list() public mint {
        vm.startPrank(USER1);
        
        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();
        uint256 listingDelay = nftMarketplace.getListingDelayFromMarketplace();

        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, price);
        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);

        assertEq(marketItem.owner, address(nftMarketplace));
        assertEq(marketItem.lister, USER1);
        assertEq(marketItem.price, price);
        assertFalse(marketItem.sold);
        assertEq(marketItem.startTime, block.timestamp + listingDelay);
        assertEq(nftMarketplace.ownerOf(tokenId), address(nftMarketplace));

        vm.stopPrank();
    }

    function test_emit_list() public mint {
        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 listingFee = nftMarketplace.getListingFee();

        vm.expectEmit();
        emit Events.List(tokenId, USER1, price);
        vm.prank(USER1);
        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, price);
    }

//     function test_listBatch() public mintBatch(2) {
//         vm.startPrank(USER1);

//         uint256[] memory tokenIds = new uint256[](2);
//         tokenIds[0] = 0;
//         tokenIds[1] = 1;
//         uint256[] memory prices = new uint256[](2);
//         prices[0] = 1 ether;
//         prices[1] = 2 ether;
//         uint256 listingFee = nftMarketplace.getListingFee();
//         uint256 totalListingFee = listingFee * tokenIds.length;

//         nftMarketplace.listBatch{value: totalListingFee}(tokenIds, prices);
//         NFTMarketplace.MarketItem memory marketItem1 = nftMarketplace.getItemForTokenId(tokenIds[0]);
//         NFTMarketplace.MarketItem memory marketItem2 = nftMarketplace.getItemForTokenId(tokenIds[1]);

//         console.log(nftMarketplace.ownerOf(tokenIds[0]));
//         console.log(marketItem2.tokenId);

//         assertEq(marketItem1.owner, address(nftMarketplace));
//         assertEq(marketItem1.lister, USER1);
//         assertEq(marketItem1.price, prices[0]);
//         assertFalse(marketItem1.sold);
//         assertEq(marketItem2.owner, address(nftMarketplace));
//         assertEq(marketItem2.lister, USER1);
//         assertEq(marketItem2.price, prices[1]);
//         assertFalse(marketItem2.sold);
//         assertEq(nftMarketplace.ownerOf(tokenIds[0]), address(nftMarketplace));
//         assertEq(nftMarketplace.ownerOf(tokenIds[1]), address(nftMarketplace));

//         vm.stopPrank();
        
//     }

    //////////////////////////////////////////////////////////
    ///////////////////    Buy Tests    //////////////////////
    //////////////////////////////////////////////////////////
    modifier list() {
        vm.startPrank(USER1);

        Vm.Log[] memory logs;
        bytes32 requestIdBytes; // nếu requestId là indexed
        uint256 requestId;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.startPrank(USER1);

        vm.recordLogs();
        nftMarketplace.mintFromMarketplace{value: mintFee}();
        logs = vm.getRecordedLogs();

        // Lấy requestId từ log
        requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
        requestId = uint256(requestIdBytes);

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, nftMarketplace.getVRFHandler());

        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, price);

        vm.stopPrank();

        _;
    }

//     modifier listBatch() {
//         vm.startPrank(USER1);
//         uint256 mintFee = nftMarketplace.getMintFee();
//         uint256 amount = 2;

//         for(uint256 i = 0; i < amount; i++){
//             vm.recordLogs();
//             nftMarketplace.mint{value: mintFee}();
//             Vm.Log[] memory logs = vm.getRecordedLogs();

//             // Lấy requestId từ log
//             bytes32 requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
//             uint256 requestId = uint256(requestIdBytes);

//             VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, address(nftMarketplace));
//         }
    
//         vm.stopPrank();

//         vm.startPrank(USER1);

//         uint256[] memory tokenIds = new uint256[](2);
//         tokenIds[0] = 0;
//         tokenIds[1] = 1;
//         uint256[] memory prices = new uint256[](2);
//         prices[0] = 1 ether;
//         prices[1] = 2 ether;
//         uint256 listingFee = nftMarketplace.getListingFee();
//         uint256 totalListingFee = listingFee * tokenIds.length;
        
//         nftMarketplace.listBatch{value: totalListingFee}(tokenIds, prices);

//         vm.stopPrank();

//         _;
//     }

    function test_revert_buy() public list {
        uint256 tokenId = 0;
        uint256 listingDelay = nftMarketplace.getListingDelayFromMarketplace();

        vm.warp(block.timestamp + listingDelay + 1);

        vm.prank(USER2);
        vm.expectRevert(NFTMarketplace__PriceMismatch.selector);
        nftMarketplace.buyFromMarketplace{value: 0.5 ether}(tokenId);

        vm.prank(USER2);
        nftMarketplace.buyFromMarketplace{value: 1 ether}(tokenId);
        vm.prank(USER3);
        vm.expectRevert(NFTMarketplace__ItemAlreadySold.selector);
        nftMarketplace.buyFromMarketplace{value: 1 ether}(tokenId);
    }

    function test_revertListingDelay_buy() public list {
        uint256 tokenId = 0;

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__ListingDelayNotMet.selector);
        nftMarketplace.buyFromMarketplace{value: 1 ether}(tokenId);

        vm.stopPrank();

    }

    // function test_revertFailTransferLister_buy() public {
    //     uint256 tokenId = 0;
    //     uint256 price = 1 ether;
    //     uint256 listingFee = nftMarketplace.getListingFee();

    //     MocksTransferFailed mockTransferFailed = new MocksTransferFailed();
    //     vm.deal(address(mockTransferFailed), INITIAL_BALANCE);

    //     vm.startPrank(address(mockTransferFailed));

    //     uint256 mintFee = nftMarketplace.getMintFee();

    //     vm.recordLogs();
    //     nftMarketplace.mint{value: mintFee}();
    //     Vm.Log[] memory logs = vm.getRecordedLogs();

    //     // Lấy requestId từ log
    //     bytes32 requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
    //     uint256 requestId = uint256(requestIdBytes);

    //     VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, address(nftMarketplace));

    //     nftMarketplace.list{value: listingFee}(tokenId, price);

    //     vm.stopPrank();
        
    //     vm.prank(address(nftMarketplace.owner()));
    //     nftMarketplace.resetTokenRoyalty(tokenId);

    //     vm.prank(USER2);
    //     vm.expectRevert(NFTMarketplace.NFTMarketplace__TransferToSellerFailed.selector);
    //     nftMarketplace.buy{value: 1 ether}(tokenId);
    // }

    // function test_revertFailTransferReceiver_buy() public {
    //     uint256 tokenId = 0;
    //     uint256 price = 1 ether;
    //     uint256 listingFee = nftMarketplace.getListingFee();

    //     MocksTransferFailed mockTransferFailed = new MocksTransferFailed();
    //     vm.deal(address(mockTransferFailed), INITIAL_BALANCE);

    //     vm.startPrank(address(mockTransferFailed));

    //     uint256 mintFee = nftMarketplace.getMintFee();

    //     vm.recordLogs();
    //     nftMarketplace.mint{value: mintFee}();
    //     Vm.Log[] memory logs = vm.getRecordedLogs();

    //     // Lấy requestId từ log
    //     bytes32 requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
    //     uint256 requestId = uint256(requestIdBytes);

    //     VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, address(nftMarketplace));

    //     nftMarketplace.list{value: listingFee}(tokenId, price);

    //     vm.stopPrank();

    //     vm.prank(USER3);
    //     vm.expectRevert(NFTMarketplace.NFTMarketplace__TransferToRoyaltyReceiverFailed.selector);
    //     nftMarketplace.buy{value: 1 ether}(tokenId);
    // }

    // function test_revertFailTransferMarketplace_buy() public list {
    //     uint256 tokenId = 0;

    //     MocksTransferFailed mockTransferFailed = new MocksTransferFailed();

    //     vm.prank(nftMarketplace.owner());
    //     nftMarketplace.transferOwnership(address(mockTransferFailed));

    //     vm.prank(address(mockTransferFailed));
    //     nftMarketplace.acceptOwnership();

    //     vm.prank(USER2);
    //     vm.expectRevert(NFTMarketplace.NFTMarketplace__TransferToMarketplaceFailed.selector);
    //     nftMarketplace.buy{value: 1 ether}(tokenId);
    // }

    // function test_buy() public list {
    //     vm.startPrank(USER2);

    //     uint256 tokenId = 0;
    //     uint256 price = 1 ether;
    //     uint256 marketplaceFeeBP = 30;

    //     uint256 listerBalBefore = address(USER1).balance;

    //     nftMarketplace.buy{value: 1 ether}(tokenId);

    //     bool itemAlreadySold = nftMarketplace.getItemForTokenId(tokenId).sold;
    //     uint256 itemSold = nftMarketplace.getItemSold();
    //     address itemOwner = nftMarketplace.getItemForTokenId(tokenId).owner;
    //     address itemLister = nftMarketplace.getItemForTokenId(tokenId).lister;
    //     uint256 listerBalAfter = address(USER1).balance;
    //     (address royaltyReceiver, uint256 royaltyAmount) = nftMarketplace.royaltyInfo(tokenId, price);
    //     uint256 feeMarketAmount = (price * marketplaceFeeBP) / MARKETPLACE_FEE_DENOM;

    //     assertTrue(itemAlreadySold);
    //     assertEq(itemSold, 1);
    //     assertEq(itemOwner, USER2);
    //     assertEq(nftMarketplace.ownerOf(tokenId), address(USER2));
    //     assertEq(royaltyAmount, 0.1 ether);
    //     assertEq(royaltyReceiver, USER1);
    //     assertEq(feeMarketAmount, 0.03 ether);
    //     if (royaltyReceiver == itemLister) {
    //         assertEq(listerBalAfter - listerBalBefore, price - feeMarketAmount);
    //     } else {
    //         assertEq(listerBalAfter - listerBalBefore, price - royaltyAmount - feeMarketAmount);
    //     }

    //     vm.stopPrank();
    // }

    function test_buy() public list {
        vm.startPrank(USER2);

        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 marketplaceFeeBP = 30;
        uint256 listingDelay = nftMarketplace.getListingDelayFromMarketplace();
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.warp(block.timestamp + listingDelay + 1);

        nftMarketplace.buyFromMarketplace{value: 1 ether}(tokenId);
        NFTMarketplace.MarketItem memory item = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);

        uint256 itemSold = nftMarketplace.getItemSoldFromMarketplace();
        (address royaltyReceiver, uint256 royaltyAmount) = nftMarketplace.royaltyInfo(tokenId, price);
        uint256 feeMarketAmount = (price * marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;
        uint256 contractProceed = nftMarketplace.getProceedsForAddressFromMarketplace(nftMarketplace.getOwner());

        assertTrue(item.sold);
        assertEq(itemSold, 1);
        assertEq(item.owner, USER2);
        assertEq(nftMarketplace.ownerOf(tokenId), address(USER2));
        assertEq(royaltyAmount, 0.1 ether);
        assertEq(royaltyReceiver, USER1);
        assertEq(feeMarketAmount, 0.03 ether);
        assertEq(contractProceed, feeMarketAmount + listingFee + mintFee);
        
        vm.stopPrank();
    }

    function test_emit_buy() public list {
        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 listingDelay = nftMarketplace.getListingDelayFromMarketplace();

        vm.warp(block.timestamp + listingDelay + 1);

        vm.expectEmit();
        emit Events.Buy(tokenId, USER2, price);
        vm.prank(USER2);
        nftMarketplace.buyFromMarketplace{value: 1 ether}(tokenId);
    }

//     function test_buyBatch() public listBatch {        
//         vm.startPrank(USER2);

//         uint256 listingDelay = nftMarketplace.getListingDelay();
//         vm.warp(block.timestamp + listingDelay + 1);

//         uint256[] memory tokenIds = new uint256[](2);
//         tokenIds[0] = 0;
//         tokenIds[1] = 1;
//         uint256[] memory prices = new uint256[](2);
//         prices[0] = 1 ether;
//         prices[1] = 2 ether;
//         uint256 totalPrice = prices[0] + prices[1];

//         nftMarketplace.buyBatch{value: totalPrice}(tokenIds);

//         NFTMarketplace.MarketItem memory item0 = nftMarketplace.getItemForTokenId(tokenIds[0]);
//         NFTMarketplace.MarketItem memory item1 = nftMarketplace.getItemForTokenId(tokenIds[1]);
//         uint256 itemSold = nftMarketplace.getItemSold();

//         assertTrue(item0.sold);
//         assertTrue(item1.sold);
//         assertEq(itemSold, 2);
//         assertEq(item0.owner, USER2);
//         assertEq(item1.owner, USER2);
//         assertEq(nftMarketplace.ownerOf(tokenIds[0]), address(USER2));
//         assertEq(nftMarketplace.ownerOf(tokenIds[1]), address(USER2));

//         vm.stopPrank();
//     }

    //////////////////////////////////////////////////////////
    ////////////////////   ReSell Tests   ////////////////////
    //////////////////////////////////////////////////////////
    modifier buy() {
        vm.startPrank(USER1);

        Vm.Log[] memory logs;
        bytes32 requestIdBytes; // nếu requestId là indexed
        uint256 requestId;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.recordLogs();
        nftMarketplace.mintFromMarketplace{value: mintFee}();
        logs = vm.getRecordedLogs();

        // Lấy requestId từ log
        requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
        requestId = uint256(requestIdBytes);

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, nftMarketplace.getVRFHandler());

        uint256 tokenId = 0;
        uint256 price = 1 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, price);

        vm.stopPrank();

        vm.startPrank(USER2);
        uint256 listingDelay = nftMarketplace.getListingDelayFromMarketplace();

        vm.warp(block.timestamp + listingDelay + 1);

        nftMarketplace.buyFromMarketplace{value: 1 ether}(tokenId);

        vm.stopPrank();

        _;
    }

    function test_revert_reSell() public buy {
        uint256 tokenId = 0;
        uint256 price = 2 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        vm.startPrank(USER1);

        vm.expectRevert(NFTMarketplace__OnlyTokenOwnerCanResell.selector);
        nftMarketplace.reSellFromMarketplace{value: listingFee}(tokenId, price);

        vm.stopPrank();

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__AmountMustBeAboveZero.selector);
        nftMarketplace.reSellFromMarketplace{value: listingFee}(tokenId, 0);

        vm.expectRevert(NFTMarketplace__ListingFeeMismatch.selector);
        nftMarketplace.reSellFromMarketplace{value: 0 ether}(tokenId, price);

        vm.stopPrank();
        
    }

    function test_reSell() public buy {
        vm.startPrank(USER2);

        uint256 tokenId = 0;
        uint256 price = 2 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        nftMarketplace.reSellFromMarketplace{value: listingFee}(tokenId, price);

        NFTMarketplace.MarketItem memory item = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);
        uint256 itemSold = nftMarketplace.getItemSoldFromMarketplace();

        assertEq(item.owner, address(nftMarketplace));
        assertEq(item.price, price);
        assertEq(item.lister, address(USER2));
        assertFalse(item.sold);
        assertEq(itemSold, 0);

        vm.stopPrank();
    }

    function test_emit_reSell() public buy {
        uint256 tokenId = 0;
        uint256 price = 2 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        vm.expectEmit();
        emit Events.ReSell(tokenId, USER2, price);
        vm.prank(USER2);
        nftMarketplace.reSellFromMarketplace{value: listingFee}(tokenId, price);
    }

    //////////////////////////////////////////////////////////
    /////////  Update ListingFee And MintFee Tests  //////////
    //////////////////////////////////////////////////////////
    function test_revert_updateListingFee_and_updateMintFee() public {
        vm.startPrank(address(nftMarketplace.owner()));

        vm.expectRevert(NFTMarketplace__AmountMustBeAboveZero.selector);
        nftMarketplace.updateListingFeeFromMarketplace(0);

        vm.expectRevert(NFTMarketplace__AmountMustBeAboveZero.selector);
        nftMarketplace.updateMintFeeFromMarketplace(0);

        vm.stopPrank();
    }

    function test_updateListingFee() public {
        vm.startPrank(address(nftMarketplace.owner()));

        nftMarketplace.updateListingFeeFromMarketplace(0.02 ether);

        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        assertEq(listingFee, 0.02 ether);

        vm.stopPrank();
    }

    function test_updateMintFee() public {
        vm.startPrank(address(nftMarketplace.owner()));

        nftMarketplace.updateMintFeeFromMarketplace(0.02 ether);

        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        assertEq(mintFee, 0.02 ether);

        vm.stopPrank();
    }

    function test_emit_updateListingFee() public {
        vm.startPrank(address(nftMarketplace.owner()));

        vm.expectEmit();
        emit Events.ListingFeeUpdated(0.02 ether);
        nftMarketplace.updateListingFeeFromMarketplace(0.02 ether);

        vm.stopPrank();
    }

    function test_emit_updateMintFee() public {
        vm.startPrank(address(nftMarketplace.owner()));

        vm.expectEmit();
        emit Events.MintFeeUpdated(0.02 ether);
        nftMarketplace.updateMintFeeFromMarketplace(0.02 ether);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    ///////////////////   Withdraw Tests   ///////////////////
    //////////////////////////////////////////////////////////
    function test_revert_withdraw() public {
        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__NoProceeds.selector);
        nftMarketplace.withdrawProceedsFromMarketplace();

        vm.stopPrank();
    }

    function test_withdraw() public buy {
        vm.startPrank(USER1);

        nftMarketplace.withdrawProceedsFromMarketplace();

        uint256 currentProceed = nftMarketplace.getProceedsForAddressFromMarketplace(USER1);

        assertEq(currentProceed, 0 ether);

        vm.stopPrank();
    }

    // function test_revert_withdrawFailed_withdraw() public {
    //     MocksTransferFailed mockTransferFailed = new MocksTransferFailed();
    //     vm.deal(address(mockTransferFailed), INITIAL_BALANCE);

    //     vm.startPrank(address(mockTransferFailed));

    //     uint256 mintFee = nftMarketplace.getMintFee();

    //     vm.recordLogs();
    //     nftMarketplace.mint{value: mintFee}();
    //     Vm.Log[] memory logs = vm.getRecordedLogs();

    //     // Lấy requestId từ log
    //     bytes32 requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
    //     uint256 requestId = uint256(requestIdBytes);

    //     VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, address(nftMarketplace));

    //     uint256 tokenId = 0;
    //     uint256 price = 1 ether;
    //     uint256 listingFee = nftMarketplace.getListingFee();

    //     nftMarketplace.list{value: listingFee}(tokenId, price);

    //     vm.stopPrank();

    //     vm.startPrank(USER2);

    //     nftMarketplace.buy{value: 1 ether}(tokenId);

    //     vm.stopPrank();

    //     vm.startPrank(address(mockTransferFailed));

    //     vm.expectRevert(NFTMarketplace.NFTMarketplace__WithdrawProceedsFailed.selector);
    //     nftMarketplace.withdrawProceeds();

    //     vm.stopPrank();
    // }

    function test_emit_withdraw() public buy {
        vm.startPrank(USER1);

        vm.expectEmit();
        emit Events.Withdraw(USER1);
        nftMarketplace.withdrawProceedsFromMarketplace();

        vm.stopPrank();
    }

//     //////////////////////////////////////////////////////////
//     /////////////////////     URI Tests     //////////////////
//     //////////////////////////////////////////////////////////
//     // function test_updateBaseURI() public {
//     //     vm.startPrank(address(nftMarketplace.owner()));

//     //     string memory newBaseURI = "ar://";

//     //     nftMarketplace.updateBaseURI(newBaseURI);

//     //     string memory currentBaseURI = nftMarketplace.getBaseURI();

//     //     assertEq(newBaseURI, currentBaseURI);

//     //     vm.stopPrank();
//     // }

//     // function test_emit_updateBaseURI() public {
//     //     vm.startPrank(address(nftMarketplace.owner()));

//     //     string memory newBaseURI = "ar://";

//     //     vm.expectEmit();
//     //     emit BaseURIUpdated(newBaseURI);
//     //     nftMarketplace.updateBaseURI(newBaseURI);

//     //     vm.stopPrank();
//     // }

//     // function test_emit_updateURIs() public {
//     //     vm.startPrank(address(nftMarketplace.owner()));

//     //     string memory common = "common1";
//     //     string memory rare = "rare1";
//     //     string memory legendary = "legendary1";

//     //     vm.expectEmit();
//     //     emit URIsUpdated(common, rare, legendary);
//     //     nftMarketplace.updateURIs(common, rare, legendary);

//     //     vm.stopPrank();
//     // }

    //////////////////////////////////////////////////////////
    /////////////////   CancelListing Tests    ///////////////
    //////////////////////////////////////////////////////////
    function test_revertOnlyOwner_cancelListing() public list {
        uint256 tokenId = 0;
        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__CallerNotOwner.selector);
        nftMarketplace.cancelListingFromMarketplace(tokenId);

        vm.stopPrank();
    }

    function test_cancelListing() public list {
        vm.startPrank(USER1);

        uint256 tokenId = 0;
        nftMarketplace.cancelListingFromMarketplace(tokenId);
        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);

        assertEq(marketItem.owner, USER1);
        assertEq(marketItem.price, 0);
        assertFalse(marketItem.sold);
        assertEq(nftMarketplace.ownerOf(tokenId), USER1);

        vm.stopPrank();
    }

    function test_emit_cancelListing() public list {
        uint256 tokenId = 0;

        vm.expectEmit();
        emit Events.CancelListing(tokenId, USER1);
        vm.prank(USER1);
        nftMarketplace.cancelListingFromMarketplace(tokenId);
    }

    //////////////////////////////////////////////////////////
    //////////////////    PlaceOffer Tests     ///////////////
    //////////////////////////////////////////////////////////
    function test_revert_placeOffer() public list {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__AmountMustBeAboveZero.selector);
        nftMarketplace.placeOfferFromMarketplace{value: 2 ether}(tokenId, 0);

        vm.expectRevert(NFTMarketplace__IncorrectPaymentAmount.selector);
        nftMarketplace.placeOfferFromMarketplace{value: 3 ether}(tokenId, price);

        vm.stopPrank();
    }

    function test_placeOffer() public list {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);

        nftMarketplace.placeOfferFromMarketplace{value: 2 ether}(tokenId, price);

        NFTMarketplace.Offer memory item = nftMarketplace.getOfferForTokenIdFromMarketplace(tokenId, USER2);
        uint256 refundProceed = nftMarketplace.getProceedsForAddressFromMarketplace(USER2);

        assertEq(refundProceed, 0 ether);
        assertEq(item.tokenId, tokenId);
        assertEq(item.bidder, USER2);
        assertEq(item.price, price);
        assertTrue(item.active);

        vm.stopPrank();
    }

    function test_emit_placeOffer() public list {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);

        vm.expectEmit();
        emit Events.PlaceOffer(tokenId, USER2, price);
        nftMarketplace.placeOfferFromMarketplace{value: 3 ether}(tokenId, price);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    //////////////////    CancelOffer Tests     //////////////
    //////////////////////////////////////////////////////////
    modifier offer() {
        uint256 tokenId = 0;

        vm.startPrank(USER1);

        Vm.Log[] memory logs;
        bytes32 requestIdBytes; // nếu requestId là indexed
        uint256 requestId;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.recordLogs();
        nftMarketplace.mintFromMarketplace{value: mintFee}();
        logs = vm.getRecordedLogs();

        // Lấy requestId từ log
        requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
        requestId = uint256(requestIdBytes);

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, nftMarketplace.getVRFHandler());

        uint256 price = 1 ether;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        nftMarketplace.listFromMarketplace{value: listingFee}(tokenId, price);

        vm.stopPrank();

        vm.startPrank(USER2);

        uint256 priceOffer = 0.5 ether;

        nftMarketplace.placeOfferFromMarketplace{value: priceOffer}(tokenId, priceOffer);

        vm.stopPrank();
        _;
    }

    function test_revert_cancelOffer() public {
        uint256 tokenId = 0;

        vm.startPrank(USER1);

        vm.expectRevert(NFTMarketplace__OfferNotActive.selector);
        nftMarketplace.cancelOfferFromMarketplace(tokenId);

        vm.stopPrank();
    }

    function test_cancelOffer() public offer {
        uint256 tokenId = 0;

        vm.startPrank(USER2);

        nftMarketplace.cancelOfferFromMarketplace(tokenId);

        NFTMarketplace.Offer memory item = nftMarketplace.getOfferForTokenIdFromMarketplace(tokenId, USER2);
        uint256 refundProceed = nftMarketplace.getProceedsForAddressFromMarketplace(USER2);

        assertFalse(item.active);
        assertEq(refundProceed, 0.5 ether);

        vm.stopPrank();
    }

    function test_emit_cancelOffer() public offer {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);

        vm.expectEmit();
        emit Events.CancelOffer(tokenId, USER2, price);
        nftMarketplace.cancelOfferFromMarketplace(tokenId);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    //////////////////    AcceptOffer Tests     //////////////
    //////////////////////////////////////////////////////////
    function test_revert_acceptOffer() public offer {
        uint256 tokenId = 0;

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__CallerNotTokenOwner.selector);
        nftMarketplace.acceptOfferFromMarketplace(tokenId, USER2);

        vm.stopPrank();
    }

    function test_acceptOffer() public offer {
        uint256 tokenId = 0;
        uint256 priceOffer = 0.5 ether;
        uint256 marketplaceFeeBP = 30;
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.startPrank(USER1);

        nftMarketplace.acceptOfferFromMarketplace(tokenId, USER2);
        NFTMarketplace.MarketItem memory item = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);

        (address royaltyReceiver, uint256 royaltyAmount) = nftMarketplace.royaltyInfo(tokenId, priceOffer);
        uint256 feeMarketAmount = (priceOffer * marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;
        uint256 contractProceed = nftMarketplace.getProceedsForAddressFromMarketplace(nftMarketplace.getOwner());

        assertTrue(item.sold);
        assertEq(item.owner, USER2);
        assertEq(nftMarketplace.ownerOf(tokenId), address(USER2));
        assertEq(royaltyAmount, 0.05 ether);
        assertEq(royaltyReceiver, USER1);
        assertEq(feeMarketAmount, 0.015 ether);
        assertEq(contractProceed, feeMarketAmount + listingFee + mintFee);
        assertFalse(nftMarketplace.getOfferForTokenId(tokenId, USER2).active);

        vm.stopPrank();
    }

    function test_emit_acceptOffer() public offer {
        uint256 tokenId = 0;
        uint256 price = 0.5 ether;

        vm.startPrank(USER1);

        vm.expectEmit();
        emit Events.AcceptOffer(tokenId, USER1, USER2, price);
        nftMarketplace.acceptOfferFromMarketplace(tokenId, USER2);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    /////////////////    CreateAuction Tests     /////////////
    //////////////////////////////////////////////////////////
    function test_revert_createAuction() public mint {
        uint256 tokenId = 0;
        uint256 startingPrice = 2 ether;
        uint256 duration = 3600; // second
        uint256 listingFee = nftMarketplace.getListingFee();

        vm.startPrank(USER1);

        vm.expectRevert(NFTMarketplace__AmountMustBeAboveZero.selector);
        nftMarketplace.createAuction{value: listingFee}(tokenId, 0, duration);

        vm.expectRevert(NFTMarketplace__InvalidAuctionDuration.selector);
        nftMarketplace.createAuction{value: listingFee}(tokenId, startingPrice, 0);

        vm.stopPrank();

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__CallerNotTokenOwner.selector);
        nftMarketplace.createAuction{value: listingFee}(tokenId, startingPrice, duration);

        vm.stopPrank();
    }

    function test_createAuction() public mint {
        vm.startPrank(USER1);

        uint256 tokenId = 0;
        uint256 startingPrice = 2 ether;
        uint256 duration = 3600; // second
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        nftMarketplace.createAuctionFromMarketplace{value: listingFee}(tokenId, startingPrice, duration);
        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);
        NFTMarketplace.Auction memory auctionItem = nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId);

        assertEq(marketItem.owner, address(nftMarketplace));
        assertEq(marketItem.lister, USER1);
        assertEq(marketItem.price, 0);
        assertFalse(marketItem.sold);
        assertEq(nftMarketplace.ownerOf(tokenId), address(nftMarketplace));
        assertEq(auctionItem.tokenId, tokenId);
        assertEq(auctionItem.lister, USER1);
        assertEq(auctionItem.highestBid, startingPrice);
        assertEq(auctionItem.highestBidder, address(0));
        assertEq(auctionItem.endTime, block.timestamp + duration);
        assertTrue(auctionItem.active);

        vm.stopPrank();
    }

    function test_emit_createAuction() public mint {
        uint256 tokenId = 0;
        uint256 startingPrice = 2 ether;
        uint256 duration = 3600; // second
        uint256 listingFee = nftMarketplace.getListingFee();

        vm.startPrank(USER1);

        vm.expectEmit();
        emit Events.CreateAuction(tokenId, USER1, startingPrice, block.timestamp + duration);
        nftMarketplace.createAuction{value: listingFee}(tokenId, startingPrice, duration);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    //////////////////      PlaceBid Tests      //////////////
    //////////////////////////////////////////////////////////
    modifier auction() {
        vm.startPrank(USER1);

        Vm.Log[] memory logs;
        bytes32 requestIdBytes; // nếu requestId là indexed
        uint256 requestId;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();

        vm.recordLogs();
        nftMarketplace.mintFromMarketplace{value: mintFee}();
        logs = vm.getRecordedLogs();

        // Lấy requestId từ log
        requestIdBytes = logs[1].topics[1]; // nếu requestId là indexed
        requestId = uint256(requestIdBytes);

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(requestId, nftMarketplace.getVRFHandler());

        uint256 tokenId = 0;
        uint256 startingPrice = 2 ether;
        uint256 duration = 3600; // second
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        nftMarketplace.createAuction{value: listingFee}(tokenId, startingPrice, duration);

        vm.stopPrank();

        _;
    }

    function test_revert_placeBid() public auction {
        uint256 tokenId = 0;

        vm.startPrank(USER1);

        vm.expectRevert(NFTMarketplace__BidBelowMinimum.selector);
        nftMarketplace.placeBidFromMarketplace{value: 1 ether}(tokenId);

        vm.stopPrank();
    }

    function test_revertAuctionEnded_placeBid() public mint {
        uint256 tokenId = 0;
        uint256 startingPrice = 2 ether;
        uint256 duration = 3600; // second
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        vm.startPrank(USER1);

        nftMarketplace.createAuctionFromMarketplace{value: listingFee}(tokenId, startingPrice, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__AuctionHasEnded.selector);
        nftMarketplace.placeBidFromMarketplace(tokenId);

        vm.stopPrank();
    }

    function test_revertAuctionInactive_placeBid() public {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);
        vm.expectRevert(NFTMarketplace__AuctionNotActive.selector);
        nftMarketplace.placeBidFromMarketplace{value: price}(tokenId);
        vm.stopPrank();
    }

    //first placeBid
    function test_first_placeBid() public auction {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);

        nftMarketplace.placeBidFromMarketplace{value: price}(tokenId);

        NFTMarketplace.Auction memory auctionItem = nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId);

        assertEq(auctionItem.highestBid, price);
        assertEq(auctionItem.highestBidder, USER2);

        vm.stopPrank();
    }

    //second placeBid
    function test_second_placeBid() public auction {
        uint256 tokenId = 0;
        uint256 firstPrice = 2 ether;
        uint256 secondPrice = 3 ether;

        vm.startPrank(USER2);

        nftMarketplace.placeBidFromMarketplace{value: firstPrice}(tokenId);

        vm.stopPrank();

        vm.startPrank(USER3);

        nftMarketplace.placeBidFromMarketplace{value: secondPrice}(tokenId);

        NFTMarketplace.Auction memory auctionItem = nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId);
        uint256 refundProceed = nftMarketplace.getProceedsForAddressFromMarketplace(USER2);

        assertEq(auctionItem.highestBid, secondPrice);
        assertEq(auctionItem.highestBidder, USER3);
        assertEq(refundProceed, firstPrice);

        vm.stopPrank();
    }

    function test_emitPlaceBid_placeBid() public auction {
        uint256 tokenId = 0;
        uint256 price = 3 ether;

        vm.startPrank(USER2);

        vm.expectEmit();
        emit Events.PlaceBid(tokenId, USER2, price);
        nftMarketplace.placeBid{value: price}(tokenId);

        vm.stopPrank();
    }

    function test_auctionExtended_placeBid() public auction {
        uint256 tokenId = 0;
        uint256 price = 2 ether;

        vm.startPrank(USER2);

        uint256 oldEndTime = nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).endTime;
        vm.warp(oldEndTime - 300);

        nftMarketplace.placeBid{value: price}(tokenId);

        uint256 newEndTime = nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).endTime;

        assertEq(oldEndTime + Constants.AUCTION_EXTENSION, newEndTime);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    /////////////////      EndAuction Tests      /////////////
    //////////////////////////////////////////////////////////
    function test_revertAuctionInactive_endAuction() public {
        uint256 tokenId = 0;

        vm.startPrank(USER2);
        vm.expectRevert(NFTMarketplace__AuctionNotActive.selector);
        nftMarketplace.endAuctionFromMarketplace(tokenId);
        vm.stopPrank();
    }

    function test_revertAuctionEnded_endAuction() public auction {
        uint256 tokenId = 0;

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__AuctionStillActive.selector);
        nftMarketplace.endAuction(tokenId);

        vm.stopPrank();
    }

    function test_success_endAuction() public auction {
        uint256 tokenId = 0;
        uint256 duration = 3600; // second
        uint256 marketplaceFeeBP = 30;
        uint256 priceBid = 3 ether;
        uint256 mintFee = nftMarketplace.getMintFeeFromMarketplace();
        uint256 listingFee = nftMarketplace.getListingFeeFromMarketplace();

        vm.prank(USER2);
        nftMarketplace.placeBidFromMarketplace{value: priceBid}(tokenId);

        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(USER1);

        nftMarketplace.endAuction(tokenId);
        NFTMarketplace.MarketItem memory item = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId);

        uint256 itemSold = nftMarketplace.getItemSold();
        (address royaltyReceiver, uint256 royaltyAmount) = nftMarketplace.royaltyInfo(tokenId, priceBid);
        uint256 feeMarketAmount = (priceBid * marketplaceFeeBP) / Constants.MARKETPLACE_FEE_DENOM;
        uint256 contractProceed = nftMarketplace.getProceedsForAddress(nftMarketplace.getOwner());

        assertTrue(item.sold);
        assertFalse(nftMarketplace.getAuctionForTokenId(tokenId).active);
        assertEq(itemSold, 1);
        assertEq(item.price, 3 ether);
        assertEq(item.owner, USER2);
        assertEq(nftMarketplace.ownerOf(tokenId), address(USER2));
        assertEq(royaltyAmount, 0.3 ether);
        assertEq(royaltyReceiver, USER1);
        assertEq(contractProceed, feeMarketAmount + mintFee + listingFee);

        vm.stopPrank();
    }

    function test_emit_success_endAuction() public auction {
        uint256 tokenId = 0;
        uint256 priceBid = 3 ether;
        uint256 duration = 3600; // second

        vm.prank(USER2);
        nftMarketplace.placeBidFromMarketplace{value: priceBid}(tokenId);

        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(USER1);

        vm.expectEmit();
        emit Events.EndAuction(tokenId, nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).highestBidder, 
                        nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).highestBid);
        nftMarketplace.endAuctionFromMarketplace(tokenId);

        vm.stopPrank();
    }

    function test_fail_endAuction() public auction {
        uint256 tokenId = 0;
        uint256 duration = 3600; // second

        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(USER1);

        nftMarketplace.endAuctionFromMarketplace(tokenId);

        bool itemAlreadySold = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId).sold;
        uint256 itemSold = nftMarketplace.getItemSoldFromMarketplace();
        address itemOwner = nftMarketplace.getItemForTokenIdFromMarketplace(tokenId).owner;

        assertFalse(itemAlreadySold);
        assertFalse(nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).active);
        assertEq(itemSold, 0);
        assertEq(nftMarketplace.getItemForTokenIdFromMarketplace(tokenId).price, 0 ether);
        assertEq(itemOwner, USER1);
        assertEq(nftMarketplace.ownerOf(tokenId), address(USER1));

        vm.stopPrank();
    }

    function test_emit_fail_endAuction() public auction {
        uint256 tokenId = 0;
        uint256 priceBid = 3 ether;
        uint256 duration = 3600; // second

        vm.prank(USER2);
        nftMarketplace.placeBidFromMarketplace{value: priceBid}(tokenId);

        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(USER1);

        vm.expectEmit();
        emit Events.EndAuction(tokenId, nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).highestBidder, 
                                nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).highestBid);
        nftMarketplace.endAuctionFromMarketplace(tokenId);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    ///////////////      CancelAuction Tests      ////////////
    //////////////////////////////////////////////////////////
    function test_revertAuctionInactive_cancelAuction() public {
        uint256 tokenId = 0;        

        vm.startPrank(USER1);

        vm.expectRevert(NFTMarketplace__AuctionNotActive.selector);
        nftMarketplace.cancelAuctionFromMarketplace(tokenId);

        vm.stopPrank();
    }

    function test_revertNotOwner_cancelAuction() public auction() {
        uint256 tokenId = 0;        

        vm.startPrank(USER2);

        vm.expectRevert(NFTMarketplace__CallerNotTokenOwner.selector);
        nftMarketplace.cancelAuctionFromMarketplace(tokenId);

        vm.stopPrank();
    }

    function test_cancelAuction() public auction() {
        uint256 tokenId = 0;        

        vm.startPrank(USER1);

        nftMarketplace.cancelAuctionFromMarketplace(tokenId);
        
        NFTMarketplace.Auction memory auction = nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId);
        
        assertFalse(auction.active);
        assertEq(nftMarketplace.ownerOf(tokenId), address(USER1));

        vm.stopPrank();
    }

    function test_emit_cancelAuction() public auction() {
        uint256 tokenId = 0;        

        vm.startPrank(USER1);

        vm.expectEmit();
        emit Events.CancelAuction(tokenId, nftMarketplace.getAuctionForTokenIdFromMarketplace(tokenId).lister);
        nftMarketplace.cancelAuctionFromMarketplace(tokenId);

        vm.stopPrank();
    }

}