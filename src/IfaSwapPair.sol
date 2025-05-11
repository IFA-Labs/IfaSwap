//SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "./interfaces/IIfaSwapPair.sol";
import "./interfaces/IIfaSwapFactory.sol";
import {IERC20, IfaSwapERC20} from "src/IfaSwapERC20.sol";
import {Math} from "./libraries/Math.sol";
import "./interfaces/IIfaPriceFeed.sol";

contract IfaSwapPair is IfaSwapERC20 {
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

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    bytes32 public immutable assetId0;
    bytes32 public immutable assetId1;
    IIfaPriceFeed public immutable priceFeed;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant STALENESS_THRESHOLD = 1 hours;
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

    constructor(address _token0, address _token1, bytes32 _assetId0, bytes32 _assetId1, address _priceFeed) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
        assetId0 = _assetId0;
        assetId1 = _assetId1;
        priceFeed = IIfaPriceFeed(_priceFeed);
    }

    function getReserves() public view returns (uint128 _reserve0, uint128 _reserve1, uint256 _reserveUsd) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _reserveUsd = getUsdValue(token0, reserve0) + getUsdValue(token1, reserve1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external lock {
        require(amount0Out > 0 || amount1Out > 0, INSUFFICIENT_OUTPUT_AMOUNT());
        (uint128 _reserve0, uint128 _reserve1, uint256 _reserveUsd) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, INSUFFICIENT_LIQUIDITY());

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, INVALID_TO());
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, INSUFFICIENT_INPUT_AMOUNT());
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * (6));
            uint256 balance1Adjusted = balance1 * (1000) - (amount1In * (6));
            uint256 balance0Usd = getUsdValue(token0, balance0Adjusted);
            uint256 balance1Usd = getUsdValue(token1, balance1Adjusted);
            require(balance0Usd + balance1Usd >= _reserveUsd, INVALID_AFTERSWAPCHEK());
        }

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint128 _reserve0, uint128 _reserve1, uint256 _reserveUsd) = getReserves(); // gas savings
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

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
            amount0 = (liquidity * (balance0)) / _totalSupply; // using balances ensures pro-rata distribution
        }
        if (balance1 > 0) {
            amount1 = (liquidity * (balance1)) / _totalSupply; // using balances ensures pro-rata distribution
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
        address feeTo = IIfaSwapFactory(factory).feeTo();
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

    function getUsdValue(address token, uint256 amount) public view returns (uint256 scaledTokenPrice) {
        bytes32 assetId = (token == token0) ? assetId0 : assetId1;
        (IIfaPriceFeed.PriceFeed memory assetInfo, bool exist) = priceFeed.getAssetInfo(assetId);
        require(exist, DOES_NOT_EXIST());
        require(block.timestamp - assetInfo.lastUpdateTime <= STALENESS_THRESHOLD, PRICE_FEED_STALE());
        require(assetInfo.price > 0, ASSET_NOT_SET());
        uint256 feedDecimalDelta = uint256(18) - uint256(uint8(-assetInfo.decimal));

        if (feedDecimalDelta > 0) {
            scaledTokenPrice = scaledTokenPrice * (10 ** feedDecimalDelta);
        }
        uint256 tokenDecimalDelta = IERC20(token).decimals();

        uint256 decimalDelta = uint256(18) - tokenDecimalDelta;

        if (decimalDelta > 0) {
            scaledTokenPrice = scaledTokenPrice * (10 ** decimalDelta);
        }
        return scaledTokenPrice;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), TRANSFER_FAILED());
    }
}
