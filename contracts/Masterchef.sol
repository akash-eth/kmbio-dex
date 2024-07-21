// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BombToken.sol";

// MasterChef is the master of Bomb. He can make Bomb and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Bomb is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Bombs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accBombPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBombPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Bombs to distribute per block.
        uint256 lastRewardBlock; // Last block number that Bombs distribution occurs.
        uint256 accBombPerShare; // Accumulated Bombs per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
    }

    // The Bomb TOKEN!
    BombToken public Bomb;
    // Dev address.
    address public devaddr;
    // Bomb tokens created per block.
    uint256 public BombPerBlock; // 0.03 bomb
    // Bonus muliplier for early Bomb makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Check if lpToken pool exist or not
    mapping(IERC20 => bool) public isPoolExist;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Bomb mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        BombToken _bomb,
        address _devaddr,
        address _feeAddress,
        uint256 _bombPerBlock,
        uint256 _startBlock
    ) {
        Bomb = _bomb;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        BombPerBlock = _bombPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(
            PoolInfo({
                lpToken: _bomb,
                allocPoint: 1000,
                lastRewardBlock: startBlock,
                accBombPerShare: 0,
                depositFeeBP: 500
            })
        );

        totalAllocPoint = 1000;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(!isPoolExist[_lpToken], "Pool already exist");
        require(_depositFeeBP <= 500, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        isPoolExist[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accBombPerShare: 0,
                depositFeeBP: _depositFeeBP
            })
        );
        updateStakingPool();
    }

    // Update the given pool's Bomb allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(_depositFeeBP <= 500, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(
                _allocPoint
            );
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(
                points
            );
            poolInfo[0].allocPoint = points;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending Bombs on frontend.
    function pendingBomb(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBombPerShare = pool.accBombPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 BombReward = multiplier
                .mul(BombPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accBombPerShare = accBombPerShare.add(
                BombReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accBombPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 BombReward = multiplier
            .mul(BombPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        Bomb.mint(devaddr, BombReward.div(10));
        Bomb.mint(address(this), BombReward);
        pool.accBombPerShare = pool.accBombPerShare.add(
            BombReward.mul(1e12).div(lpSupply)
        );

        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for Bomb allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        // require(_pid != 0, "deposit Bomb by staking");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accBombPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeBombTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);

                pool.lpToken.safeTransfer(feeAddress, depositFee);

                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accBombPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        // require(_pid != 0, "withdraw Bomb by unstaking");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accBombPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeBombTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBombPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // // Stake Bomb tokens to MasterChef
    // function enterStaking(uint256 _amount) public {
    //     PoolInfo storage pool = poolInfo[0];
    //     UserInfo storage user = userInfo[0][msg.sender];
    //     updatePool(0);
    //     if (user.amount > 0) {
    //         uint256 pending = user
    //             .amount
    //             .mul(pool.accBombPerShare)
    //             .div(1e12)
    //             .sub(user.rewardDebt);
    //         if (pending > 0) {
    //             safeBombTransfer(msg.sender, pending);
    //         }
    //     }
    //     if (_amount > 0) {
    //         pool.lpToken.safeTransferFrom(
    //             address(msg.sender),
    //             address(this),
    //             _amount
    //         );
    //             user.amount = user.amount.add(_amount);
            
    //     }
    //     user.rewardDebt = user.amount.mul(pool.accBombPerShare).div(1e12);
    //     // syrup.mint(msg.sender, _amount);

    //     emit Deposit(msg.sender, 0, _amount);
    // }

    // // Withdraw Bomb tokens from STAKING.
    // function leaveStaking(uint256 _amount) public {
    //     PoolInfo storage pool = poolInfo[0];
    //     UserInfo storage user = userInfo[0][msg.sender];
    //     require(user.amount >= _amount, "withdraw: not good");
    //     updatePool(0);
    //     uint256 pending = user.amount.mul(pool.accBombPerShare).div(1e12).sub(
    //         user.rewardDebt
    //     );
    //     if (pending > 0) {
    //         safeBombTransfer(msg.sender, pending);
    //     }
    //     if (_amount > 0) {
    //         user.amount = user.amount.sub(_amount);
    //         pool.lpToken.safeTransfer(address(msg.sender), _amount);
    //     }
    //     user.rewardDebt = user.amount.mul(pool.accBombPerShare).div(1e12);
    //     // syrup.burn(msg.sender, _amount);
    //     emit Withdraw(msg.sender, 0, _amount);
    // }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe Bomb transfer function, just in case if rounding error causes pool to not have enough Bombs.
    function safeBombTransfer(address _to, uint256 _amount) internal {
        uint256 BombBal = Bomb.balanceOf(address(this));
        if (_amount > BombBal) {
            Bomb.transfer(_to, BombBal);
        } else {
            Bomb.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    function updateEmissionRate(uint256 _bombPerBlock) public onlyOwner {
        massUpdatePools();
        BombPerBlock = _bombPerBlock;
    }
}