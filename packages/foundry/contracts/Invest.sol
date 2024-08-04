//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "forge-std/console.sol";

/**
 * A smart contract that allows changing a state variable of the contract and tracking the changes
 * It also allows the owner to withdraw the Ether in the contract
 * @author BuidlGuidl
 */
contract Invest {
    // State Variables
    address public immutable owner;
    IWETH public immutable weth;
    ISwapRouter02 public immutable router;
    // 10_000 = 100%
    uint256 public fees;

    event Invested(
        address indexed token,
        address indexed investor,
        uint256 indexed tokenId,
        uint256 amount
    );

    // Constructor: Called once on contract deployment
    // Check packages/foundry/deploy/Deploy.s.sol
    constructor(address _owner, address _weth, address _router, uint256 _fees) {
        owner = _owner;
        weth = IWETH(_weth);
        router = ISwapRouter02(_router);
        require(_fees < 100, "Fees can't be more than 1 %");
        fees = _fees;
    }

    function InvestNative(
        address counterPart,
        uint256 amountOutMin,
        uint24 fee,
        uint256 tickLower,
        uint256 tickUpper
    ) public payable returns (uint256) {
        uint256 platformFees = 0;
        if (fees > 0) {
            platformFees = (msg.value * fees) / 10_000;
            (bool sent, ) = owner.call{value: platformFees}("");
            require(sent, "Failed to send Ether");
        }
        uint256 amountInvested = msg.value - platformFees;
        weth.deposit{value: amountInvested}();

        // swap necessary token
        _swapExactInputSingleHop(
            address(weth),
            counterPart,
            amountInvested,
            amountOutMin,
            fee
        );

        return 0;
    }

    function InvestToken(
        address token,
        uint256 amount,
        uint256 amountOutMin,
        address counterPart,
        uint24 fee,
        uint256 tickLower,
        uint256 tickUpper
    ) public returns (uint256) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 platformFees = 0;
        if (fees > 0) {
            platformFees = (amount * fees) / 10_000;
            IERC20(token).transfer(owner, platformFees);
        }
        uint256 amountInvested = amount - platformFees;

         // swap necessary token
        _swapExactInputSingleHop(
            address(token),
            counterPart,
            amountInvested,
            amountOutMin,
            fee
        );

        return 0;
    }

    function _swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 fee
    ) private {
        IERC20(tokenIn).approve(address(router), amountIn);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: msg.sender,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });

        router.exactInputSingle(params);
    }
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
