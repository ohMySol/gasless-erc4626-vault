// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IVault {
    /// @notice Vault fee in basis points. Can not be greater than 100%(10_000 BPS).
    function FEE_BPS() external view returns (uint256);
    
    /// @notice Vault fee recipient address. Can not be the zero address.
    function FEE_RECIPIENT() external view returns (address);
    
    /// @notice Deposits assets into the vault, and take a deposit `FEE_BPS` fee from assets, 
    /// and send the fee to `FEE_RECIPIENT` using a permit signature.
    /// @dev The caller must sign a permit signature off chain before calling this function, and provide the signature components.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The address to receive the shares.
    /// @param deadline The deadline for the permit.
    /// @param permitV The v component of the signature.
    /// @param permitR The r component of the signature.
    /// @param permitS The s component of the signature.
    function depositWithPermit(
        uint256 assets, 
        address receiver, 
        uint256 deadline, 
        uint8 permitV, 
        bytes32 permitR, 
        bytes32 permitS
    ) external returns (uint256);
    
    /// @notice Pauses the vault. 
    /// @dev Only the owner can pause the vault.
    function pause() external;

    /// @notice Unpauses the vault.
    /// @dev Only the owner can unpause the vault.
    function unpause() external;
}