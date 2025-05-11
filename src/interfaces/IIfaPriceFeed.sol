// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

interface IIfaPriceFeed {
    enum PairDirection {
        Forward, // asset0/asset1
        Backward // asset1/asset0

    }
    /// @notice Thrown when an invalid asset index is used. i.e  asset does not exist
    /// @param _assetIndex The invalid asset index.

    error InvalidAssetIndex(bytes32 _assetIndex);

    /// @notice Thrown when the length of two asset index arrays are not equal.
    /// @param _assetIndex0 The length of the first asset index array.
    /// @param _assetIndex1 The length of the second asset index array.
    error InvalidAssetIndexLength(uint256 _assetIndex0, uint256 _assetIndex1);

    /// @notice Thrown when the length of asset index arrays and direction array are not equal.
    /// @param _assetIndex0 The length of the first asset index array.
    /// @param _assetIndex1 The length of the second asset index array.
    /// @param _direction The length of the direction array.
    error InvalidAssetorDirectionIndexLength(uint256 _assetIndex0, uint256 _assetIndex1, uint256 _direction);

    /// @notice Thrown when the caller is not the Verifer contract.
    error NotVerifier();
    /// @notice Thrown when the verifier is set to zero address.
    error InvalidVerifier(address _verifier);

    struct PriceFeed {
        int8 decimal;
        uint256 lastUpdateTime;
        uint256 price;
    }

    struct DerviedPair {
        int8 decimal; // DerviedPair is always  MAX_DECIMAL(18)
        uint256 lastUpdateTime; // the  min of  asset0.lastUpdateTime  and asset1.lastUpdateTime
        uint256 derivedPrice;
    }

    event AssetInfoSet(bytes32 indexed _assetIndex, PriceFeed indexed assetInfo);
    event VerifierSet(address indexed _verifier);

    function setAssetInfo(bytes32 _assetIndex, PriceFeed memory assetInfo) external;
    /// @notice Get the price information of an asset
    /// @param _assetIndex The index of the asset
    /// @return assetInfo The price information of the asset

    function getAssetInfo(bytes32 _assetIndex) external view returns (PriceFeed memory assetInfo, bool exist);

    /// @notice Get the price information of multiple assets
    /// @param _assetIndexes The array of asset indexes
    /// @return assetsInfo The price information of the assets & exists to confirm if the price information of the asset exist
    function getAssetsInfo(bytes32[] memory _assetIndexes)
        external
        returns (PriceFeed[] memory assetsInfo, bool[] memory exists);

    /// @notice Retrieves pair information for a given asset pair and direction.
    /// @param _assetIndex0 Index of the first asset.
    /// @param _assetIndex1 Index of the second asset.
    /// @param _direction Direction of the pair (Forward or Backward).
    /// @return pairInfo The derived pair information.
    function getPairbyId(bytes32 _assetIndex0, bytes32 _assetIndex1, PairDirection _direction)
        external
        returns (DerviedPair memory pairInfo);

    /// @notice Retrieves pair information for multiple asset pairs with specified directions.
    /// @param _assetIndexes0 Array of indexes for the first assets in pairs.
    /// @param _assetsIndexes1 Array of indexes for the second assets in pairs.
    /// @param _direction Array of directions for each pair (Forward or Backward).
    /// @return pairsInfo Array of derived pair information.
    function getPairsbyId(
        bytes32[] memory _assetIndexes0,
        bytes32[] memory _assetsIndexes1,
        PairDirection[] memory _direction
    ) external returns (DerviedPair[] memory pairsInfo);

    /// @notice Retrieves pair information for multiple asset pairs in the forward direction.
    /// @param _assetIndexes0 Array of indexes for the first assets in pairs.
    /// @param _assetsIndexes1 Array of indexes for the second assets in pairs.
    /// @return pairsInfo Array of derived pair information.
    function getPairsbyIdForward(bytes32[] memory _assetIndexes0, bytes32[] memory _assetsIndexes1)
        external
        returns (DerviedPair[] memory pairsInfo);

    /// @notice Retrieves pair information for multiple asset pairs in the backward direction.
    /// @param _assetIndexes0 Array of indexes for the first assets in pairs.
    /// @param _assetsIndexes1 Array of indexes for the second assets in pairs.
    /// @return pairsInfo Array of derived pair information.
    function getPairsbyIdBackward(bytes32[] memory _assetIndexes0, bytes32[] memory _assetsIndexes1)
        external
        returns (DerviedPair[] memory pairsInfo);
}
