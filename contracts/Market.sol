pragma solidity ^0.8.24

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
  
contract Market {

  uint256 public nextId;
  mapping(uint256 => item) items;

  struct Item {
    address seller;
    address nft;
    uint256 nftId;
    uint256 price;
    bool forSale;
  }
  
  // Event to log items listed for sale on the martket
  event Sale(address indexed nft, address indexed seller, uint256 nftId, uint256 itemId, uint256 price);

  function listForSale(address nft, uint256 nftId, uint256 price) external nonReentrant {

    // Check to see if listing price is valid
    require(price >= 0, "Price can not be less than zero");

    // Transfer ownership of item to contract for holding
    IERC721(nft).safeTransferFrom(msg.sender, address(this), nftId);

    // Log listing in contract listings and emit Sale event for logging
    items[nextId] = Item(msg.sender, nft, nftId, price, true);
    emit Sale(nft, msg.sender, nftId, nextId++, price);

  }

  // Event to log items bought from the market
  event Bought(address indexed nft, address indexed buyer, uint256 nftId, uint256 price);

  function buyItem(uint256 itemId) external payable nonReentrant {
    // Check if itemId is accounted for
    requre(itemId < nextId && itemId >= 0, "Invalid item ID");

    // Retrieve existing item and check if for sale
    Item memory item = items[itemId];
    require(item.forSale == True, "Item is not for sale");

    // Ensure purchaser has provided enough funds to purchase
    require(msg.value == item.price, "Incorrect funds provided. Ensure to provide the exact amount listed.");

    (bool success, ) = item.seller.call{value: msg.value}("");

  }


  cancelSale


}
