pragma solidity ^0.8.24

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
  
contract Market {

  uint256 public nextId;
  mapping(uint256 => item) items;

  struct item {
    address seller;
    address item;
    uint256 id;
    uint256 price;
    bool forSale;
  }

  function listForSale(address nft, uint256 price) external nonReentrant {

  }

  function buyItem(uint256
  cancelSale


}
