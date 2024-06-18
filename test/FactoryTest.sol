// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ArbimisticGovernor} from "../src/contracts/ArbimisticGovernor.sol";
import {ArbimisticFactory} from "../src/contracts/ArbimisticFactory.sol";
import {ArbitrumTimelock} from "../src/contracts/@arbitrum/ArbitrumTimelock.sol";
import {L2ArbitrumToken} from "../src/contracts/@arbitrum/L2ArbitrumToken.sol";
import {IGovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/IGovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "./util/TestUtil.sol";


contract FactoryTest is Test {
    address l1TokenAddress = address(137);
    uint256 initialTokenSupply = 50_000;
    address tokenOwner = address(238);
    uint256 votingPeriod = 6;
    uint256 votingDelay = 9;
    address excludeListMember = address(339);
    uint256 quorumNumerator = 500;
    uint256 proposalThreshold = 1;
    uint64  initialVoteExtension = 5;

    address[] stubAddressArray = [address(640)];
    address proposer = address(572); 
    address someRando = address(741);
    address bigRando = address(742);
    address executor = address(842);
    ArbimisticGovernor governor;
    ArbimisticFactory factory;
    L2ArbitrumToken token;
    ArbitrumTimelock timelock;


    function setUp() public {
        // deploy factory
        factory = new ArbimisticFactory();
        (governor, token, timelock) = deployAndInit();
        distributeVotingPower();
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

        ArbimisticGovernor _arbimisticGovernor = factory.createGovernor(
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

    function testProperlyInitialized() external {
        assertEq(governor.votingDelay(), votingDelay, "votingDelay not set properly");
        assertEq(governor.votingPeriod(), votingPeriod, "votingPeriod not set properly");
    }

        function testPastCirculatingSupplyMint() external {
        vm.warp(200_000_000_000_000_000);
        vm.roll(2);

        vm.prank(tokenOwner);
        token.mint(someRando, 200);
        vm.roll(3);
        assertEq(
            governor.getPastCirculatingSupply(2),
            initialTokenSupply + 200,
            "Mint should be reflected in getPastCirculatingSupply"
        );
        assertEq(
            governor.quorum(2),
            ((initialTokenSupply + 200) * quorumNumerator) / 10_000,
            "Mint should be reflected in quorum"
        );
    }

    function testPastCirculatingSupplyExclude() external {
        address excludeAddress = governor.EXCLUDE_ADDRESS();

        vm.roll(3);
        vm.warp(300_000_000_000_000_000);
        vm.prank(tokenOwner);
        token.mint(excludeListMember, 300);

        vm.prank(excludeListMember);
        token.delegate(excludeAddress);
        vm.roll(4);
        assertEq(
            token.getPastVotes(excludeAddress, 3), 300, "didn't delegate to votes exclude address"
        );

        assertEq(
            governor.getPastCirculatingSupply(3),
            initialTokenSupply,
            "votes at exlcude-address member shouldn't affect circulating supply"
        );
        assertEq(
            governor.quorum(3),
            (initialTokenSupply * quorumNumerator) / 10_000,
            "votes at exlcude-address member shouldn't affect quorum"
        );
    }

    function testPastCirculatingSupply() external {

        vm.warp(200_000_000_000_000_000);
        vm.roll(2);
        assertEq(
            governor.getPastCirculatingSupply(1),
            initialTokenSupply,
            "Inital supply error"
        );
    }

    function testExecutorPermissions() external {
        vm.startPrank(executor);

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.setProposalThreshold.selector, 2)
        );
        assertEq(governor.proposalThreshold(), 2, "Prop threshold");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.setVotingDelay.selector, 2)
        );
        assertEq(governor.votingDelay(), 2, "Voting delay");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.setVotingPeriod.selector, 2)
        );
        assertEq(governor.votingPeriod(), 2, "Voting period");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.updateQuorumNumerator.selector, 400)
        );
        assertEq(governor.quorumNumerator(), 400, "Quorum num");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.updateTimelock.selector, address(137))
        );
        assertEq(governor.timelock(), address(137), "Timelock");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.setAuthorizedProposer.selector, someRando)
        );
        assertEq(governor.authorizedProposer(), someRando, "Proposer");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.setMaxActiveProposals.selector, 100)
        );
        assertEq(governor.maxActiveProposals(), 100, "Max active proposals");

        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.setMaxProposalsPeriod.selector, 302400)
        );
        assertEq(governor.maxProposalsPeriod(), 302400, "Max proposal period");

        vm.stopPrank();
    }

    function testExecutorPermissionsFail() external {
        vm.startPrank(someRando);

        vm.expectRevert("Governor: onlyGovernance");
        governor.setProposalThreshold(2);

        vm.expectRevert("Governor: onlyGovernance");
        governor.setVotingDelay(2);

        vm.expectRevert("Governor: onlyGovernance");
        governor.setVotingPeriod(2);

        vm.expectRevert("Governor: onlyGovernance");
        governor.updateQuorumNumerator(400);

        vm.expectRevert("Governor: onlyGovernance");
        governor.updateTimelock(TimelockControllerUpgradeable(payable(address(137))));

        vm.expectRevert("Ownable: caller is not the owner");
        governor.relay(
            address(governor),
            0,
            abi.encodeWithSelector(governor.updateQuorumNumerator.selector, 400)
        );

        vm.stopPrank();
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
        uint proposalId = createProposal(389);
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
        uint proposalId = createProposal(2892);
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
        uint proposalId = createProposal(2892);
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
        uint proposalId = createProposal(2892);
        uint proposalId2 = createProposal(2893);
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

    // Utils

    function distributeVotingPower() public {
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
}