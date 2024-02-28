import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Networks } from "@crowdswap/constant";
import { ethers, upgrades } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { network, config } = hre;



  console.log("Start [ETFProxy] contract deployment");


  const ETFProxyFactory = await ethers.getContractFactory("ETFProxy");
  const ETFProxyProxy = await upgrades.upgradeProxy(
    "0x7bA4984a4e7Fe5D2eAA1f4ccC1186B3c3Ef3A171",
    ETFProxyFactory
  );
  console.log("Finish [ETFProxy] contract deployment");

  const ETFProxyImpl = await getImplementationAddress(
    ethers.provider,
    ETFProxyProxy.address
  );
  console.log("ETFProxyProxy", ETFProxyProxy.address);
  console.log("ETFProxyImpl", ETFProxyImpl);

};
export default func;
func.tags = ["UpgradeETFProxy"];
