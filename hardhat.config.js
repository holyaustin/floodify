require("@nomiclabs/hardhat-waffle");
// require("@nomiclabs/hardhat-etherscan"); 
require("@nomicfoundation/hardhat-verify");
require('dotenv').config();
//console.log(process.env.NEXT_PUBLIC_PRIVATE_KEY);

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337
    },

    solaris: {
      url: 'https://rpc-mainnet.uniultra.xyz/',
      accounts: [process.env.NEXT_PUBLIC_PRIVATE_KEY], // it should start with 0x...
    },
    nebulas: {
      url: 'https://rpc-nebulas-testnet.uniultra.xyz/',
      accounts: [process.env.NEXT_PUBLIC_PRIVATE_KEY], // it should start with 0x...
    },
   
    testnet: {
      url: `https://rpc.testnet.mantle.xyz`, 
      accounts: [process.env.NEXT_PUBLIC_PRIVATE_KEY],
    }

  },
  etherscan: {
    apiKey: {
      nebulas: "abc", // arbitrary string
    },
    customChains: [
      {
        network: "nebulas",
        chainId: 2484,
        urls: {
          apiURL: "https://testnet.u2uscan.xyz/api",
          browserURL: "https://testnet.u2uscan.xyz"
        }
      },
    ]
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};
