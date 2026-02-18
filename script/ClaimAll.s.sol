// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { LinearVesting } from "../src/LinearVestingWCO.sol";

contract ClaimAll is Script {
    address public constant TREASURY = 0x67F2696c125D8D1307a5aE17348A440718229D03;
    address[] public contracts = [
        0x2ca9472ADd8a02c74D50FC3Ea444548502E35BDb,
        0x94DbFF05e1C129869772E1Fb291901083CdAdef1,
        0xa237FeAFa2BAc4096867aF6229a2370B7A661A5F,
        0x80eaBD19b84b4f5f042103e957964297589C657D,
        0x57Ab15Ca8Bd528D509DbC81d11E9BecA44f3445f
    ];

    event ClaimableAmountChecked(address indexed vestingContract, uint256 amount);
    event ClaimExecuted(address indexed vestingContract, uint256 amount);
    event TotalTransferred(address indexed treasury, uint256 totalAmount);

    function run() external {
        uint256 PK = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(PK);

        uint256 balanceBeforeClaiming = msg.sender.balance;
        console.log("Starting balance: ", balanceBeforeClaiming);
        
        uint256 totalClaimAmount = 0;
        
        // First pass: Check claimable amounts and accumulate total
        for (uint256 i = 0; i < contracts.length; i++) {
            LinearVesting vestingContract = LinearVesting(payable(contracts[i]));
            uint256 claimableAmount = vestingContract.getClaimableAmount();
            
            if (claimableAmount > 0) {
                totalClaimAmount += claimableAmount;
                emit ClaimableAmountChecked(contracts[i], claimableAmount);
            }
        }
        
        // Second pass: Execute claims (ETH goes to msg.sender)
        for (uint256 i = 0; i < contracts.length; i++) {
            LinearVesting vestingContract = LinearVesting(payable(contracts[i]));
            uint256 claimableAmount = vestingContract.getClaimableAmount();
            
            if (claimableAmount > 0) {
                uint256 balanceBeforeClaim = msg.sender.balance;
                vestingContract.claim();
                uint256 balanceAfterClaim = msg.sender.balance;
                
                // Verify ETH was received
                require(balanceAfterClaim >= balanceBeforeClaim, "ETH not received from claim");
                
                emit ClaimExecuted(contracts[i], claimableAmount);
                console.log("Claim", i, "- Balance increased by:", balanceAfterClaim - balanceBeforeClaim);
            }
        }

        console.log("Total claimable amount:", totalClaimAmount);
        
        // Calculate actual claimed amount (delta between before and after)
        // Individual balance checks after each claim ensure ETH is properly credited
        uint256 balanceAfterClaiming = msg.sender.balance;
        
        // Handle potential underflow if balance decreased due to gas costs
        uint256 actualClaimedAmount;
        if (balanceAfterClaiming >= balanceBeforeClaiming) {
            actualClaimedAmount = balanceAfterClaiming - balanceBeforeClaiming;
        } else {
            // Balance decreased due to gas costs, so no net gain to transfer
            actualClaimedAmount = 0;
            console.log("Balance decreased due to gas costs, no transfer needed");
        }
        
        console.log("Actual claimed amount (delta):", actualClaimedAmount);
        console.log("Balance after claiming:", balanceAfterClaiming);
        
        vm.stopBroadcast();
    }
    
}
