// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ArbimisticGovernor} from "../src/contracts/ArbimisticGovernor.sol";
import {ArbitrumTimelock} from "../src/contracts/@arbitrum/ArbitrumTimelock.sol";
import {L2ArbitrumToken} from "../src/contracts/@arbitrum/L2ArbitrumToken.sol";
import {IGovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/IGovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "./util/TestUtil.sol";


contract VotingTest is Test {
    address l1TokenAddress = address(137);
    uint256 initialTokenSupply = 50_000;
    address tokenOwner = address(238);
    uint256 votingPeriod = 6;
    uint256 votingDelay = 9;
    address excludeListMember = address(339);
    uint256 quorumNumerator = 500;

    address[] stubAddressArray = [address(640)];
    address proposer = address(572);
    address someRando = address(741);
    address bigRando = address(742);
    address executor = address(842);

    ArbimisticGovernor governor;
    L2ArbitrumToken token;
    ArbitrumTimelock timelock;


    function setUp() public {
        (governor, token, timelock) = deployAndInit();
    }

    function deployAndInit()
        private
        returns (ArbimisticGovernor, L2ArbitrumToken, ArbitrumTimelock)
    {
        L2ArbitrumToken _token =
            L2ArbitrumToken(TestUtil.deployProxy(address(new L2ArbitrumToken())));
        _token.initialize(l1TokenAddress, initialTokenSupply, tokenOwner);

        ArbitrumTimelock _timelock =
            ArbitrumTimelock(payable(TestUtil.deployProxy(address(new ArbitrumTimelock()))));
        _timelock.initialize(1, stubAddressArray, stubAddressArray);

        ArbimisticGovernor _arbimisticGovernor =
            ArbimisticGovernor(payable(TestUtil.deployProxy(address(new ArbimisticGovernor()))));
        _arbimisticGovernor.initialize(
            _token,
            _timelock,
            executor,
            votingDelay,
            votingPeriod,
            quorumNumerator,
            proposer
        );
        return (_arbimisticGovernor, _token, _timelock);
    }

    function createProposal() internal returns (uint256) {
        vm.prank(tokenOwner);
        token.transfer(someRando, 1);
        vm.prank(someRando);
        token.delegate(someRando);
        // delegate to vetoer
        vm.prank(tokenOwner);
        token.transfer(bigRando, 2500);
        vm.prank(bigRando);
        token.delegate(bigRando);
        // self delegate
        vm.prank(tokenOwner);
        token.delegate(tokenOwner);
        vm.roll(block.number + 1); // forward one block for voting power to accrue

        address[] memory targets = new address[](1); 
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Proposal #1: Change quorum";

        // Mocking a proposal creation
        targets[0] = address(governor);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 400);

        vm.prank(proposer); 
        return governor.propose(targets, values, calldatas, description);
    }

    function createSecondProposal() public returns (uint) {
        address[] memory targets = new address[](1); 
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Proposal #2: Change voting period";

        // Mocking a proposal creation
        targets[0] = address(governor);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateVotingPeriod(uint256)", 200);

        vm.prank(proposer); 
        return governor.propose(targets, values, calldatas, description);
    }

    function createProposal(uint salt) public returns (uint) {
        address[] memory targets = new address[](1); 
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Proposal #";

        // Mocking a proposal creation
        targets[0] = address(governor);
        values[0] = salt;
        calldatas[0] = abi.encodeWithSignature("updateQuorumNumerator(uint256)", 400);

        vm.prank(proposer); 
        return governor.propose(targets, values, calldatas, description);
    }

    function testPermission(address randoProposer) public {
        vm.assume(randoProposer != proposer);
        address[] memory targets = new address[](1); 
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Proposal #2: Change voting period";

        // Mocking a proposal creation
        targets[0] = address(governor);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateVotingPeriod(uint256)", 200);

        vm.prank(randoProposer); 
        vm.expectRevert("Auth: caller is not the authorized proposer");
        governor.propose(targets, values, calldatas, description);
    }

    function testVotingFor() public {
        address voter = tokenOwner;
        uint proposalId = createProposal();
        vm.roll(block.number + votingDelay + 1); // Skip to the start of the voting period
        // Cast a vote
        vm.prank(voter);
        governor.castVote(proposalId, 1); // 1 for support

         vm.roll(block.number + votingPeriod + 1); // Skip to the end of the voting period

        // Check proposal state (assuming it should be successful)
        require(
            governor.state(proposalId) == IGovernorUpgradeable.ProposalState.Succeeded,
            "Proposal did not succeed"
        );
    }

    function testVotingAgainstBelowQuorum() public {
        address voter = someRando;
        uint proposalId = createProposal();
        vm.roll(block.number + votingDelay + 1); // Skip to the start of the voting period
        // Cast a vote
        vm.prank(voter);
        governor.castVote(proposalId, 0); // 0 for against

         vm.roll(block.number + votingPeriod + 1); // Skip to the end of the voting period

        // Check proposal state 
        require(
            governor.state(proposalId) == IGovernorUpgradeable.ProposalState.Succeeded,
            "Proposal did not succeed"
        );
    }

    function testVotingAgainstQuorumReached() public {
        address voter = someRando;
        uint proposalId = createProposal();
        vm.roll(block.number + votingDelay + 1); // Skip to the start of the voting period
        // Cast a vote
        vm.prank(voter);
        governor.castVote(proposalId, 0); // 0 for against
        vm.prank(bigRando);
        governor.castVote(proposalId, 0); // 0 for against
        vm.prank(tokenOwner);
        governor.castVote(proposalId, 0); // 0 for against

         vm.roll(block.number + votingPeriod + 1); // Skip to the end of the voting period

        // Check proposal state
        require(
            governor.state(proposalId) == IGovernorUpgradeable.ProposalState.Defeated,
            "Proposal was not defeated"
        );
    }

    function testTwoVotesAtSameTime() public {
        address voter1 = someRando; // not enough votes to veto
        address voter2 = bigRando;  // enough votes to veto
        uint proposalId = createProposal();
        uint proposalId2 = createSecondProposal();
        vm.roll(block.number + votingDelay + 1); // Skip to the start of the voting period

        // Cast votes
        vm.prank(voter1);
        governor.castVote(proposalId, 0); // 0 for against
        vm.prank(voter2);
        governor.castVote(proposalId2, 0); // 0 for against

        vm.roll(block.number + votingPeriod + 1); // Skip to the end of the voting period

        // Check proposal state
        require(
            governor.state(proposalId) == IGovernorUpgradeable.ProposalState.Succeeded,
            "Proposal did not succeed"
        );
        // Check proposal state
        require(
            governor.state(proposalId2) == IGovernorUpgradeable.ProposalState.Defeated,
            "Proposal was not defeated"
        );
    }

    function testMaxProposalsPerPeriod() public {
        // create 9 proposals
        for (uint i = 0; i < 10; i++) {
            createProposal(i+1);
        }
        vm.expectRevert("Governor: max proposals per period exceeded");
        createProposal(11);
        vm.warp(604800);
        createProposal(11);
    }
    
}