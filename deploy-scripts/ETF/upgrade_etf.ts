import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Networks } from "@crowdswap/constant";
import { ethers, upgrades } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { network, config } = hre;



  console.log("Start [ETFReceipt] contract deployment");


  const ETFReceiptFactory = await ethers.getContractFactory("ETFReceipt");
  const ETFReceiptProxy = await upgrades.upgradeProxy(
    "0x4c035237eE762fE3258B82Ec509Dc7B9FF9E56c6",
    ETFReceiptFactory
  );
  console.log("Finish [ETFReceipt] contract deployment");

  const ETFReceiptImpl = await getImplementationAddress(
    ethers.provider,
    ETFReceiptProxy.address
  );
  console.log("ETFReceiptProxy", ETFReceiptProxy.address);
  console.log("ETFReceiptImpl", ETFReceiptImpl);

};
export default func;
func.tags = ["UpgradeETFReceipt"];
