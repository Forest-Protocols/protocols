// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IForestProtocol.sol";
import "./interfaces/IForestRegistry.sol";

contract ForestSlasher is Ownable, Pausable {
    /***********************************|
    |              Events               |
    |__________________________________*/

    event CommitSubmitted(  
        address indexed valAddr,
        address indexed pcAddr,
        bytes32 hashValue,
        uint256 indexed epochEndBlockNum
    );
    
    event CommitRevealed(
        address indexed valAddr,
        address indexed pcAddr,
        bytes32 hashValue,
        uint256 indexed epochEndBlockNum
    );

    event ActorCollateralTopuped(
        address indexed actorAddr,
        uint256 amount
    );

    event ActorCollateralWithdrawn(
        address indexed actorAddr,
        uint256 amount
    );

    /***********************************|
    |          Structs & Enums          |
    |__________________________________*/

    enum CommitStatus {
        NONE,
        COMMITED,
        REVEALED
    }

    struct ProviderScore {
        uint24 provId; // we are using IDs to save on space, 24 bits vs 20*8 bits
        uint256 score;
        uint32 agreementId; 
    }

    struct EpochScoreGranular {
        uint24 valId; // we are using IDs to save on space, 24 bits vs 20*8 bits
        ProviderScore[] provScores;
        bytes32 commitHash;
        CommitStatus status;
    }

    struct EpochScoreAggregate {
        address pcAddr;
        uint256 revenueAtEpochClose;
        uint256[2][] provRanks; // the tuple is (providerId, aggregatedScore) or (providerId, rank)
        uint256[2][] valRanks; // the tuple is (validatorId, diviationScore) or (validatorId, rank)
    }

    /***********************************|
    |            Variables              |
    |__________________________________*/

    IERC20 public forestToken; // Interface object for the Forest token
    IForestRegistry public registry; // Interface object for the Registry contract

    mapping(address => mapping(address => uint256)) actorCollateralBalanceOf; // mapping of PC address to Provider address to deposited token amount on this PC

    uint256 firstEpochEndBlockNum; // Block number when the first epoch ends
    uint256 currentEpochEndBlockNum; // Block number when the currently processed epoch ends
    address[] currentPcAddresses; // array of addresses to which at least one commit has been submitted
    mapping(address => bool) currentPcAddressesMap; // mapping to check uniqueness before adding to the array
    mapping(address => EpochScoreGranular[]) currentPcAddrToEpochScoreMap; // mapping from PC address to array of EpochScoreGranular objects
    mapping(bytes32 => uint256) currentHashToIndexMap; // mapping from hash to index that can be used to access EpochScoreGranular objects from the currentPcAddrToEpochScoreMap if we have the Pc address

    // helper variables for aggregateScores calculations, cleared after each aggregation is complete
    mapping(uint24 => uint256) actorIdToAggregateScore; // mapping from actor ID to aggregated score
    uint256[2][] provIdToScore; // array of tuples (providerId, aggregatedScore)
    uint256[2][] provIdToTestNum; // array of tuples (providerId, number of tests)
    uint256[2][] valIdToTestNum; // array of tuples (validatorId, number of tests)
    uint24[] uniqueActors; // array of unique actor IDs
    
    mapping(uint256 => EpochScoreAggregate[]) epochToAggregatedScoreMap; // mapping from Epoch to struct with PC address and Val/Prov ranks

    // uint256 public constant EPOCH_LENGTH = 302400; // a week on Optimism that has 2 sec block time
    // uint256 public constant REVEAL_WINDOW = 43200; // one day on Optimism
    uint256 public EPOCH_LENGTH = 1800; // TODO: JUST FOR TESTING: an hour on Optimism that has 2 sec block time
    uint256 public REVEAL_WINDOW = 300; //// TODO: JUST FOR TESTING:  10min on Optimism
 
    /***********************************|
    |            Constructor            |
    |__________________________________*/

    constructor() Ownable(_msgSender()) { 
         currentEpochEndBlockNum = computeCurrentEpochEndBlockNum();
         firstEpochEndBlockNum = currentEpochEndBlockNum;
    }

    /// @notice Sets the Registry interface object based on the provided address and uses the registry contract to lookup and set the Forest token interface object
    /// @dev Can only be called by the owner
    /// @param _registryAddr Address of the Registry contract
    function setRegistryAndForestAddr(address _registryAddr) external onlyOwner {
        if (_registryAddr == address(0))
            revert ForestCommon.InvalidAddress();
        registry = IForestRegistry(_registryAddr);
        forestToken = IERC20(registry.getForestTokenAddr());
    }

    /***********************************|
    |        Slasher Functions          |
    |__________________________________*/

    /// @notice Commits validator's scores hash for a PC in the current epoch. Commitments are made during a voting window.
    /// @dev Validators must commit their scores before revealing them to prevent manipulation
    /// @param _commitHash Hash of the provider scores
    /// @param _valAddr Address of the validator to whom the commitment belongs
    /// @param _pcAddr Address of the Protocol being scored
    function commit(bytes32 _commitHash, address _valAddr, address _pcAddr) public whenNotPaused {
        onlyWhenRegistryAndTokenSet();
        IForestProtocol pc = getCheckedPc(_pcAddr);
        // check if the previous epoch is closed
        if (computeCurrentEpochEndBlockNum() > currentEpochEndBlockNum)
            revert ForestCommon.InvalidState();
        // check if commitment is not already submitted
        if (currentPcAddrToEpochScoreMap[_pcAddr].length > 0 && currentPcAddrToEpochScoreMap[_pcAddr][currentHashToIndexMap[_commitHash]].commitHash == _commitHash)
            revert ForestCommon.CommitmentAlreadySubmitted();
        // check if _msgSender() is a representative of a registered active validator
        if (!pc.isActiveRegisteredAndAuthorizedRepresentative(ForestCommon.ActorType.VALIDATOR, _valAddr, _msgSender()))
            revert ForestCommon.OnlyOwnerOrOperatorAllowed();
        
        // create the object commited object
        EpochScoreGranular memory granularScore = EpochScoreGranular(
            registry.getActor(_valAddr).id,
            new ProviderScore[](1),
            _commitHash,
            CommitStatus.COMMITED
        );

        // update global state
        if (!currentPcAddressesMap[_pcAddr]) {
            currentPcAddresses.push(_pcAddr);
            currentPcAddressesMap[_pcAddr] = true;
        }
        currentPcAddrToEpochScoreMap[_pcAddr].push(granularScore);
        currentHashToIndexMap[_commitHash] = currentPcAddrToEpochScoreMap[_pcAddr].length - 1;
        
        // emit event
        emit CommitSubmitted(
            _valAddr,
            _pcAddr,
            _commitHash,
            currentEpochEndBlockNum
        );
    }

    /// @notice Reveals previously committed scores for providers
    /// @dev Can only be called during the reveal window after epoch end
    /// @param _commitHash Hash that was previously committed
    /// @param _valAddr Validator address to whom the commitment belongs
    /// @param _pcAddr Protocol address being scored
    /// @param _provScores Array of provider scores being revealed that after hashing produce the _commitHash
    function reveal(bytes32 _commitHash, address _valAddr, address _pcAddr, ProviderScore[] memory _provScores) public whenNotPaused {
        onlyWhenRegistryAndTokenSet();
        // check if the reveal is not too early or too late
        if (block.number <= currentEpochEndBlockNum || block.number > currentEpochEndBlockNum + REVEAL_WINDOW)
            revert ForestCommon.InvalidState();
        // validate PC based on call arg
        IForestProtocol pc = getCheckedPc(_pcAddr);
        // check if hash exists and has relevant status
        EpochScoreGranular storage granularScore = currentPcAddrToEpochScoreMap[_pcAddr][currentHashToIndexMap[_commitHash]];
        if(granularScore.status != CommitStatus.COMMITED)
            revert ForestCommon.InvalidState();
        // check if this commitment belongs to the _valAddr
        if(granularScore.valId != registry.getActor(_valAddr).id)
            revert ForestCommon.Unauthorized();
        // check if _msgSender() is a representative of a registered active validator
        if (!pc.isActiveRegisteredAndAuthorizedRepresentative(ForestCommon.ActorType.VALIDATOR, _valAddr, _msgSender()))
            revert ForestCommon.OnlyOwnerOrOperatorAllowed();

        // check if hashes add up
        bytes32 computedHash = computeHash(_provScores);
        if (_commitHash != computedHash)
            revert ForestCommon.InvalidAddress();

        for (uint i = 0; i < _provScores.length; i++) {
            // check if agreementId exists
            ForestCommon.Agreement memory agreement = pc.getAgreement(_provScores[i].agreementId);
            
            if (agreement.status == ForestCommon.Status.NONE)
                revert ForestCommon.ObjectNotActive();
            // check if agreement points to provider address
            if (registry.getActor(pc.getOffer(agreement.offerId).ownerAddr).id != _provScores[i].provId)
                revert ForestCommon.ProviderDoesNotMatchAgreement(_provScores[i].provId, agreement.id);
            // check if agreement userAddr is equal to _msgSender() or _valAddr
            if (agreement.userAddr != _msgSender() && agreement.userAddr != _valAddr)
                revert ForestCommon.ValidatorDoesNotMatchAgreement(granularScore.valId , agreement.id);
        }

        // save
        granularScore.provScores = _provScores;
        granularScore.status = CommitStatus.REVEALED;

        emit CommitRevealed(_valAddr, _pcAddr, _commitHash, currentEpochEndBlockNum);
    }

    /// @notice Closes the currently processed epoch and aggregates all revealed scores as well as computes scores for validators
    /// @dev Can only be called after the reveal window has ended
    function closeEpoch() public whenNotPaused {
        onlyWhenRegistryAndTokenSet();
        // check if the close is not too early 
        if(block.number <= currentEpochEndBlockNum + REVEAL_WINDOW)
            revert ForestCommon.InvalidState();
        
        // aggregate scores in each PC and save in epochToAggregatedScoreMap
        epochToAggregatedScoreMap[currentEpochEndBlockNum] = aggregateScores(); // TODO: possibly call off-chain zk computation engine

        // reset relevant variables
        // step 1: clear global simple vars
        currentEpochEndBlockNum = computeCurrentEpochEndBlockNum();

        // step 2: clear mappings: currentPcAddrToEpochScoreMap, currentHashToIndexMap, currentPcAddressesMap
        for (uint256 i = 0; i < currentPcAddresses.length; i++) {
            address pcAddress = currentPcAddresses[i];

            // clear currentHashToIndexMap entries for each EpochScoreGranular
            EpochScoreGranular[] storage epochScores = currentPcAddrToEpochScoreMap[pcAddress];
            for (uint256 j = 0; j < epochScores.length; j++) {
                bytes32 commitHash = epochScores[j].commitHash;
                delete currentHashToIndexMap[commitHash];
            }

            // clear the EpochScoreGranular array for the PC address
            delete currentPcAddrToEpochScoreMap[pcAddress];

            // clear mapping used for uniqueness check
            delete currentPcAddressesMap[pcAddress];
        }

        // step 3: clear: currentPcAddresses
        delete currentPcAddresses;
    }

    /// @notice Clears temporary data structures used in score aggregation
    /// @dev Internal function called after aggregation is complete
    function clearAggregateScoresHelpers() internal {
        for (uint24 i = 0; i < uniqueActors.length; i++) 
            delete actorIdToAggregateScore[uniqueActors[i]];
        delete provIdToScore;
        delete provIdToTestNum;
        delete valIdToTestNum;
        delete uniqueActors;
    }

    /// @notice Calculates aggregate weighted scores for providers and validators across all PCs.
    /// @dev Used internally in closeEpoch()
    /// @return Array of aggregated scores for each PC
    function aggregateScores() internal returns (EpochScoreAggregate[] memory) {
        address[] memory pcAddresses = registry.getAllPcAddresses();
        EpochScoreAggregate[] memory aggregates = new EpochScoreAggregate[](pcAddresses.length);

        for (uint256 i = 0; i < pcAddresses.length; i++) {
            address pcAddress = pcAddresses[i];
            IForestProtocol pc = IForestProtocol(pcAddress);

            // iterate through all the epoch scores for this pc address and provide scores within each epoch score
            EpochScoreGranular[] memory epochScores = currentPcAddrToEpochScoreMap[pcAddress];
            // if there are no commits, save empty object for this PC
            if (epochScores.length != 0) {
                // initialize the arrays with first entry so it's easier to properly find indexes using mapping (non-existant entry in array will return 0 index, so we don't want to use it)
                provIdToScore.push([0,0]);
                provIdToTestNum.push([0,0]);
                valIdToTestNum.push([0,0]);
                uniqueActors.push(0);

                for (uint256 j = 0; j < epochScores.length; j++) {
                    // take into account only Revealed commits
                    if (epochScores[j].status != CommitStatus.REVEALED)
                        continue;
                    for (uint256 k = 0; k < epochScores[j].provScores.length; k++) {
                        uint256 index = actorIdToAggregateScore[epochScores[j].provScores[k].provId];
                        if (index == 0) {
                            provIdToScore.push([epochScores[j].provScores[k].provId, epochScores[j].provScores[k].score]);
                            provIdToTestNum.push([epochScores[j].provScores[k].provId, 1]);
                            actorIdToAggregateScore[epochScores[j].provScores[k].provId] = provIdToScore.length - 1;
                            uniqueActors.push(epochScores[j].provScores[k].provId);
                        } else {
                            provIdToScore[index][1] += epochScores[j].provScores[k].score;
                            provIdToTestNum[index][1] += 1;
                        }

                        index = actorIdToAggregateScore[epochScores[j].valId];
                        if (index == 0) {
                            valIdToTestNum.push([epochScores[j].valId, 1]);
                            actorIdToAggregateScore[epochScores[j].valId] = valIdToTestNum.length - 1;
                            uniqueActors.push(epochScores[j].valId);
                        } else {
                            valIdToTestNum[index][1] += 1;
                        }
                    }
                }

                // once the summation is complete, 1) substitue the 0-indexed fillers with last elements of each of the array and 2) take an average of the provider scores
                // step 1)
                provIdToScore[0] = provIdToScore[provIdToScore.length - 1];
                provIdToScore.pop();
                provIdToTestNum[0] = provIdToTestNum[provIdToTestNum.length - 1];
                provIdToTestNum.pop();
                valIdToTestNum[0] = valIdToTestNum[valIdToTestNum.length - 1];
                valIdToTestNum.pop();
                uniqueActors[0] = uniqueActors[uniqueActors.length - 1];
                uniqueActors.pop();

                // step 2)
                for (uint256 j = 0; j < provIdToScore.length; j++) {
                    if (provIdToTestNum[j][1] == 0) {
                        provIdToScore[j][1] = 0;
                    } else {
                        provIdToScore[j][1] = provIdToScore[j][1] / provIdToTestNum[j][1];
                    }
                }
            }
            
            aggregates[i] = EpochScoreAggregate(pcAddress, pc.getActiveAgreementsValue(), provIdToScore, valIdToTestNum);
            clearAggregateScoresHelpers();
        }
        return aggregates;
    }

    // checks whether the pc is registered in the Registry contract and active
    function getCheckedPc(address _pcAddr) internal view returns (IForestProtocol) {
        IForestProtocol pc = IForestProtocol(_pcAddr);
        if (!registry.isPcRegisteredAndActive(_pcAddr))
            revert ForestCommon.ObjectNotActive();
        return pc;
    }

    /// @notice Allows actors to deposit collateral for a specific PC
    /// @dev Collateral is required for providers and validators to participate. Since the caller can be a PC during Actor registration, we can't simpyly use _msgSender. Can be called only by the owner of the actor. Not an operator.
    /// @param _pcAddr Address of the Protocol
    /// @param _actorType Type of actor (Provider or Validator)
    /// @param _sender Owner address of the actor for which collateral is being deposited
    /// @param _amount Amount of collateral to deposit
    function topupActorCollateral(address _pcAddr, ForestCommon.ActorType _actorType, address _sender, uint256 _amount) public whenNotPaused {
        onlyWhenRegistryAndTokenSet();
        IForestProtocol pc = getCheckedPc(_pcAddr);
        // validate args
        if (_amount <= 0) revert ForestCommon.InsufficientAmount();
        // if the sender is not the pc itself, then the sender must be a registered, owner actor
        if (_msgSender() != _pcAddr && !(pc.isActiveRegisteredOwner(_actorType, _sender) && _sender == _msgSender()))
            revert ForestCommon.Unauthorized();

        // transfer tokens
        forestToken.transferFrom(_sender, address(this), _amount);

        // update the balance
        actorCollateralBalanceOf[_pcAddr][_sender] += _amount;

        emit ActorCollateralTopuped(_sender, _amount);
    }

    /// @notice Allows actors to withdraw their collateral
    /// @dev Can only withdraw if remaining amount meets minimum collateral requirement. Can be called only by the owner of the actor. Operator not allowed.
    /// @param _pcAddr Address of the Protocol
    /// @param _actorType Type of actor (Provider or Validator)
    /// @param _amount Amount of collateral to withdraw
    function withdrawActorCollateral(
        address _pcAddr,
        ForestCommon.ActorType _actorType,
        uint256 _amount
    ) public whenNotPaused {
        onlyWhenRegistryAndTokenSet();
        IForestProtocol pc = getCheckedPc(_pcAddr);
        // validate args
        if (_amount <= 0) revert ForestCommon.InsufficientAmount();
        if (!pc.isActiveRegisteredOwner(_actorType, _msgSender()))
            revert ForestCommon.OnlyOwnerAllowed();
        // TODO: possibly we should add a termsUpdateDelay-based logic

        uint256 currentCollateral = actorCollateralBalanceOf[_pcAddr][ _msgSender()];
        
        if (currentCollateral < _amount)
            _amount = currentCollateral; // TODO: unify behaviour in such case, throw error or pay out max?
        if (currentCollateral - _amount < pc.getMinCollateral())
            revert ForestCommon.InsufficientAmount();
        
        actorCollateralBalanceOf[_pcAddr][_msgSender()] -= _amount;
        
        forestToken.transferFrom(address(this), _msgSender(), _amount);
        
        emit ActorCollateralWithdrawn(_msgSender(), _amount);
    }

    /***********************************|
    |      OZ Pausable Related          |
    |__________________________________*/

    /// @notice Pauses the contract
    function pause() external onlyOwner() {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner() {
        _unpause(); 
    }

    /***********************************|
    |         Helper Functions          |
    |__________________________________*/

    /// @notice Computes hash of provider scores for commitment
    /// @dev Used to create commitment hash before revealing scores
    /// @param _provScores Array of provider scores to hash
    /// @return Hash of the encoded provider scores
    function computeHash(ProviderScore[] memory _provScores) public pure returns (bytes32) {
        return keccak256(abi.encode(_provScores));
    }

    /// @notice Calculates the block number when current epoch ends
    /// @dev Uses constant EPOCH_LENGTH to determine epoch boundaries
    /// @return Block number when current epoch ends
    function computeCurrentEpochEndBlockNum() public view returns (uint256) {
        return block.number - (block.number % EPOCH_LENGTH) + EPOCH_LENGTH;
    }

    /// @notice Validates if a given block number is a valid epoch end
    /// @dev Checks if block number aligns with epoch length and is after first epoch
    /// @param _epochEndBlockNum Block number to validate
    /// @return True if block number is valid epoch end
    function isValidEpochEndBlockNum(uint256 _epochEndBlockNum) public view returns (bool) {
        return (_epochEndBlockNum % EPOCH_LENGTH == 0) && _epochEndBlockNum >= firstEpochEndBlockNum;
    }

    /// @notice Ensures that the registry and forest contracts are set
    function onlyWhenRegistryAndTokenSet() public view {
        if (address(registry) == address(0) || address(forestToken) == address(0))
            revert ForestCommon.InvalidAddress();
    }

    /***********************************|
    |         Setter Functions          |
    |__________________________________*/

    // TODO: remove after testing
    // @notice FOR TESTING ONLY, revert after testing: Sets the epoch length
    /// @param _epochLength New epoch length
    function setEpochLength(uint256 _epochLength) external onlyOwner {
        EPOCH_LENGTH = _epochLength;
    }

    // TODO: remove after testing
    /// @notice FOR TESTING ONLY, revert after testing: Sets the reveal window
    /// @param _revealWindow New reveal window
    function setRevealWindow(uint256 _revealWindow) external onlyOwner {
        REVEAL_WINDOW = _revealWindow;
    }

    /***********************************|
    |         Getter Functions          |
    |__________________________________*/

    /// @notice Gets the collateral balance of an actor for a specific PC
    /// @param _pcAddr Address of the Protocol
    /// @param _addr Owner address of the actor to get the collateral balance for
    /// @return collateralBalance Collateral balance of the given actor for the specified PC
    function getCollateralBalanceOf(address _pcAddr, address _addr) external view returns (uint256) {
        return actorCollateralBalanceOf[_pcAddr][_addr];
    }

    /// @notice Gets the block number when the currently processed epoch ends
    /// @return currentEpochEndBlockNum Block number when the currently processed epoch ends
    function getCurrentEpochEndBlockNum() external view returns (uint256) {
        return currentEpochEndBlockNum;
    }

    /// @notice Gets the number of PCs that have submitted commits for the currently processed epoch
    /// @return pcNum Number of PCs that have submitted commits for the currently processed epoch
    function getPcNumThisEpoch() external view returns (uint256) {
        return currentPcAddresses.length;
    }

    /// @notice Gets the granular scores for a specific PC for the currently processed epoch
    /// @param _pcAddr Address of the Protocol
    /// @return epochScores Granular scores for the specified PC for the currently processed epoch
    function getEpochScoresGranular(address _pcAddr) external view returns (EpochScoreGranular[] memory) {
        return currentPcAddrToEpochScoreMap[_pcAddr];
    }

    /// @notice Gets the index of a commit hash
    /// @param _commitHash Commit hash to get the index for
    /// @return index Index of the commit hash
    function getHashToIndex(bytes32 _commitHash) external view returns (uint256) {
        return currentHashToIndexMap[_commitHash];
    }

    /// @notice Gets the aggregated scores for all PCs for a specific epoch
    /// @param _epoch Epoch number to get the aggregated scores for
    /// @return aggregatedScores Aggregated scores for all PCs for the specified epoch
    function getEpochScoresAggregate(uint256 _epoch) external view returns (EpochScoreAggregate[] memory) {
        return epochToAggregatedScoreMap[_epoch];
    }

}

    /***********************************|
    |        Questions & TODOs          |
    |__________________________________*/
    /*

    * TODO: add hash validation
    *
    * 

    */
