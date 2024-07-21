require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();
console.log("%c Line:28 🍐 process.env.RPC_URL", "color:#7f2b82", process.env.RPC_URL);
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [{version: "0.4.18"},
                {version: "0.5.16"},
                {version: "0.6.6",
                settings: {
                  optimizer: {
                    enabled: true,
                    runs: 200,
                  },
                }},
                {version: "0.8.4"},
                {version: "0.8.14"}],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    goerli: {
      url: "https://developer-access-mainnet.base.org",
      accounts: [process.env.SIGNER_PRIV_KEY],
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API_KEY,
    },
    customChains: [
      {
        network: "goerli",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      }
    ]
  }
};