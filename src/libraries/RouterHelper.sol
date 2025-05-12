// SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "../interfaces/IIfaSwapPair.sol";
import "../interfaces/IIfaPriceFeed.sol";

library RouterHelper {
    error IDENTICAL_ADDRESSES();
    error ZERO_ADDRESS();
    error INSUFFICIENT_AMOUNT();
    error INSUFFICIENT_LIQUIDITY();
    error INVALID_PATH();
    error INSUFFICIENT_OUTPUT_AMOUNT();
    error INSUFFICIENT_INPUT_AMOUNT();
    error PRICE_FEED_STALE();
    error INVALID_PRICE_FEED();

    uint256 constant FEE_DENOMINATOR = 1000;
    uint256 constant FEE_NUMERATOR = 6;
    uint256 constant STALENESS_THRESHOLD = 1 hours;

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
    // returns sorted token addresses, used to handle return values from pairs sorted in this order

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, IDENTICAL_ADDRESSES());
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZERO_ADDRESS());
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // pair = address(
        //     uint256(
        //         keccak256(
        //             abi.encodePacked(
        //                 hex"ff",
        //                 factory,
        //                 keccak256(abi.encodePacked(token0, token1)),
        //                 hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
        //             )
        //         )
        //     )
        // );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IIfaSwapPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
}
