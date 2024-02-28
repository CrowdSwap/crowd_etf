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
    "Crowd ETF",
    "CrowdETF"
  ];

  if (params.includes(null) || params.includes(undefined)) {
    throw Error("Required data is missing.");
  }
  console.log(params);
  console.log("Start [ETFReceipt] contract deployment");
  const ETFReceiptFactory = await ethers.getContractFactory("ETFReceipt");
  const ETFReceiptProxy = await upgrades.deployProxy(ETFReceiptFactory, params, {
    kind: "uups",
  });
  await ETFReceiptProxy.deployed();
  console.log("Finish [ETFReceipt] contract deployment");

  const ETFReceiptImpl = await getImplementationAddress(
    ethers.provider,
    ETFReceiptProxy.address
  );
  console.log("ETFReceiptProxy", ETFReceiptProxy.address);
  console.log("ETFReceiptImpl", ETFReceiptImpl);

};
export default func;
func.tags = ["ETFReceipt"];
