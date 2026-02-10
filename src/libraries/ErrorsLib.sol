// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ErrorsLib
/// @notice Library of errors for the Vault contract
library ErrorsLib {
    /// @notice Thrown when the fee BPS is too high
    error InvalidFeeBPS();
}