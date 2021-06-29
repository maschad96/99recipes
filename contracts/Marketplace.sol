// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract NFT is ERC721URIStorage {
	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;
	address contractAddress;

	constructor(address marketplaceAddress) ERC721("99Recipes", "99R") {
		contractAddress = marketplaceAddress;
	}

	function createToken(string memory tokenURI) public returns (uint) {
		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(msg.sender, newItemId);
		_setTokenURI(newItemId, tokenURI);
		setApprovalForAll(contractAddress, true);
		return newItemId;
	}
}

contract NFTMarket is ReentrancyGuard {
	using Counters for Counters.Counter;
	Counters.Counter private _itemIds; // keep track of total items
	Counters.Counter private _itemsSold; // keep track of how many items have been sold

	address payable owner;
	uint256 listingPrice = 0.02 ether;

	constructor() {
		owner = payable(msg.sender);
	}

	struct MarketItem {
		uint itemId;
		address nftContract;
		uint256 tokenId;
		address payable seller;
		address payable owner;
		uint256 price;
	}

	mapping(uint256 => MarketItem) private idToMarketItem;

	event MarketItemCreated(
		uint256 indexed itemId,
		address indexed nftContract,
		uint256 indexed tokenId,
		address seller,
		address owner,
		uint256 price
	);

	function createMarketItem(
		address nftContract,
		uint256 tokenId,
		uint256 price
	) public payable nonReentrant {
		require(price > 0, "Price must be at least one wei");
		require(msg.value == listingPrice, "Price must be equal to listing price");

		_itemIds.increment();
		uint256 itemId = _itemIds.current();

		idToMarketItem[itemId] = MarketItem(
			itemId,
			nftContract,
			tokenId,
			payable(msg.sender),
			payable(address(0)),
			price
		);

		IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

		emit MarketItemCreated(
			itemId,
			nftContract,
			tokenId,
			msg.sender,
			address(0),
			price
		);
	}

	function createMarketSale(
		address nftContract,
		uint256 itemId
	) public payable nonReentrant {
		uint price = idToMarketItem[itemId].price;
		uint tokenId = idToMarketItem[itemId].tokenId;

		require(msg.value == price, "Please submit the asking price in order to complete the purchase");

		// Pay the seller the amount
		idToMarketItem[itemId].seller.transfer(msg.value);

		// Transfer the NFT to the buyer's address
		IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

		// Set the owner to the msg.sender, since they now own the asset
		idToMarketItem[itemId].owner = payable(msg.sender);

		// Increment the total items sold
		_itemsSold.increment();

		payable(owner).transfer(listingPrice);
	}

	function fetchMarketItems() public view returns (MarketItem[] memory) {
		uint itemCount = _itemIds.current();
		uint unsoldItemCount = itemCount - _itemsSold.current();
		uint currentIndex = 0;

		MarketItem[] memory items = new MarketItem[](unsoldItemCount);
		for (uint i = 0; i < itemCount; i++) {
			if (idToMarketItem[i + 1].owner == address(0)) {
				uint currentId = idToMarketItem[i + 1].itemId;
				MarketItem storage currentItem = idToMarketItem[currentId];
				items[currentIndex] = currentItem;
				currentIndex += 1;
			}
		}
		return items;
	}

	function fetchMyNFTs() public view returns (MarketItem[] memory) {
		uint totalItemCount = _itemIds.current();
		uint itemCount = 0;
		uint currentIndex = 0;

		for ( uint i = 0; i < totalItemCount; i++) {
			if (idToMarketItem[i + 1].owner == msg.sender) {
				itemCount += 1;
			}
		}

		MarketItem[] memory items = new MarketItem[](itemCount);
		for ( uint i = 0; i < totalItemCount; i++) {
			if (idToMarketItem[i + 1].owner == msg.sender) {
				uint currentId = idToMarketItem[i + 1].itemId;
				MarketItem storage currentItem = idToMarketItem[currentId];
				items[currentIndex] = currentItem;
				currentIndex += 1;
			}
		}
		return items;
	}
}