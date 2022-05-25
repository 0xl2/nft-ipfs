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

        // set mint minter
        await nftContract.setMinter(acc1.address);
    });

    it("mint nft should work", async() => {
        await nftContract.connect(acc1).mintNFT(acc2.address, "ipfs_url");
        await expect(
            nftContract.connect(acc1).mintNFT(acc2.address, "url")
        ).to.be.revertedWith("Mint already");
    });
});
