// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/transparent/ProxyAdmin.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {ArbimisticGovernor} from "./ArbimisticGovernor.sol";

contract ArbimisticFactory {
    event NewArbimisticGovernor(address governor, address token, address timelock, address executor, address proposer);

    function createGovernor(
        IVotesUpgradeable token,
        TimelockControllerUpgradeable timelock,
        address executor,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumNumerator,
        address proposer
    ) 
        external 
        returns (ArbimisticGovernor)
    {

        ArbimisticGovernor arbimisticGovernor =
            ArbimisticGovernor(payable(deployProxy(address(new ArbimisticGovernor()))));
        arbimisticGovernor.initialize(
            token,
            timelock,
            executor,
            votingDelay,
            votingPeriod,
            quorumNumerator,
            proposer
        );

        emit NewArbimisticGovernor(address(arbimisticGovernor), address(token), address(timelock), executor, proposer);
        return arbimisticGovernor;
    }

    function deployProxy(address logic) public returns (address) {
        ProxyAdmin pa = new ProxyAdmin();
        return address(new TransparentUpgradeableProxy(address(logic), address(pa), ""));
    }
}