# Easy-Track Governor

## Abstract

**Easy Track** is a type of voting where a proposal is considered to have passed if the minimum objections threshold hasn’t been reached.

**EasyTrack Governor contract** implements the Easy Track voting mechanism. To achieve enhanced security and ensure compatibility, EasyTrack Governor contract aims at inheriting extensively, where possible, from the Arbitrum Core [Governor](https://github.com/ArbitrumFoundation/governance/tree/main/src) contracts. 

### Solution Summary

Arbitrum currently operates a single quorum-based governor type for voting through Tally, and the easy-track module consists of a modified version of the Governor smart contract. 

This easy-tack governor works with a Safe to make a veto council. The Safe is the council. The council would have the proposer role on the governor, so it could make proposals. Voters can veto those proposals.

To support this flow, this governor inverts the voting rules for passing proposals. Instead of voting “in favor” to pass a vote, voters can only vote "against" proposals. If enough "against" votes are cast, the proposal is blocked. This new easy-track governor smart contract can then be added to Tally so that it can be selected when creating new proposals.

### Proposed Solution

Enabling easy-track would require changes on how the ProposalState is updated in the Governor smart contracts. 
The current proposal state is defined by the following struct:

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

Proposal state can be obtained on the Governor smart contract by querying the state function. The Arbitrum's Core Governor contract inherits from several OpenZeppelin contracts:

    - Initializable.
    - GovernorSettingsUpgradeable.
    - GovernorCountingSimpleUpgradeable.
    - GovernorVotesUpgradeable.
    - GovernorTimelockControlUpgradeable.
    - GovernorVotesQuorumFractionUpgradeable.
    - GovernorPreventLateQuorumUpgradeable.
    - OwnableUpgradeable.

Ultimately, the OZ [GovernorCountingSimpleUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/extensions/GovernorCountingSimple.sol) module is responsible for checking if the proposal vote succeeded by invoking the following check:

        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }

The simplest way to implement the Easy Track Governor is by modifying the OZ GovernorCountingSimpleUpgradeable module _voteSucceeded function:

    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];

        return proposalvote.forVotes > proposalvote.againstVotes;
    }

In particular, the proposal state transition from Active to Succeeed will rely on the deadline parameter and the number of against votes, which will need to be > the required against Quorum. Moreover, a check on the Quorum of against votes in order to Defeat the proposal will need to implemented, while standard "in favor" quorum can be set to Zero. This can achieved by allowing the GovernorCountingSimpleUpgradeable module to receive and againstQuorum parameter at initialization.

### Conclusion

The EasyTrack Governor contract introduces a distinct voting mechanism, where proposals pass by default unless they meet a minimum threshold of objections. This approach deviates from the standard in favor/quorum-based voting system. The primary alteration involves modifying the GovernorCountingSimpleUpgradeable module to focus on the count of objection votes rather than supportive votes. The Quorum parameters will also need to be adjusted. Implementing this system in the Arbitrum governance structure, particularly in conjunction with Tally, necessitates adjustments in the ProposalState transitions within the Governor smart contracts. The success of a proposal in this model is contingent on the objection votes not exceeding a set quorum, changing the dynamics of decision-making in the smart contract governance. This method may be particularly relevant for decisions that are inherently non-contentious and proposed by already elected council members, making such proposals cheaper and easier to manage.
