// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IfaSwapFactory} from "../src/IfaSwapFactory.sol";

import "../src/IfaSwapRouter.sol";
import "./mock/MockToken.sol";
import "./mock/MockPriceFeed.sol";

import {IfaSwapPair} from "../src/IfaSwapPair.sol";
import "../src/interfaces/IIfaPriceFeed.sol";
import "../src/interfaces/IIfaSwapPair.sol";
import "../src/interfaces/IWETH.sol";

// Mock WETH for testing
contract MockWETH is MockToken {
    constructor() MockToken("Wrapped Ether", "WETH", 18) {}

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "WETH: insufficient balance");
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    receive() external payable {
        deposit();
    }
}

contract IfaSwapIntegrationTest is Test {
    // Contracts
    IfaSwapFactory public factory;
    IfaSwapRouter public router;
    MockPriceFeed public priceFeed;
    MockWETH public weth;

    // Tokens
    MockToken public tokenA;
    MockToken public tokenB;
    MockToken public tokenC;

    // Asset IDs
    bytes32 public assetIdA = bytes32(uint256(1));
    bytes32 public assetIdB = bytes32(uint256(2));
    bytes32 public assetIdC = bytes32(uint256(3));
    bytes32 public assetIdWeth = bytes32(uint256(4));

    // Addresses
    address public feeSetter = address(1);
    address public priceFeedSetter = address(2);
    address public user = address(3);
    address public liquidityProvider = address(4);

    // Constants
    uint256 public constant INITIAL_BALANCE = 1000000 * 10 ** 18;

    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockToken("Token A", "TA", 18);
        tokenB = new MockToken("Token B", "TB", 18);
        tokenC = new MockToken("Token C", "TC", 18);
        weth = new MockWETH();

        // Deploy price feed and set prices
        priceFeed = new MockPriceFeed();

        // Set token price information
        // Asset A = $1.00, Asset B = $2.00, Asset C = $3.00
        priceFeed.setAssetInfo(
            assetIdA,
            IIfaPriceFeed.PriceFeed({price: 1 * 10 ** 18, decimal: -18, lastUpdateTime: uint64(block.timestamp)})
        );

        priceFeed.setAssetInfo(
            assetIdB,
            IIfaPriceFeed.PriceFeed({price: 2 * 10 ** 18, decimal: -18, lastUpdateTime: uint64(block.timestamp)})
        );

        priceFeed.setAssetInfo(
            assetIdC,
            IIfaPriceFeed.PriceFeed({price: 3 * 10 ** 18, decimal: -18, lastUpdateTime: uint64(block.timestamp)})
        );
        priceFeed.setAssetInfo(
            assetIdWeth,
            IIfaPriceFeed.PriceFeed({price: 2000 * 10 ** 18, decimal: -18, lastUpdateTime: uint64(block.timestamp)})
        );

        // Deploy factory and router
        factory = new IfaSwapFactory(feeSetter, priceFeedSetter, address(priceFeed));
        router = new IfaSwapRouter(address(factory), address(weth), address(priceFeed));

        // Set router in factory
        vm.prank(priceFeedSetter);
        factory.setRouter(address(router));

        // Set price feeds in factory
        vm.startPrank(priceFeedSetter);
        factory.setPriceFeed(address(tokenA), assetIdA);
        factory.setPriceFeed(address(tokenB), assetIdB);
        factory.setPriceFeed(address(tokenC), assetIdC);
        factory.setPriceFeed(address(weth), assetIdWeth);
        vm.stopPrank();

        // Mint tokens to users
        tokenA.mint(user, INITIAL_BALANCE);
        tokenB.mint(user, INITIAL_BALANCE);
        tokenC.mint(user, INITIAL_BALANCE);

        tokenA.mint(liquidityProvider, INITIAL_BALANCE);
        tokenB.mint(liquidityProvider, INITIAL_BALANCE);
        tokenC.mint(liquidityProvider, INITIAL_BALANCE);

        // Set ETH balance for users
        vm.deal(user, 100 ether);
        vm.deal(liquidityProvider, 100 ether);
    }

    function testAddAndRemoveLiquidity() public {
        vm.startPrank(liquidityProvider);

        // Approve tokens to router
        tokenA.approve(address(router), INITIAL_BALANCE);
        tokenB.approve(address(router), INITIAL_BALANCE);

        // Add liquidity to A-B pair
        uint256 amountA = 10000 * 10 ** 18;
        uint256 amountB = 5000 * 10 ** 18; // Since B is worth 2x A, this is equivalent value

        (uint256 actualAmountA, uint256 actualAmountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0, // min A
            0, // min B
            liquidityProvider,
            block.timestamp + 1 hours
        );

        address pairAB = factory.getPair(address(tokenA), address(tokenB));
        console2.log("balance::", IfaSwapPair(pairAB).balanceOf(liquidityProvider));

        // Verify liquidity was added correctly
        assertEq(tokenA.balanceOf(liquidityProvider), INITIAL_BALANCE - actualAmountA);
        assertEq(tokenB.balanceOf(liquidityProvider), INITIAL_BALANCE - actualAmountB);
        assertEq(IfaSwapPair(pairAB).balanceOf(liquidityProvider), liquidity);

        // Remove liquidity
        IfaSwapPair(pairAB).approve(address(router), type(uint256).max);
        IfaSwapPair(pairAB).allowance(address(liquidityProvider), address(router));

        (uint256 removedA, uint256 removedB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0, // min A  bad pratice I know but is is just testing lol
            0, // min B
            liquidityProvider,
            block.timestamp + 1 hours
        );

        // The removed amounts should be approximately equal to the added amounts
        // (might be slightly less due to fees)
        assertApproxEqRel(removedA, actualAmountA, 0.001e18); // 0.1% tolerance
        assertApproxEqRel(removedB, actualAmountB, 0.001e18); // 0.1% tolerance

        // LP token balance should be 0
        assertEq(IfaSwapPair(pairAB).balanceOf(liquidityProvider), 0);

        vm.stopPrank();
    }

    function testAddLiquidityForThreeTokens() public {
        vm.startPrank(liquidityProvider);

        // Approve tokens to router
        tokenA.approve(address(router), INITIAL_BALANCE);
        tokenB.approve(address(router), INITIAL_BALANCE);
        tokenC.approve(address(router), INITIAL_BALANCE);

        // Add liquidity to A-B pair
        uint256 amountA_AB = 10000 * 10 ** 18;
        uint256 amountB_AB = 5000 * 10 ** 18;

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA_AB,
            amountB_AB,
            0, // min A
            0, // min B
            liquidityProvider,
            block.timestamp + 1 hours
        );

        // Add liquidity to B-C pair
        uint256 amountB_BC = 6000 * 10 ** 18;
        uint256 amountC_BC = 4000 * 10 ** 18; // Since C is worth 3/2 of B, this is equivalent value

        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            amountB_BC,
            amountC_BC,
            0, // min B
            0, // min C
            liquidityProvider,
            block.timestamp + 1 hours
        );

        // Add liquidity to A-C pair
        uint256 amountA_AC = 9000 * 10 ** 18;
        uint256 amountC_AC = 3000 * 10 ** 18; // Since C is worth 3x A, this is equivalent value

        router.addLiquidity(
            address(tokenA),
            address(tokenC),
            amountA_AC,
            amountC_AC,
            0, // min A
            0, // min C
            liquidityProvider,
            block.timestamp + 1 hours
        );

        // Verify pairs were created
        address pairAB = factory.getPair(address(tokenA), address(tokenB));
        address pairBC = factory.getPair(address(tokenB), address(tokenC));
        address pairAC = factory.getPair(address(tokenA), address(tokenC));

        (uint256 _reserve0, uint256 _reserve1, uint256 _reserveusd) = IfaSwapPair(pairAC).getReserves();
        console2.log("_reserve0: ", _reserve0);
        console2.log("_reserve1: ", _reserve1);
        console2.log("_reserveusd: ", _reserveusd);

        assertTrue(pairAB != address(0), "A-B pair not created");
        assertTrue(pairBC != address(0), "B-C pair not created");
        assertTrue(pairAC != address(0), "A-C pair not created");

        vm.stopPrank();
    }

    function testSwapExactTokensForTokens() public {
        // First, add liquidity for all pairs
        testAddLiquidityForThreeTokens();

        vm.startPrank(user);

        // Approve tokens to router
        tokenA.approve(address(router), INITIAL_BALANCE);

        // Check initial balances
        uint256 initialBalanceA = tokenA.balanceOf(user);
        uint256 initialBalanceC = tokenC.balanceOf(user);

        // Swap from A to C directly
        uint256 amountIn = 1000 * 10 ** 18;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenC);

        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        uint256 expectedAmountOut = amountsOut[1];
        address pairAC = factory.getPair(address(tokenA), address(tokenC));
        (uint256 _reserve0, uint256 _reserve1, uint256 _reserveusd) = IfaSwapPair(pairAC).getReserves();
        console2.log("_reserve0: ", _reserve0);
        console2.log("_reserve1: ", _reserve1);
        console2.log("_reserveusd: ", _reserveusd);
        router.swapExactTokensForTokens(
            amountIn,
            0, // min amount out
            path,
            user,
            block.timestamp + 1 hours
        );

        // Verify balances after swap
        assertEq(tokenA.balanceOf(user), initialBalanceA - amountIn);
        assertEq(tokenC.balanceOf(user), initialBalanceC + expectedAmountOut);

        vm.stopPrank();
    }

    function testMultiHopSwap() public {
        // First, add liquidity for all pairs
        testAddLiquidityForThreeTokens();

        vm.startPrank(user);

        // Approve tokens to router
        tokenA.approve(address(router), INITIAL_BALANCE);

        // Check initial balances
        uint256 initialBalanceA = tokenA.balanceOf(user);
        uint256 initialBalanceC = tokenC.balanceOf(user);

        // Multi-hop swap: A -> B -> C
        uint256 amountIn = 1000 * 10 ** 18;
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        uint256 expectedAmountOut = amountsOut[2];

        router.swapExactTokensForTokens(
            amountIn,
            0, // min amount out
            path,
            user,
            block.timestamp + 1 hours
        );

        // Verify balances after swap
        assertEq(tokenA.balanceOf(user), initialBalanceA - amountIn);
        assertEq(tokenC.balanceOf(user), initialBalanceC + expectedAmountOut);

        vm.stopPrank();
    }

    function testETHSwaps() public {
        vm.startPrank(liquidityProvider);

        // Approve tokens to router
        tokenA.approve(address(router), INITIAL_BALANCE);

        // Add ETH-A liquidity
        uint256 ethAmount = 5 ether;
        uint256 tokenAmount = 10000 * 10 ** 18; // Assuming 1 ETH = 2000 Token A

        router.addLiquidityETH{value: ethAmount}(
            address(tokenA),
            tokenAmount,
            0, // min token
            0, // min ETH
            liquidityProvider,
            block.timestamp + 1 hours
        );

        vm.stopPrank();

        vm.startPrank(user);

        // Check initial balances
        uint256 initialETHBalance = address(user).balance;
        uint256 initialTokenABalance = tokenA.balanceOf(user);

        // Swap ETH for Token A
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        uint256 swapAmount = 1 ether;
        uint256[] memory amountsOut = router.getAmountsOut(swapAmount, path);

        router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user,
            block.timestamp + 1 hours
        );

        // Verify balances after swap
        assertEq(address(user).balance, initialETHBalance - swapAmount);
        assertEq(tokenA.balanceOf(user), initialTokenABalance + amountsOut[1]);

        // Now swap Token A back to ETH
        uint256 tokenSwapAmount = amountsOut[1];
        tokenA.approve(address(router), tokenSwapAmount);

        address[] memory reversePath = new address[](2);
        reversePath[0] = address(tokenA);
        reversePath[1] = address(weth);

        uint256[] memory reverseAmountsOut = router.getAmountsOut(tokenSwapAmount, reversePath);

        router.swapExactTokensForETH(
            tokenSwapAmount,
            0, // min amount out
            reversePath,
            user,
            block.timestamp + 1 hours
        );

        // The returned ETH should be slightly less than the original due to fees
        assertApproxEqRel(address(user).balance, initialETHBalance - swapAmount + reverseAmountsOut[1], 0.001e18);
        assertEq(tokenA.balanceOf(user), initialTokenABalance);

        vm.stopPrank();
    }

    function testComplexMultiHopSwapPath() public {
        // First, add liquidity for all pairs
        testAddLiquidityForThreeTokens();

        vm.startPrank(user);

        // Approve tokens to router
        tokenA.approve(address(router), INITIAL_BALANCE);

        // Check initial balances
        uint256 initialBalanceA = tokenA.balanceOf(user);
        uint256 initialBalanceB = tokenB.balanceOf(user);

        // Complex swap path: A -> C -> B (might be inefficient but tests complex routing)
        uint256 amountIn = 1000 * 10 ** 18;
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenC);
        path[2] = address(tokenB);

        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        uint256 expectedAmountOut = amountsOut[2];

        router.swapExactTokensForTokens(
            amountIn,
            0, // min amount out
            path,
            user,
            block.timestamp + 1 hours
        );

        // Verify balances after swap
        assertEq(tokenA.balanceOf(user), initialBalanceA - amountIn);
        assertEq(tokenB.balanceOf(user), initialBalanceB + expectedAmountOut);

        vm.stopPrank();
    }
}
