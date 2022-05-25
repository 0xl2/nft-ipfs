//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is Ownable, ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;

    address public Minter;

    Counters.Counter private _tokenIds;

    event MintNFT(address indexed minter, uint tokenId);
    event MinterSet(address indexed beforeAddr, address indexed afterAddr);

    constructor() 
    ERC721("MyNFT", "MYNFT") { }

    function setMinter(address minter) external onlyOwner {
        require(minter != address(0), "Invalid minter");

        emit MinterSet(Minter, minter);

        Minter = minter;
    }

    function getTokenCount() external view returns(uint) {
        return _tokenIds.current();
    }

    function mintNFT(address minter, string memory metaURI) external nonReentrant returns(uint tokenId) {
        require(msg.sender == Minter, "Not authorized");
        require(balanceOf(minter) == 0, "Mint already");

        _tokenIds.increment();
        tokenId = _tokenIds.current();

        _mint(minter, tokenId);
        _setTokenURI(tokenId, metaURI);

        emit MintNFT(minter, tokenId);
    }

    function withdraw(address wallet) external onlyOwner {
        payable(wallet).transfer(address(this).balance);
    }

    receive() external payable {}
}