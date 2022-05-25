const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    // const myNFT = await ethers.getContractAt("MyNFT", "");
    
    // MyNFT contract
    const MyNFT = await ethers.getContractFactory("MyNFT");
    const myNFT = await MyNFT.deploy();
    await myNFT.deployed();
    console.log(`mynft contract deployed to: ${myNFT.address}`);
}

main()
.then(() => process.exit())
.catch((error) => {
    console.error(error);
    process.exit(1);
});
