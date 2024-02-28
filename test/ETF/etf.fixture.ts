import { Fixture } from "ethereum-waffle";

const { ethers, upgrades } = require("hardhat");
import {
  ETFReceipt,
  ETFReceipt__factory,
  ETFProxy__factory,
  ETFProxy,
  CrowdTokenWrapper,
  CrowdTokenWrapper__factory,
  CrowdswapV1Test__factory,
  CrowdswapV1Test,
} from "../../artifacts/types";

const tokenFixture: Fixture<{
  USDT: CrowdTokenWrapper;
  CROWD: CrowdTokenWrapper;
  UNI: CrowdTokenWrapper;
  WBTC: CrowdTokenWrapper;
  MATIC: CrowdTokenWrapper;
}> = async ([wallet], provider) => {
  const network = await ethers.provider.getNetwork();
  const signer = provider.getSigner(wallet.address);
  const chainId = network.chainId;
  switch (chainId) {
    case 31337:
      return {
        USDT: await new CrowdTokenWrapper__factory(signer).deploy(
          "USDT minter",
          "USDT"
        ),
        CROWD: await new CrowdTokenWrapper__factory(signer).deploy(
          "CROWD minter",
          "CROWD"
        ),
        UNI: await new CrowdTokenWrapper__factory(signer).deploy(
          "UNI minter",
          "UNI"
        ),
        WBTC: await new CrowdTokenWrapper__factory(signer).deploy(
          "WBTC minter",
          "WBTC"
        ),
        MATIC: await new CrowdTokenWrapper__factory(signer).deploy(
          "MATIC minter",
          "MATIC"
        ),
      };
  }
};

export const ETFFixture: Fixture<{
  etfReceipt: ETFReceipt;
  etfProxy: ETFProxy;
  swapContract: CrowdswapV1Test;
  USDT: CrowdTokenWrapper;
  CROWD: CrowdTokenWrapper;
  UNI: CrowdTokenWrapper;
  WBTC: CrowdTokenWrapper;
  MATIC: CrowdTokenWrapper;
}> = async ([wallet, account1, account2], provider) => {
  const signer = provider.getSigner(wallet.address);
  const { USDT, CROWD, UNI, WBTC, MATIC } = await tokenFixture(
    [wallet],
    provider
  );

  const swapContractFactory = new CrowdswapV1Test__factory(signer);

  const swapContract = await swapContractFactory.deploy();
  await swapContract.deployed();

  await USDT.connect(wallet).setMinter(wallet.address);
  await CROWD.connect(wallet).setMinter(wallet.address);
  await UNI.connect(wallet).setMinter(wallet.address);
  await WBTC.connect(wallet).setMinter(wallet.address);
  await MATIC.connect(wallet).setMinter(wallet.address);
  
  await USDT.connect(wallet).setMinter(swapContract.address);
  await CROWD.connect(wallet).setMinter(swapContract.address);
  await UNI.connect(wallet).setMinter(swapContract.address);
  await WBTC.connect(wallet).setMinter(swapContract.address);
  await MATIC.connect(wallet).setMinter(swapContract.address);


  const ETFReceiptFactory = new ETFReceipt__factory(signer);

  const receiptParams = ["crowdETF", "crowdETF"];

  const etfReceipt = (await upgrades.deployProxy(
    ETFReceiptFactory,
    receiptParams,
    {
      kind: "uups",
    }
  )) as ETFReceipt;

  const ETFProxyFactory = new ETFProxy__factory(signer);

  const proxyParams = [
    etfReceipt.address,
    swapContract.address,
    {
      feeTo: wallet.address,
      investFee: ethers.utils.parseUnits("1", 17),
      withdrawFee: ethers.utils.parseUnits("1", 17),
    },
  ];

  const etfProxy = (await upgrades.deployProxy(ETFProxyFactory, proxyParams, {
    kind: "uups",
  })) as ETFProxy;

  return {
    etfReceipt,
    etfProxy,
    swapContract,
    USDT,
    CROWD,
    UNI,
    WBTC,
    MATIC,
  };
};
