// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.24;

/// -----------------------------------------------------------------------
/// Minimal interface – only what we call ⤵
interface IERC721 {
    function ownerOf(uint256 id) external view returns (address);
    function transferFrom(address from, address to, uint256 id) external;
}

/// Marketplace that lists any external ERC‑721 without OZ helpers.
contract SimpleMarketplace {
    struct Listing {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 price;     // wei
        bool    active;
    }

    uint256 public nextListingId;
    mapping(uint256 => Listing) public listings;
    mapping(address => uint256) public proceeds; // seller ⇒ ETH earned

    // ----------- modifiers & re‑entrancy guard -----------
    bool private locked;
    modifier nonReentrant() { require(!locked, "RE"); locked = true; _; locked = false; }

    // ------------------- events --------------------------
    event Listed(uint256 id, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);
    event Cancelled(uint256 id);
    event Bought(uint256 id, address indexed buyer, uint256 price);

    // -------------- core user flows ----------------------
    function list(address nft, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "price=0");
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "!owner");

        uint256 id = nextListingId++;
        listings[id] = Listing(msg.sender, nft, tokenId, price, true);

        // escrow the NFT in the marketplace itself
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);
        emit Listed(id, msg.sender, nft, tokenId, price);
    }

    function cancel(uint256 id) external nonReentrant {
        Listing storage L = listings[id];
        require(L.active, "!active");
        require(L.seller == msg.sender, "!seller");

        L.active = false;
        IERC721(L.nft).transferFrom(address(this), msg.sender, L.tokenId);
        emit Cancelled(id);
    }

    function buy(uint256 id) external payable nonReentrant {
        Listing storage L = listings[id];
        require(L.active, "!active");
        require(msg.value == L.price, "bad price");

        L.active = false;
        proceeds[L.seller] += msg.value;
        IERC721(L.nft).transferFrom(address(this), msg.sender, L.tokenId);
        emit Bought(id, msg.sender, msg.value);
    }

    function withdraw() external nonReentrant {
        uint256 bal = proceeds[msg.sender];
        require(bal > 0, "0");
        proceeds[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "transfer fail");
    }

    // ------------- view helpers for the dApp -------------
    function getListing(uint256 id) external view returns (Listing memory) { return listings[id]; }

    /// Return active listings in an inclusive [start, stop) window
    function activeListings(uint256 start, uint256 stop) external view returns (Listing[] memory arr) {
        uint256 len = stop - start;
        arr = new Listing[](len);
        for (uint256 i; i < len; ++i) arr[i] = listings[start + i];
    }
}
