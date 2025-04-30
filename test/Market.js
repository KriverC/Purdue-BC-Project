// test/Market.t.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Market", () => {
  let nft, market, seller, buyer, third;

  // ───────────────────────────────────────────────────────
  // Deploy a mock ERC‑721 + the marketplace before each test
  beforeEach(async () => {
    [seller, buyer, third] = await ethers.getSigners();

    // Minimal in‑house ERC‑721 (only what we need)
    const Mock721 = await ethers.getContractFactory(`
      // SPDX‑License‑Identifier: MIT
      pragma solidity ^0.8.28;
      import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
      contract Mock721 is ERC721 {
        constructor() ERC721("Mock","MOCK") {}
        function mint(address to, uint id) external { _mint(to, id); }
      }`);
    nft = await Mock721.deploy();

    // Mint token #1 to seller
    await nft.mint(seller.address, 1);

    // Deploy market (after you inherit ReentrancyGuard, no args)
    const Market = await ethers.getContractFactory("Market");
    market = await Market.deploy();
  });

  // ───────────────────────────────────────────────────────
  it("lists an NFT for sale", async () => {
    // Seller approves market, then lists
    await nft.connect(seller).approve(market.target, 1);

    const price = ethers.parseEther("1");

    await expect(
      market.connect(seller).listForSale(nft.target, 1, price)
    )
      .to.emit(market, "Sale")
      .withArgs(nft.target, seller.address, 1, 0, price); // itemId is 0 on first list

    // Ownership has moved to the marketplace
    expect(await nft.ownerOf(1)).to.equal(market.target);
  });

  // ───────────────────────────────────────────────────────
  it("lets a buyer purchase the listed NFT", async () => {
    await nft.connect(seller).approve(market.target, 1);
    const price = ethers.parseEther("1");
    await market.connect(seller).listForSale(nft.target, 1, price);

    // Buyer balance bookkeeping: we’ll check ether transfer
    await expect(
      market.connect(buyer).buyItem(0, { value: price })
    )
      .to.changeEtherBalances(
        [buyer, seller],
        [price * -1n, price]          // buyer pays, seller receives
      )
      .and.to.emit(market, "Bought")
      .withArgs(nft.target, buyer.address, 1, price);

    // Buyer now owns the NFT
    expect(await nft.ownerOf(1)).to.equal(buyer.address);
  });

  // ───────────────────────────────────────────────────────
  it("allows the seller to cancel a listing", async () => {
    await nft.connect(seller).approve(market.target, 1);
    await market.connect(seller).listForSale(nft.target, 1, 0);

    await expect(market.connect(seller).cancelSale(0))
      .to.emit(market, "Cancel")
      .withArgs(0);

    // NFT returned to seller
    expect(await nft.ownerOf(1)).to.equal(seller.address);
  });

  // ───────────────────────────────────────────────────────
  it("reverts if someone else tries to cancel", async () => {
    await nft.connect(seller).approve(market.target, 1);
    await market.connect(seller).listForSale(nft.target, 1, 0);

    await expect(
      market.connect(third).cancelSale(0)
    ).to.be.revertedWith("You must own this listing to cancel");
  });
});