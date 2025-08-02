import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { verifyProxy } from "./verify";
import { 
  getDeployConfig, 
  isDevelopmentChain, 
  isTestnet, 
  isMainnet,
  shouldVerifyContracts
} from "../config/deploy-config";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  // Get network from Hardhat Runtime Environment
  const hre: HardhatRuntimeEnvironment = require("hardhat");
  const { network } = hre;
  const networkName = network.name;
  
  console.log("🚀 Starting Thurman Protocol Deployment");
  console.log("========================================");
  console.log(`Network: ${networkName}`);
  console.log(`ChainId: ${network.config.chainId}`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
  
  // Get network-specific configuration
  const config = getDeployConfig(networkName);
  console.log(`\n📋 Using configuration for ${config.network}`);
  
  // Set deployer addresses for roles
  const treasuryAddress = config.roles.treasury || deployer.address;
  const adminAddress = config.roles.admin || deployer.address;
  
  // Validate network type and verification eligibility
  if (isDevelopmentChain(networkName)) {
    console.log("🔧 Development chain detected - using mock tokens");
    console.log("⏭️  Contract verification disabled (development network)");
  } else if (isTestnet(networkName)) {
    console.log("🧪 Testnet detected - using test tokens");
    console.log("🔍 Contract verification enabled (testnet)");
  } else if (isMainnet(networkName)) {
    console.log("🌐 Mainnet detected - using production tokens");
    console.log("🔍 Contract verification enabled (mainnet)");
    console.log("⚠️  WARNING: This is a mainnet deployment!");
  }
  
  console.log("\n📦 Deploying Core Contracts...");
  
  // 1. Deploy OriginatorRegistry
  console.log("\n1️⃣ Deploying OriginatorRegistry...");
  const OriginatorRegistryFactory = await ethers.getContractFactory("OriginatorRegistry");
  const originatorRegistry = await upgrades.deployProxy(OriginatorRegistryFactory, [
    adminAddress,
    config.tokens.USDC
  ]);
  await originatorRegistry.waitForDeployment();
  const originatorRegistryAddress = await originatorRegistry.getAddress();
  console.log(`   ✅ OriginatorRegistry: ${originatorRegistryAddress}`);

  // 2. Deploy LoanManager
  console.log("\n2️⃣ Deploying LoanManager...");
  const LoanManagerFactory = await ethers.getContractFactory("LoanManager");
  const loanManager = await upgrades.deployProxy(LoanManagerFactory, []);
  await loanManager.waitForDeployment();
  const loanManagerAddress = await loanManager.getAddress();
  console.log(`   ✅ LoanManager: ${loanManagerAddress}`);

  // 3. Deploy PoolManager
  console.log("\n3️⃣ Deploying PoolManager...");
  const PoolManagerFactory = await ethers.getContractFactory("PoolManager");
  const poolManager = await upgrades.deployProxy(PoolManagerFactory, []);
  await poolManager.waitForDeployment();
  const poolManagerAddress = await poolManager.getAddress();
  console.log(`   ✅ PoolManager: ${poolManagerAddress}`);

  // 4. Deploy SToken
  console.log("\n4️⃣ Deploying SToken...");
  const STokenFactory = await ethers.getContractFactory("SToken");  
  const sToken = await upgrades.deployProxy(STokenFactory, [
    poolManagerAddress,
    treasuryAddress,
    config.tokenNames.sTokenName,
    config.tokenNames.sTokenSymbol
  ]);
  await sToken.waitForDeployment();
  const sTokenAddress = await sToken.getAddress();
  console.log(`   ✅ SToken: ${sTokenAddress}`);

  // 5. Deploy DToken
  console.log("\n5️⃣ Deploying DToken...");
  const DTokenFactory = await ethers.getContractFactory("DToken");
  const dToken = await upgrades.deployProxy(DTokenFactory, [
    poolManagerAddress,
    config.tokenNames.dTokenName,
    config.tokenNames.dTokenSymbol
  ]);
  await dToken.waitForDeployment();
  const dTokenAddress = await dToken.getAddress();
  console.log(`   ✅ DToken: ${dTokenAddress}`);

  // 6. Deploy ERC7540Vault
  console.log("\n6️⃣ Deploying ERC7540Vault...");
  const VaultFactory = await ethers.getContractFactory("ERC7540Vault");
  const vault = await upgrades.deployProxy(VaultFactory, [
    config.tokens.USDC,
    sTokenAddress,
    dTokenAddress, 
    poolManagerAddress,
    loanManagerAddress
  ]);
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log(`   ✅ ERC7540Vault: ${vaultAddress}`);

  // 7. Configure initial pool
  console.log("\n7️⃣ Configuring initial pool...");
  console.log("🔍 Vault address:", vaultAddress);
  console.log("🔍 Originator registry address:", originatorRegistryAddress);
  console.log("🔍 Margin fee:", ethers.parseEther(config.poolSettings.marginFee));

  // Debug: Check PoolManager state
  console.log("🔍 PoolManager owner:", await poolManager.owner());
  console.log("🔍 PoolManager pool count:", await poolManager.getPoolCount());
  console.log("🔍 Deployer address:", deployer.address);

  // Debug: Test vault.asset() call with retry
  let assetAddress: string | null = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`🔍 Testing vault.asset() call (attempt ${attempt}/3)...`);
      const vaultContract = await ethers.getContractAt("IERC7540Vault", vaultAddress);
      assetAddress = await vaultContract.asset();
      console.log("🔍 Vault asset address:", assetAddress);
      break; // Success, exit retry loop
    } catch (error) {
      console.log(`❌ vault.asset() call failed (attempt ${attempt}/3):`, error);
      if (attempt < 3) {
        console.log("⏳ Waiting 2 seconds before retry...");
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
  }
  
  if (!assetAddress) {
    console.log("❌ WARNING: vault.asset() call failed after 3 attempts. This might cause issues.");
  }

  const marginFee = ethers.parseEther(config.poolSettings.marginFee);
  
  // Try addPool with retry mechanism
  let addPoolSuccess = false;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`🔍 About to call addPool (attempt ${attempt}/3)...`);
      const addPoolTx = await poolManager.addPool(
        vaultAddress,
        originatorRegistryAddress,
        marginFee
      );
      console.log("🔍 addPool transaction sent, waiting for confirmation...");
      await addPoolTx.wait(1); // Wait for 1 confirmation
      console.log(`   ✅ Pool added with ${config.poolSettings.marginFee} margin fee`);
      
      // Wait a bit longer for state to settle
      console.log("⏳ Waiting 3 seconds for state to settle...");
      await new Promise(resolve => setTimeout(resolve, 3000));
      addPoolSuccess = true;
      break; // Success, exit retry loop
    } catch (error) {
      console.log(`❌ addPool failed (attempt ${attempt}/3):`, error);
      if (attempt < 3) {
        console.log("⏳ Waiting 5 seconds before retry...");
        await new Promise(resolve => setTimeout(resolve, 5000));
      } else {
        throw error; // Re-throw on final attempt
      }
    }
  }

  const poolCountAfter = await poolManager.getPoolCount();
  console.log("🔍 Pool count after addPool:", poolCountAfter);
  
  if (poolCountAfter === 0n) {
    console.log("❌ WARNING: Pool count is still 0 after addPool! This means the pool wasn't actually added.");
    throw new Error("Pool was not added successfully");
  }
  
  // Debug: Check pool data in detail
  const poolData = await poolManager.getPool(0);
  console.log("🔍 Pool data details:");
  console.log("  - config.depositsEnabled:", poolData.config.depositsEnabled);
  console.log("  - config.withdrawalsEnabled:", poolData.config.withdrawalsEnabled);
  console.log("  - config.borrowingEnabled:", poolData.config.borrowingEnabled);
  console.log("  - config.isPaused:", poolData.config.isPaused);
  console.log("  - vault:", poolData.vault);
  console.log("  - originatorRegistry:", poolData.originatorRegistry);
  console.log("  - marginFee:", poolData.marginFee);

  // Debug: Check if we can access the pools mapping directly
  try {
    const directPoolData = await poolManager._pools(0);
    console.log("🔍 Direct _pools(0) access:", directPoolData);
  } catch (error) {
    console.log("❌ Direct _pools access failed:", error);
  }

  // 8. Configure pool operational settings
  console.log("\n8️⃣ Configuring pool operational settings...");
  const poolId = 0; // First pool
  const setSettingsTx = await poolManager.setPoolOperationalSettings(
    poolId,
    config.poolSettings.depositsEnabled,
    config.poolSettings.withdrawalsEnabled,
    config.poolSettings.borrowingEnabled,
    config.poolSettings.isPaused,
    ethers.parseUnits(config.poolSettings.maxDepositAmount, config.decimals.USDC),
    ethers.parseUnits(config.poolSettings.minDepositAmount, config.decimals.USDC),
    ethers.parseUnits(config.poolSettings.depositCap, config.decimals.USDC)
  );
  await setSettingsTx.wait(1); // Wait for 1 confirmation
  console.log(`   ✅ Pool operational settings configured`);

  // 9. Grant ACCRUER_ROLE to PoolManager in OriginatorRegistry
  console.log("\n9️⃣ Setting up permissions...");
  const grantRoleTx = await originatorRegistry.grantRole(await originatorRegistry.ACCRUER_ROLE(), poolManagerAddress);
  await grantRoleTx.wait(1); // Wait for 1 confirmation
  console.log(`   ✅ ACCRUER_ROLE granted to PoolManager`);

  // Check if we should verify contracts based on network type
  const shouldVerify = shouldVerifyContracts(networkName);
  
  if (shouldVerify && config.verification.enabled) {
    console.log(`\n⏳ Waiting ${config.verification.delay}ms for deployment indexing...`);
    await new Promise(resolve => setTimeout(resolve, config.verification.delay));
    
    console.log("\n🔍 Starting Contract Verification...");
    console.log("=====================================");
    
    try {
      console.log("\n📋 Verifying OriginatorRegistry...");
      await verifyProxy(originatorRegistryAddress);

      console.log("\n📋 Verifying LoanManager...");
      await verifyProxy(loanManagerAddress);

      console.log("\n📋 Verifying PoolManager...");
      await verifyProxy(poolManagerAddress);

      console.log("\n📋 Verifying SToken...");
      await verifyProxy(sTokenAddress);

      console.log("\n📋 Verifying DToken...");
      await verifyProxy(dTokenAddress);

      console.log("\n📋 Verifying ERC7540Vault...");
      await verifyProxy(vaultAddress);

      console.log("\n✅ All contracts verified successfully!");
    } catch (error) {
      console.log("\n❌ Verification failed:", error);
    }
  } else {
    if (!shouldVerify) {
      console.log("\n⏭️  Skipping verification (development network)");
    } else if (!config.verification.enabled) {
      console.log("\n⏭️  Skipping verification (disabled in config)");
    }
  }

  // Generate deployment summary
  const deployment = {
    network: config.network,
    chainId: network.config.chainId,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    config: {
      marginFee: config.poolSettings.marginFee,
      depositCap: config.poolSettings.depositCap,
      maxDepositAmount: config.poolSettings.maxDepositAmount,
      minDepositAmount: config.poolSettings.minDepositAmount,
      depositsEnabled: config.poolSettings.depositsEnabled,
      withdrawalsEnabled: config.poolSettings.withdrawalsEnabled,
      borrowingEnabled: config.poolSettings.borrowingEnabled,
      isPaused: config.poolSettings.isPaused,
      usdcAddress: config.tokens.USDC,
      usdcDecimals: config.decimals.USDC,
      treasury: treasuryAddress,
      admin: adminAddress
    },
    contracts: {
      poolManager: poolManagerAddress,
      loanManager: loanManagerAddress,
      originatorRegistry: originatorRegistryAddress,
      sToken: sTokenAddress,
      dToken: dTokenAddress,
      vault: vaultAddress
    },
    verification: {
      attempted: shouldVerify && config.verification.enabled,
      networkType: isDevelopmentChain(networkName) ? "development" : isTestnet(networkName) ? "testnet" : "mainnet"
    }
  };

  console.log("\n🎉 Deployment Summary");
  console.log("====================");
  console.log(JSON.stringify(deployment, null, 2));
  
  // Save deployment info to file
  const fs = require('fs');
  const deploymentFile = `deployments/${networkName}-${Date.now()}.json`;
  fs.mkdirSync('deployments', { recursive: true });
  fs.writeFileSync(deploymentFile, JSON.stringify(deployment, null, 2));
  console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);
  
  console.log("\n🚀 Thurman Protocol deployment completed successfully!");
}

main().catch((error) => {
  console.error("\n❌ Deployment failed:", error);
  process.exitCode = 1;
}); 