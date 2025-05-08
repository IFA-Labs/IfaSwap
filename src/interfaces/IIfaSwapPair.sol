//SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

interface IIfaSwapPair {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    error INSUFFICIENT_LIQUIDITY_BURNED();
    error INSUFFICIENT_LIQUIDITY_MINTED();
    error TRANSFER_FAILED();
    error INSUFFICIENT_OUTPUT_AMOUNT();
    error INSUFFICIENT_LIQUIDITY();
    error INVALID_TO();
    error INSUFFICIENT_INPUT_AMOUNT();
    error INVALID_AFTERSWAPCHEK();
}
