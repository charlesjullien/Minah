const hre = require("hardhat");

async function main() {

  console.log(
    `hello ?`
  );

  // Déploiement des contrats
  const Minah = await hre.ethers.getContractFactory("Minah");
  console.log(
    `1`
  );
  const minah = await Minah.deploy();
  console.log(
    `2`
  );
  await minah.deployed();

  console.log(
    `minah deployed to ${minah.address}`
  );
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
