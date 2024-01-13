const hre = require("hardhat");

async function main() {

  // Déploiement des contrats
  const Minah = await hre.ethers.getContractFactory("Minah");

  const minah = await Minah.deploy();

  await minah.deployed();

  console.log(
    `minah deployed to ${minah.address}`
  );
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
