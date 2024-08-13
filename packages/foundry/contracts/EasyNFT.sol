// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract EasyNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    IERC721Receiver
{
    uint256 public _nextTokenId;

    mapping(uint256 => uint256) public linkedPosition;

    /*   /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC721_init("EasyNFT", "EASY");
        __ERC721Burnable_init();
        __Ownable_init(initialOwner);
    }*/

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
