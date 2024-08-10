const ethers = require("ethers");
const { parse, stringify } = require("envfile");
const fs = require("fs");
const { Pool, Position, Tick, computePoolAddress, FeeAmount, nearestUsableTick } = require('@uniswap/v3-sdk');
const JSBI = require('jsbi');
const { BigIntish, Token } = require('@uniswap/sdk-core');
const IUniswapV3PoolABI = require('@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json')
const axios = require('axios');

const envFilePath = "./.env";


async function main() {

  const usdc = new Token(1, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6);
  const weth = new Token(1, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18);
  const fee = FeeAmount.LOW;
  // const sqrt = "1543922854351029034552027788781182";

  //  const pool = new Pool(token0, token1, fee,sqrt,);
  const tickLower = -200;
  const tickUpper = 100;
  const amount0 = '1000000000000000000'
  const useFullPrecision = true;

  let provider = new ethers.providers.JsonRpcProvider("https://eth.llamarpc.com");

  const poolContract = new ethers.Contract(
    // ether/usdc 0.05% fee on ethereum
    "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640",
    IUniswapV3PoolABI.abi,
    provider
  );

  const [slot0, liquidity] = await Promise.all([
    poolContract.slot0(),
    poolContract.liquidity()
  ]);

  const sqrt = slot0.sqrtPriceX96.toString();
  const liq = liquidity.toString();

  console.log("slot0", sqrt);
  console.log("liquidity", liq);

  const usdcWethPool = new Pool(
    usdc,
    weth,
    fee,
    sqrt,
    liq,
    slot0.tick
  )

  // const tickLower2 = nearestUsableTick(slot0.tick, slot0.tickSpacing) -
  //   poolInfo.tickSpacing * 2;
  // const tickUpper2 = nearestUsableTick(slot0.tick, slot0.tickSpacing) +
  //   poolInfo.tickSpacing * 2;

  const singleSidePositionToken0 = Position.fromAmount0({
    pool: usdcWethPool,
    tickLower,
    tickUpper,
    amount0,
    useFullPrecision
  });

  console.log("singleSidePositionToken0", singleSidePositionToken0);

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
