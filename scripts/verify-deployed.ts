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



  console.log("=== Verifying Deployed Contracts ===");
  console.log("Network:", network);

  for (const [contractName, address] of Object.entries(deployedContracts)) {
    if (address) {
      console.log(`\nVerifying ${contractName}...`);
      await verifyProxy(address);
    } else {
      console.log(`\n⚠️  Skipping ${contractName} - missing address`);
    }
  }

  console.log("\n✅ Verification process completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 