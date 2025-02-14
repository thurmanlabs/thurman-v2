import { TestEnv } from "../test/helpers/setupTests";

export async function requestDeposit(testEnv: TestEnv, amount: bigint, userIndex: number) {
    const { poolManager, users, vault, usdc } = testEnv;
    await usdc.connect(users[userIndex]).approve(String(vault.target), amount);
    await poolManager.connect(users[userIndex]).requestDeposit(0, amount);
}

export async function fulfillDeposit(testEnv: TestEnv, amount: bigint, userIndex: number) {
    const { deployer, poolManager, users } = testEnv;
    const poolId = 0;
    await requestDeposit(testEnv, amount, userIndex);
    await poolManager.connect(deployer).fulfillDeposit(poolId, amount, users[userIndex].address);
}

export async function deposit(testEnv: TestEnv, amount: bigint, userIndex: number) {
    const { users, poolManager } = testEnv;
    const poolId = 0;
    await fulfillDeposit(testEnv, amount, userIndex);
    await poolManager.connect(users[userIndex]).deposit(poolId, amount, users[userIndex].address);
}

export async function requestRedeem(testEnv: TestEnv, amount: bigint, userIndex: number) {
    const { users, poolManager, vault, sUSDC } = testEnv;
    const poolId = 0;
    await deposit(testEnv, amount, userIndex);
    await sUSDC.connect(users[userIndex]).approve(vault.target.toString(), amount);
    await poolManager.connect(users[userIndex]).requestRedeem(poolId, amount, users[userIndex].address, users[userIndex].address);
}

export async function fulfillRedeem(testEnv: TestEnv, amount: bigint, userIndex: number) {
    const { users, deployer, poolManager } = testEnv;
    const poolId = 0;
    await requestRedeem(testEnv, amount, userIndex);
    await poolManager.connect(deployer).fulfillRedeem(poolId, amount, users[userIndex].address);
}
