//SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

interface IIfaSwapPair {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    error INSUFFICIENT_LIQUIDITY_BURNED();
    error INSUFFICIENT_LIQUIDITY_MINTED();
    error TRANSFER_FAILED();
}
