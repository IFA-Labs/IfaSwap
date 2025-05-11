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
    error ASSET_NOT_SET();
    error DOES_NOT_EXIST();
    error PRICE_FEED_STALE();

    function getReserves() external view returns (uint128 _reserve0, uint128 _reserve1, uint256 _reserveUsd);
    function getUsdValue(address token, uint256 amount) external view returns (uint256);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function mint(address to) external returns (uint256 liquidity);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
