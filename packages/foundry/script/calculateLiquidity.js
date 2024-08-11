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

  const amount0 = '1000000000000000000'
  const useFullPrecision = true;

  let provider = new ethers.providers.JsonRpcProvider("https://eth.llamarpc.com");

  const poolContract = new ethers.Contract(
    // ether/usdc 0.05% fee on ethereum
    "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640",
    IUniswapV3PoolABI.abi,
    provider
  );

  const [slot0, liquidity, tickSpacing] = await Promise.all([
    poolContract.slot0(),
    poolContract.liquidity(),
    poolContract.tickSpacing()
  ]);

  const sqrt = slot0.sqrtPriceX96.toString();
  const liq = liquidity.toString();

  console.log("slot0", slot0);
  console.log("liquidity", liq);
  console.log("sqrt", sqrt);

  const usdcWethPool = new Pool(
    usdc,
    weth,
    fee,
    sqrt,
    liq,
    slot0.tick
  )

  const tickLower = nearestUsableTick(slot0.tick, tickSpacing) -
    100;
  const tickUpper = nearestUsableTick(slot0.tick, tickSpacing) +
    100;

  console.log("tickLower", tickLower)
  console.log("tickUpper", tickUpper)

  const newliquidity = ethers.BigNumber.from('10000000000000000');
  const position = new Position({
    pool: usdcWethPool,
    liquidity: newliquidity,
    tickLower,
    tickUpper
  });

  console.log(`Amount of Token0 needed: ${position.amount0.toSignificant(6)}`);
  console.log(`Amount of Token1 needed: ${position.amount1.toSignificant(6)}`);

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
