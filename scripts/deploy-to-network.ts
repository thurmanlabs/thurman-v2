#!/usr/bin/env node

import { spawn } from 'child_process';
import { getDeployConfig, deployConfigs } from '../config/deploy-config';

// Get network from command line argument
const network = process.argv[2];

if (!network) {
  console.log("🌐 Available Networks:");
  console.log("=====================");
  
  Object.keys(deployConfigs).forEach(networkName => {
    const config = deployConfigs[networkName];
    const type = networkName === 'hardhat' || networkName === 'localhost' 
      ? '🔧 Development' 
      : networkName.includes('Sepolia') || networkName.includes('goerli') 
        ? '🧪 Testnet' 
        : '🌐 Mainnet';
    
    console.log(`${type} - ${networkName}`);
  });
  
  console.log("\n📖 Usage:");
  console.log("  npm run deploy <network>");
  console.log("  npx hardhat run scripts/deploy.ts <network> --network <network>");
  console.log("\n💡 Examples:");
  console.log("  npm run deploy baseSepolia");
  console.log("  npm run deploy base");
  console.log("  npm run deploy mainnet");
  
  process.exit(1);
}

// Validate network
if (!deployConfigs[network]) {
  console.error(`❌ Error: Network '${network}' not found in configuration`);
  console.log("\n🌐 Available networks:", Object.keys(deployConfigs).join(', '));
  process.exit(1);
}

// Get configuration for the network
const config = getDeployConfig(network);

console.log("🚀 Deploying Thurman Protocol");
console.log("=============================");
console.log(`Network: ${network}`);
console.log(`Type: ${network === 'hardhat' || network === 'localhost' ? 'Development' : network.includes('Sepolia') || network.includes('goerli') ? 'Testnet' : 'Mainnet'}`);
console.log(`USDC: ${config.tokens.USDC}`);
console.log(`Margin Fee: ${config.poolSettings.marginFee}`);
console.log(`Verification: ${config.verification.enabled ? 'Enabled' : 'Disabled'}`);

if (network === 'mainnet' || network === 'base') {
  console.log("\n⚠️  WARNING: This is a mainnet deployment!");
  console.log("Make sure you have:");
  console.log("  ✅ Sufficient ETH for gas");
  console.log("  ✅ Correct private key in .env");
  console.log("  ✅ Verified all contract addresses");
  
  // Ask for confirmation
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  rl.question('\nAre you sure you want to continue? (yes/no): ', (answer: string) => {
    rl.close();
    
    if (answer.toLowerCase() !== 'yes') {
      console.log("❌ Deployment cancelled");
      process.exit(0);
    }
    
    console.log("✅ Proceeding with deployment...\n");
    runDeployment();
  });
} else {
  runDeployment();
}

function runDeployment() {
  // Run the deployment script with network as argument
  const child = spawn('npx', ['hardhat', 'run', 'scripts/deploy.ts', network, '--network', network], {
    stdio: 'inherit',
    shell: true
  });
  
  child.on('close', (code) => {
    if (code === 0) {
      console.log("\n🎉 Deployment completed successfully!");
    } else {
      console.log(`\n❌ Deployment failed with code ${code}`);
    }
    process.exit(code || 0);
  });
  
  child.on('error', (error) => {
    console.error('❌ Failed to start deployment:', error);
    process.exit(1);
  });
} 