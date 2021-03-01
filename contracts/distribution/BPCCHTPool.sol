pragma solidity ^0.6.0;
/**
 *Submitted for verification at Etherscan.io on 2020-07-17
 */

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: BASISCASHRewards.sol
*
* Docs: https://docs.synthetix.io/
*
*
* MIT License
* ===========
*
* Copyright (c) 2020 Synthetix
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

// File: @openzeppelin/contracts/math/Math.sol

import '@openzeppelin/contracts/math/Math.sol';

// File: @openzeppelin/contracts/math/SafeMath.sol

import '@openzeppelin/contracts/math/SafeMath.sol';

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// File: @openzeppelin/contracts/utils/Address.sol

import '@openzeppelin/contracts/utils/Address.sol';

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

// File: contracts/IRewardDistributionRecipient.sol

import '../interfaces/IRewardDistributionRecipient.sol';

contract HTWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public payable virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
    }

    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        address payable to = msg.sender;
        to.transfer(amount);
    }
}

contract BPCCHTPool is HTWrapper, IRewardDistributionRecipient {
    IERC20 public basisCash;
    uint256 public DURATION = 5 days;
    uint256 public MATURE_DURATION = 3 days;
    uint256 public MATURE_MAX = 10000; // 100%
    uint256 public MATURE_MIN = 100; // 1%

    uint256 public starttime;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public userLastGetRewardTime;
    mapping(address => uint8) public depositFlag;

    address public devaddr;
    address public unmatureCashSupplier1;
    address public unmatureCashSupplier2;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address basisCash_,
        uint256 starttime_,
        address devaddr_,
        address unmatureCashSupplier1_,
        address unmatureCashSupplier2_
    ) public {
        basisCash = IERC20(basisCash_);
        starttime = starttime_;
        devaddr = devaddr_;
        unmatureCashSupplier1 = unmatureCashSupplier1_;
        unmatureCashSupplier2 = unmatureCashSupplier2_;
    }

    modifier checkStart() {
        require(block.timestamp >= starttime, 'BPCCHTPool: not start');
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake()
        public
        payable
        updateReward(msg.sender)
        checkStart
    {
        uint256 amount = msg.value;
        require(amount > 0, 'BPCCHTPool: Cannot stake 0');
        uint256 newDeposit = deposits[msg.sender].add(amount);
        // require(
        //     newDeposit <= 20000e18,
        //     'BPCCHTPool: deposit amount exceeds maximum 20000'
        // );
        deposits[msg.sender] = newDeposit;
        super.stake(amount);

        if (depositFlag[msg.sender] == 0) {
            userLastGetRewardTime[msg.sender] = block.timestamp;
            depositFlag[msg.sender] = 1;
        }

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkStart
    {
        require(amount > 0, 'BPCCHTPool: Cannot withdraw 0');
        deposits[msg.sender] = deposits[msg.sender].sub(amount);
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getMatureRate(address account) public view returns (uint256) {
        uint256 matureRate = 0;

        if (depositFlag[account] == 0) {
            return matureRate; // 0
        }

        if (block.timestamp < starttime) {
            matureRate = 0;
        } else {
            uint256 start = Math.max(starttime, userLastGetRewardTime[account]);
            uint256 elapse = block.timestamp.sub(start);
            matureRate = elapse.mul(MATURE_MAX).div(MATURE_DURATION);
            if (matureRate < MATURE_MIN) {
                matureRate = MATURE_MIN;
            } else if (matureRate > MATURE_MAX) {
                matureRate = MATURE_MAX;
            }
        }

        return matureRate;
    }

    function getReward() public updateReward(msg.sender) checkStart {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            uint256 matureRate = getMatureRate(msg.sender);
            if (matureRate > 0) {
                uint256 matureReward = reward.mul(matureRate).div(MATURE_MAX);
                basisCash.safeTransfer(msg.sender, matureReward);
                uint256 unmatureReward = reward.sub(matureReward);
                uint256 devReward = unmatureReward.mul(5).div(100);
                basisCash.safeTransfer(devaddr, devReward);
                uint256 remain = unmatureReward.sub(devReward);
                uint256 remain1 = remain.div(2);
                basisCash.safeTransfer(unmatureCashSupplier1, remain1);
                uint256 remain2 = remain.sub(remain1);
                basisCash.safeTransfer(unmatureCashSupplier2, remain2);
            }
            
            userLastGetRewardTime[msg.sender] = block.timestamp;
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward)
        external
        override
        onlyRewardDistribution
        updateReward(address(0))
    {
        if (block.timestamp > starttime) {
            if (block.timestamp >= periodFinish) {
                rewardRate = reward.div(DURATION);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                rewardRate = reward.add(leftover).div(DURATION);
            }
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp.add(DURATION);
            emit RewardAdded(reward);
        } else {
            rewardRate = reward.div(DURATION);
            lastUpdateTime = starttime;
            periodFinish = starttime.add(DURATION);
            emit RewardAdded(reward);
        }
    }
}