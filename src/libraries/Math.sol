//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function convertToUint(int64 price, int32 expo, uint8 targetDecimals) public pure returns (uint256) {
        if (price < 0 || expo > 0 || expo < -255) {
            revert();
        }

        uint8 priceDecimals = uint8(uint32(-1 * expo));

        if (targetDecimals >= priceDecimals) {
            return uint256(uint64(price)) * 10 ** uint32(targetDecimals - priceDecimals);
        } else {
            return uint256(uint64(price)) / 10 ** uint32(priceDecimals - targetDecimals);
        }
    }
}
