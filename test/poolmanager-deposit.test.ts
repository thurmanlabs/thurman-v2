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

describe("PoolManager Deposit", () => {
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
        const { deployer, users, usdc, poolManager } = testEnv;
        const amount = ethers.parseUnits("100", 6);
        await usdc.connect(whaleSigner).transfer(deployer.address, amount);

        for (let i = 0; i < users.length; i++) {
            await usdc.connect(whaleSigner).transfer(users[i].address, amount);
        }

        // Enable pool operations for testing
        await poolManager.connect(deployer).setPoolOperationalSettings(
            0, // poolId
            true,  // depositsEnabled
            true,  // withdrawalsEnabled
            false, // borrowingEnabled
            false, // isPaused
            ethers.parseUnits("1000000", 6), // maxDepositAmount
            ethers.parseUnits("1", 6),       // minDepositAmount
            ethers.parseUnits("10000000", 6) // depositCap
        );
    });

    afterEach(async () => {
        // Revert to the snapshot after each test
        await network.provider.send("evm_revert", [snapshotId]);
    });

    after(async () => {
        if (whale) {
            await network.provider.request({
                method: "hardhat_stopImpersonatingAccount",
                params: [whale]
            });
        }
    });

    describe("Deposit Events", () => {

        it("should set operator", async () => {
            const { deployer, users, poolManager, usdc, vault } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            expect(await poolManager.connect(users[userIndex]).setOperator(poolId, deployer.address, true))
                .to.emit(vault, "OperatorSet");
        });

        it("should request deposit", async () => {
            const { deployer, poolManager, usdc, vault } = testEnv;
            const amount = ethers.parseUnits("1", 6);
            await usdc.approve(vault.target.toString(), amount);
            expect(await poolManager.requestDeposit(0, amount, deployer.address))
                .to.emit(vault, "DepositRequest");           
        });

        it("should allow an authorized user to fulfill a deposit request", async () => {
            const { users, deployer, poolManager, vault, usdc } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            const amount = ethers.parseUnits("1", 6);
            await requestDeposit(testEnv, amount, userIndex);
            expect(await poolManager.connect(deployer).fulfillDeposit(poolId, amount, users[userIndex].address))
                .to.emit(vault, "DepositClaimable");
        });

        it("should allow a user to deposit", async () => {
            const { users, poolManager, vault } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            const amount = ethers.parseUnits("1", 6);
            await fulfillDeposit(testEnv, amount, userIndex);
            expect(await poolManager.connect(users[userIndex])
                .deposit(poolId, amount, users[userIndex].address))
                .to.emit(vault, "Deposit");
        });

        it("should allow a user to request redeem", async () => {
            const { users, poolManager, vault, sUSDC } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            const amount = ethers.parseUnits("1", 6);
            await deposit(testEnv, amount, userIndex);
            const shares = await vault.convertToShares(amount);
            await sUSDC.connect(users[userIndex]).approve(vault.target.toString(), shares);
            expect(await poolManager.connect(users[userIndex])
                .requestRedeem(poolId, amount, users[userIndex].address, users[userIndex].address))
                .to.emit(vault, "RedeemRequest");
        });

        it("should allow an authorized user to fulfill a redeem request", async () => {
            const { deployer, users, poolManager, vault, aUSDC } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            const amount = ethers.parseUnits("1", 6);
            await requestRedeem(testEnv, amount, userIndex);
            expect(await poolManager.connect(deployer)
                .fulfillRedeem(poolId, amount, users[userIndex].address))
                .to.emit(vault, "RedeemClaimable");
        });

        it("should allow a user to redeem", async () => {
            const { users, poolManager, vault } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            const amount = ethers.parseUnits("1", 6);
            await fulfillRedeem(testEnv, amount, userIndex);
            expect(await poolManager.connect(users[userIndex])
                .redeem(poolId, amount, users[userIndex].address))
                .to.emit(vault, "Withdraw");
        });
    });

    describe("Deposit Request Validation", () => {
        it("should not allow a user to request a deposit if they are not the owner", async () => {
            const { users, poolManager, vault, usdc, deployer } = testEnv;
            const poolId = 0;
            const userIndex = 0;
            const amount = ethers.parseUnits("1", 6);
            await usdc.connect(users[userIndex]).approve(vault.target.toString(), amount);
            await expect(poolManager.connect(users[userIndex])
                .requestDeposit(poolId, amount, deployer.address))
                .to.be.revertedWith("ERC7540Vault/invalid-controller");

        });
    });
});
