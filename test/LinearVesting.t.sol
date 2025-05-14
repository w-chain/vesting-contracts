// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { LinearVesting } from "../src/LinearVesting.sol";
import { ACM } from "../src/ACM.sol";

contract LinearVestingTest is Test {
    LinearVesting public vesting;
    ACM public acm;

    address public constant ADMIN = address(1);
    address public constant DAO_SIGNER = address(2);
    address public constant UNAUTHORIZED = address(3);

    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant TOTAL_EPOCHS = 10;
    uint256 public constant VESTING_AMOUNT = 10 ether;
    uint256 public constant AMOUNT_PER_EPOCH = VESTING_AMOUNT / TOTAL_EPOCHS;

    event VestingCreated(string name, uint256 epochDuration, uint256 totalEpochs, uint256 startTime, uint256 endTime, uint256 amountPerEpoch);
    event VestingClaimed(uint256 indexed epoch, uint256 amount);
    event VestingCompleted(uint256 indexed epoch, uint256 amount);
    event EmergencyWithdrawal(address indexed signer, uint256 amount);

    function setUp() public {
        // Deploy ACM and set up roles
        acm = new ACM();
        vm.startPrank(acm.DEFAULT_ADMIN());
        acm.addAdmin(ADMIN);
        acm.addDaoSigner(DAO_SIGNER);
        vm.stopPrank();

        // Deploy LinearVesting
        uint256 startTime = block.timestamp;
        vm.deal(address(this), VESTING_AMOUNT);
        vesting = new LinearVesting{
            value: VESTING_AMOUNT
        }(
            address(acm),
            "Test Vesting",
            EPOCH_DURATION,
            TOTAL_EPOCHS,
            startTime
        );
    }

    function test_Constructor() public {
        assertEq(address(vesting.acm()), address(acm));
        assertEq(vesting.name(), "Test Vesting");
        assertEq(vesting.epochDuration(), EPOCH_DURATION);
        assertEq(vesting.totalEpochs(), TOTAL_EPOCHS);
        assertEq(vesting.amountPerEpoch(), AMOUNT_PER_EPOCH);
        assertEq(vesting.lastClaimedEpoch(), 0);
        assertEq(address(vesting).balance, VESTING_AMOUNT);
    }

    function test_GetCurrentEpoch() public {
        // Initial epoch
        assertEq(vesting.getCurrentEpoch(), 0);

        // Middle of vesting
        vm.warp(block.timestamp + (EPOCH_DURATION * 5));
        assertEq(vesting.getCurrentEpoch(), 5);

        // End of vesting
        vm.warp(block.timestamp + (EPOCH_DURATION * 5));
        assertEq(vesting.getCurrentEpoch(), TOTAL_EPOCHS);

        // After vesting ends
        vm.warp(block.timestamp + EPOCH_DURATION);
        assertEq(vesting.getCurrentEpoch(), TOTAL_EPOCHS);
    }

    function test_GetClaimableAmount() public {
        // Initial amount
        assertEq(vesting.getClaimableAmount(), 0);

        // After 5 epochs
        vm.warp(block.timestamp + (EPOCH_DURATION * 5));
        assertEq(vesting.getClaimableAmount(), AMOUNT_PER_EPOCH * 5);

        // Claim 5 epochs
        vm.prank(ADMIN);
        vesting.claim();

        // No immediate claim available
        assertEq(vesting.getClaimableAmount(), 0);

        // After 3 more epochs
        vm.warp(block.timestamp + (EPOCH_DURATION * 3));
        assertEq(vesting.getClaimableAmount(), AMOUNT_PER_EPOCH * 3);
    }

    function test_Claim() public {
        // Advance 5 epochs
        vm.warp(block.timestamp + (EPOCH_DURATION * 5));
        uint256 claimAmount = AMOUNT_PER_EPOCH * 5;

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit VestingClaimed(5, claimAmount);
        vesting.claim();

        assertEq(vesting.lastClaimedEpoch(), 5);
        assertEq(ADMIN.balance, claimAmount);
    }

    function test_ClaimFinal() public {
        // Advance to end of vesting
        vm.warp(block.timestamp + (EPOCH_DURATION * TOTAL_EPOCHS));

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit VestingCompleted(TOTAL_EPOCHS, VESTING_AMOUNT);
        vesting.claim();

        assertEq(vesting.lastClaimedEpoch(), TOTAL_EPOCHS);
        assertEq(ADMIN.balance, VESTING_AMOUNT);
        assertEq(address(vesting).balance, 0);
    }

    function test_RevertClaim_Unauthorized() public {
        vm.warp(block.timestamp + EPOCH_DURATION);
        
        vm.prank(UNAUTHORIZED);
        vm.expectRevert(LinearVesting.Unauthorized.selector);
        vesting.claim();
    }

    function test_RevertClaim_InvalidEpoch() public {
        vm.prank(ADMIN);
        vm.expectRevert(LinearVesting.InvalidEpoch.selector);
        vesting.claim();
    }

    function test_EmergencyWithdraw() public {
        vm.prank(DAO_SIGNER);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(DAO_SIGNER, VESTING_AMOUNT);
        vesting.emergencyWithdraw();

        assertEq(DAO_SIGNER.balance, VESTING_AMOUNT);
        assertEq(address(vesting).balance, 0);
        assertEq(vesting.lastClaimedEpoch(), TOTAL_EPOCHS);
    }

    function test_RevertEmergencyWithdraw_Unauthorized() public {
        vm.prank(UNAUTHORIZED);
        vm.expectRevert(LinearVesting.Unauthorized.selector);
        vesting.emergencyWithdraw();
    }

    function test_RevertEmergencyWithdraw_NoBalance() public {
        // First withdraw all funds
        vm.prank(DAO_SIGNER);
        vesting.emergencyWithdraw();

        // Try to withdraw again
        vm.prank(DAO_SIGNER);
        vm.expectRevert(LinearVesting.InvalidParams.selector);
        vesting.emergencyWithdraw();
    }
}