// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const KmbioRouter = await hre.ethers.getContractFactory("KmbioRouter");
  const kmbioRouter = await KmbioRouter.deploy("0xbaa207a1673dea8b6890817e5e68e06677471cfb", "0x4200000000000000000000000000000000000006");

  await kmbioRouter.deployed();

  console.log(
    `KmbioRouter deployed to ${kmbioRouter.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});