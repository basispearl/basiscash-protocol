pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import '@openzeppelin/contracts/math/Math.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// USDTBPCSLPTokenCashPool is the master of Sushi. He can make Sushi and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CASH is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract USDTBPCSLPTokenCashPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public DURATION = 5 days;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CASHs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCashPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCashPerShare` (and `lastRewardTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 lastRewardTime;  // Last block timestamp that CASH distribution occurs.
        uint256 accCashPerShare; // Accumulated CASH per share, times 1e12. See below.
    }

    IERC20 public cash;
    address public supplier;

    // Info of the pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP token.
    mapping (address => UserInfo) public userInfo;
    uint256 public starttime;
    uint256 public periodFinish = 0;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        IERC20 _cash,
        address _lpToken,
        uint256 _starttime,
        address _supplier
    ) public {
        cash = _cash;
        starttime = _starttime;
        periodFinish = starttime.add(DURATION);
        supplier = _supplier;

        poolInfo = PoolInfo({
            lpToken: IERC20(_lpToken),
            lastRewardTime: starttime,
            accCashPerShare: 0
        });
    }

    modifier checkStart() {
        require(
            block.timestamp >= starttime,
            'USDTBPCSLPTokenCashPool: not start'
        );
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function totalSupply() public view returns (uint256) {
        uint256 lpSupply = poolInfo.lpToken.balanceOf(address(this));
        return lpSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        UserInfo storage user = userInfo[account];
        return user.amount;
    }

    // View function to see pending CASHs on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accCashPerShare = poolInfo.accCashPerShare;
        uint256 lpSupply = poolInfo.lpToken.balanceOf(address(this));

        if (lastTimeRewardApplicable() > poolInfo.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = lastTimeRewardApplicable().sub(poolInfo.lastRewardTime);
            uint256 remainTime = periodFinish.sub(poolInfo.lastRewardTime);
            uint256 rewardSupply = cash.balanceOf(supplier);
            
            uint256 reward = multiplier.mul(rewardSupply).div(remainTime);
            accCashPerShare = poolInfo.accCashPerShare.add(reward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCashPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        if (lastTimeRewardApplicable() <= poolInfo.lastRewardTime) {
            return;
        }
        uint256 lpSupply = poolInfo.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            poolInfo.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = lastTimeRewardApplicable().sub(poolInfo.lastRewardTime);
        uint256 remainTime = periodFinish.sub(poolInfo.lastRewardTime);
        uint256 rewardSupply = cash.balanceOf(supplier);

        uint256 reward = multiplier.mul(rewardSupply).div(remainTime);
        cash.safeTransferFrom(supplier, address(this), reward);
        poolInfo.accCashPerShare = poolInfo.accCashPerShare.add(reward.mul(1e12).div(lpSupply));
        poolInfo.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to USDTBPCSLPTokenCashPool for CASH allocation.
    function stake(uint256 _amount) public checkStart {
        require(_amount > 0, 'USDTBPCSLPTokenCashPool: Cannot stake 0');
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(poolInfo.accCashPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeCashTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            poolInfo.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(poolInfo.accCashPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens from USDTBPCSLPTokenCashPool.
    function withdraw(uint256 _amount) public checkStart {
        require(_amount > 0, 'USDTBPCSLPTokenCashPool: Cannot withdraw 0');
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();

        uint256 pending = user.amount.mul(poolInfo.accCashPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeCashTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            poolInfo.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(poolInfo.accCashPerShare).div(1e12);
        emit Withdraw(msg.sender, _amount);
    }

    function exit() external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, 'USDTBPCSLPTokenCashPool: No stake');
        withdraw(user.amount);
    }

    function getReward() public checkStart {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, 'USDTBPCSLPTokenCashPool: No stake');

        updatePool();
        uint256 pending = user.amount.mul(poolInfo.accCashPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeCashTransfer(msg.sender, pending);
        }
        user.rewardDebt = user.amount.mul(poolInfo.accCashPerShare).div(1e12);
    }

    function safeCashTransfer(address _to, uint256 _amount) internal {
        uint256 cashBal = cash.balanceOf(address(this));
        if (_amount > cashBal) {
            cash.transfer(_to, cashBal);
        } else {
            cash.transfer(_to, _amount);
        }
    }
}
