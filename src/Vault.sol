// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626,ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

contract Vault is ERC4626, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @dev The vault fee in basis points
    uint256 public immutable FEE_BPS;
    
    /// @dev The vault fee recipient
    address public immutable FEE_RECIPIENT;
    
    /// @dev Intiializes the contract
    /// @param _asset The address of the underlying asset
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault 
    /// @param _vaultFee The vault fee in basis points
    /// @param _feeRecipient The address of the fee recipient
    constructor(
        address _asset, 
        string memory _name, 
        string memory _symbol,
        uint256 _vaultFee,
        address _feeRecipient
    )
     ERC4626(IERC20(_asset)) 
     ERC20(_name, _symbol)
     Ownable(msg.sender)
     {
        FEE_BPS = _vaultFee;
        FEE_RECIPIENT = _feeRecipient;
    }
    /// @inheritdoc IERC4626
    /// @dev Calculates the amount of shares for a given amount of assets - `FEE_BPS` entry fee.
    /// @return The amount of shares the user will receive after the fee is taken.
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        uint256 fee = _fee(assets);
        return super.previewDeposit(assets - fee);
    }

    /// @inheritdoc IERC4626
    /// @dev Calculates the amount of assets needed to mint a given amount of shares, including the `FEE_BPS` entry fee.
    /// @return The amount of assets(including fee) the user must send to mint the requested shares.
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        // Calculate net assets needed (without fee) to mint the requested shares
        uint256 netAssets = super.previewMint(shares);

        uint256 denominator = 10000 - FEE_BPS;
        if (denominator == 0) revert ErrorsLib.InvalidFeeBPS(); // Fee must be < 100%
        // Gross up to include the fee
        uint256 assetsGross = (netAssets * 10000 + denominator - 1) / denominator;
        return assetsGross;
    }

    /// @inheritdoc IERC4626
    /// @dev Deposits assets into the vault, and take a deposit `FEE_BPS` fee and send it to `FEE_RECIPIENT`.
    /// @return The amount of shares the user will receive (after fee).
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 fee = _fee(assets);
        if (fee > 0) {
            IERC20(asset()).safeTransferFrom(msg.sender, FEE_RECIPIENT, fee);
        }
        
        uint256 shares = previewDeposit(assets);
        super._deposit(_msgSender(), receiver, assets - fee, shares);
        
        return shares;
    }

    /// @dev Mints shares to `receiver` by taking the required assets (including fee) from the caller.
    /// @return The amount of assets (gross) the user must send.
    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }
        
        uint256 assetsGross = previewMint(shares);
        uint256 fee = _fee(assetsGross);
        if (fee > 0) {
            IERC20(asset()).safeTransferFrom(msg.sender, FEE_RECIPIENT, fee);
        }
        
        super._deposit(_msgSender(), receiver, assetsGross - fee, shares);
        
        return assetsGross;
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /// @notice Calculates the fee for a given amount of assets.
    /// @param assets The amount of assets to calculate the fee for.
    /// @return The fee amount.
    function _fee(uint256 assets) internal view returns (uint256) {
        return (assets * FEE_BPS) / 10000;
    }
}