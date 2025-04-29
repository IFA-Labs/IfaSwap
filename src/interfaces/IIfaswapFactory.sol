//SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

interface IIfaswapFactory {
    event PairCreated(
        address indexed token0, address indexed token1, address pair, uint256 pairNumber, uint256 creationTime
    );

    error IdenticalAddresses();
    error ZeroAddress();
    error PairExists();
    error Forbidden();

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
