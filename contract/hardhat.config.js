require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const config = require('./config/config.json');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  defaultNetwork: 'fuji',
  networks: {
    ganache: {
      url: 'http://localhost:7545',
      chainId: 1337,
      accounts: [
        config.p_key,
        config.acc1,
        config.acc2
      ]
    },
    fuji: {
      url: "https://speedy-nodes-nyc.moralis.io/1c8d8856c017266c637672dd/avalanche/testnet",
      chainId: 43113,
      accounts: [config.p_key]
    }
  },
  etherscan: {
    apiKey: config.api_key
  }
};
