// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const KmbioFactory = await hre.ethers.getContractFactory("KmbioFactory");
  const kmbioFactory = await KmbioFactory.deploy("0xE05B36b0e0e070bC5Bc1b90B3435924aa02cC061");

  await kmbioFactory.deployed();

  console.log(
    `KmbioFactory deployed to ${kmbioFactory.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});