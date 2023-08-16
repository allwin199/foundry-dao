// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    GovToken govToken;
    TimeLock timeLock;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant minDelay = 3600; //60mins * 60sec = 3600 seconds
    address[] public proposers;
    address[] public executors;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        // we have to delegate voting power to the user
        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(minDelay, proposers, executors);
        governor = new MyGovernor(govToken,timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        // only the governor can purpose some stuff to timelock
        timeLock.grantRole(proposerRole, address(governor));
        // anybody can execute a passed proposal
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, USER);
        // if user is the admin, it is centralized, so we have to revoke the user as admin
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));
        // timelock is owned by the DOA
    }

    function test_CantUpdateBox_WithoutGovernance() public {
        // since box is owned by governor, if anyone else call box, it should revert
        vm.expectRevert();
        box.store(1);
    }
}
