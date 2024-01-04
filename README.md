# Solidity smart contract and hardhat dev environment for Minah

The .env file is not included in this repository. 

Create it and add the following keys :

POLYGONSCAN=[YOUR POLYGONSCAN API KEY]
ALCHEMYMUMBAI=[YOUR ALCHEMY MUMBAI API KEY]
PK=[YOUR DEV WALLET PRIVATE KEY WITH MUMBAI MATIC ON IT]

to run and deploy it through bash command line : 

git clone git@github.com:charlesjullien/Minah.git
cd Minah
yarn install
(create your .env file here as explained above)
yarn hardhat run ./scripts/deploy.js --network polygonMumbai
(the aboove step will deploy the contract and generate an address, paste it in your clipboard for the 'verify' step just below)
yarn hardhat verify --network polygonMumbai [THE GENERATED ADDRESS AS EXPLAINED ON THE STEP RIGHT ABOVE]

The Smart contract will then be deployed and you will be able to interact with it through the block explorer.