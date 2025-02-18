// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../ForestCommon.sol";

library ForestSlasher {
    type CommitStatus is uint8;

    struct EpochScoreAggregate {
        address pcAddr;
        uint256 revenueAtEpochClose;
        uint256[2][] provRanks;
        uint256[2][] valRanks;
    }

    struct EpochScoreGranular {
        uint24 valId;
        ProviderScore[] provScores;
        bytes32 commitHash;
        CommitStatus status;
    }

    struct ProviderScore {
        uint24 provId;
        uint256 score;
        uint32 agreementId;
    }
}

interface IForestSlasher {
    error CommitmentAlreadySubmitted();
    error EnforcedPause();
    error ExpectedPause();
    error InsufficientAmount();
    error InvalidAddress();
    error InvalidState();
    error ObjectNotActive();
    error OnlyOwnerAllowed();
    error OnlyOwnerOrOperatorAllowed();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error ProviderDoesNotMatchAgreement(uint24 _providerId, uint32 _agreementId);
    error Unauthorized();
    error ValidatorDoesNotMatchAgreement(uint24 _validatorId, uint32 _agreementId);

    event ActorCollateralTopuped(address indexed actorAddr, uint256 amount);
    event ActorCollateralWithdrawn(address indexed actorAddr, uint256 amount);
    event CommitRevealed(
        address indexed valAddr, address indexed pcAddr, bytes32 hashValue, uint256 indexed epochEndBlockNum
    );
    event CommitSubmitted(
        address indexed valAddr, address indexed pcAddr, bytes32 hashValue, uint256 indexed epochEndBlockNum
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);

    function EPOCH_LENGTH() external view returns (uint256);
    function REVEAL_WINDOW() external view returns (uint256);
    function closeEpoch() external;
    function commit(bytes32 _commitHash, address _valAddr, address _pcAddr) external;
    function computeCurrentEpochEndBlockNum() external view returns (uint256);
    function computeHash(ForestSlasher.ProviderScore[] memory _provScores) external pure returns (bytes32);
    function forestToken() external view returns (address);
    function getCollateralBalanceOf(address _pcAddr, address _addr) external view returns (uint256);
    function getCurrentEpochEndBlockNum() external view returns (uint256);
    function getEpochScoresAggregate(uint256 _epoch)
        external
        view
        returns (ForestSlasher.EpochScoreAggregate[] memory);
    function getEpochScoresGranular(address _pcAddr)
        external
        view
        returns (ForestSlasher.EpochScoreGranular[] memory);
    function getHashToIndex(bytes32 _commitHash) external view returns (uint256);
    function getPcNumThisEpoch() external view returns (uint256);
    function isValidEpochEndBlockNum(uint256 _epochEndBlockNum) external view returns (bool);
    function onlyWhenRegistryAndTokenSet() external view;
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function registry() external view returns (address);
    function renounceOwnership() external;
    function reveal(
        bytes32 _commitHash,
        address _valAddr,
        address _pcAddr,
        ForestSlasher.ProviderScore[] memory _provScores
    ) external;
    function setEpochLength(uint256 _epochLength) external;
    function setRegistryAndForestAddr(address _registryAddr) external;
    function setRevealWindow(uint256 _revealWindow) external;
    function topupActorCollateral(address _pcAddr, ForestCommon.ActorType _actorType, address _sender, uint256 _amount)
        external;
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function withdrawActorCollateral(address _pcAddr, ForestCommon.ActorType _actorType, uint256 _amount) external;
}
