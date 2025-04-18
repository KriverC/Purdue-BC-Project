pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Market is ReentrancyGuard, IERC721Receiver {
    
  using Address for address payable;

  uint256 public nextId;
  mapping(uint256 => Listing) public listings;

  struct Listing{
    address seller;
    address nftAddr;
    uint256 nftId;
    uint256 price;
  }

  enum Status {Listed, Bought, Cancelled}
  
  // Function to confirm safe handling of nft tokens
  function onERC721Received(
    address,      // operator
    address,      // from
    uint256,      // tokenId
    bytes calldata  /* data */
  ) external pure override returns (bytes4) {
    // Return the selector to confirm the transfer
    return IERC721Receiver.onERC721Received.selector;
  } 

  // One event for all occurences for friendly logging 
  event Update(
    uint256 indexed listingId,
    Status indexed status,
    address indexed nftAddr,
    uint256 nftId,
    address seller,
    address buyer,
    uint256 price
  );

  function listForSale(address nftAddr, uint256 nftId, uint256 price) external nonReentrant {

    // Check to see if listing price is valid
    require(price > 0, "Price can not be zero or less");

    // Transfer ownership of item to contract for holding
    IERC721(nftAddr).safeTransferFrom(msg.sender, address(this), nftId);

    // Map listing in to listingId and emit List event for logging
    listings[nextId] = Listing(msg.sender, nftAddr, nftId, price);
    emit Update(nextId, Status.Listed, nftAddr, nftId, msg.sender, address(0), price);
    nextId++;

  }

  function buy(uint256 listingId) external payable nonReentrant {

    Listing memory listing = listings[listingId];

    // Check if listing exists
    require(listing.seller != address(0), "This listing does not exist.");

    // Ensure purchaser has provided enough funds to purchase
    require(msg.value == listing.price, "Incorrect funds provided. Ensure to provide the exact amount listed.");
    
    // Delete listing from mapping
    delete listings[listingId];

    // Attempt to pay seller 
    payable(listing.seller).sendValue(msg.value);
  
    // Transfer nft to buyer and emit log
    IERC721(listing.nftAddr).safeTransferFrom(address(this), msg.sender, listing.nftId);
    emit Update(listingId, Status.Bought, listing.nftAddr, listing.nftId, listing.seller, msg.sender, listing.price);

  }
  
  
  function cancelSale(uint256 listingId) external nonReentrant {
     
    // Retrieve listing to check if exists and if sender is seller
    Listing memory listing = listings[listingId];
    require(listing.seller != address(0), "This listing does not exist.");
    require(msg.sender == listing.seller, "You must own this listing to cancel");

    // Remove listing
    delete listings[listingId];

    // Safely transfer nft back to owner
    IERC721(listing.nftAddr).safeTransferFrom(address(this), listing.seller, listing.nftId);

    // Emit cancellation log
    emit Update(listingId, Status.Cancelled, listing.nftAddr, listing.nftId, listing.seller, address(0), listing.price);

  }

}
