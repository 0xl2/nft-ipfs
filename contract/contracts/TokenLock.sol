// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenLockInterest is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Lock {
        uint256 amount;
        uint256 startTime;
        bool unlocked;
    }

    bytes32[] private _lockIds; // Lock IDs
    mapping(bytes32 => Lock) private _locks; // Lock per ID
    mapping(address => mapping(address => bytes32[])) private _userLocks; // User Lock IDs per token
    mapping(address => mapping(address => uint256)) private _userTokenBalances; // User balances per token
    uint256 private immutable _timeLockPeriod; // Timelock period = 1 month
    uint256 private immutable _interestPercent; // 2%

    event Deposited(
        address indexed account,
        address indexed token,
        uint256 amount
    );
    event Locked(
        address indexed account,
        address indexed token,
        uint256 amount,
        bytes32 lockId
    );
    event Withdrawn(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    constructor(uint256 interestPercent_) {
        _interestPercent = interestPercent_;
        _timeLockPeriod = block.timestamp + 5 minutes;
    }

    receive() external payable {}

    function _getNextLockId(address account_, address tokenAddress_)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account_, tokenAddress_));
    }

    function _isContract(address tokenAddress_) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(tokenAddress_)
        }
        return (size > 0);
    }

    function _updateLocks(address account_, address tokenAddress_) internal {
        uint256 length = _userLocks[msg.sender][tokenAddress_].length;
        for (uint256 i; i < length; i++) {
            bytes32 lockId = _userLocks[msg.sender][tokenAddress_][i];
            Lock memory mLock = _locks[lockId];
            if (mLock.unlocked) continue;
            if (mLock.startTime + _timeLockPeriod >= block.timestamp) {
                Lock storage sLock = _locks[lockId];
                _userTokenBalances[account_][tokenAddress_] += sLock.amount;
                _userTokenBalances[account_][tokenAddress_] +=
                    (sLock.amount / 100) *
                    _interestPercent;
                sLock.amount = 0;
                sLock.unlocked = true;
            }
        }
    }

    function deposit(address tokenAddress_, uint256 amount_)
        external
        nonReentrant
    {
        require(tokenAddress_ != address(0), "TLI: Zero address");
        _userTokenBalances[msg.sender][tokenAddress_] += amount_;
        IERC20(tokenAddress_).safeTransferFrom(
            msg.sender,
            address(this),
            amount_
        );
        emit Deposited(msg.sender, tokenAddress_, amount_);
    }

    function lock(address tokenAddress_, uint256 amount_)
        external
        nonReentrant
    {
        require(tokenAddress_ != address(0), "TLI: Zero address");
        require(amount_ > 0, "TLI: Invalid amount");
        require(
            _userTokenBalances[msg.sender][tokenAddress_] >= amount_,
            "TLI: Insufficient amount"
        );
        _userTokenBalances[msg.sender][tokenAddress_] -= amount_;
        bytes32 lockId = _getNextLockId(msg.sender, tokenAddress_);
        _lockIds.push(lockId);
        _userLocks[msg.sender][tokenAddress_].push(lockId);
        _locks[lockId] = Lock(amount_, block.timestamp, false);
        emit Locked(msg.sender, tokenAddress_, amount_, lockId);
    }

    function withdraw(address tokenAddress_, uint256 amount_)
        external
        nonReentrant
    {
        require(tokenAddress_ != address(0), "TLI: Zero address");
        require(
            IERC20(tokenAddress_).balanceOf(address(this)) >= amount_,
            "TLI: Insufficient amount"
        );
        _updateLocks(msg.sender, tokenAddress_);
        require(
            _userTokenBalances[msg.sender][tokenAddress_] > 0,
            "TLI: Nothing to withdraw"
        );
        require(
            amount_ <= _userTokenBalances[msg.sender][tokenAddress_],
            "TLI: Insufficient amount"
        );
        _userTokenBalances[msg.sender][tokenAddress_] -= amount_;
        IERC20(tokenAddress_).safeTransfer(msg.sender, amount_);
        emit Withdrawn(msg.sender, tokenAddress_, amount_);
    }

    function withdrawAll(address tokenAddress_) external nonReentrant {
        require(tokenAddress_ != address(0), "TLI: Zero address");
        _updateLocks(msg.sender, tokenAddress_);
        require(
            _userTokenBalances[msg.sender][tokenAddress_] > 0,
            "TLI: Nothing to withdraw"
        );
        uint256 all = _userTokenBalances[msg.sender][tokenAddress_];
        _userTokenBalances[msg.sender][tokenAddress_] = 0;
        IERC20(tokenAddress_).safeTransfer(msg.sender, all);
        emit Withdrawn(msg.sender, tokenAddress_, all);
    }

    function getLock(address tokenAddress_, bytes32 lockId_)
        public
        returns (Lock memory)
    {
        require(
            msg.sender != address(0) && tokenAddress_ != address(0),
            "TLI: Zero address"
        );
        _updateLocks(msg.sender, tokenAddress_);
        return _locks[lockId_];
    }

    function getLockRemainingTime(address tokenAddress_, bytes32 lockId_)
        public
        returns (uint256)
    {
        require(
            msg.sender != address(0) && tokenAddress_ != address(0),
            "TLI: Zero address"
        );
        _updateLocks(msg.sender, tokenAddress_);
        Lock memory mLock = _locks[lockId_];
        if (mLock.unlocked) return 0;
        return block.timestamp - mLock.startTime + _timeLockPeriod;
    }

    function getWithdrawableAmount(address tokenAddress_)
        public
        returns (uint256)
    {
        require(
            msg.sender != address(0) && tokenAddress_ != address(0),
            "TLI: Zero address"
        );
        _updateLocks(msg.sender, tokenAddress_);
        return _userTokenBalances[msg.sender][tokenAddress_];
    }
}