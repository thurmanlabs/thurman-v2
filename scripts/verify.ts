import { run } from "hardhat";

export const verify = async function(contractAddress: string, args: any[]) {
  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    console.log("✅ Contract verified successfully");
  } catch (error: any) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("ℹ️  Contract already verified");
    } else {
      console.log("❌ Verification failed:", error.message);
    }
  }
};

export const verifyProxy = async function(contractAddress: string, args: any[]) {
  console.log("Verifying proxy contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    console.log("✅ Proxy contract verified successfully");
  } catch (error: any) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("ℹ️  Proxy contract already verified");
    } else {
      console.log("❌ Proxy verification failed:", error.message);
    }
  }
}; 