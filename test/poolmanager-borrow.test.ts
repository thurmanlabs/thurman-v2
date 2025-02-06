import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { setupTestEnv, TestEnv } from "./helpers/setupTests";
import { getAddresses } from "../config/addresses";
import {
    requestDeposit,
    fulfillDeposit,
    deposit,
    requestRedeem,
    fulfillRedeem
} from "../helpers/contract-helpers";

describe("PoolManager Borrow", () => {
    let testEnv: TestEnv;
    let whale: string; 
    let whaleSigner: HardhatEthersSigner;
    let snapshotId: string;

    before(async () => {
        testEnv = await setupTestEnv();
        const addresses = getAddresses("polygon");
        whale = addresses.whales.USDC;
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [whale]
        });
        await network.provider.send("hardhat_setBalance", [
            whale,
            "0xD0D4271C559400",
        ]);
        whaleSigner = await ethers.getImpersonatedSigner(whale) as unknown as HardhatEthersSigner;
    });

    beforeEach(async () => {
        // Take a snapshot of the blockchain state
        snapshotId = await network.provider.send("evm_snapshot");

        // Setup initial state for each test
        const { deployer, users, usdc } = testEnv;
        const amount = ethers.parseUnits("100", 6);
        await usdc.connect(whaleSigner).transfer(deployer.address, amount);

        for (let i = 0; i < users.length; i++) {
            await usdc.connect(whaleSigner).transfer(users[i].address, amount);
        }
    });

    afterEach(async () => {
        await network.provider.send("evm_revert", [snapshotId]);
    });

    after(async () => {
        await network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: [whale]
        });
    });

    describe("Borrow Events", () => {
        it("should initialize a loan", async () => {
            const { deployer, users, poolManager, usdc, vault } = testEnv;
            const userIndex = 0;
            const borrowerIndex = 1;
            const poolId = 0;
            const amount = ethers.parseUnits("10", 6);        // 10 USDC
            const loanAmount = ethers.parseUnits("1", 6);     // 1 USDC
            const interestRate = 600;                         // 6% (600 basis points)
            await deposit(testEnv, amount, userIndex);
            expect(await poolManager.connect(deployer)
                .initLoan(poolId, users[borrowerIndex].address, loanAmount, 12, interestRate))
                .to.emit(vault, "LoanInitialized");
        });

        it("should repay a loan", async () => {
            const { deployer, users, poolManager, usdc, vault } = testEnv;
            const userIndex = 0;
            const borrowerIndex = 1;
            const poolId = 0;
            const amount = ethers.parseUnits("10", 6);
            const loanAmount = ethers.parseUnits("1", 6);
            const interestRate = 600;
            
            // Setup initial balances
            await deposit(testEnv, amount, userIndex);
            
            // Give borrower some USDC for repayment
            await usdc.connect(whaleSigner).transfer(
                users[borrowerIndex].address, 
                ethers.parseUnits("1", 6)
            );
            
            // Initialize loan
            await poolManager.connect(deployer)
                .initLoan(poolId, users[borrowerIndex].address, loanAmount, 12, interestRate);
            
            const repayAmount = ethers.parseUnits("0.1", 6);
            
            // Time travel
            const thirtyDaysInSeconds = 30 * 24 * 60 * 60;
            await ethers.provider.send("evm_increaseTime", [thirtyDaysInSeconds]);
            await ethers.provider.send("evm_mine");
            
            // Approve vault to spend borrower's USDC
            await usdc.connect(users[borrowerIndex]).approve(String(vault.target), repayAmount);
            
            expect(await poolManager.connect(users[borrowerIndex])
                .repayLoan(poolId, repayAmount, users[borrowerIndex].address, 0))
                .to.emit(vault, "LoanRepaid");
        });
    });
    
    
});