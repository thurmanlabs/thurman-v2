import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, upgrades } from "hardhat";
import { ContractFactory } from "ethers";
import { IPool } from "../../typechain-types";
import { PoolManager, ERC7540Vault, SToken, DToken } from "../../typechain-types";
import { getAddresses } from "../../config/addresses";
import { IERC20 } from "../../typechain-types";

export interface TestEnv {
    deployer: HardhatEthersSigner;
    users: HardhatEthersSigner[];
    poolManager: PoolManager;
    vault: ERC7540Vault;
    sUSDC: SToken;
    dUSDC: DToken;
    usdc: IERC20;
    aUSDC: IERC20;
    aavePool: IPool;
}

export const testEnv: TestEnv = {
    deployer: {} as HardhatEthersSigner,
    users: [] as HardhatEthersSigner[],
    poolManager: {} as PoolManager,
    vault: {} as ERC7540Vault,
    sUSDC: {} as SToken
} as TestEnv;

export async function setupTestEnv(): Promise<TestEnv> {
    const addresses = getAddresses("polygon");
    const [deployer, ...users] = await ethers.getSigners();
    testEnv.deployer = deployer as unknown as HardhatEthersSigner;
    testEnv.users = users as unknown as HardhatEthersSigner[];

    const PoolManagerFactory = await ethers.getContractFactory("PoolManager");
    const poolManager = await upgrades.deployProxy(PoolManagerFactory as unknown as ContractFactory, []);
    await poolManager.waitForDeployment();
    testEnv.poolManager = poolManager as unknown as PoolManager;

    const STokenFactory = await ethers.getContractFactory("SToken");
    const sUSDC = await upgrades.deployProxy(STokenFactory as unknown as ContractFactory, 
        [
            poolManager.target,
            deployer.address,
            "sUSDC", 
            "sUSDC"
        ],
        {
            initializer: "initialize"
        }
    );
    await sUSDC.waitForDeployment();
    testEnv.sUSDC = sUSDC as unknown as SToken;

    const DTokenFactory = await ethers.getContractFactory("DToken");
    const dUSDC = await upgrades.deployProxy(DTokenFactory as unknown as ContractFactory, 
        [
            poolManager.target,
            "dUSDC",
            "dUSDC"
        ],
        {
            initializer: "initialize"
        }
    );
    await dUSDC.waitForDeployment();
    testEnv.dUSDC = dUSDC as unknown as DToken;

    const VaultFactory = await ethers.getContractFactory("ERC7540Vault");
    const vault = await upgrades.deployProxy(VaultFactory as unknown as ContractFactory, 
        [
            addresses.tokens.USDC,
            sUSDC.target,
            dUSDC.target,
            poolManager.target
        ]
    );
    await vault.waitForDeployment();
    testEnv.vault = vault as unknown as ERC7540Vault;

    testEnv.usdc = await ethers.getContractAt("IERC20", addresses.tokens.USDC, testEnv.deployer);
    testEnv.aUSDC = await ethers.getContractAt("IERC20", addresses.tokens.aUSDC);
    testEnv.aavePool = await ethers.getContractAt("IPool", addresses.aave.pool);
    
    await testEnv.poolManager.addPool(
        vault.getAddress(),
        addresses.aave.pool,
        ethers.parseEther("0.1"),
        ethers.parseEther("0.9"),
        ethers.parseEther("0.1"),
        ethers.parseEther("0.02"),
        ethers.parseEther("0.1"),
    )
    
    return testEnv;
}