// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/Invest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InvestTest is Test {
    Invest public invest;

    ERC20 public constant wEth =
        ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    ERC20 public constant usdcToken =
        ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    ERC20 public constant btcToken =
        ERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    ERC20 public constant linkToken =
        ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);

    ERC20 public constant rEth =
        ERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);

    address deployer = makeAddr("Deployer");
    address alice = makeAddr("Alice");

    function setUp() public {
        vm.createSelectFork("mainnet");
        // addres for uniswap on ethereum, factory 0x1F98431c8aD98523631AE4a59f267346ea31F984
        invest = new Invest(
            deployer,
            address(wEth),
            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            100
        );
    }

    function testInvestNative() public {
        // 1250 $ for 0.5 ether, pool usdc/eth 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640
        uint256 amountUsdc = 1250 * 10 ** 6;
        uint256 id = invest.InvestNative{value: 1 ether}(
            address(usdcToken),
            0.5 ether,
            amountUsdc,
            500,
            196310,
            197410,
            alice
        );

        assertEq(id, 0);

        uint256 position = invest.linkedPosition(id);
        assertGt(position, 1);
        console.log("position", position);
    }

    function testInvestBtc() public {
        deal(address(btcToken), deployer, 10 * 10 ** 8);
        vm.startPrank(deployer);
        // 29000 $ for 0.5 wbtc, pool usdc/wbtc 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35
        uint256 btc = 1 * 10 ** 8;
        uint256 amountin = btc / 2;
        uint256 amountUsdc = 29000 * 10 ** 6;

        btcToken.approve(address(invest), btc);
        uint256 id = invest.InvestToken(
            address(btcToken),
            btc,
            amountin,
            amountUsdc,
            address(usdcToken),
            3000,
            63120,
            65100,
            alice
        );

        assertEq(id, 0);

        uint256 position = invest.linkedPosition(id);
        assertGt(position, 1);
        console.log("position", position);
        vm.stopPrank();
    }
}
