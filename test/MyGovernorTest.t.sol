// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
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

    uint256 public constant MIN_DELAY = 3600; // 60mins * 60sec = 3600 seconds
    uint256 public constant VOTING_DELAY = 7200; // how may blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 50400;

    address[] public proposers;
    address[] public executors;
    uint256[] public values;
    address[] public targets;
    bytes[] public calldatas;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        // we have to delegate voting power to the user
        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
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

    function test_GovernanceCan_UpdateBox() public {
        uint256 valueToStore = 123;
        string memory description = "Store 123 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0); // we are not sending any ETH
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // view the state of the proposal
        console2.log("Proposal State", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console2.log("Current Proposal State", uint256(governor.state(proposalId)));

        // 2. Vote on the proposal
        string memory reason = "number should be 123";

        uint8 voteWay = 1; // voting for

        vm.startPrank(USER);

        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        console2.log("Box Value", box.readNumber());
        assertEq(box.readNumber(), valueToStore);
    }
}
