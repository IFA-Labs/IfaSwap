// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/interfaces/IIfaPriceFeed.sol";
// Mock Price Feed for testing

contract MockPriceFeed is IIfaPriceFeed {
    mapping(bytes32 => PriceFeed) public assetInfo;
    mapping(bytes32 => bool) public assetExists;
    address public verifier;

    constructor() {
        verifier = msg.sender;
    }

    function setAssetInfo(bytes32 _assetIndex, PriceFeed memory _assetInfo) external override {
        if (msg.sender != verifier) revert NotVerifier();
        assetInfo[_assetIndex] = _assetInfo;
        assetExists[_assetIndex] = true;
        emit AssetInfoSet(_assetIndex, _assetInfo);
    }

    function getAssetInfo(bytes32 _assetIndex) external view override returns (PriceFeed memory, bool) {
        return (assetInfo[_assetIndex], assetExists[_assetIndex]);
    }

    function getAssetsInfo(bytes32[] memory _assetIndexes)
        external
        view
        override
        returns (PriceFeed[] memory assetsInfo, bool[] memory exists)
    {
        assetsInfo = new PriceFeed[](_assetIndexes.length);
        exists = new bool[](_assetIndexes.length);

        for (uint256 i = 0; i < _assetIndexes.length; i++) {
            assetsInfo[i] = assetInfo[_assetIndexes[i]];
            exists[i] = assetExists[_assetIndexes[i]];
        }
    }

    function getPairbyId(bytes32 _assetIndex0, bytes32 _assetIndex1, PairDirection _direction)
        external
        view
        override
        returns (DerviedPair memory pairInfo)
    {
        PriceFeed memory asset0 = assetInfo[_assetIndex0];
        PriceFeed memory asset1 = assetInfo[_assetIndex1];

        if (!assetExists[_assetIndex0] || !assetExists[_assetIndex1]) {
            revert InvalidAssetIndex(_assetIndex0);
        }

        uint256 lastUpdateTime =
            asset0.lastUpdateTime < asset1.lastUpdateTime ? asset0.lastUpdateTime : asset1.lastUpdateTime;

        uint256 derivedPrice;
        if (_direction == PairDirection.Forward) {
            // Calculate price ratio, adjust for decimals
            // This is simplified - in a real implementation, we would need to handle decimal scaling properly
            if (asset0.price > 0 && asset1.price > 0) {
                derivedPrice = uint256(asset0.price * 10 ** 30 / asset1.price);
            }
        } else {
            if (asset0.price > 0 && asset1.price > 0) {
                derivedPrice = uint256(asset1.price * 10 ** 30 / asset0.price);
            }
        }

        return DerviedPair({
            decimal: -30, // Always -30 as per the contract spec
            lastUpdateTime: lastUpdateTime,
            derivedPrice: derivedPrice
        });
    }

    function getPairsbyId(
        bytes32[] memory _assetIndexes0,
        bytes32[] memory _assetsIndexes1,
        PairDirection[] memory _direction
    ) external view override returns (DerviedPair[] memory) {
        if (_assetIndexes0.length != _assetsIndexes1.length) {
            revert InvalidAssetIndexLength(_assetIndexes0.length, _assetsIndexes1.length);
        }
        if (_assetIndexes0.length != _direction.length) {
            revert InvalidAssetorDirectionIndexLength(_assetIndexes0.length, _assetsIndexes1.length, _direction.length);
        }

        DerviedPair[] memory pairs = new DerviedPair[](_assetIndexes0.length);

        for (uint256 i = 0; i < _assetIndexes0.length; i++) {
            pairs[i] = this.getPairbyId(_assetIndexes0[i], _assetsIndexes1[i], _direction[i]);
        }

        return pairs;
    }

    function getPairsbyIdForward(bytes32[] memory _assetIndexes0, bytes32[] memory _assetsIndexes1)
        external
        view
        override
        returns (DerviedPair[] memory)
    {
        if (_assetIndexes0.length != _assetsIndexes1.length) {
            revert InvalidAssetIndexLength(_assetIndexes0.length, _assetsIndexes1.length);
        }

        DerviedPair[] memory pairs = new DerviedPair[](_assetIndexes0.length);

        for (uint256 i = 0; i < _assetIndexes0.length; i++) {
            pairs[i] = this.getPairbyId(_assetIndexes0[i], _assetsIndexes1[i], PairDirection.Forward);
        }

        return pairs;
    }

    function getPairsbyIdBackward(bytes32[] memory _assetIndexes0, bytes32[] memory _assetsIndexes1)
        external
        view
        override
        returns (DerviedPair[] memory)
    {
        if (_assetIndexes0.length != _assetsIndexes1.length) {
            revert InvalidAssetIndexLength(_assetIndexes0.length, _assetsIndexes1.length);
        }

        DerviedPair[] memory pairs = new DerviedPair[](_assetIndexes0.length);

        for (uint256 i = 0; i < _assetIndexes0.length; i++) {
            pairs[i] = this.getPairbyId(_assetIndexes0[i], _assetsIndexes1[i], PairDirection.Backward);
        }

        return pairs;
    }
}
