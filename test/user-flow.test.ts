import { expect } from "chai";
import { setupTestEnv, TestEnv } from "./helpers/setupTests";
import { ethers, network } from "hardhat";
import { getAddresses } from "../config/addresses";

describe("Complete User Flow", () => {
  let testEnv: TestEnv;
  let whaleSigner: any;
  let snapshotId: string;
  const poolId = 0;
  
  before(async () => {
    testEnv = await setupTestEnv();
    
    // Setup whale for USDC transfers (using mainnet network which has a real whale)
    const addresses = getAddresses("base") as any;
    const whale = addresses.whales.USDC;
    
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whale]
    });
    await network.provider.send("hardhat_setBalance", [
      whale,
      "0xD0D4271C559400",
    ]);
    whaleSigner = await ethers.getImpersonatedSigner(whale);
  });
  
  beforeEach(async () => {
    // Take a snapshot of the blockchain state
    snapshotId = await network.provider.send("evm_snapshot");
    
    // Provide USDC to deployer and users for testing
    // const addresses = getAddresses("base") as any;
    // const whale = addresses.whales.USDC;
    const amount = ethers.parseUnits("100000", 6); // 100k USDC
    
    // Check whale balance and address
    const whaleBalance = await testEnv.usdc.balanceOf(whaleSigner.address);
    
    await testEnv.usdc.connect(whaleSigner).transfer(testEnv.deployer.address, amount);
    
    for (let i = 0; i < testEnv.users.length; i++) {
      await testEnv.usdc.connect(whaleSigner).transfer(testEnv.users[i].address, amount);
    }
  });

  afterEach(async () => {
    // Revert to the snapshot after each test
    await network.provider.send("evm_revert", [snapshotId]);
  });

  it("should add batch loans from CSV data", async () => {
    // Step 1: Enable borrowing
    await testEnv.poolManager.setPoolOperationalSettings(
      poolId,
      false, // depositsEnabled - not yet
      false, // withdrawalsEnabled - not yet  
      true,  // borrowingEnabled - enable for loan addition
      false, // isPaused
      ethers.parseUnits("1000000", 6), // maxDepositAmount
      ethers.parseUnits("1", 6),       // minDepositAmount
      ethers.parseUnits("10000000", 6) // depositCap
    );

    // Register deployer as originator
    await testEnv.originatorRegistry.connect(testEnv.deployer).registerOriginator(testEnv.deployer.address);

    // Step 2: Create batch loan data
    const batchLoans = [
      {
        borrower: testEnv.users[1].address,
        retentionRate: ethers.parseEther("0.1"), // 10%
        principal: ethers.parseUnits("5000", 6), // $5,000
        termMonths: 12,
        interestRate: ethers.parseEther("0.08") // 8%
      },
      {
        borrower: testEnv.users[2].address, 
        retentionRate: ethers.parseEther("0.15"), // 15%
        principal: ethers.parseUnits("7500", 6), // $7,500
        termMonths: 24,
        interestRate: ethers.parseEther("0.075") // 7.5%
      }
    ];

    // Step 3: Add batch loans (this simulates CSV upload processing)
    await testEnv.poolManager.batchInitLoan(poolId, batchLoans, testEnv.deployer.address);
    
    // Verify loans were added
    const pool = await testEnv.poolManager.getPool(poolId);
    expect(pool.totalPrincipal).to.equal(ethers.parseUnits("12500", 6));
  });

  it("should enable deposits and handle investor funding", async () => {
    // First add loans (prerequisite)
    await testEnv.poolManager.setPoolOperationalSettings(poolId, false, false, true, false,
      ethers.parseUnits("1000000", 6), ethers.parseUnits("1", 6), ethers.parseUnits("10000000", 6));
    
    // Register deployer as originator
    await testEnv.originatorRegistry.connect(testEnv.deployer).registerOriginator(testEnv.deployer.address);
    
    const batchLoans = [{
      borrower: testEnv.users[1].address,
      retentionRate: ethers.parseEther("0.1"),
      principal: ethers.parseUnits("10000", 6),
      termMonths: 12,
      interestRate: ethers.parseEther("0.08")
    }];
    await testEnv.poolManager.batchInitLoan(poolId, batchLoans, testEnv.deployer.address);

    // Step 4: Enable deposits with cap matching loan principal
    await testEnv.poolManager.setPoolOperationalSettings(
      poolId,
      true,  // depositsEnabled - now enable
      false, // withdrawalsEnabled - not yet
      true,  // borrowingEnabled
      false, // isPaused
      ethers.parseUnits("15000", 6), // maxDepositAmount
      ethers.parseUnits("1000", 6),  // minDepositAmount  
      ethers.parseUnits("10000", 6)  // depositCap - match loan needs
    );

    // Step 5: Investor deposits funds
    const investor = testEnv.users[3];
    const depositAmount = ethers.parseUnits("10000", 6);
    
    // Approve vault to spend investor's USDC (assuming investor has USDC)
    await testEnv.usdc.connect(investor).approve(testEnv.vault.target, depositAmount);
    
    // Request deposit
    await testEnv.poolManager.connect(investor).requestDeposit(poolId, depositAmount, investor.address);
    
    // Fulfill deposit (pool manager action)
    await testEnv.poolManager.connect(testEnv.deployer).fulfillDeposit(poolId, depositAmount, investor.address);
    
    // Verify deposit was processed
    const pool = await testEnv.poolManager.getPool(poolId);
    expect(pool.totalDeposits).to.equal(depositAmount);
  });

  it("should transfer sale proceeds to originator", async () => {
    // Setup: Add loans and get deposits (prerequisites)
    await testEnv.poolManager.setPoolOperationalSettings(poolId, false, false, true, false,
      ethers.parseUnits("1000000", 6), ethers.parseUnits("1", 6), ethers.parseUnits("10000000", 6));
    
    const originator = testEnv.users[0]; // Use user[0] as originator
    
    // Register originator first
    await testEnv.originatorRegistry.connect(testEnv.deployer).registerOriginator(originator.address);
    
    const batchLoans = [{
      borrower: testEnv.users[1].address,
      retentionRate: ethers.parseEther("0.1"),
      principal: ethers.parseUnits("8000", 6),
      termMonths: 12,
      interestRate: ethers.parseEther("0.08")
    }];
    await testEnv.poolManager.batchInitLoan(poolId, batchLoans, originator.address);

    // Enable deposits and process investor funding
    await testEnv.poolManager.setPoolOperationalSettings(poolId, true, false, true, false,
      ethers.parseUnits("15000", 6), ethers.parseUnits("1000", 6), ethers.parseUnits("8000", 6));
    
    const investor = testEnv.users[3];
    const depositAmount = ethers.parseUnits("8000", 6);
    await testEnv.usdc.connect(investor).approve(testEnv.vault.target, depositAmount);
    await testEnv.poolManager.connect(investor).requestDeposit(poolId, depositAmount, investor.address);
    await testEnv.poolManager.connect(testEnv.deployer).fulfillDeposit(poolId, depositAmount, investor.address);

    // Step 6: Transfer sale proceeds to originator
    const originatorBalanceBefore = await testEnv.usdc.balanceOf(originator.address);
    
    await testEnv.poolManager.transferSaleProceeds(poolId, originator.address, depositAmount);
    
    const originatorBalanceAfter = await testEnv.usdc.balanceOf(originator.address);
    expect(originatorBalanceAfter - originatorBalanceBefore).to.equal(depositAmount);
  });

  it("should handle batch loan repayments", async () => {
    // Setup: Complete flow through sale proceeds transfer
    await testEnv.poolManager.setPoolOperationalSettings(poolId, false, false, true, false,
      ethers.parseUnits("1000000", 6), ethers.parseUnits("1", 6), ethers.parseUnits("1000000000", 6));
    
    const originator = testEnv.users[0];
    const borrower1 = testEnv.users[1];
    const borrower2 = testEnv.users[2];
    
    // Register originator first
    await testEnv.originatorRegistry.connect(testEnv.deployer).registerOriginator(originator.address);
    
    const batchLoans = [
      {
        borrower: borrower1.address,
        retentionRate: ethers.parseEther("0.1"),
        principal: ethers.parseUnits("4000", 6),
        termMonths: 12,
        interestRate: ethers.parseEther("0.08")
      },
      {
        borrower: borrower2.address,
        retentionRate: ethers.parseEther("0.1"), 
        principal: ethers.parseUnits("4000", 6),
        termMonths: 12,
        interestRate: ethers.parseEther("0.08")
      }
    ];
    await testEnv.poolManager.batchInitLoan(poolId, batchLoans, originator.address);

    // Process deposits and sale proceeds
    await testEnv.poolManager.setPoolOperationalSettings(poolId, true, false, true, false,
      ethers.parseUnits("15000", 6), ethers.parseUnits("1000", 6), ethers.parseUnits("8000", 6));
    
    const investor = testEnv.users[3];
    const depositAmount = ethers.parseUnits("8000", 6);
    await testEnv.usdc.connect(investor).approve(testEnv.vault.target, depositAmount);
    await testEnv.poolManager.connect(investor).requestDeposit(poolId, depositAmount, investor.address);
    await testEnv.poolManager.connect(testEnv.deployer).fulfillDeposit(poolId, depositAmount, investor.address);
    await testEnv.poolManager.transferSaleProceeds(poolId, originator.address, depositAmount);

    // Step 7: Originator makes batch repayments
    const repaymentAmount = ethers.parseUnits("4400", 6); // Principal + interest for one loan
    
    // Check originator USDC balance
    const originatorBalance = await testEnv.usdc.balanceOf(originator.address);
    
    // Originator approves vault to spend USDC
    await testEnv.usdc.connect(originator).approve(testEnv.vault.target, repaymentAmount);
    
    const batchRepayments = [{
      borrower: borrower1.address,
      loanId: 0,
      paymentAmount: repaymentAmount
    }];

    await testEnv.poolManager.connect(originator).batchRepayLoans(poolId, batchRepayments, originator.address);
    
    // Verify repayment was processed
    const pool = await testEnv.poolManager.getPool(poolId);
    expect(pool.cumulativeDistributionsPerShare).to.be.gt(0);
  });

  it("should allow investor withdrawals after repayments", async () => {
    // Setup: Complete flow through repayments
    await testEnv.poolManager.setPoolOperationalSettings(poolId, false, false, true, false,
      ethers.parseUnits("1000000", 6), ethers.parseUnits("1", 6), ethers.parseUnits("10000000", 6));
    
    const originator = testEnv.users[0];
    const borrower = testEnv.users[1];
    const investor = testEnv.users[3];
    
    // Register originator first
    await testEnv.originatorRegistry.connect(testEnv.deployer).registerOriginator(originator.address);
    
    // Add loan
    const batchLoans = [{
      borrower: borrower.address,
      retentionRate: ethers.parseEther("0.1"),
      principal: ethers.parseUnits("5000", 6),
      termMonths: 12,
      interestRate: ethers.parseEther("0.08")
    }];
    await testEnv.poolManager.batchInitLoan(poolId, batchLoans, originator.address);

    // Process deposits and sale proceeds
    await testEnv.poolManager.setPoolOperationalSettings(poolId, true, false, true, false,
      ethers.parseUnits("15000", 6), ethers.parseUnits("1000", 6), ethers.parseUnits("1000000000", 6));
    
    const depositAmount = ethers.parseUnits("5000", 6);
    await testEnv.usdc.connect(investor).approve(testEnv.vault.target, depositAmount);
    await testEnv.poolManager.connect(investor).requestDeposit(poolId, depositAmount, investor.address);
    await testEnv.poolManager.connect(testEnv.deployer).fulfillDeposit(poolId, depositAmount, investor.address);
    
    await testEnv.poolManager.connect(investor).deposit(poolId, depositAmount, investor.address);
    await testEnv.poolManager.transferSaleProceeds(poolId, originator.address, depositAmount);

    // Process repayment
    const repaymentAmount = ethers.parseUnits("5400", 6); // Principal + interest
    
    await testEnv.usdc.connect(originator).approve(testEnv.vault.target, repaymentAmount);
    
    const batchRepayments = [{
      borrower: borrower.address,
      loanId: 0,
      paymentAmount: repaymentAmount
    }];
    await testEnv.poolManager.connect(originator).batchRepayLoans(poolId, batchRepayments, originator.address);

    // Step 8: Enable withdrawals and investor claims returns
    await testEnv.poolManager.setPoolOperationalSettings(poolId, true, true, true, false,
      ethers.parseUnits("15000", 6), ethers.parseUnits("1000", 6), ethers.parseUnits("5000", 6));

    const investorBalanceBefore = await testEnv.usdc.balanceOf(investor.address);
    const shares = await testEnv.sUSDC.balanceOf(investor.address);
    
    // Approve vault to spend shares
    await testEnv.sUSDC.connect(investor).approve(testEnv.vault.target, shares);
    
    // Request redemption
    await testEnv.vault.connect(investor).requestRedeem(shares, investor.address, investor.address);
    
    // Fulfill redemption (use same amount since convertToShares is 1:1)
    await testEnv.poolManager.fulfillRedeem(poolId, shares, investor.address);
    
    // Claim withdrawal (convert shares to assets since redeem expects assets)
    const assets = await testEnv.vault.convertToAssets(shares);
    
    await testEnv.vault.connect(investor).redeem(assets, investor.address, investor.address);
    
    const investorBalanceAfter = await testEnv.usdc.balanceOf(investor.address);
    
    // Investor should receive more than original deposit due to interest
    expect(investorBalanceAfter).to.be.gt(investorBalanceBefore + depositAmount);
  });
  
  after(async () => {
    if (whaleSigner) {
      await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [whaleSigner.address]
      });
    }
  });
}); 