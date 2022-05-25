const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    const myNFT = await ethers.getContractAt("MyNFT", "0xFb470DFbd969Ed0858a61EC5d7Fb8CB96ea12692");
    await myNFT.setMinter("0xFC38390A8621c76c4e5e7b5451a844995086dAfa");
    
    // MyNFT contract
    // const MyNFT = await ethers.getContractFactory("MyNFT");
    // const myNFT = await MyNFT.deploy();
    // await myNFT.deployed();
    // console.log(`mynft contract deployed to: ${myNFT.address}`);
}

main()
.then(() => process.exit())
.catch((error) => {
    console.error(error);
    process.exit(1);
});
