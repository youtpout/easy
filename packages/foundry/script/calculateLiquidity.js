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
  const amount1 = '1000000000000000000'
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

  const tickLower = nearestUsableTick(slot0.tick, tickSpacing) -
    1000;
  const tickUpper = nearestUsableTick(slot0.tick, tickSpacing) +
    1000;

  console.log("tickLower", tickLower)
  console.log("tickUpper", tickUpper)

  // Calculer le prix actuel de l'ETH en termes de USDC
  const priceEthInUsdc = Math.pow(slot0.sqrtPriceX96 / Math.pow(2, 96), 2);
  const ratio = Math.pow(10, 18) / Math.pow(10, 6);
  const total = ratio / priceEthInUsdc;

  console.log(`Actual eth price in the pool ${total.toFixed(6)} USDC`);

  const singleSidePositionToken0 = Position.fromAmount1({
    pool: usdcWethPool,
    tickLower,
    tickUpper,
    amount1,
    useFullPrecision
  });

  // Calculate the required USDC amount
  const amountUsdcRequired = singleSidePositionToken0.amount0.toSignificant(6);
  const amountEthUsed = singleSidePositionToken0.amount1.toSignificant(6);

  console.log(`With 1 ETH, you would need approximately ${amountUsdcRequired} USDC to provide liquidity.`);
  console.log(`This will use approximately ${amountEthUsed} ETH for the position.`);

  const fromAmount = Position.fromAmounts({
    pool: usdcWethPool,
    tickLower,
    tickUpper,
    amount0: Math.pow(10, 17) * 5,
    amount1: Math.pow(10, 6) * 1350,
    useFullPrecision
  });

  const amountUsdc = fromAmount.amount0.toSignificant(6);
  const amountEth = fromAmount.amount1.toSignificant(6);


  console.log(`With 1 ETH, you would need approximately ${amountUsdc} USDC to provide liquidity.`);
  console.log(`This will use approximately ${amountEth} ETH for the position.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
