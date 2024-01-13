require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan"); //installs itself with hardhat packages

const PK = process.env.PK || "";

const ALCHEMYARBITRUM = process.env.ALCHEMYARBITRUM || "";
const ARBITRUMSCAN = process.env.ARBITRUMSCAN || "";

const ALCHEMYMUMBAI = process.env.ALCHEMYMUMBAI || "";
const POLYGONSCAN = process.env.POLYGONSCAN || "";

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      allowUnlimitedContractSize: true //to enable contracts interaction in /backend/scripts/deploy.js
    },
    arbitrumGoerli: {
      url: ALCHEMYARBITRUM,
      accounts: [`0x${PK}`],
      chainId: 421613,
      // gas: 5000000,  //uncomment to enable contracts interaction in /backend/scripts/deploy.js
      // gasPrice: 50000000000 //same
    },
    polygonMumbai: {
      url: ALCHEMYMUMBAI,
      accounts: [`0x${PK}`],
      chainId: 80001
      //gas : 5000000,
      //gasPrice: 50000000000
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000
          }
        }
      },
    ],
  },
  etherscan: {
    apiKey: {
      arbitrumGoerli: ARBITRUMSCAN,
      polygonMumbai: POLYGONSCAN
    }
  },
  namedAccounts: {
    deployer: {
      default: 0,
      1: 0,
    },
  }
};