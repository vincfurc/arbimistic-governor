// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (governance/extensions/GovernorSettings.sol)

pragma solidity ^0.8.0;

import "../GovernorUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {Governor} for settings updatable through governance.
 *
 * _Available since v4.4._
 */
abstract contract OptimisticGovernorSettingsUpgradeable is Initializable, GovernorUpgradeable {
    uint256 private _votingDelay;
    uint256 private _votingPeriod;
    uint256 private _proposalThreshold;
    address private _authorizedProposer;
    uint256 private _maxProposalsPeriod;
    uint256 private _maxActiveProposalsPerPeriod;

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event AuthorizedProposerSet(address oldAuthorizedProposer, address newAuthorizedProposer);

    /**
     * @dev Initialize the governance parameters.
     */
    function __GovernorSettings_init(
        uint256 initialVotingDelay,
        uint256 initialVotingPeriod,
        address initialAuthProposer
    ) internal onlyInitializing {
        __GovernorSettings_init_unchained(initialVotingDelay, initialVotingPeriod, initialAuthProposer);
    }

    function __GovernorSettings_init_unchained(
        uint256 initialVotingDelay,
        uint256 initialVotingPeriod,
        address initialAuthProposer
    ) internal onlyInitializing {
        _setVotingDelay(initialVotingDelay);
        _setVotingPeriod(initialVotingPeriod);
        _setAuthorizedProposer(initialAuthProposer);
        _setMaxProposalsPeriod(604800);
        _setMaxActiveProposals(10);
    }

    /**
     * @dev See {IGovernor-votingDelay}.
     */
    function votingDelay() public view virtual override returns (uint256) {
        return _votingDelay;
    }

    /**
     * @dev See {IGovernor-votingPeriod}.
     */
    function votingPeriod() public view virtual override returns (uint256) {
        return _votingPeriod;
    }

    /**
     * @dev See {Governor-proposalThreshold}.
     */
    function proposalThreshold() public view virtual override returns (uint256) {
        return _proposalThreshold;
    }

    /**
     * @dev See {Governor-authorizedProposer}.
     */
    function authorizedProposer() public view virtual returns (address) {
        return _authorizedProposer;
    }

    /**
     * @dev See {IGovernor-maxActiveProposals}.
     */
    function maxActiveProposals() public view returns (uint256) {
        return _maxActiveProposalsPerPeriod;
    }

    /**
     * @dev See {IGovernor-proposalPeriod}.
     */
    function maxProposalsPeriod() public view virtual returns (uint256) {
        return _maxProposalsPeriod;
    }

    /**
     * @dev Update the voting delay. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint256 newVotingDelay) public virtual onlyGovernance {
        _setVotingDelay(newVotingDelay);
    }

    /**
     * @dev Update the voting period. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint256 newVotingPeriod) public virtual onlyGovernance {
        _setVotingPeriod(newVotingPeriod);
    }

    /**
     * @dev Update the proposal threshold. This operation can only be performed through a governance proposal.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint256 newProposalThreshold) public virtual onlyGovernance {
        _setProposalThreshold(newProposalThreshold);
    }

    /**
     * @dev Update the authorized proposer. This operation can only be performed through a governance proposal.
     *
     * Emits a {AuthorizedProposerSet} event.
     */
    function setAuthorizedProposer(address newAuthorizedProposer) public virtual onlyGovernance {
        _setAuthorizedProposer(newAuthorizedProposer);
    }

    /**
     * @dev Update the maximum number of active proposals. This operation can only be performed through a governance proposal.
     */
    function setMaxActiveProposals(uint256 maxActiveProposalsPerPeriod) public virtual onlyGovernance {
        _setMaxActiveProposals(maxActiveProposalsPerPeriod);
    }

    /**
     * @dev Internal setter for the maximum number of active proposals.
     */
    function _setMaxActiveProposals(uint256 maxActiveProposalsPerPeriod) internal virtual {
        _maxActiveProposalsPerPeriod = maxActiveProposalsPerPeriod;
    }

    /**
     * @dev Update the proposal period. This operation can only be performed through a governance proposal.
     */
    function setMaxProposalsPeriod(uint256 proposalsPeriod) public virtual onlyGovernance {
        _setMaxProposalsPeriod(proposalsPeriod);
    }

    /**
     * @dev Internal setter for the proposal period.
     */
    function _setMaxProposalsPeriod(uint256 proposalsPeriod) internal virtual {
        _maxProposalsPeriod = proposalsPeriod;
    }

    /**
     * @dev Internal setter for the authorized proposer.
     *
     * Emits a {AuthorizedProposerSet} event.
     */
    function _setAuthorizedProposer(address newAuthorizedProposer) internal virtual {
        emit AuthorizedProposerSet(_authorizedProposer, newAuthorizedProposer);
        _authorizedProposer = newAuthorizedProposer;
    }

    /**
     * @dev Internal setter for the voting delay.
     *
     * Emits a {VotingDelaySet} event.
     */
    function _setVotingDelay(uint256 newVotingDelay) internal virtual {
        emit VotingDelaySet(_votingDelay, newVotingDelay);
        _votingDelay = newVotingDelay;
    }

    /**
     * @dev Internal setter for the voting period.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function _setVotingPeriod(uint256 newVotingPeriod) internal virtual {
        // voting period must be at least one block long
        require(newVotingPeriod > 0, "GovernorSettings: voting period too low");
        emit VotingPeriodSet(_votingPeriod, newVotingPeriod);
        _votingPeriod = newVotingPeriod;
    }

    /**
     * @dev Internal setter for the proposal threshold.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function _setProposalThreshold(uint256 newProposalThreshold) internal virtual {
        emit ProposalThresholdSet(_proposalThreshold, newProposalThreshold);
        _proposalThreshold = newProposalThreshold;
    }

    /**
     * @dev Throws if called by any account other than the authorized proposer.
     */
    modifier onlyProposer(){
        require(_authorizedProposer == _msgSender(), "Auth: caller is not the authorized proposer");
        _;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
