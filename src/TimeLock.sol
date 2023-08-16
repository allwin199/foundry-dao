// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    ///
    /// @param minDelay is how long you have to wait before executing
    /// @param proposers is the list of addresses that can propose
    /// @param executors is the list of addresses that can execute
    /// msg.sender will be the admin
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}