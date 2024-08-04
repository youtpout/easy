// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract EasyNFT is ERC721, ERC721Burnable, Ownable, IERC721Receiver {
    uint256 private _nextTokenId;

    mapping(uint256 => uint256) public linkedPosition;

    constructor(
        address initialOwner
    ) ERC721("EasyNFT", "EASY") Ownable(initialOwner) {}

    function safeMint(
        address to,
        uint256 tokenIdPosition
    ) internal returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        linkedPosition[tokenId] = tokenIdPosition;
        _safeMint(to, tokenId);
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // todo check come from uniswap

        return this.onERC721Received.selector;
    }
}
