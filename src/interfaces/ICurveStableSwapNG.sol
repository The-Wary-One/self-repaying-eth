// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

/// @dev Solidity Curve StableSwapNG Pool interface because it is written in vyper.
interface ICurveStableSwapNG {
    /// @notice Function to calculate the predicted input amount `i` to receive dy of coin `j` at the pool's current state.
    /// @param i Index value of input coin.
    /// @param j Index value of output coin.
    /// @param dy Amount of output coin received.
    /// @return Predicted input amount of `i`.
    function get_dx(int128 i, int128 j, uint256 dy) external view returns (uint256);

    /// @notice Function to exchange `_dx` amount of coin `i` for coin `j`, receiving a minimum amount of `_min_dy`. This is done without actually transferring the coins into the pool within the same call. The exchange is based on the change in the balance of coin `i`, eliminating the need to grant approval to the contract.
    /// @dev A detailed article can be found here: https://blog.curvemonitor.com/posts/exchange-received/.
    ///
    /// @param i Index value of input coin.
    /// @param j Index value of output coin.
    /// @param _dx Amount of coin `i` being exchanged.
    /// @param _min_dy Minimum amount of coin `j` to receive.
    /// @return Amount of output coin received.
    function exchange_received(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external returns (uint256);

    /// @notice Function to add liquidity into the pool and mint a minimum of _min_mint_amount of the corresponding LP tokens to _receiver.
    /// @return Amount of LP tokens received.
    function add_liquidity(uint256[] calldata _amounts, uint256 _min_amount) external returns (uint256);
}
