import { expect } from "chai";
import { setupTestEnv, TestEnv } from "./helpers/setupTests";

describe("Basic Protocol Setup", () => {
  let testEnv: TestEnv;

  before(async () => {
    testEnv = await setupTestEnv();
  });

  it("should deploy all contracts successfully", async () => {
    expect(testEnv.poolManager.target).to.not.equal("0x0000000000000000000000000000000000000000");
    expect(testEnv.vault.target).to.not.equal("0x0000000000000000000000000000000000000000");  
    expect(testEnv.sUSDC.target).to.not.equal("0x0000000000000000000000000000000000000000");
    expect(testEnv.loanManager.target).to.not.equal("0x0000000000000000000000000000000000000000");
    expect(testEnv.originatorRegistry.target).to.not.equal("0x0000000000000000000000000000000000000000");
  });

  it("should have created initial pool", async () => {
    const poolCount = await testEnv.poolManager.getPoolCount();
    expect(poolCount).to.equal(1);
  });
}); 