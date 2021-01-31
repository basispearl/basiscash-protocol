// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

contract UnmatureCashSupplier is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public cash;

    address public consumer;
    uint256 totalInitialBalance;

    constructor(
        address _cash,
        uint256 _totalInitialBalance
    ) public {
        cash = _cash;
        totalInitialBalance = _totalInitialBalance;
    }

    function setConsumer(address _consumer) external onlyOwner {
        consumer = _consumer;
        IERC20(cash).safeApprove(consumer, totalInitialBalance);
    }
}
