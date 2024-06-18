// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ArbimisticGovernor} from "../src/contracts/ArbimisticGovernor.sol";
import {ArbitrumTimelock} from "../src/contracts/@arbitrum/ArbitrumTimelock.sol";
import {L2ArbitrumToken} from "../src/contracts/@arbitrum/L2ArbitrumToken.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "./util/TestUtil.sol";


contract GovernorTest is Test {
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
    address executor = address(842);
    ArbimisticGovernor governor;


    function setUp() public {
        ArbimisticGovernor _governor = new ArbimisticGovernor();
        governor = _governor;
    }

    function deployAndInit()
        private
        returns (ArbimisticGovernor, L2ArbitrumToken, ArbitrumTimelock)
    {
        L2ArbitrumToken token =
            L2ArbitrumToken(TestUtil.deployProxy(address(new L2ArbitrumToken())));
        token.initialize(l1TokenAddress, initialTokenSupply, tokenOwner);

        ArbitrumTimelock timelock =
            ArbitrumTimelock(payable(TestUtil.deployProxy(address(new ArbitrumTimelock()))));
        timelock.initialize(1, stubAddressArray, stubAddressArray);

        ArbimisticGovernor arbimisticGovernor =
            ArbimisticGovernor(payable(TestUtil.deployProxy(address(new ArbimisticGovernor()))));
        arbimisticGovernor.initialize(
            token,
            timelock,
            executor,
            votingDelay,
            votingPeriod,
            quorumNumerator,
            proposer
        );
        return (arbimisticGovernor, token, timelock);
    }

    function testCantReinit() external {
        (ArbimisticGovernor ArbimisticGovernor, L2ArbitrumToken token, ArbitrumTimelock timelock) =
            deployAndInit();

        vm.expectRevert("Initializable: contract is already initialized");
        ArbimisticGovernor.initialize(
            token,
            timelock,
            someRando,
            votingDelay,
            votingPeriod,
            quorumNumerator,
            proposer
        );
    }

    function testProperlyInitialized() external {
        (ArbimisticGovernor ArbimisticGovernor,,) = deployAndInit();
        assertEq(ArbimisticGovernor.votingDelay(), votingDelay, "votingDelay not set properly");
        assertEq(ArbimisticGovernor.votingPeriod(), votingPeriod, "votingPeriod not set properly");
    }

    function testPastCirculatingSupplyMint() external {
        (ArbimisticGovernor ArbimisticGovernor, L2ArbitrumToken token,) = deployAndInit();

        vm.warp(200_000_000_000_000_000);
        vm.roll(2);

        vm.prank(tokenOwner);
        token.mint(someRando, 200);
        vm.roll(3);
        assertEq(
            ArbimisticGovernor.getPastCirculatingSupply(2),
            initialTokenSupply + 200,
            "Mint should be reflected in getPastCirculatingSupply"
        );
        assertEq(
            ArbimisticGovernor.quorum(2),
            ((initialTokenSupply + 200) * quorumNumerator) / 10_000,
            "Mint should be reflected in quorum"
        );
    }

    function testPastCirculatingSupplyExclude() external {
        (ArbimisticGovernor ArbimisticGovernor, L2ArbitrumToken token,) = deployAndInit();
        address excludeAddress = ArbimisticGovernor.EXCLUDE_ADDRESS();

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
            ArbimisticGovernor.getPastCirculatingSupply(3),
            initialTokenSupply,
            "votes at exlcude-address member shouldn't affect circulating supply"
        );
        assertEq(
            ArbimisticGovernor.quorum(3),
            (initialTokenSupply * quorumNumerator) / 10_000,
            "votes at exlcude-address member shouldn't affect quorum"
        );
    }

    function testPastCirculatingSupply() external {
        (ArbimisticGovernor ArbimisticGovernor,,) = deployAndInit();

        vm.warp(200_000_000_000_000_000);
        vm.roll(2);
        assertEq(
            ArbimisticGovernor.getPastCirculatingSupply(1),
            initialTokenSupply,
            "Inital supply error"
        );
    }

    function testExecutorPermissions() external {
        (ArbimisticGovernor ArbimisticGovernor,,) = deployAndInit();
        vm.startPrank(executor);

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.setProposalThreshold.selector, 2)
        );
        assertEq(ArbimisticGovernor.proposalThreshold(), 2, "Prop threshold");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.setVotingDelay.selector, 2)
        );
        assertEq(ArbimisticGovernor.votingDelay(), 2, "Voting delay");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.setVotingPeriod.selector, 2)
        );
        assertEq(ArbimisticGovernor.votingPeriod(), 2, "Voting period");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.updateQuorumNumerator.selector, 400)
        );
        assertEq(ArbimisticGovernor.quorumNumerator(), 400, "Quorum num");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.updateTimelock.selector, address(137))
        );
        assertEq(ArbimisticGovernor.timelock(), address(137), "Timelock");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.setAuthorizedProposer.selector, someRando)
        );
        assertEq(ArbimisticGovernor.authorizedProposer(), someRando, "Proposer");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.setMaxActiveProposals.selector, 100)
        );
        assertEq(ArbimisticGovernor.maxActiveProposals(), 100, "Max active proposals");

        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.setMaxProposalsPeriod.selector, 302400)
        );
        assertEq(ArbimisticGovernor.maxProposalsPeriod(), 302400, "Max proposal period");

        vm.stopPrank();
    }

    function testExecutorPermissionsFail() external {
        (ArbimisticGovernor ArbimisticGovernor,,) = deployAndInit();

        vm.startPrank(someRando);

        vm.expectRevert("Governor: onlyGovernance");
        ArbimisticGovernor.setProposalThreshold(2);

        vm.expectRevert("Governor: onlyGovernance");
        ArbimisticGovernor.setVotingDelay(2);

        vm.expectRevert("Governor: onlyGovernance");
        ArbimisticGovernor.setVotingPeriod(2);

        vm.expectRevert("Governor: onlyGovernance");
        ArbimisticGovernor.updateQuorumNumerator(400);

        vm.expectRevert("Governor: onlyGovernance");
        ArbimisticGovernor.updateTimelock(TimelockControllerUpgradeable(payable(address(137))));

        vm.expectRevert("Ownable: caller is not the owner");
        ArbimisticGovernor.relay(
            address(ArbimisticGovernor),
            0,
            abi.encodeWithSelector(ArbimisticGovernor.updateQuorumNumerator.selector, 400)
        );

        vm.stopPrank();
    }

}