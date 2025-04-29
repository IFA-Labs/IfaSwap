//SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import {IfaswapERC20} from "src/IfaSwapERC20.sol";

contract IfaSwapPair is IfaswapERC20 {
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    error UnAuthorized();

    constructor(address _token0, address _token1) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }
}
