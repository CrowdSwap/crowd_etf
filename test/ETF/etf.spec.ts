const { ethers } = require("hardhat");
import { expect } from "chai";

import { ETFFixture } from "./etf.fixture";
import { waffle } from "hardhat";

describe("ETFProxy Contract", function () {
  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;
  let owner, account1, account2;
  let network;
  let zeroAddress = "0x0000000000000000000000000000000000000000";

  beforeEach(async function () {
    [owner, account1, account2] = await ethers.getSigners();
    loadFixture = waffle.createFixtureLoader(
      [owner, account1, account2],
      <any>ethers.provider
    );
    network = await ethers.provider.getNetwork();
  });

  it("Should deploy the contracts", async function () {
    const { etfReceipt: hardhatETFReceipt, etfProxy: hardhatETFProxy } =
      await loadFixture(ETFFixture);
    expect(hardhatETFReceipt.address).to.not.equal(0);
    expect(hardhatETFProxy.address).to.not.equal(0);
  });

  // Write your test cases here
  it("Should create a new plan", async function () {
    const {
      etfReceipt: hardhatETFReceipt,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await loadFixture(ETFFixture);

    const tokens = [CROWD.address, MATIC.address, UNI.address, WBTC.address];

    const percentages = [2000, 3000, 4000, 1000];

    const tokenPercentages = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenPercentages.push({ token: tokens[i], percentage: percentages[i] });
    }

    await expect(
      hardhatETFReceipt.connect(owner).createPlan("first_etf", tokenPercentages)
    ).to.emit(hardhatETFReceipt, "PlanCreated");
  });

  it("Should revert because of miscalculation in percentages when creating a new plan", async function () {
    const {
      etfReceipt: hardhatETFReceipt,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await loadFixture(ETFFixture);

    const tokens = [CROWD.address, MATIC.address, UNI.address, WBTC.address];

    const percentages = [2000, 3000, 4000, 2000];

    const tokenPercentages = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenPercentages.push({ token: tokens[i], percentage: percentages[i] });
    }

    await expect(
      hardhatETFReceipt.connect(owner).createPlan("first_etf", tokenPercentages)
    ).to.be.revertedWith(
      "ETFReceipt: There is a miscalculation in plan percentages"
    );
  });

  it("Should revert because of wrong address when creating a new plan", async function () {
    const {
      etfReceipt: hardhatETFReceipt,
      MATIC,
      UNI,
      WBTC,
    } = await loadFixture(ETFFixture);

    const tokens = [zeroAddress, MATIC.address, UNI.address, WBTC.address];

    const percentages = [2000, 3000, 4000, 1000];

    const tokenPercentages = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenPercentages.push({ token: tokens[i], percentage: percentages[i] });
    }

    await expect(
      hardhatETFReceipt.connect(owner).createPlan("first_etf", tokenPercentages)
    ).to.be.revertedWith("ETFReceipt: one of the addresses is invalid");
  });

  it("Should revert because of calling by no owner when creating a new plan", async function () {
    const {
      etfReceipt: hardhatETFReceipt,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await loadFixture(ETFFixture);

    const tokens = [CROWD.address, MATIC.address, UNI.address, WBTC.address];

    const percentages = [2000, 3000, 4000, 1000];

    const tokenPercentages = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenPercentages.push({ token: tokens[i], percentage: percentages[i] });
    }

    await expect(
      hardhatETFReceipt
        .connect(account1)
        .createPlan("first_etf", tokenPercentages)
    ).to.be.revertedWith("ce30");
  });

  it("Should changePlanActiveStatus", async function () {
    const { hardhatETFReceipt } = await createPlan();

    await expect(
      hardhatETFReceipt
        .connect(owner)
        .changePlanActiveStatus(0, "first_etf", false)
    ).to.emit(hardhatETFReceipt, "PlanUpdated");
  });

  it("Should revert because of calling by no owner when changePlanActiveStatus", async function () {
    const { hardhatETFReceipt } = await createPlan();

    await expect(
      hardhatETFReceipt
        .connect(account1)
        .changePlanActiveStatus(0, "first_etf", false)
    ).to.be.revertedWith("ce30");
  });

  it("Should revert because of invalid plan ID when changePlanActiveStatus", async function () {
    const { tokens, hardhatETFReceipt } = await createPlan();

    await expect(
      hardhatETFReceipt
        .connect(owner)
        .changePlanActiveStatus(1, "first_etf", false)
    ).to.be.revertedWith("ETFReceipt: Invalid plan ID");
  });

  it("Should mint a new NFT receipt", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    expect(await hardhatETFReceipt.totalSupply()).to.be.eq(1);
  });

  it("Should burn a NFT receipt", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    expect(await hardhatETFReceipt.totalSupply()).to.be.eq(1);

    await hardhatETFReceipt.connect(account2).approve(owner.address, 0);

    await expect(hardhatETFReceipt.connect(owner).burn(0)).to.emit(
      hardhatETFReceipt,
      "Burned"
    );

    expect(await hardhatETFReceipt.totalSupply()).to.be.eq(0);
  });

  it("Should revert if burning a NFT for the second time", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    expect(await hardhatETFReceipt.totalSupply()).to.be.eq(1);

    await hardhatETFReceipt.connect(account2).approve(owner.address, 0);

    await expect(hardhatETFReceipt.connect(owner).burn(0)).to.emit(
      hardhatETFReceipt,
      "Burned"
    );

    expect(await hardhatETFReceipt.totalSupply()).to.be.eq(0);

    await expect(hardhatETFReceipt.connect(owner).burn(0)).to.be.revertedWith(
      "ERC721: invalid token ID"
    );
  });

  it("Should revert because of approve with wrong owner", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt.connect(account1).approve(owner.address, 0)
    ).to.be.revertedWith(
      "ERC721: approve caller is not token owner or approved for all"
    );
  });

  it("Should transfer NFT", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt
        .connect(account2)
        .transferFrom(account2.address, account1.address, 0)
    ).to.emit(hardhatETFReceipt, "Transfer");
  });

  it("Should safeTransfer NFT", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt
        .connect(account2)
        ["safeTransferFrom(address,address,uint256)"].apply(this, [
          account2.address,
          account1.address,
          0,
        ])
    ).to.emit(hardhatETFReceipt, "Transfer");
  });

  it("Should revert transfer because wrong owner NFT", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt
        .connect(account1)
        .transferFrom(account2.address, account1.address, 0)
    ).to.be.revertedWith("RC721: caller is not token owner or approved");
  });

  it("Should transfer account2 to account1 with approved token NFT", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await hardhatETFReceipt.connect(account2).approve(owner.address, 0);

    await expect(
      hardhatETFReceipt
        .connect(owner)
        .transferFrom(account2.address, account1.address, 0)
    ).to.emit(hardhatETFReceipt, "Transfer");
  });

  it("Get all plans", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    const plans = await hardhatETFReceipt.getAllPlans();

    expect(plans.length).to.be.eq(1);
    expect(plans[0].name).to.be.eq("first_etf");
  });

  it("Get a user tokens", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );
    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    const tokenList = await hardhatETFReceipt.getTokensByOwner(
      account2.address
    );

    expect(tokenList.length).to.be.eq(2);
    expect(tokenList[0].id.toString()).to.be.eq("0");
    expect(tokenList[1].id.toString()).to.be.eq("1");
  });

  it("Should revert if a user wants to burn his NFT", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );
    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt.connect(account2.address).burn(0)
    ).to.be.revertedWith("ETFReceipt: Invalid caller");
  });

  it("Get user tokens after transfer", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );
    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt
        .connect(account2)
        .transferFrom(account2.address, account1.address, 0)
    ).to.emit(hardhatETFReceipt, "Transfer");

    const tokenListAccount2 = await hardhatETFReceipt.getTokensByOwner(
      account2.address
    );
    const tokenListAccount1 = await hardhatETFReceipt.getTokensByOwner(
      account1.address
    );

    expect(tokenListAccount2.length).to.be.eq(1);
    expect(tokenListAccount1.length).to.be.eq(1);
    expect(tokenListAccount2[0].id.toString()).to.be.eq("1");
    expect(tokenListAccount1[0].id.toString()).to.be.eq("0");
  });

  it("Should revert transfer a token to two users", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await expect(
      hardhatETFReceipt
        .connect(account2)
        .transferFrom(account2.address, account1.address, 0)
    ).to.emit(hardhatETFReceipt, "Transfer");
    await expect(
      hardhatETFReceipt
        .connect(account2)
        .transferFrom(account2.address, owner.address, 0)
    ).to.be.revertedWith("ERC721: caller is not token owner or approved");
  });

  it("Should revert transfer a token after burn", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await hardhatETFReceipt.connect(account2).approve(owner.address, 0);

    await expect(hardhatETFReceipt.connect(owner).burn(0)).to.emit(
      hardhatETFReceipt,
      "Burned"
    );
    await expect(
      hardhatETFReceipt
        .connect(account2)
        .transferFrom(account2.address, owner.address, 0)
    ).to.be.revertedWith("ERC721: invalid token ID");
  });

  it("Get an invest with a tokenId", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );
    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    const token = await hardhatETFReceipt.tokenByTokenId(account2.address, 0);

    expect(token.id.toString()).to.be.eq("0");
    expect(token.tokenDetails.length).to.be.eq(4);
    expect(token.tokenDetails[0].amount.toString()).to.be.eq(
      ethers.utils.parseUnits("1000", 18).toString()
    );
  });

  it("New tokenId must increment after burning a token", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );
    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    await hardhatETFReceipt.connect(account2).approve(owner.address, 1);
    await hardhatETFReceipt.connect(owner).burn(1);

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    const tokenList = await hardhatETFReceipt.getTokensByOwner(
      account2.address
    );

    expect(tokenList.length).to.be.eq(2);
    expect(tokenList[0].id.toString()).to.be.eq("0");
    expect(tokenList[1].id.toString()).to.be.eq("2");
  });

  it("Should burnAndMint", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC
    );

    const prices = [
      ethers.utils.parseUnits("1000", 6),
      ethers.utils.parseUnits("1000", 6),
      ethers.utils.parseUnits("1000", 6),
      ethers.utils.parseUnits("1000", 6),
    ];
    const amounts = [
      ethers.utils.parseUnits("1000", 18),
      ethers.utils.parseUnits("1000", 18),
      ethers.utils.parseUnits("1000", 18),
      ethers.utils.parseUnits("1000", 18),
    ];

    const tokenDetail = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenDetail.push({
        token: tokens[i],
        amount: amounts[i],
        price: prices[i],
      });
    }

    await expect(
      hardhatETFReceipt
        .connect(owner)
        .burnAndMint(0, account2.address, 0, tokenDetail)
    ).to.be.revertedWith("ETFReceipt: approve needed");

    await hardhatETFReceipt.connect(account2).approve(owner.address, 0);
    await expect(
      hardhatETFReceipt
        .connect(owner)
        .burnAndMint(0, account2.address, 0, tokenDetail)
    ).to.emit(hardhatETFReceipt, "BurnedAndMinted");

    const tokenList = await hardhatETFReceipt.getTokensByOwner(
      account2.address
    );
    const totalSupply = await hardhatETFReceipt.totalSupply();

    expect(tokenList.length).to.be.eq(1);
    expect(totalSupply.toString()).to.be.eq("1");
  });

  it("Should withdraw without swap 100%", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
      true
    );

    await hardhatETFReceipt
      .connect(account2)
      .approve(hardhatETFProxy.address, 0);

    await expect(
      hardhatETFProxy.connect(account2).withdrawWithoutSwap(0, 10000)
    ).to.emit(hardhatETFReceipt, "Burned");
    expect((await hardhatETFReceipt.totalSupply()).toString()).to.be.eq("0");
    expect(
      (await CROWD.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq("0");
    expect(
      (await MATIC.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq("0");
    expect((await UNI.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      "0"
    );
    expect((await WBTC.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      "0"
    );
    expect((await CROWD.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("999", 18).toString()
    );
    expect((await MATIC.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("999", 18).toString()
    );
    expect((await UNI.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("999", 18).toString()
    );
    expect((await WBTC.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("999", 18).toString()
    );
  });

  it("Should withdraw without swap 40%", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
      true
    );

    await hardhatETFReceipt
      .connect(account2)
      .approve(hardhatETFProxy.address, 0);
    await expect(
      hardhatETFProxy.connect(account2).withdrawWithoutSwap(0, 6000)
    ).to.emit(hardhatETFReceipt, "BurnedAndMinted");
    expect((await hardhatETFReceipt.totalSupply()).toString()).to.be.eq("1");
    expect(
      (await hardhatETFReceipt.balanceOf(account2.address)).toString()
    ).to.be.eq("1");
    expect(
      (await CROWD.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq(ethers.utils.parseUnits("400", 18).toString());
    expect(
      (await MATIC.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq(ethers.utils.parseUnits("400", 18).toString());
    expect((await UNI.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("400", 18).toString()
    );
    expect((await WBTC.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("400", 18).toString()
    );
    expect((await CROWD.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("599.4", 18).toString()
    );
    expect((await MATIC.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("599.4", 18).toString()
    );
    expect((await UNI.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("599.4", 18).toString()
    );
    expect((await WBTC.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("599.4", 18).toString()
    );
  });

  it("Should withdraw with swap 100%", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      hardhatSwapContract,
      CROWD,
      MATIC,
      UNI,
      WBTC,
      USDT,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
      true
    );

    await hardhatETFReceipt
      .connect(account2)
      .approve(hardhatETFProxy.address, 0);

    const swapInfoList = [];

    let populateTransaction =
      await hardhatSwapContract.populateTransaction.swap(
        CROWD.address,
        USDT.address,
        hardhatETFProxy.address,
        ethers.utils.parseUnits("1000", 18),
        0,
        "0x0011"
      );
    swapInfoList.push({
      token: CROWD.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      MATIC.address,
      USDT.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("1000", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: MATIC.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      UNI.address,
      USDT.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("1000", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: UNI.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      WBTC.address,
      USDT.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("1000", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: WBTC.address,
      price: 1000000,
      data: populateTransaction.data,
    });

    await expect(
      hardhatETFProxy
        .connect(account2)
        .withdrawWithSwap(0, USDT.address, 10000, swapInfoList)
    ).to.emit(hardhatETFReceipt, "Burned");
    expect((await hardhatETFReceipt.totalSupply()).toString()).to.be.eq("0");

    expect(
      (await CROWD.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq("0");
    expect(
      (await MATIC.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq("0");
    expect((await UNI.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      "0"
    );
    expect((await WBTC.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      "0"
    );

    expect((await USDT.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("3996", 18).toString()
    );
  });

  it("Should withdraw with swap 10%", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      hardhatSwapContract,
      CROWD,
      MATIC,
      UNI,
      WBTC,
      USDT,
    } = await createPlan();

    await mintNFT(
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      CROWD,
      MATIC,
      UNI,
      WBTC,
      true
    );

    await hardhatETFReceipt
      .connect(owner)
      .setETFProxyAddress(hardhatETFProxy.address);

    await hardhatETFReceipt
      .connect(account2)
      .approve(hardhatETFProxy.address, 0);

    const swapInfoList = [];

    let populateTransaction =
      await hardhatSwapContract.populateTransaction.swap(
        CROWD.address,
        USDT.address,
        hardhatETFProxy.address,
        ethers.utils.parseUnits("100", 18),
        0,
        "0x0011"
      );
    swapInfoList.push({
      token: CROWD.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      MATIC.address,
      USDT.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("100", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: MATIC.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      UNI.address,
      USDT.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("100", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: UNI.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      WBTC.address,
      USDT.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("100", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: WBTC.address,
      price: 1000000,
      data: populateTransaction.data,
    });

    await expect(
      hardhatETFProxy
        .connect(account2)
        .withdrawWithSwap(0, USDT.address, 1000, swapInfoList)
    ).to.emit(hardhatETFReceipt, "BurnedAndMinted");
    expect((await hardhatETFReceipt.totalSupply()).toString()).to.be.eq("1");

    expect(
      (await CROWD.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq(ethers.utils.parseUnits("900", 18).toString());
    expect(
      (await MATIC.balanceOf(hardhatETFProxy.address)).toString()
    ).to.be.eq(ethers.utils.parseUnits("900", 18).toString());
    expect((await UNI.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("900", 18).toString()
    );
    expect((await WBTC.balanceOf(hardhatETFProxy.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("900", 18).toString()
    );

    expect((await USDT.balanceOf(account2.address)).toString()).to.be.eq(
      ethers.utils.parseUnits("399.6", 18).toString()
    );
  });

  it("Should invest", async function () {
    const {
      tokens,
      hardhatETFReceipt,
      hardhatETFProxy,
      hardhatSwapContract,
      USDT,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await createPlan();

    await hardhatETFReceipt
      .connect(owner)
      .setETFProxyAddress(hardhatETFProxy.address);

    const swapInfoList = [];

    let populateTransaction =
      await hardhatSwapContract.populateTransaction.swap(
        USDT.address,
        CROWD.address,
        hardhatETFProxy.address,
        ethers.utils.parseUnits("249.75", 18),
        0,
        "0x0011"
      );
    swapInfoList.push({
      token: CROWD.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      USDT.address,
      MATIC.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("249.75", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: MATIC.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      USDT.address,
      UNI.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("249.75", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: UNI.address,
      price: 1000000,
      data: populateTransaction.data,
    });
    populateTransaction = await hardhatSwapContract.populateTransaction.swap(
      USDT.address,
      WBTC.address,
      hardhatETFProxy.address,
      ethers.utils.parseUnits("249.75", 18),
      0,
      "0x0011"
    );
    swapInfoList.push({
      token: WBTC.address,
      price: 1000000,
      data: populateTransaction.data,
    });

    await USDT.mint(account2.address, ethers.utils.parseUnits("1000", 18));
    await USDT.connect(account2).approve(
      hardhatETFProxy.address,
      ethers.utils.parseUnits("1000", 18)
    );

    await hardhatETFProxy
      .connect(account2)
      .invest(
        account2.address,
        0,
        USDT.address,
        ethers.utils.parseUnits("1000", 18),
        swapInfoList
      );

    const investList = await hardhatETFReceipt.getTokensByOwner(
      account2.address
    );
    expect(investList.length).to.be.eq(1);
    expect(investList[0].tokenDetails.length).to.be.eq(4);
    expect(investList[0].tokenDetails[0].amount.toString()).to.be.eq(
      ethers.utils.parseUnits("249.75", 18).toString()
    );
  });

  async function mintNFT(
    tokens,
    hardhatETFReceipt,
    hardhatETFProxy,
    CROWD,
    MATIC,
    UNI,
    WBTC,
    setETFProxyAddress?: boolean
  ) {
    const prices = [
      ethers.utils.parseUnits("1000", 6),
      ethers.utils.parseUnits("1000", 6),
      ethers.utils.parseUnits("1000", 6),
      ethers.utils.parseUnits("1000", 6),
    ];
    const amounts = [
      ethers.utils.parseUnits("1000", 18),
      ethers.utils.parseUnits("1000", 18),
      ethers.utils.parseUnits("1000", 18),
      ethers.utils.parseUnits("1000", 18),
    ];

    await CROWD.mint(hardhatETFProxy.address, amounts[0]);

    await MATIC.mint(hardhatETFProxy.address, amounts[1]);

    await UNI.mint(hardhatETFProxy.address, amounts[2]);

    await WBTC.mint(hardhatETFProxy.address, amounts[3]);

    const tokenDetail = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenDetail.push({
        token: tokens[i],
        amount: amounts[i],
        price: prices[i],
      });
    }

    await hardhatETFReceipt.connect(owner).setETFProxyAddress(owner.address);

    await expect(
      hardhatETFReceipt.connect(owner).mint(account2.address, 0, tokenDetail)
    ).to.emit(hardhatETFReceipt, "Minted");

    if (setETFProxyAddress) {
      await hardhatETFReceipt
        .connect(owner)
        .setETFProxyAddress(hardhatETFProxy.address);
    }
  }

  async function createPlan() {
    const {
      etfReceipt: hardhatETFReceipt,
      etfProxy: hardhatETFProxy,
      swapContract: hardhatSwapContract,
      USDT,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    } = await loadFixture(ETFFixture);

    const tokens = [CROWD.address, MATIC.address, UNI.address, WBTC.address];

    const percentages = [2500, 2500, 2500, 2500];
    const tokenPercentages = [];
    for (let i = 0; i < tokens.length; i++) {
      tokenPercentages.push({ token: tokens[i], percentage: percentages[i] });
    }

    await hardhatETFReceipt
      .connect(owner)
      .createPlan("first_etf", tokenPercentages);

    return {
      tokens: tokens,
      hardhatETFReceipt: hardhatETFReceipt,
      hardhatETFProxy: hardhatETFProxy,
      hardhatSwapContract: hardhatSwapContract,
      USDT,
      CROWD,
      MATIC,
      UNI,
      WBTC,
    };
  }
});
