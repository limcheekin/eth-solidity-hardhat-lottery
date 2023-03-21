# :1st_place_medal: Lottery :tada:

> Lottery contract with Chainlink VRFv2 and Automation.
> The contract is using Chainlink VRFv2 for generating random numbers
> and Chainlink Automation to pick a winner periodically.

Therefore, for the correct operation of the contract, it is necessary to:

-   create subscription on > https://vrf.chain.link/sepolia for sepolia testnet, replenish the balance of LINK and add contract address as a consumer
-   create time-based upkeep on > https://automation.chain.link/sepolia for sepolia testnet, replenish the balance of LINK, add contract address, specify target function and schedule to be triggered.

## :file_folder: Table of Contents

-   [General Info](#-general-information)
-   [Technologies Used](#-technologies-used)
-   [Features](#-features)
-   [Requirements For Initial Setup](#-requirements-for-initial-setup)
-   [Setup](#-setup)
-   [Contact](#-contact)

## ℹ️ General Information

-   The lottery is start right after the contract is deployed
-   Every user can participate with 0.01 ETH
-   After the scheduler (Upkeep) end a lottery round, the winner will be picked using randomness from Chainlink VRFv2 Coordinator
-   Then, new lottery round start again

## 💻 Technologies Used

-   Chainlink VRFv2
-   Chainlink Automation
-   solhint
-   docgen
-   hardhat-deploy
-   trailofbits/eth-security-toolbox

## 🌟 Features

-   Trully random contract(Ideally for lottery)
-   Fully autonomous contract without human intervention

## 👀 Requirements For Initial Setup

-   Install [NodeJS](https://nodejs.org/en/), should work with any node version above 16.16.0
-   Install [Yarn](https://yarnpkg.com/getting-started/install),
    if yarn version >1.22.19 is installed, set it to version 1.22.19
    ```bash
    yarn set version 1.22.19
    ```
-   Install [Hardhat](https://hardhat.org/)

## 📟 Setup

### 1. 💾 Clone/Download the Repository

### 2. 📦 Install Dependencies:

```bash
$ cd eth-solidity-hardhat-lottery
$ yarn install
```

### 3. 📔 .env environment variables required to set up

Create a .env file inside the project directory by making a copy of .env.sample file and filling in the required variables.

-   You can get your ethereum or testnet URL [here](https://infura.io/dashboard/ethereum), [here](https://www.alchemy.com) or any other service that allow you to connect to the nodes
-   You can get your private key from your wallet (Don't share your private key with untrusted parties)
-   Subscription id can be obtained here after creation of subscription [here](https://vrf.chain.link)
-   Gas Lane/Key Hash and address of vrf coordinator can be obtained from here [here](https://docs.chain.link/vrf/v2/subscription/supported-networks) Just choose network and copy. :)
-   You can get your etherscan API key [here](https://etherscan.io/myapikey).
-   You can get your coinmarketcap API key [here](https://pro.coinmarketcap.com/account) if you want the gas cost reported in USD.

```
SEPOLIA_RPC_URL = <URL to connect to sepolia testnet>
PRIVATE_KEY = <Private key of your wallet u want to deploy contracts from, make sure it didn't has real money>
ETHERSCAN_API_KEY = <Etherscan API key in order to verify your contracts>
REPORT_GAS = <true or false to enabled or disabled gas reporting>
COINMARKETCAP_API_KEY = <Coinmarketcap API key in order to get the current price of ETH used by gas reporter>
VRF_COORDINATOR_V2 = <VRF coordinator address(depends on network)>
SUBSCRIPTION_ID = <VRFv2 subscription id.>
GAS_LANE = <Gas lane or key hash(depends on network)>
CALLBACK_GAS_LIMIT = <The gas limit to use for the VRFv2 callback function>
UPKEEP_PERFORM_IN_SECONDS = <Interval between lottery rounds>
LOTTERY_ENTRANCE_FEE = <Entrance fee of the lottery>
```

The .env.ci file is used by GitHub Actions (.github/workflows/hardhat.yml) to run unit test, display gas report and run code coverage on every `git push` and pull request.

### 4. ⚠️ Run Tests

```bash
$ yarn test
```

```bash
$ yarn coverage
```

### 5. 🚀 Deploy to Sepolia

```bash
$ yarn deploy:sepolia
```

### Note:

01-deploy-lottery.ts implements the verification script and you don't need to complete any additional steps in order to verify the contract.

## 💬 Contact

Created by [@limcheekin](https://www.linkedin.com/in/limcheekin/) - feel free to contact me!
