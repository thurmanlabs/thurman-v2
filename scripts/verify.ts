import { run } from "hardhat";

export const verify = async function(contractAddress: string) {
  console.log("Verifying implementation contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [], // Implementation contracts have no constructor args
    });
    console.log("✅ Implementation contract verified successfully");
  } catch (error: any) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("ℹ️  Implementation contract already verified");
    } else {
      console.log("❌ Implementation verification failed:", error.message);
    }
  }
};

export const verifyProxy = async function(contractAddress: string) {
  console.log("Verifying proxy contract...");
  try {
    // For proxy contracts, we verify the implementation contract
    // The proxy itself doesn't need constructor arguments verification
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [], // Proxy contracts don't use constructor args
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