// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// ---------------------- Errors ----------------------
error NFTMarketplace__PriceMustBeAboveZero();
error NFTMarketplace__NotApprovedForMarketplace();
error NFTMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NFTMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NFTMarketplace__NotOwner();
error NFTMarketplace__PriceNotMet(
    address nftAddress,
    uint256 tokenId,
    uint256 price
);
error NFTMarketplace__NoProceedsToWithdraw();
error NFTMarketplace__ProceedsTransferFailed();

// ---------------------- Types ----------------------
struct Listing {
    uint256 price;
    address seller;
}

contract NFTMarketplace is ReentrancyGuard {
    // ---------------------- State variables ----------------------
    // NFT contract address => token ID => listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    // keep track of people balances (how much they have earned): sellerAddress => balance
    mapping(address => uint256) private s_proceeds;

    // ---------------------- Modifiers ----------------------
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];

        if (listing.price > 0) {
            revert NFTMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        IERC721 nftContract = IERC721(nftAddress);
        if (nftContract.ownerOf(tokenId) != owner) {
            revert NFTMarketplace__NotOwner();
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];

        if (listing.price <= 0) {
            revert NFTMarketplace__NotListed(nftAddress, tokenId);
        }
        _;
    }

    // ---------------------- Events ----------------------
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    // ---------------------- Functions ----------------------
    function listIem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        // TODO: Have this contract accept payment in subset of ERC20 tokens (Hint: use chanlink price feeds)
        notListed(nftAddress, tokenId, msg.sender)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert NFTMarketplace__PriceMustBeAboveZero();
        }

        IERC721 nftContract = IERC721(nftAddress);
        if (nftContract.getApproved(tokenId) != address(this)) {
            revert NFTMarketplace__NotApprovedForMarketplace();
        }

        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert NFTMarketplace__PriceNotMet(
                nftAddress,
                tokenId,
                listedItem.price
            );
        }

        s_proceeds[listedItem.seller] += msg.value;

        delete (s_listings[nftAddress][tokenId]);

        // Transfer NFT to buyer
        IERC721(nftAddress).safeTransferFrom(
            listedItem.seller,
            msg.sender,
            tokenId
        );

        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    function cancelListing(
        address nftAddress,
        uint256 tokenId
    )
        external
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId)
    {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        isListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        s_listings[nftAddress][tokenId].price = newPrice;
        // re-listing the item with new price
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) revert NFTMarketplace__NoProceedsToWithdraw();
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) revert NFTMarketplace__ProceedsTransferFailed();
    }

    // ---------------------- Getters ----------------------
    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}

// listItem: list NFTs on marketplace
// buyItem: buy NFTs from marketplace
// cancelItem: cancel NFTs from marketplace
// updateListing: update NFTs price
// withdrawProceeds: withdraw proceeds from sales

// PULL OVER PUSH
// Pull over push is a security best practice in solidity, where you don't send funds to a user, but instead let them pull the funds from your contract.this is because if you send funds to a user, they can call a function in their contract that reverts, and then the funds will be stuck in your contract

// Re-entrancy attack
// Re-entrancy attack is when a malicious contract calls a function in your contract, and then calls the same function again before the first call is finished. This can be used to drain funds from your contract.
// that's why we use pull over push, so change state before sending funds

// Oracle attack
// Happens usually when a protocol doesn't use a decentralized oracle like chainlink, and instead uses a centralized oracle. A malicious actor can then bribe the oracle to give a false price, and then drain funds from the protocol.
// that's why we use chainlink price feeds
