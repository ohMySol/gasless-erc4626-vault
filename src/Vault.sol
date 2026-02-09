// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MyVault is ERC4626 {
    using SafeERC20 for IERC20;

    /// @dev The vault fee in basis points
    uint256 public immutable FEE_BPS;
    
    /// @dev The vault fee recipient
    address public immutable FEE_RECIPIENT;

    /// @dev Mapping of user addresses to their shares
    mapping(address => uint256) public userShares;
    
    /// @dev Intiializes the contract
    /// @param _asset The address of the underlying asset
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault 
    /// @param _vaultFee The vault fee in basis points
    constructor(
        address _asset, 
        string memory _name, 
        string memory _symbol,
        uint256 _vaultFee,
        address _feeRecipient
    )
     ERC4626(IERC20(_asset)) 
     ERC20(_name, _symbol) 
    {
        FEE_BPS = _vaultFee;
        FEE_RECIPIENT = _feeRecipient;
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        _afterDeposit(assets); // Take fee after deposit
        
        return shares;
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);
        _afterDeposit(assets); // Take fee after deposit
        
        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _beforeWithdraw(assets, shares); // Take fee before withdrawal
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _beforeWithdraw(assets, shares); // Take fee before withdrawal
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual {
    }

    function _afterDeposit(uint256 assets) internal virtual {
        uint256 fee = assets * FEE_BPS / 10000;
        if (fee > 0) {
            IERC20(asset()).safeTransferFrom(msg.sender, FEE_RECIPIENT, fee);
        }
    }
}