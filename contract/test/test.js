const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Mynft testing", function () {
    let deployer, acc1, acc2;
    let nftContract;

    before("Deploy contracts", async() => {
        [deployer, acc1, acc2] = await ethers.getSigners();

        // deploy MyNFT contract
        const MyNFT = await ethers.getContractFactory("MyNFT");
        nftContract = await MyNFT.deploy();
        await nftContract.deployed();
        console.log(`MyNFT contract deployed to: ${nftContract.address}`);

        // set mint price 0.1ETH
        await nftContract.setMintPrice(ethers.utils.parseUnits("0.1"));
    });

    it("mint nft requires 0.1 ETH", async() => {
        await expect(
            nftContract.mintNFT("ipfs_url")
        ).to.be.revertedWith("Insufficient balance");

        await expect(
            nftContract.mintNFT("ipfs_url", {value: ethers.utils.parseUnits("0.01")})
        ).to.be.revertedWith("Insufficient balance");
    });

    it("mint nft should work", async() => {
        await nftContract.connect(acc1).mintNFT("ipfs_url", {value: ethers.utils.parseUnits("0.1")});
        const tokenId = await nftContract.tokenOfOwnerByIndex(acc1.address, 0);
        expect(tokenId).to.eq(1);

        await nftContract.connect(acc2).mintNFT("ipfs_url", {value: ethers.utils.parseUnits("0.1")});
        const tokenId2 = await nftContract.tokenOfOwnerByIndex(acc2.address, 0);
        expect(tokenId2).to.eq(2);
    });
});
