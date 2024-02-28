import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Networks } from "@crowdswap/constant";
import { ethers, upgrades } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { network, config } = hre;
  const chainId = network.config.chainId;
  const networkName = network.name;
//   if (![Networks.BSCMAIN].includes(networkName)) {
//     throw Error(
//       `Deploying [CrowdArbStakingLp] contracts on the given network ${networkName} is not supported`
//     );
//   }

  const params = [
    "0x1Ee02f15A0360BDf03a37628D7d2Ea741904e3fF",
    "0xd4560c06db2bAe0b06E9243896aD48e4bD14cdb2",
    {
      feeTo:"0xdF9C09f9332669F6a5B06Df53a342a66D7ce7667",
      investFee:"100000000000000000",
      withdrawFee:"100000000000000000"
    }
  ];

  if (params.includes(null) || params.includes(undefined)) {
    throw Error("Required data is missing.");
  }
  console.log(params);
  console.log("Start [ETFProxy] contract deployment");
  const ETFProxyFactory = await ethers.getContractFactory("ETFProxy");
  const ETFProxyProxy = await upgrades.deployProxy(ETFProxyFactory, params, {
    kind: "uups",
  });
  await ETFProxyProxy.deployed();
  console.log("Finish [ETFProxy] contract deployment");

  const ETFProxyImpl = await getImplementationAddress(
    ethers.provider,
    ETFProxyProxy.address
  );
  console.log("ETFProxyProxy", ETFProxyProxy.address);
  console.log("ETFProxyImpl", ETFProxyImpl);

};
export default func;
func.tags = ["ETFProxy"];
