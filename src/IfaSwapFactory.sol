//SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import {IIfaSwapFactory} from "./interfaces/IIfaSwapFactory.sol";
import {IIfaSwapRouter} from "./interfaces/IIfaSwapRouter.sol";
import {IfaSwapPair} from "./IfaSwapPair.sol";

contract IfaSwapFactory is IIfaSwapFactory {
    address public feeTo;
    address public feeToSetter;
    address public priceFeedSetter;
    address public priceFeedAddress;
    address public router;

    mapping(address tokenAddress => bytes32 assetId) public priceFeeds;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter, address _priceFeedSetter, address _priceFeedAddress) {
        require(_priceFeedSetter != address(0) && _feeToSetter != address(0), ZeroAddress());
        feeToSetter = _feeToSetter;
        priceFeedSetter = _priceFeedSetter;
        priceFeedAddress = _priceFeedAddress;
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
        IfaSwapPair pair = new IfaSwapPair{salt: salt}(token0, token1, assetId0, assetId1, priceFeedAddress);

        getPair[token0][token1] = address(pair);
        getPair[token1][token0] = address(pair);
        allPairs.push(address(pair));
        emit PairCreated(token0, token1, address(pair), allPairs.length, block.timestamp);
        return address(pair);
    }

    function setFeeTo(address _feeTo) external {
        require(_feeTo != address(0));
        require(msg.sender == feeToSetter, Forbidden());
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(_feeToSetter != address(0));
        require(msg.sender == feeToSetter, Forbidden());
        feeToSetter = _feeToSetter;
    }

    function setpriceFeedAddress(address _priceFeedAddress) external {
        require(_priceFeedAddress != address(0));
        require(msg.sender == priceFeedSetter, Forbidden());
        priceFeedAddress = _priceFeedAddress;
        IIfaSwapRouter(router).setpriceFeedAddress(_priceFeedAddress);
    }

    function setPriceFeed(address _token, bytes32 _assetId) external {
        require(_token != address(0) && _assetId != bytes32(0));
        require(msg.sender == priceFeedSetter, Forbidden());
        priceFeeds[_token] = _assetId;
        IIfaSwapRouter(router).setPriceFeed(_token, _assetId);
    }

    function setRouter(address _router) external {
        require(_router != address(0));
        require(msg.sender == priceFeedSetter, Forbidden());
        router = _router;
    }
}
