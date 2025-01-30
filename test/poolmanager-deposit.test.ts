import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { setupTestEnv, TestEnv } from "./helpers/setupTests";
import { getAddresses } from "../config/addresses";
import { IERC20 } from "../typechain-types";

describe("PoolManager Deposit", () => {
    let testEnv: TestEnv;
    let usdc: IERC20;
    let whale: string;
    let whaleSigner: HardhatEthersSigner;

    before(async () => {
        testEnv = await setupTestEnv();
        const addresses = getAddresses("polygon");
        whale = addresses.whales.USDC;
        usdc = await ethers.getContractAt("IERC20", addresses.tokens.USDC);
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
        const { deployer } = testEnv;
        const amount = ethers.parseUnits("100", 6);
        await usdc.connect(whaleSigner).transfer(deployer.address, amount);
    });

    after(async () => {
        await network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: [whale]
        });
    });

    describe("Deposit", () => {
        it("should request deposit", async () => {
            const { deployer, poolManager, vault } = testEnv;
            await poolManager.addPool(String(vault.target));
            const amount = ethers.parseUnits("1", 6);
            await usdc.approve(String(vault.target), amount);
            expect(await poolManager.requestDeposit(0, ethers.parseUnits("0.1", 6)))
                .to.emit(vault, "DepositRequest")
                .withArgs(deployer.address, deployer.address, 0, deployer.address, amount)           
        });
    });
});
