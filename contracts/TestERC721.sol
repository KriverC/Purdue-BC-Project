// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 public nextTokenId;

    constructor() ERC721("TestNFT", "TNFT") {}

    /// @notice Mint a fresh NFT to `to`
    function mint(address to) external returns (uint256) {
        uint256 tid = nextTokenId++;
        _safeMint(to, tid);
        return tid;
    }
}

