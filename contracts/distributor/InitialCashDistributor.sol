pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IDistributor.sol';
import '../interfaces/IRewardDistributionRecipient.sol';

contract InitialCashDistributor is IDistributor {
    using SafeMath for uint256;

    event Distributed(address pool, uint256 cashAmount);

    bool public once = true;

    IERC20 public cash;
    IRewardDistributionRecipient[] public pools;
    uint256[] public weights;
    uint256 public totalWeight;
    uint256 public totalInitialBalance;

    constructor(
        IERC20 _cash,
        IRewardDistributionRecipient[] memory _pools,
        uint256[] memory _weights,
        uint256 _totalWeight,
        uint256 _totalInitialBalance
    ) public {
        require(_pools.length != 0, 'a list of BAC pools are required');

        cash = _cash;
        pools = _pools;
        weights = _weights;
        totalWeight = _totalWeight;
        totalInitialBalance = _totalInitialBalance;
    }

    function distribute() public override {
        require(
            once,
            'InitialCashDistributor: you cannot run this function twice'
        );

        for (uint256 i = 0; i < pools.length; i++) {
            uint256 amount = totalInitialBalance.mul(weights[i]).div(totalWeight);

            cash.transfer(address(pools[i]), amount);
            pools[i].notifyRewardAmount(amount);

            emit Distributed(address(pools[i]), amount);
        }

        once = false;
    }
}
