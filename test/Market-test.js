const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Market", function () {
  let Market, TestERC721;
  let market, erc721;
  let seller, buyer, other;
  let nftAddr, mktAddr, tokenId;

  beforeEach(async function () {
    [seller, buyer, other] = await ethers.getSigners();

    // Deploy and wait
    TestERC721 = await ethers.getContractFactory("TestERC721");
    erc721 = await TestERC721.deploy();
    await erc721.waitForDeployment();
    nftAddr = await erc721.getAddress();

    // Mint one NFT to seller and capture the token ID
    tokenId = await erc721.mint.staticCall(seller.address);
    await erc721.mint(seller.address);

    // Deploy the marketplace
    Market = await ethers.getContractFactory("Market");
    market = await Market.deploy();
    await market.waitForDeployment();
    mktAddr = await market.getAddress();
  });

  it("should let seller list an NFT", async function () {
    // Approve marketplace to move the NFT
    await erc721.connect(seller).approve(mktAddr, tokenId);

    // List for 1 ETH
    await expect(
      market
        .connect(seller)
        .listForSale(nftAddr, tokenId, ethers.parseEther("1"))
    )
      .to.emit(market, "Update")
      .withArgs(
        0,                           // listingId
        0,                           // Status.Listed
        nftAddr,                     // nftAddr
        tokenId,                     // nftId
        seller.address,              // seller
        ethers.ZeroAddress,          // buyer = 0x00
        ethers.parseEther("1")      // price
      );

    // NFT custody moved to contract
    expect(await erc721.ownerOf(tokenId)).to.equal(mktAddr);

    // Mapping reflects the listing
    const listing = await market.listings(0);
    expect(listing.seller).to.equal(seller.address);
    expect(listing.price).to.equal(ethers.parseEther("1"));
  });

  it("should let buyer purchase an NFT", async function () {
    // Setup: seller lists at 2 ETH
    await erc721.connect(seller).approve(mktAddr, tokenId);
    await market
      .connect(seller)
      .listForSale(nftAddr, tokenId, ethers.parseEther("2"));

    // Buyer pays exactly 2 ETH
    await expect(
      market.connect(buyer).buy(0, { value: ethers.parseEther("2") })
    )
      .to.emit(market, "Update")
      .withArgs(
        0,
        1,                       // Status.Bought
        nftAddr,
        tokenId,
        seller.address,
        buyer.address,
        ethers.parseEther("2")
      );

    // Ownership passes to buyer
    expect(await erc721.ownerOf(tokenId)).to.equal(buyer.address);

    // Listing cleared
    const listing = await market.listings(0);
    expect(listing.seller).to.equal(ethers.ZeroAddress);
  });

  it("should allow seller to cancel", async function () {
    // Setup: seller lists at 3 ETH
    await erc721.connect(seller).approve(mktAddr, tokenId);
    await market
      .connect(seller)
      .listForSale(nftAddr, tokenId, ethers.parseEther("3"));

    // Cancel the sale
    await expect(market.connect(seller).cancelSale(0))
      .to.emit(market, "Update")
      .withArgs(
        0,
        2,                       // Status.Cancelled
        nftAddr,
        tokenId,
        seller.address,
        ethers.ZeroAddress,
        ethers.parseEther("3")
      );

    // NFT returned to seller
    expect(await erc721.ownerOf(tokenId)).to.equal(seller.address);

    // Listing cleared
    const listing = await market.listings(0);
    expect(listing.seller).to.equal(ethers.ZeroAddress);
  });

  it("should revert on wrong price or unauthorized cancel", async function () {
    // Seller lists at 1 ETH
    await erc721.connect(seller).approve(mktAddr, tokenId);
    await market
      .connect(seller)
      .listForSale(nftAddr, tokenId, ethers.parseEther("1"));

    // Wrong funds
    await expect(
      market.connect(buyer).buy(0, { value: ethers.parseEther("0.5") })
    ).to.be.revertedWith(
      "Incorrect funds provided. Ensure to provide the exact amount listed."
    );

    // Someone else tries to cancel
    await expect(
      market.connect(other).cancelSale(0)
    ).to.be.revertedWith("You must own this listing to cancel");
  });
});

