pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IDistributor.sol';
import '../interfaces/IRewardDistributionRecipient.sol';

contract InitialShareDistributor is IDistributor {
    using SafeMath for uint256;

    event Distributed(address pool, uint256 cashAmount);

    bool public once = true;

    IERC20 public share;
    IRewardDistributionRecipient public daibacLPPool;
    uint256 public daibacInitialBalance;
    IRewardDistributionRecipient public daibasLPPool;
    uint256 public daibasInitialBalance;
    IRewardDistributionRecipient public basPool;
    uint256 public basInitialBalance;

    constructor(
        IERC20 _share,
        IRewardDistributionRecipient _daibacLPPool,
        uint256 _daibacInitialBalance,
        IRewardDistributionRecipient _daibasLPPool,
        uint256 _daibasInitialBalance,
        IRewardDistributionRecipient _basPool,
        uint256 _basInitialBalance
    ) public {
        share = _share;
        daibacLPPool = _daibacLPPool;
        daibacInitialBalance = _daibacInitialBalance;
        daibasLPPool = _daibasLPPool;
        daibasInitialBalance = _daibasInitialBalance;
        basPool = _basPool;
        basInitialBalance = _basInitialBalance;
    }

    function distribute() public override {
        require(
            once,
            'InitialShareDistributor: you cannot run this function twice'
        );

        share.transfer(address(daibacLPPool), daibacInitialBalance);
        daibacLPPool.notifyRewardAmount(daibacInitialBalance);
        emit Distributed(address(daibacLPPool), daibacInitialBalance);

        share.transfer(address(daibasLPPool), daibasInitialBalance);
        daibasLPPool.notifyRewardAmount(daibasInitialBalance);
        emit Distributed(address(daibasLPPool), daibasInitialBalance);

        share.transfer(address(basPool), basInitialBalance);
        basPool.notifyRewardAmount(basInitialBalance);
        emit Distributed(address(basPool), basInitialBalance);

        once = false;
    }
}
