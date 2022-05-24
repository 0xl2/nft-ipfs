//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MyNFT is Ownable, ERC721URIStorage, ERC721Enumerable, ReentrancyGuard {
    using Counters for Counters.Counter;

    uint public MintPrice;

    Counters.Counter private _tokenIds;

    event PriceSet(uint price);
    event MintNFT(address indexed minter, uint tokenId);

    constructor() 
    ERC721("MyNFT", "MYNFT") {}

    function setMintPrice(uint _price) external onlyOwner {
        require(_price > 0, "Invalid price");
        MintPrice = _price;

        emit PriceSet(MintPrice);
    }

    function mintNFT(string memory metaURI) external payable nonReentrant returns(uint tokenId) {
        require(balanceOf(msg.sender) == 0, "Mint already");
        require(msg.value >= MintPrice, "Insufficient balance");

        _tokenIds.increment();
        tokenId = _tokenIds.current();

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, metaURI);

        emit MintNFT(msg.sender, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function withdraw(address wallet) external onlyOwner {
        payable(wallet).transfer(address(this).balance);
    }

    receive() external payable {}
}