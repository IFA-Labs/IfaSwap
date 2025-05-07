//SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "./interfaces/IIfaswapFactory.sol";
import "./IfaSwapPair.sol";

contract IfaSwapFactory is IIfaswapFactory {
    address public feeTo;
    address public feeToSetter;
    address public priceFeedSetter;

    mapping(address tokenAddress => bytes32 assetId) public priceFeeds;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter, address _priceFeedSetter) {
        require(_priceFeedSetter != address(0) && _feeToSetter != address(0), ZeroAddress());
        feeToSetter = _feeToSetter;
        priceFeedSetter = _priceFeedSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address) {
        require(tokenA != tokenB, IdenticalAddresses());
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists());

        bytes32 assetId0 = priceFeeds[token0];
        bytes32 assetId1 = priceFeeds[token1];
        require(assetId0 != bytes32(0), PriceFeedDoesNotExists(tokenA));
        require(assetId1 != bytes32(0), PriceFeedDoesNotExists(tokenB));

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        IfaSwapPair pair = new IfaSwapPair{salt: salt}(token0, token1, assetId0, assetId1);

        getPair[token0][token1] = address(pair);
        getPair[token1][token0] = address(pair);
        allPairs.push(address(pair));
        emit PairCreated(token0, token1, address(pair), allPairs.length, block.timestamp);
        return address(pair);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, Forbidden());
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, Forbidden());
        feeToSetter = _feeToSetter;
    }

    function setPriceFeed(address _token, bytes32 _assetId) external {
        require(msg.sender == priceFeedSetter, Forbidden());
        priceFeeds[_token] = _assetId;
    }
}
