// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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

// ---------------------- Types ----------------------
struct Listing {
    uint256 price;
    address seller;
}

contract NFTMarketplace {
    // ---------------------- State variables ----------------------
    // NFT contract address => token ID => listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    // keep track of people balances: address => balance
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
    ) external payable isListed(nftAddress, tokenId) {
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

        emit ItemBought(
            msg.sender,
            nftAddress,
            tokenId,
            listedItem.price,
        );
    }
}

// listItem: list NFTs on marketplace
// buyItem: buy NFTs from marketplace
// cancelItem: cancel NFTs from marketplace
// updateListing: update NFTs price
// withdrawProceeds: withdraw proceeds from sales
