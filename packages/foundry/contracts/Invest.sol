//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "forge-std/console.sol";
import "./EasyNFT.sol";

/**
 * A smart contract that allows changing a state variable of the contract and tracking the changes
 * It also allows the owner to withdraw the Ether in the contract
 * @author BuidlGuidl
 */
contract Invest is EasyNFT {
    // State Variables
    IWETH public immutable weth;
    ISwapRouter02 public immutable router;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    // 10_000 = 100%
    uint256 public fees;

    mapping(uint256 => address) collectedToken;

    event Invested(
        address indexed token,
        address indexed investor,
        uint256 indexed tokenId,
        uint256 tokenIdPosition,
        uint256 amount
    );

    event Closed(
        uint256 indexed tokenId,
        address indexed receiver,
        uint256 tokenIdPosition,
        uint256 amount
    );

    // Constructor: Called once on contract deployment
    // Check packages/foundry/deploy/Deploy.s.sol
    constructor(
        address _owner,
        address _weth,
        address _router,
        address _nonfungiblePositionManager,
        uint256 _fees
    ) EasyNFT(_owner) {
        require(_fees < 100, "Fees can't be more than 1 %");
        weth = IWETH(_weth);
        router = ISwapRouter02(_router);
        nonfungiblePositionManager = INonfungiblePositionManager(
            _nonfungiblePositionManager
        );
        fees = _fees;
    }

    function InvestNative(
        address counterPart,
        uint256 amountOutMin,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        address receiver
    ) public payable returns (uint256) {
        uint256 platformFees = 0;
        if (fees > 0) {
            platformFees = (msg.value * fees) / 10_000;
            (bool sent, ) = owner().call{value: platformFees}("");
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

        (uint256 tokenIdPosition, , , ) = _mintNewPosition(
            address(weth),
            counterPart,
            tickLower,
            tickUpper,
            fee,
            amountInvested,
            amountOutMin
        );

        uint256 tokenId = safeMint(receiver, tokenIdPosition);

        emit Invested(
            address(weth),
            receiver,
            tokenId,
            tokenIdPosition,
            msg.value
        );

        collectedToken[tokenId] = address(weth);

        return tokenId;
    }

    function InvestToken(
        address token,
        uint256 amount,
        uint256 amountOutMin,
        address counterPart,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        address receiver
    ) public returns (uint256) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 platformFees = 0;
        if (fees > 0) {
            platformFees = (amount * fees) / 10_000;
            IERC20(token).transfer(owner(), platformFees);
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

        (uint256 tokenIdPosition, , , ) = _mintNewPosition(
            token,
            counterPart,
            tickLower,
            tickUpper,
            fee,
            amountInvested,
            amountOutMin
        );

        uint256 tokenId = safeMint(receiver, tokenIdPosition);

        emit Invested(token, receiver, tokenId, tokenIdPosition, amount);

        collectedToken[tokenId] = address(token);

        return tokenId;
    }

    function close(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "You can't close this position ");
        uint256 positionId = linkedPosition[tokenId];

        _closePosition(tokenId, positionId, owner);
    }

    function botClose(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        uint256 positionId = linkedPosition[tokenId];
        (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = nonfungiblePositionManager.positions(tokenId);

        address factory = router.factory();
        address pool = IUniswapV3Factory(factory).getPool(token0, token1, fee);
        IUniswapV3Pool.Slot0 memory slot = IUniswapV3Pool(pool).slot0();
        int24 currentTick = slot.tick;

        // todo check if tick negative or positive maybe
        bool canClose = currentTick < tickLower || currentTick > tickUpper;

        require(canClose, "Position stays active");

        _closePosition(tokenId, positionId, owner);
    }

    function _closePosition(
        uint256 tokenId,
        uint256 positionId,
        address receiver
    ) private {
        uint256 positionId = linkedPosition[tokenId];
        (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = nonfungiblePositionManager.positions(tokenId);

        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        nonfungiblePositionManager.collect(params);

        INonfungiblePositionManager.DecreaseLiquidityParams
            memory paramsDecrease = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        nonfungiblePositionManager.decreaseLiquidity(paramsDecrease);

        address tokenOut = collectedToken[tokenId];
        require(
            tokenOut == token0 || tokenOut == token1,
            "Incorrect out token"
        );

        // reswap in collected amount
        if (tokenOut == token0) {
            _swapExactInputSingleHop(
                token1,
                token0,
                IERC20(token1).balanceOf(address(this)),
                1,
                fee
            );
        } else {
            _swapExactInputSingleHop(
                token0,
                token1,
                IERC20(token0).balanceOf(address(this)),
                1,
                fee
            );
        }

        uint256 amount = IERC20(tokenOut).balanceOf(address(this));

        // send collected feed back to owner
        if (tokenOut == address(weth)) {
            weth.withdraw(amount);
            (bool sent, ) = receiver.call{value: amount}("");
            require(sent, "Failed to send Ether");
        } else {
            IERC20(tokenOut).transfer(receiver, amount);
        }

        emit Closed(tokenId, receiver, positionId, amount);
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

    /// @notice Calls the mint function defined in periphery, mints the same amount of each token. For this example we are providing 1000 DAI and 1000 USDC in liquidity
    /// @return tokenId The id of the newly minted ERC721
    /// @return liquidity The amount of liquidity for the position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function _mintNewPosition(
        address token0,
        address token1,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee,
        uint256 amountToken0,
        uint256 amountToken1
    )
        private
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        IERC20(token0).transfer(
            address(nonfungiblePositionManager),
            amountToken1
        );
        IERC20(token1).transfer(
            address(nonfungiblePositionManager),
            amountToken1
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amountToken1,
                amount1Desired: amountToken1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        // Note that the pool defined by DAI/USDC and fee tier 0.3% must already be created and initialized in order to mint
        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);
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

    function factory() external pure returns (address);
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

interface IUniswapV3Pool {
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    function slot0() external returns (Slot0 memory);

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function positions(
        uint256 tokenId
    )
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(
        CollectParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);
}
