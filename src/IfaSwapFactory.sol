//SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "./interfaces/IIfaswapFactory.sol";
import "./IfaSwapPair.sol";

contract IfaSwapFactory is IIfaswapFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address) {
        require(tokenA != tokenB, IdenticalAddresses());

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists());

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        IfaSwapPair pair = new IfaSwapPair{salt: salt}(token0, token1);

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
}
