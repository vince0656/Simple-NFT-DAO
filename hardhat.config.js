require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-truffle5");
require('solidity-coverage');
require('@nomiclabs/hardhat-solhint');
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');

const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

let liveNetworks = {}

// If we have a private key, we can setup non dev networks
if (INFURA_PROJECT_ID && PRIVATE_KEY) {
  liveNetworks = {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
  }
}

module.exports = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20
      }
    }
  },
  networks: {
    ...liveNetworks,
    coverage: {
      url: 'http://localhost:8555',
    },
    hardhat: {
      initialBaseFeePerGas: 1
    }
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 120,
    enabled: !!process.env.GAS_REPORT
  }
};
