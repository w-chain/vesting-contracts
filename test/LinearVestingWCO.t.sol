// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { LinearVesting } from "../src/LinearVestingWCO.sol";
import { ACM } from "../src/ACM.sol";

contract LinearVestingWCOTest is Test {
    LinearVesting public vesting;
    ACM public acm;

    address public constant ADMIN = address(1);
    address public constant DAO_SIGNER = address(2);
    address public constant UNAUTHORIZED = address(3);
    address public constant FUNDER = address(4);

    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant TOTAL_EPOCHS = 10;
    uint256 public constant VESTING_AMOUNT = 10 ether;
    uint256 public constant AMOUNT_PER_EPOCH = VESTING_AMOUNT / TOTAL_EPOCHS;

    event VestingEnabled(string name, uint256 epochDuration, uint256 totalEpochs, uint256 startTime, uint256 endTime, uint256 amountPerEpoch, uint256 totalAmount);
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

        // Deploy LinearVestingWCO without funding
        uint256 startTime = block.timestamp;
        vesting = new LinearVesting(
            address(acm),
            "Test Vesting WCO",
            VESTING_AMOUNT,
            EPOCH_DURATION,
            TOTAL_EPOCHS,
            startTime
        );

        // Give FUNDER some ETH
        vm.deal(FUNDER, VESTING_AMOUNT * 2);
    }

    function test_Constructor() public {
        assertEq(address(vesting.acm()), address(acm));
        assertEq(vesting.name(), "Test Vesting WCO");
        assertEq(vesting.epochDuration(), EPOCH_DURATION);
        assertEq(vesting.totalEpochs(), TOTAL_EPOCHS);
        assertEq(vesting.totalAmount(), VESTING_AMOUNT);
        assertEq(vesting.amountPerEpoch(), AMOUNT_PER_EPOCH);
        assertEq(vesting.lastClaimedEpoch(), 0);
        assertEq(address(vesting).balance, 0);
        assertFalse(vesting.enabled());
    }

    function test_ReceiveFunction_EnablesVesting() public {
        vm.prank(FUNDER);
        vm.expectEmit(true, true, true, true);
        emit VestingEnabled(
            "Test Vesting WCO",
            EPOCH_DURATION,
            TOTAL_EPOCHS,
            block.timestamp,
            block.timestamp + (EPOCH_DURATION * TOTAL_EPOCHS),
            AMOUNT_PER_EPOCH,
            VESTING_AMOUNT
        );
        (bool success,) = address(vesting).call{value: VESTING_AMOUNT}("");
        assertTrue(success);
        
        assertTrue(vesting.enabled());
        assertEq(address(vesting).balance, VESTING_AMOUNT);
    }

    function test_RevertReceive_InsufficientFunds() public {
        vm.prank(FUNDER);
        vm.expectRevert(LinearVesting.InsufficientFunds.selector);
        (bool success,) = address(vesting).call{value: VESTING_AMOUNT - 1}("");
        // When expectRevert is used, the call will revert as expected
        // but success will still be true since the revert was expected
    }

    function test_RevertReceive_AlreadyEnabled() public {
        // First funding
        vm.prank(FUNDER);
        (bool success,) = address(vesting).call{value: VESTING_AMOUNT}("");
        assertTrue(success);
        
        // Second funding attempt
        vm.prank(FUNDER);
        vm.expectRevert(LinearVesting.AlreadyEnabled.selector);
        (bool success2,) = address(vesting).call{value: VESTING_AMOUNT}("");
        // When expectRevert is used, the call will revert as expected
        // but success will still be true since the revert was expected
    }

    function test_GetCurrentEpoch() public {
        _fundVesting();
        
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
        _fundVesting();
        
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
        _fundVesting();
        
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
        _fundVesting();
        
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
        _fundVesting();
        vm.warp(block.timestamp + EPOCH_DURATION);
        
        vm.prank(UNAUTHORIZED);
        vm.expectRevert(LinearVesting.Unauthorized.selector);
        vesting.claim();
    }

    function test_RevertClaim_InvalidEpoch() public {
        _fundVesting();
        
        vm.prank(ADMIN);
        vm.expectRevert(LinearVesting.InvalidEpoch.selector);
        vesting.claim();
    }

    function test_EmergencyWithdraw() public {
        _fundVesting();
        
        vm.prank(DAO_SIGNER);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(DAO_SIGNER, VESTING_AMOUNT);
        vesting.emergencyWithdraw();

        assertEq(DAO_SIGNER.balance, VESTING_AMOUNT);
        assertEq(address(vesting).balance, 0);
        assertEq(vesting.lastClaimedEpoch(), TOTAL_EPOCHS);
    }

    function test_RevertEmergencyWithdraw_Unauthorized() public {
        _fundVesting();
        
        vm.prank(UNAUTHORIZED);
        vm.expectRevert(LinearVesting.Unauthorized.selector);
        vesting.emergencyWithdraw();
    }

    function test_RevertEmergencyWithdraw_NoBalance() public {
        _fundVesting();
        
        // First withdraw all funds
        vm.prank(DAO_SIGNER);
        vesting.emergencyWithdraw();

        // Try to withdraw again
        vm.prank(DAO_SIGNER);
        vm.expectRevert(LinearVesting.InvalidParams.selector);
        vesting.emergencyWithdraw();
    }

    function test_PartialClaimThenEmergencyWithdraw() public {
        _fundVesting();
        
        // Advance 5 epochs and claim
        vm.warp(block.timestamp + (EPOCH_DURATION * 5));
        vm.prank(ADMIN);
        vesting.claim();
        
        uint256 remainingBalance = address(vesting).balance;
        uint256 expectedRemaining = VESTING_AMOUNT - (AMOUNT_PER_EPOCH * 5);
        assertEq(remainingBalance, expectedRemaining);
        
        // Emergency withdraw remaining
        vm.prank(DAO_SIGNER);
        vesting.emergencyWithdraw();
        
        assertEq(DAO_SIGNER.balance, expectedRemaining);
        assertEq(address(vesting).balance, 0);
    }

    function test_ExcessFunding() public {
        uint256 excessAmount = VESTING_AMOUNT + 1 ether;
        
        vm.prank(FUNDER);
        (bool success,) = address(vesting).call{value: excessAmount}("");
        assertTrue(success);
        
        assertTrue(vesting.enabled());
        assertEq(address(vesting).balance, excessAmount);
        
        // When claiming final epoch, should get all remaining balance
        vm.warp(block.timestamp + (EPOCH_DURATION * TOTAL_EPOCHS));
        vm.prank(ADMIN);
        vesting.claim();
        
        assertEq(ADMIN.balance, excessAmount);
    }

    function test_RevertConstructor_ZeroAddress() public {
        vm.expectRevert(LinearVesting.ZeroAddress.selector);
        new LinearVesting(
            address(0),
            "Test",
            VESTING_AMOUNT,
            EPOCH_DURATION,
            TOTAL_EPOCHS,
            block.timestamp
        );
    }

    function test_RevertConstructor_InvalidParams() public {
        // Zero epoch duration
        vm.expectRevert(LinearVesting.InvalidParams.selector);
        new LinearVesting(
            address(acm),
            "Test",
            VESTING_AMOUNT,
            0,
            TOTAL_EPOCHS,
            block.timestamp
        );
        
        // Zero total epochs
        vm.expectRevert(LinearVesting.InvalidParams.selector);
        new LinearVesting(
            address(acm),
            "Test",
            VESTING_AMOUNT,
            EPOCH_DURATION,
            0,
            block.timestamp
        );
        
        // Zero total amount
        vm.expectRevert(LinearVesting.InvalidParams.selector);
        new LinearVesting(
            address(acm),
            "Test",
            0,
            EPOCH_DURATION,
            TOTAL_EPOCHS,
            block.timestamp
        );
    }

    // Helper function to fund the vesting contract
    function _fundVesting() internal {
        vm.prank(FUNDER);
        (bool success,) = address(vesting).call{value: VESTING_AMOUNT}("");
        assertTrue(success);
    }
}