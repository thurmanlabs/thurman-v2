import { ethers } from "hardhat";
import { verify, verifyProxy } from "./verify";

async function main() {
  const network = process.env.HARDHAT_NETWORK || "hardhat";
  
  if (network === "hardhat") {
    console.log("❌ Cannot verify on hardhat network");
    return;
  }

  // Add your deployed contract addresses here
  const deployedContracts: Record<string, string> = {
    // Example - replace with your actual deployed addresses
    // originatorRegistry: "0x...",
    // loanManager: "0x...",
    // poolManager: "0x...",
    // sToken: "0x...",
    // dToken: "0x...",
    // vault: "0x...",
  };

  // Add your constructor arguments here
  const constructorArgs: Record<string, any[]> = {
    // Example - replace with your actual constructor arguments
    // originatorRegistry: ["0x...", "0x..."], // [deployer, USDC]
    // loanManager: [],
    // poolManager: [],
    // sToken: ["0x...", "0x...", "Thurman USDC Shares", "sUSDC"], // [poolManager, treasury, name, symbol]
    // dToken: ["0x...", "Thurman USDC Debt", "dUSDC"], // [poolManager, name, symbol]
    // vault: ["0x...", "0x...", "0x...", "0x...", "0x..."], // [USDC, sToken, dToken, poolManager, loanManager]
  };

  console.log("=== Verifying Deployed Contracts ===");
  console.log("Network:", network);

  for (const [contractName, address] of Object.entries(deployedContracts)) {
    const args = constructorArgs[contractName as keyof typeof constructorArgs];
    if (address && args) {
      console.log(`\nVerifying ${contractName}...`);
      await verifyProxy(address, args as any[]);
    } else {
      console.log(`\n⚠️  Skipping ${contractName} - missing address or constructor args`);
    }
  }

  console.log("\n✅ Verification process completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 