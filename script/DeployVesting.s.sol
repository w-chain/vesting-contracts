// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { LinearVesting } from "../src/LinearVestingWCO.sol";

contract Deploy is Script {
    address public constant ACM = 0x883C41051A2191CF38b9F13AcEfa431a4A9aB9FE;
    uint256 public constant EPOCH_DURATION = 15 days;
    uint256 public constant START_TIME = 1748779200;

    LinearVesting public marketing;
    LinearVesting public ecosystem;
    LinearVesting public incentives;
    LinearVesting public partnerships;
    LinearVesting public development;

    function run() external {
        vm.startBroadcast();

        marketing = new LinearVesting(
            ACM,
            "Marketing & Community",
            450_000_000 ether,
            EPOCH_DURATION,
            108,
            START_TIME
        );

        ecosystem = new LinearVesting(
            ACM,
            "W Chain Ecosystem",
            333_333_333 ether,
            EPOCH_DURATION,
            60,
            START_TIME
        );

        incentives = new LinearVesting(
            ACM,
            "Incentives",
            899_999_999 ether,
            EPOCH_DURATION,
            108,
            START_TIME
        );

        partnerships = new LinearVesting(
            ACM,
            "Enterprises & Partnerships",
            899_999_999 ether,
            EPOCH_DURATION,
            108,
            START_TIME
        );

        development = new LinearVesting(
            ACM,
            "Development Fund",
            899_999_999 ether,
            EPOCH_DURATION,
            108,
            START_TIME
        );

        console.log("Marketing: ", address(marketing));
        console.log("Ecosystem: ", address(ecosystem));
        console.log("Incentives: ", address(incentives));
        console.log("Partnerships: ", address(partnerships));
        console.log("Development: ", address(development));

        vm.stopBroadcast();
    }
}