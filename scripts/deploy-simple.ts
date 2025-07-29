import { ethers, upgrades } from "hardhat";
import { getAddresses } from "../config/addresses";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = process.env.HARDHAT_NETWORK || "hardhat";
  
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Network:", network);
  
  const addresses = getAddresses("base");
  
  console.log("Deploying OriginatorRegistry...");
  const OriginatorRegistryFactory = await ethers.getContractFactory("OriginatorRegistry");
  const originatorRegistry = await upgrades.deployProxy(OriginatorRegistryFactory, [
    deployer.address,
    addresses.tokens.USDC
  ]);
  await originatorRegistry.waitForDeployment();
  console.log("OriginatorRegistry deployed to:", await originatorRegistry.getAddress());

  console.log("Deploying LoanManager...");
  const LoanManagerFactory = await ethers.getContractFactory("LoanManager");
  const loanManager = await upgrades.deployProxy(LoanManagerFactory, []);
  await loanManager.waitForDeployment();
  console.log("LoanManager deployed to:", await loanManager.getAddress());

  console.log("Deploying PoolManager...");
  const PoolManagerFactory = await ethers.getContractFactory("PoolManager");
  const poolManager = await upgrades.deployProxy(PoolManagerFactory, []);
  await poolManager.waitForDeployment();
  console.log("PoolManager deployed to:", await poolManager.getAddress());

  console.log("Deploying SToken...");
  const STokenFactory = await ethers.getContractFactory("SToken");  
  const sToken = await upgrades.deployProxy(STokenFactory, [
    await poolManager.getAddress(),
    deployer.address, // treasury
    "Thurman USDC Shares", 
    "sUSDC"
  ]);
  await sToken.waitForDeployment();
  console.log("SToken deployed to:", await sToken.getAddress());

  console.log("Deploying DToken...");
  const DTokenFactory = await ethers.getContractFactory("DToken");
  const dToken = await upgrades.deployProxy(DTokenFactory, [
    await poolManager.getAddress(),
    "Thurman USDC Debt",
    "dUSDC"  
  ]);
  await dToken.waitForDeployment();
  console.log("DToken deployed to:", await dToken.getAddress());

  console.log("Deploying ERC7540Vault...");
  const VaultFactory = await ethers.getContractFactory("ERC7540Vault");
  const vault = await upgrades.deployProxy(VaultFactory, [
    addresses.tokens.USDC,
    await sToken.getAddress(),
    await dToken.getAddress(), 
    await poolManager.getAddress(),
    await loanManager.getAddress()
  ]);
  await vault.waitForDeployment();
  console.log("ERC7540Vault deployed to:", await vault.getAddress());

  console.log("Adding initial pool...");
  await poolManager.addPool(
    await vault.getAddress(),
    await originatorRegistry.getAddress(),
    ethers.parseEther("0.02") // 2% margin fee
  );
  console.log("Initial pool added successfully");

  const deployment = {
    network: network,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      poolManager: await poolManager.getAddress(),
      loanManager: await loanManager.getAddress(),
      originatorRegistry: await originatorRegistry.getAddress(),
      sToken: await sToken.getAddress(),
      dToken: await dToken.getAddress(),
      vault: await vault.getAddress()
    }
  };

  console.log("Deployment completed:");
  console.log(JSON.stringify(deployment, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 