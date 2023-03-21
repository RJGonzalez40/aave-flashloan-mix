// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFlashLoanReceiverV2 } from './../../../interfaces/v2/IFlashLoanReceiverV2.sol';
import { ILendingPoolAddressesProviderV2 } from './../../../interfaces/v2/ILendingPoolAddressesProviderV2.sol';
import { ILendingPoolV2 } from './../../../interfaces/v2/ILendingPoolV2.sol';
import "../../utils/Withdrawable.sol";

/** 
    !!!
    Never keep funds permanently on your FlashLoanReceiverBase contract as they could be 
    exposed to a 'griefing' attack, where the stored funds are used by an attacker.
    !!!
 */
abstract contract FlashLoanReceiverBaseV2 is IFlashLoanReceiverV2 {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPoolAddressesProviderV2 public immutable override ADDRESSES_PROVIDER;
  ILendingPoolV2 public immutable override LENDING_POOL;

  constructor(address provider) {
    ADDRESSES_PROVIDER = ILendingPoolAddressesProviderV2(provider);
    LENDING_POOL = ILendingPoolV2(ILendingPoolAddressesProviderV2(provider).getLendingPool());
  }

  receive() external payable {}

  /**
   * @dev This function must be called only be the LENDING_POOL and takes care of repaying
   * active debt positions, migrating collateral and incurring new V2 debt token debt.
   *
   * @param assets The array of flash loaned assets used to repay debts.
   * @param amounts The array of flash loaned asset amounts used to repay debts.
   * @param premiums The array of premiums incurred as additional debts.
   * @param initiator The address that initiated the flash loan, unused.
   * @param params The byte array containing, in this case, the arrays of aTokens and aTokenAmounts.
   */
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  )
    external
    override
    returns (bool)
  {

    //
    // This contract now has the funds requested.
    // Your logic goes here.
    //

    // At the end of your logic above, this contract owes
    // the flashloaned amounts + premiums.
    // Therefore ensure your contract has enough to repay
    // these amounts.

    // Approve the LendingPool contract allowance to *pull* the owed amount
    for (uint256 i = 0; i < assets.length; i++) {
      uint256 amountOwing = amounts[i].add(premiums[i]);
      IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
    }

    return true;
  }
}

contract FlashloanV2 is FlashLoanReceiverBaseV2, Withdrawable {

  constructor(address _addressProvider) FlashLoanReceiverBaseV2(_addressProvider) {}

  function _flashloan(address[] memory assets, uint256[] memory amounts) internal {
        address receiverAddress = address(this);

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        uint256[] memory modes = new uint256[](assets.length);

        // 0 = no debt (flash), 1 = stable, 2 = variable
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0;
        }

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    /*
     *  Flash multiple assets 
     */
    function flashloan(address[] memory assets, uint256[] memory amounts) public onlyOwner {
        _flashloan(assets, amounts);
    }

    /*
     *  Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan(address _asset) public onlyOwner {
        bytes memory data = "";
        uint256 amount = 1 ether;

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        _flashloan(assets, amounts);
    }
}
