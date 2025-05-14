// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IACM } from "./interfaces/IACM.sol";

contract LinearVesting {
    IACM public immutable acm;
    string public name;
    uint256 public immutable epochDuration;
    uint256 public immutable totalEpochs;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable amountPerEpoch;
    uint256 public lastClaimedEpoch;

    error ZeroAddress();
    error Unauthorized();
    error InvalidParams();
    error InvalidEpoch();
    error ClaimableAmountZero();
    error FailedTransfer();

    event VestingCreated(string name, uint256 epochDuration, uint256 totalEpochs, uint256 startTime, uint256 endTime, uint256 amountPerEpoch);
    event VestingClaimed(uint256 indexed epoch, uint256 amount);
    event VestingCompleted(uint256 indexed epoch, uint256 amount);
    event EmergencyWithdrawal(address indexed signer, uint256 amount);

    modifier onlyClaimer() {
        if (!acm.verifyAdmin(msg.sender)) revert Unauthorized();
        _;
    }

    modifier onlyDaoSigner() {
        if (!acm.verifyDaoSigner(msg.sender)) revert Unauthorized();
        _;
    }

    constructor(
        address _acm,
        string memory _name,
        uint256 _epochDuration,
        uint256 _totalEpochs,
        uint256 _startTime
    ) payable {
        if (_acm == address(0)) revert ZeroAddress();
        if (_epochDuration == 0 || _totalEpochs == 0 || msg.value == 0) revert InvalidParams();

        acm = IACM(_acm);
        name = _name;
        epochDuration = _epochDuration;
        totalEpochs = _totalEpochs;
        startTime = _startTime;
        endTime = startTime + (_epochDuration * _totalEpochs);
        amountPerEpoch = msg.value / _totalEpochs;
        lastClaimedEpoch = 0;
        emit VestingCreated(_name, _epochDuration, _totalEpochs, _startTime, endTime, amountPerEpoch);
    }

    function getCurrentEpoch() public view returns (uint256) {
        if (block.timestamp >= endTime) return totalEpochs;
        return (block.timestamp - startTime) / epochDuration;
    }

    function getClaimableAmount() public view returns (uint256) {
        uint256 currentEpoch = getCurrentEpoch();
        if (currentEpoch <= lastClaimedEpoch) return 0;
        return (currentEpoch - lastClaimedEpoch) * amountPerEpoch;
    }

    function claim() external onlyClaimer {
        uint256 currentEpoch = getCurrentEpoch();
        if (currentEpoch <= lastClaimedEpoch) revert InvalidEpoch();
        
        bool success;
        if (currentEpoch == totalEpochs) {
            uint256 remainingAmount = address(this).balance;
            (success, ) = msg.sender.call{value: remainingAmount}("");
            if (!success) revert FailedTransfer();
            lastClaimedEpoch = currentEpoch;
            emit VestingCompleted(currentEpoch, remainingAmount);
        } else {
            uint256 claimableAmount = (currentEpoch - lastClaimedEpoch) * amountPerEpoch;
            if (claimableAmount == 0) revert ClaimableAmountZero();
            (success, ) = msg.sender.call{value: claimableAmount}("");
            if (!success) revert FailedTransfer();
            lastClaimedEpoch = currentEpoch;
            emit VestingClaimed(currentEpoch, claimableAmount);
        }
    }

    function emergencyWithdraw() external onlyDaoSigner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidParams();
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) revert FailedTransfer();
        lastClaimedEpoch = totalEpochs;
        emit EmergencyWithdrawal(msg.sender, balance);
    }
}