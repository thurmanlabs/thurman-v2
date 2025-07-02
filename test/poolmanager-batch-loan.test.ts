import { expect } from "chai";
import { ethers } from "hardhat";
import { setupTestEnv } from "./helpers/setupTests";
import { deposit } from "../helpers/contract-helpers";

describe("PoolManager Batch Loan", () => {
    let testEnv: any;

    beforeEach(async () => {
        testEnv = await setupTestEnv();
    });

    describe("Batch Loan Initialization", () => {
        it("should initialize multiple loans in a single transaction", async () => {
            const { deployer, users, poolManager, vault, usdc } = testEnv;
            const userIndex = 0;
            const borrowerIndex1 = 1;
            const borrowerIndex2 = 2;
            const poolId = 0;
            const amount = ethers.parseUnits("20.0", 6);
            const loanAmount1 = ethers.parseUnits("1.0", 6);
            const loanAmount2 = ethers.parseUnits("1.5", 6);
            const interestRate = ethers.parseEther("0.06"); // 6% interest rate
            const retentionRate = ethers.parseEther("0.1"); // 10% retention rate
            const originator = deployer.address; // Use deployer as originator

            // Enable borrowing for the pool
            await poolManager.connect(deployer).setPoolOperationalSettings(
                poolId,
                true,  // depositsEnabled
                true,  // withdrawalsEnabled
                true,  // borrowingEnabled
                false, // isPaused
                ethers.parseUnits("1000000", 6), // maxDepositAmount
                ethers.parseUnits("1", 6),       // minDepositAmount
                ethers.parseUnits("10000000", 6) // depositCap
            );

            await deposit(testEnv, amount, userIndex);

            // Create batch loan data
            const batchLoanData = [
                {
                    borrower: users[borrowerIndex1].address,
                    retentionRate: retentionRate,
                    principal: loanAmount1,
                    termMonths: 12,
                    interestRate: interestRate
                },
                {
                    borrower: users[borrowerIndex2].address,
                    retentionRate: retentionRate,
                    principal: loanAmount2,
                    termMonths: 18,
                    interestRate: interestRate
                }
            ];

            // Initialize batch loans
            await expect(poolManager.connect(deployer)
                .batchInitLoan(poolId, batchLoanData, originator))
                .to.emit(vault, "BatchLoanInitialized")
                .withArgs(originator, [0, 1], [users[borrowerIndex1].address, users[borrowerIndex2].address], [loanAmount1, loanAmount2]);

            // Verify loans were created
            const loan1 = await vault.getLoan(users[borrowerIndex1].address, 0);
            const loan2 = await vault.getLoan(users[borrowerIndex2].address, 1);

            expect(loan1.principal).to.equal(loanAmount1);
            expect(loan1.termMonths).to.equal(12);
            expect(loan1.interestRate).to.equal(interestRate);
            expect(loan1.originator).to.equal(originator);

            expect(loan2.principal).to.equal(loanAmount2);
            expect(loan2.termMonths).to.equal(18);
            expect(loan2.interestRate).to.equal(interestRate);
            expect(loan2.originator).to.equal(originator);
        });

        it("should revert when batch is empty", async () => {
            const { deployer, poolManager } = testEnv;
            const poolId = 0;
            const originator = deployer.address;

            await expect(poolManager.connect(deployer)
                .batchInitLoan(poolId, [], originator))
                .to.be.revertedWith("Loan/empty-batch");
        });

        it("should revert when batch is too large", async () => {
            const { deployer, users, poolManager } = testEnv;
            const poolId = 0;
            const originator = deployer.address;

            // Create a batch with more than 100 loans
            const batchLoanData = [];
            for (let i = 0; i < 101; i++) {
                batchLoanData.push({
                    borrower: users[0].address,
                    retentionRate: ethers.parseEther("0.1"),
                    principal: ethers.parseUnits("1.0", 6),
                    termMonths: 12,
                    interestRate: ethers.parseEther("0.06")
                });
            }

            await expect(poolManager.connect(deployer)
                .batchInitLoan(poolId, batchLoanData, originator))
                .to.be.revertedWith("Loan/batch-too-large");
        });

        it("should revert when borrowing is disabled", async () => {
            const { deployer, users, poolManager } = testEnv;
            const poolId = 0;
            const originator = deployer.address;

            // Disable borrowing
            await poolManager.connect(deployer).setPoolOperationalSettings(
                poolId,
                true,  // depositsEnabled
                true,  // withdrawalsEnabled
                false, // borrowingEnabled
                false, // isPaused
                ethers.parseUnits("1000000", 6), // maxDepositAmount
                ethers.parseUnits("1", 6),       // minDepositAmount
                ethers.parseUnits("10000000", 6) // depositCap
            );

            const batchLoanData = [
                {
                    borrower: users[0].address,
                    retentionRate: ethers.parseEther("0.1"),
                    principal: ethers.parseUnits("1.0", 6),
                    termMonths: 12,
                    interestRate: ethers.parseEther("0.06")
                }
            ];

            await expect(poolManager.connect(deployer)
                .batchInitLoan(poolId, batchLoanData, originator))
                .to.be.revertedWith("Loan/borrowing-disabled");
        });
    });
}); 