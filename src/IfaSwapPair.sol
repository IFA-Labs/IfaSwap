//SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "./interfaces/IIfaSwapPair.sol";
import "./interfaces/IIfaswapFactory.sol";
import {IERC20, IfaswapERC20} from "src/IfaSwapERC20.sol";
import {Math} from "./libraries/Math.sol";

contract IfaSwapPair is IIfaSwapPair, IfaswapERC20 {
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    bytes32 public immutable assetId0;
    bytes32 public immutable assetId1;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    uint128 private reserve0; // uses single storage slot, accessible via getReserves
    uint128 private reserve1; // uses single storage slot, accessible via getReserves
    uint256 public kLast; // _reserveUsd, as of immediately after the most recent liquidity event

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1);
        unlocked = 0;
        _;
        unlocked = 1;
    }

    error UnAuthorized();

    constructor(address _token0, address _token1, bytes32 _assetId0, bytes32 _assetId1) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
        assetId0 = _assetId0;
        assetId1 = _assetId1;
    }

    function getReserves() public view returns (uint128 _reserve0, uint128 _reserve1, uint256 _reserveUsd) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _reserveUsd = getUsdValue(token0, reserve0) + getUsdValue(token1, reserve1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint128 _reserve0, uint128 _reserve1, uint256 _reserveUsd) = getReserves(); // gas savings
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 balance0Usd = getUsdValue(token0, balance0);
        uint256 balance1Usd = getUsdValue(token1, balance1);

        uint256 amount0 = balance0 - (_reserve0);
        uint256 amount1 = balance1 - (_reserve1);

        bool feeOn = _mintFee(_reserveUsd);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * (amount1)) - (MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            uint256 amountsUsd = getUsdValue(token0, amount0) + getUsdValue(token1, amount1);
            liquidity = (amountsUsd * _totalSupply) / (_reserveUsd);
        }
        require(liquidity > 0, INSUFFICIENT_LIQUIDITY_MINTED());
        _mint(to, liquidity);

        if (feeOn) (,, kLast) = getReserves(); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (,, uint256 _reserveUsd) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserveUsd);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        if (balance0 > 0) {
            amount0 = liquidity * (balance0) / _totalSupply; // using balances ensures pro-rata distribution
        }
        if (balance1 > 0) {
            amount1 = liquidity * (balance1) / _totalSupply; // using balances ensures pro-rata distribution
        }
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        if (feeOn) (,, kLast) = getReserves(); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint256 _reserveUsd) private returns (bool feeOn) {
        address feeTo = IIfaswapFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(_reserveUsd);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * rootK - rootKLast;
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function getUsdValue(address token, uint256 amount) internal view returns (uint256) {}

    function _safeTransfer(address token, address to, uint256 value) private {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), TRANSFER_FAILED());
    }
}
