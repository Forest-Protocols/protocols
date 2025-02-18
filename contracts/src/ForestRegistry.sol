// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./ForestCommon.sol";
import "./ForestProtocol.sol";
import "./interfaces/IForestProtocol.sol";
import "./interfaces/IForestToken.sol";

contract ForestRegistry is Ownable, Pausable {

    using Strings for string;

    /***********************************|
    |              Events               |
    |__________________________________*/

    event NewActorRegistered(
        ForestCommon.ActorType indexed actorType,
        address indexed ownerAddr,
        address operatorAddr,
        address billingAddr,
        string detailsLink
    );

    event NewProtocolRegistered(
        address indexed addr,
        address indexed ownerAddr,
        string detailsLink
    );

    event ActorDetailsUpdated(
        ForestCommon.ActorType indexed actorType,
        address indexed ownerAddr,
        address operatorAddr,
        address billingAddr,
        string detailsLink
    );

    event PcDetailsUpdated(
        address indexed ownerAddr,
        address indexed operatorAddr,
        string detailsLink
    );

    event ProtocolParamUpdated(
        string indexed paramName
    );

    event PcStatusUpdated(
        address indexed ownerAddr,
        ForestCommon.Status status
    );

    /***********************************|
    |         Protocol Params           |
    |__________________________________*/

    struct ProtocolSettings {
        uint256 revenueShare; //  percentage of USDC fees that get deducted from user payments for resources and go to the Treasury, accepted range: 0 - 10000
        uint256 maxPcsNum; // maximum number of PCs allowed in the protocol, no limit: 0, limit: >= 1
        uint256 actorRegFee; // amount of FOREST tokens to be transferred to the Treasury for actor registration in the protocol (portion of the fee is burned)
        uint256 pcRegFee; // amount of FOREST tokens to be transferred to the Treasury for PC registration in the protocol (portion of the fee is burned)
        uint256 actorInPcRegFee; // amount of FOREST tokens to be transferred to the Treasury for actor registration in a PC (portion of the fee is burned). This is a protocol-wide minimum fee. Additional fee can be set on the PC level.
        uint256 offerInPcRegFee; // amount of FOREST tokens to be transferred to the Treasury for offer registration in a PC (portion of the fee is burned). This is a protocol-wide minimum fee. Additional fee can be set on the PC level.
        uint256 burnRatio; // percentage of protocol earnings from registration fees that gets burned, the rest goes to the Treasury, accepted range: 0 - 10000
        address treasuryAddr; // address of the Treasury
    }

    /***********************************|
    |            Variables              |
    |__________________________________*/

    address immutable pcImplementation; // address of the PC contract with the logic. When new PCs are created, a clone of this contract is deployed that keeps track of the PC's state but uses the logic from the original PC contract.
    
    ProtocolSettings settings; // current settings values for the protocol

    IERC20 usdcToken; // interface object for the USDC token
    IForestToken forestToken; // interface object for the FOREST token
    address slasherAddr; // address of the slasher contract
   
    uint24 actorIdCounter;

    mapping(address => ForestCommon.Actor) actorsMap; // map of address to actor
    mapping(address => ForestCommon.Status) pcsMap; // map of address to pc status
    mapping(uint24 => address) actorIdToAddrMap; // map of actor id to address

    address[] providerAddrs; // array of provider addresses 
    address[] validatorAddrs; // array of validator addresses
    address[] pcOwnerAddrs; // array of PC owner addresses
    address[] pcAddrs; // array of PC addresses

    /***********************************|
    |            Constructor            |
    |__________________________________*/

    constructor(
        address _slasherAddr,
        address _usdcTokenAddr,
        address _forestTokenAddr,
        uint256 _revenueShare,
        uint256 _maxPcsNum,
        uint256 _actorRegFee,
        uint256 _pcRegFee,
        uint256 _actorInPcRegFee,
        uint256 _offerInPcRegFee,
        address _treasuryAddr,
        uint256 _burnRatio) Ownable(_msgSender()) {
        if (_slasherAddr == address(0) || _usdcTokenAddr == address(0) || _forestTokenAddr == address(0) || _treasuryAddr == address(0))
            revert ForestCommon.InvalidAddress();
        
        slasherAddr = _slasherAddr;
        usdcToken = IERC20(_usdcTokenAddr);
        forestToken = IForestToken(_forestTokenAddr);

        pcImplementation = address(new ForestProtocol());

        settings = ProtocolSettings({
            revenueShare: _revenueShare,
            maxPcsNum: _maxPcsNum,
            actorRegFee: _actorRegFee,
            pcRegFee: _pcRegFee,
            actorInPcRegFee: _actorInPcRegFee,
            offerInPcRegFee: _offerInPcRegFee,
            treasuryAddr: _treasuryAddr,
            burnRatio: _burnRatio
        });
    }

    /***********************************|
    |      Modifiers                   |
    |__________________________________*/

    // function _onlyRegisteredPc() internal view {
    //     if (pcsMap[_msgSender()] == ForestCommon.Status.NONE)
    //         revert ForestCommon.ActorNotRegisteredInRegistry();
    // }

    /***********************************|
    |      Registry Functions           |
    |__________________________________*/
    
    /// @notice Registers a new actor in the protocol and pays the registration fee in FOREST token
    /// @dev Actors can be Providers, Validators, or PC Owners
    /// @param _actorType Type of actor to register
    /// @param _operatorAddr (Optional) Operator address for the actor. If not provided, the operator address will be set to the owner address.
    /// @param _billingAddr (Optional) Billing address for the actor. If not provided, the billing address will be set to the owner address.
    /// @param _detailsLink Hash of the actor details file.
    /// @return id ID of the new actor
    function registerActor(
        ForestCommon.ActorType _actorType,
        address _operatorAddr,
        address _billingAddr,
        string memory _detailsLink
    ) external whenNotPaused() returns (uint256) {
        // check if actor is already registered
        if (actorsMap[_msgSender()].actorType != ForestCommon.ActorType.NONE)
            revert ForestCommon.ActorAlreadyRegistered();

        // handle default values for alternative addresses
        if (_billingAddr == address(0)) {
            _billingAddr = _msgSender();
        }
        if (_operatorAddr == address(0)) {
            _operatorAddr = _msgSender();
        }

        // transfer registration fee (in forest token) to the treasury
        this.transferTokensToTreasury(_msgSender(), settings.actorRegFee);

        uint24 id = actorIdCounter++;

        ForestCommon.Actor memory actor = ForestCommon.Actor(
            id,
            block.timestamp,
            ForestCommon.Status.ACTIVE,
            _actorType,
            _msgSender(),
            _operatorAddr,
            _billingAddr,
            _detailsLink
        );

        actorsMap[_msgSender()] = actor;
        actorIdToAddrMap[id] = _msgSender();
        if (_actorType == ForestCommon.ActorType.PROVIDER)
            providerAddrs.push(_msgSender());
        else if (_actorType == ForestCommon.ActorType.VALIDATOR)
            validatorAddrs.push(_msgSender());
        else 
            pcOwnerAddrs.push(_msgSender());

         // emit an event
        emit NewActorRegistered(
            _actorType,
            _msgSender(),
            _operatorAddr,
            _billingAddr,
            _detailsLink
        );

        // return the id of the new actor
        return id;
    }

    /// @notice Updates the details of an actor
    /// @dev Only the owner of the actor can update the details
    /// @param _actorType Type of actor to update
    /// @param _operatorAddr (Optional) New operator address for the actor, if not provided, the operator address will be set to the owner address
    /// @param _billingAddr (Optional) New billing address for the actor, if not provided, the billing address will be set to the owner address
    /// @param _detailsLink New hash of the actor details
    function updateActorDetails(
        ForestCommon.ActorType _actorType,
        address _operatorAddr,
        address _billingAddr,
        string memory _detailsLink
    ) external {
        // check sender if he's an owner and active actor of the given type
        if (!isRegisteredActiveActor(_actorType, _msgSender()))
            revert ForestCommon.OnlyOwnerAllowed();

        // validate params
        // handle default values for alternative addresses
        if (_billingAddr == address(0)) {
            _billingAddr = _msgSender();
        }
        if (_operatorAddr == address(0)) {
            _operatorAddr = _msgSender();
        }
        if (bytes(_detailsLink).length == 0)
            revert ForestCommon.InvalidParam();
        
        ForestCommon.Actor storage actor = actorsMap[_msgSender()];

        actor.operatorAddr = _operatorAddr;
        actor.billingAddr = _billingAddr;
        actor.detailsLink = _detailsLink;

        emit ActorDetailsUpdated(
            _actorType,
            _msgSender(),
            _operatorAddr,
            _billingAddr,
            _detailsLink
        );
    }

    // TODO: unregister an actor whenNotPaused()

    /// @notice Creates a new Protocol by deploying a new Clone contract and initializing it with the provided parameters
    /// @dev Only registered PC Owners can create new PCs
    /// @param _maxValsNum Maximum number of validators allowed, no limit: 0, limit: >= 1
    /// @param _maxProvsNum Maximum number of providers allowed, no limit: 0, limit: >= 1
    /// @param _minCollateral Minimum collateral required for actors
    /// @param _valRegFee Registration fee for validators. There might be also a protocol-wide minimum fee set regardless of this fee.
    /// @param _provRegFee Registration fee for providers. There might be also a protocol-wide minimum fee set regardless of this fee.
    /// @param _offerRegFee Registration fee for offers. There might be also a protocol-wide minimum fee set regardless of this fee.
    /// @param _termUpdateDelay Delay required for term updates (in seconds)
    /// @param _provShare Provider's share of rewards emitted to this PC, accepted range: 0 - 10000
    /// @param _valShare Validator's share of rewards emitted to this PC, accepted range: 0 - 10000   
    /// @param _pcOwnerShare PC Owner's share of rewards emitted to this PC, accepted range: 0 - 10000
    /// @param _detailsLink Hash of the PC details file
    /// @return Address of the newly created PC
    function createProtocol(
        uint _maxValsNum,
        uint _maxProvsNum,
        uint _minCollateral,
        uint _valRegFee,
        uint _provRegFee,
        uint _offerRegFee,
        uint _termUpdateDelay,
        uint _provShare,
        uint _valShare,
        uint _pcOwnerShare,
        string memory _detailsLink
    ) public whenNotPaused() returns (address) {
        // check sender if he's an owner and active PC_OWNER actor
        if (!isRegisteredActiveActor(ForestCommon.ActorType.PC_OWNER, _msgSender()))
            revert ForestCommon.OnlyOwnerAllowed();
        // validate params TODO: move to PC contract specific functions
        if(_provShare + _valShare + _pcOwnerShare != ForestCommon.HUNDRED_PERCENT_POINTS)
            revert ForestCommon.InvalidParam();
        if(bytes(_detailsLink).length == 0)
            revert ForestCommon.InvalidParam();

        // validate state against settings
        if(settings.maxPcsNum != 0 && settings.maxPcsNum <= pcAddrs.length)
            revert ForestCommon.LimitExceeded();

        // pay the registration fee
        this.transferTokensToTreasury(_msgSender(), settings.pcRegFee);

        // deploy the new Protocol contract using OpenZeppelin's Clones library
        address cloneAddr = Clones.clone(pcImplementation);

        // initialize the new Protocol contract
        IForestProtocol newPc = IForestProtocol(cloneAddr);
        
        newPc.initialize(address(this));
        newPc.setMaxActors(_maxValsNum, _maxProvsNum);
        newPc.setMinCollateral(_minCollateral);
        newPc.setFees(_valRegFee, _provRegFee, _offerRegFee);
        newPc.setTermUpdateDelay(_termUpdateDelay);
        newPc.setEmissionShares(_provShare, _valShare, _pcOwnerShare);
        newPc.setDetailsLink(_detailsLink);

        // add the new address to the registry
        pcAddrs.push(cloneAddr);
        pcsMap[cloneAddr] = ForestCommon.Status.NOTACTIVE;

        // unpause, change registry state for the pc to active
        // newPc.unpause();
        pcsMap[cloneAddr] = ForestCommon.Status.ACTIVE;

        // change the owner to the sender
        newPc.setOwner(_msgSender());

        // emit an event
        emit NewProtocolRegistered(
            cloneAddr,
            _msgSender(),
            _detailsLink
        );

        return cloneAddr;
    }

    // TODO: unregister / delete a Protocol whenNotPaused()

    /***********************************|
    |       Pausable Related            |
    |__________________________________*/

    /// @notice Pauses the registry
    function pause() external onlyOwner() {
        _pause();
    }

    /// @notice Unpauses the registry
    function unpause() external onlyOwner() {
        _unpause(); 
    }

    // inteded to be called by PC smart contract
    // function pausePc() external {
    //     _onlyRegisteredPc();
    //     if (pcsMap[_msgSender()] == ForestCommon.Status.ACTIVE) {
    //         pcsMap[_msgSender()] = ForestCommon.Status.NOTACTIVE;
    //         emit PcStatusUpdated(_msgSender(), ForestCommon.Status.NOTACTIVE);
    //     }
    //     else 
    //         revert ForestCommon.WrongState();
    // }

    // // inteded to be called by PC smart contract
    // function unpausePc() external {
    //     _onlyRegisteredPc();
    //     if (pcsMap[_msgSender()] == ForestCommon.Status.NOTACTIVE) {
    //         pcsMap[_msgSender()] = ForestCommon.Status.ACTIVE;
    //         emit PcStatusUpdated(_msgSender(), ForestCommon.Status.ACTIVE);
    //     }
    //     else 
    //         revert ForestCommon.WrongState();
    // }

    /***********************************|
    |      Helper Functions           |
    |__________________________________*/

    /// @notice Transfers tokens to the treasury and burns a portion of it according to the burn ratio setting
    /// @param _from Address of the sender
    /// @param _amount Amount of tokens to transfer
    function transferTokensToTreasury(address _from, uint256 _amount) external {
        uint256 amountBurn = settings.burnRatio * _amount / ForestCommon.HUNDRED_PERCENT_POINTS; // assumes settings.burnRatio is in integer-based 2 decimal points precision percentage points
        uint256 amountTreasury = _amount - amountBurn;
        forestToken.transferFrom(_from, settings.treasuryAddr, amountTreasury);    
        forestToken.burnFrom(_from, amountBurn);
    }

    /// @notice Checks if an actor is active
    /// @param _owner Owner address of the actor
    /// @return isActive True if the actor is active, false otherwise
    function isActiveActor(address _owner) public view returns (bool isActive) {
        return actorsMap[_owner].status == ForestCommon.Status.ACTIVE;
    }

    /// @notice Checks if an actor is registered and active
    /// @param _actorType Type of actor
    /// @param _owner Owner address of the actor
    /// @return isRegistered True if the actor is registered and active, false otherwise
    function isRegisteredActiveActor(ForestCommon.ActorType _actorType, address _owner) public view returns (bool isRegistered) {
        return isActiveActor(_owner) && actorsMap[_owner].actorType == _actorType;
    }

    /// @notice Checks if an actor is registered and active and if the sender is the owner or operator of the actor
    /// @param _actorType Type of actor
    /// @param _owner Owner address of the actor
    /// @param _senderAddr Sender address
    /// @return isRegistered True if the actor is registered and active and the sender is the owner or operator of the actor, false otherwise
    function isOwnerOrOperatorOfRegisteredActiveActor(ForestCommon.ActorType _actorType, address _owner, address _senderAddr) external view returns (bool isRegistered) {
        return isRegisteredActiveActor(_actorType, _owner) && (actorsMap[_owner].ownerAddr == _senderAddr || actorsMap[_owner].operatorAddr == _senderAddr);
    }

    /***********************************|
    |         Setter Functions          |
    |__________________________________*/

    /// @notice Sets the revenue share
    /// @dev Can only be called by the owner
    /// @param _newValue New revenue share, accepted range: 0 - 10000
    function setRevenueShare(uint _newValue) external onlyOwner() {
        if (_newValue > ForestCommon.HUNDRED_PERCENT_POINTS) revert ForestCommon.InvalidParam();
        settings.revenueShare = _newValue;
        emit ProtocolParamUpdated("revenueShare");
    }

    /// @notice Sets the maximum number of PCs
    /// @dev Can only be called by the owner
    /// @param _newValue New maximum number of PCs, no limit: 0, limit: >= 1
    function setMaxPcsNum(uint _newValue) external onlyOwner() {
        settings.maxPcsNum = _newValue;
        emit ProtocolParamUpdated("maxPcsNum");
    }

    /// @notice Sets the registration fee for actors
    /// @dev Can only be called by the owner
    /// @param _newValue New registration fee for actors in FOREST tokens
    function setActorRegFee(uint _newValue) external onlyOwner() {
        settings.actorRegFee = _newValue;
        emit ProtocolParamUpdated("actorRegFee");
    }

    /// @notice Sets the registration fee for PCs
    /// @dev Can only be called by the owner
    /// @param _newValue New registration fee for PCs in FOREST tokens
    function setPcRegFee(uint _newValue) external onlyOwner() {
        settings.pcRegFee = _newValue;
        emit ProtocolParamUpdated("pcRegFee");
    }

    /// @notice Sets the registration fee for actors in PCs
    /// @dev Can only be called by the owner
    /// @param _newValue New registration fee for actors in PCs in FOREST tokens
    function setActorInPcRegFee(uint _newValue) external onlyOwner() {
        settings.actorInPcRegFee = _newValue;
        emit ProtocolParamUpdated("actorInPcRegFee");
    }

    /// @notice Sets the registration fee for offers in PCs
    /// @dev Can only be called by the owner
    /// @param _newValue New registration fee for offers in PCs in FOREST tokens
    function setOfferInPcRegFee(uint _newValue) external onlyOwner() {
        settings.offerInPcRegFee = _newValue;
        emit ProtocolParamUpdated("offerInPcRegFee");
    }

    /// @notice Sets the burn ratio
    /// @dev Can only be called by the owner
    /// @param _newValue New burn ratio, accepted range: 0 - 10000
    function setBurnRatio(uint _newValue) external onlyOwner() {
        if (_newValue > ForestCommon.HUNDRED_PERCENT_POINTS) revert ForestCommon.InvalidParam();
        settings.burnRatio = _newValue;
        emit ProtocolParamUpdated("burnRatio");
    }

    /// @notice Sets the treasury address
    /// @dev Can only be called by the owner
    /// @param _newValue New treasury address
    function setTreasuryAddrParam(address _newValue) external onlyOwner() {
        settings.treasuryAddr = _newValue;
        emit ProtocolParamUpdated("treasuryAddr");
    }

    /// @notice Sets the slasher address
    /// @dev Can only be called by the owner
    /// @param _newValue New slasher address (can't be zero address)
    function setSlasherAddress(address _newValue) external onlyOwner() {
        if (_newValue == address(0))
            revert ForestCommon.InvalidAddress();
        
        slasherAddr = _newValue;
        emit ProtocolParamUpdated("slasherAddr");
    }

    /// @notice Sets the USDC token address
    /// @dev Can only be called by the owner
    /// @param _newValue New USDC token address (can't be zero address)
    function setUsdcTokenAddress(address _newValue) external onlyOwner() {
        if (_newValue == address(0))
            revert ForestCommon.InvalidAddress();
        usdcToken = IERC20(_newValue);
        emit ProtocolParamUpdated("usdcToken");
    }

    /// @notice Sets the Forest token address
    /// @dev Can only be called by the owner
    /// @param _newValue New Forest token address (can't be zero address)
    function setForestTokenAddress(address _newValue) external onlyOwner() {
        if (_newValue == address(0))
            revert ForestCommon.InvalidAddress();
        forestToken = IForestToken(_newValue);
        emit ProtocolParamUpdated("forestToken");
    }

    /***********************************|
    |         Getter Functions          |
    |__________________________________*/

    /// @notice Gets all PC owners
    /// @return _pcos Array of all PC owners
    function getAllPcOwners() external view returns (ForestCommon.Actor[] memory) {
        ForestCommon.Actor[] memory _pcos = new ForestCommon.Actor[](pcOwnerAddrs.length);
        uint256 count = 0;
        for (uint256 i = 0; i < pcOwnerAddrs.length; i++) {
            _pcos[count] = actorsMap[pcOwnerAddrs[count]];
            count++;
        }
        return _pcos;
    }
    
    /// @notice Gets all providers
    /// @return _providers Array of all providers
    function getAllProviders() external view returns (ForestCommon.Actor[] memory) {
        ForestCommon.Actor[] memory _providers = new ForestCommon.Actor[](providerAddrs.length);
        uint256 count = 0;
        for (uint256 i = 0; i < providerAddrs.length; i++) {
            _providers[count] = actorsMap[providerAddrs[count]];
            count++;
        }
        return _providers;
    }

    /// @notice Gets the number of providers
    /// @return _providersCount Number of providers
    function getProvidersCount() external view returns (uint256) {
        return providerAddrs.length;
    }

    /// @notice Gets all PC addresses
    /// @return _pcAddresses Array of all PC addresses
    function getAllPcAddresses() external view returns (address[] memory) {
        return pcAddrs;
    }

    /// @notice Gets the number of PCs
    /// @return _pcsCount Number of PCs
    function getPcsCount() external view returns (uint256) {
        return pcAddrs.length;
    }

    /// @notice Checks if a PC is registered and active
    /// @param _addr Address of the PC
    /// @return isRegistered True if the PC is registered and active, false otherwise
    function isPcRegisteredAndActive(address _addr) external view returns (bool) {
        return pcsMap[_addr] == ForestCommon.Status.ACTIVE;
    }

    /// @notice Gets all validators
    /// @return _validators Array of all validators
    function getAllValidators() external view returns (ForestCommon.Actor[] memory) {
        ForestCommon.Actor[] memory _validators = new ForestCommon.Actor[](
            validatorAddrs.length
        );
        uint256 count = 0;
        for (uint256 i = 0; i < validatorAddrs.length; i++) {
            _validators[count] = actorsMap[validatorAddrs[count]];
            count++;
        }
        return _validators;
    }

    /// @notice Gets the number of validators
    /// @return _validatorsCount Number of validators
    function getValidatorsCount() external view returns (uint256) {
        return validatorAddrs.length;
    }

    /// @notice Gets an actor by address
    /// @param _addr Owner address of the actor
    /// @return _actor Actor
    function getActor(address _addr)  external view returns (ForestCommon.Actor memory) {
        return actorsMap[_addr];
    }

    /// @notice Gets the number of actors (providers, validators, and PC owners)
    /// @return _actorCount Number of actors
    function getActorCount() external view returns (uint256) {
        return providerAddrs.length + validatorAddrs.length + pcOwnerAddrs.length;
    }

    /// @notice Gets the revenue share
    /// @return _revenueShare Revenue share 
    function getRevenueShare() external view returns (uint256) {
        return settings.revenueShare;
    }

    /// @notice Gets the maximum number of PCs
    /// @return _maxPcsNum Maximum number of PCs
    function getMaxPcsNum() external view returns (uint256) {
        return settings.maxPcsNum;
    }

    /// @notice Gets the registration fee for actors 
    /// @return _actorRegFee Registration fee for actors in FOREST tokens
    function getActorRegFee() external view returns (uint256) {
        return settings.actorRegFee;
    }

    /// @notice Gets the registration fee for PCs
    /// @return _pcRegFee Registration fee for PCs in FOREST tokens
    function getPcRegFee() external view returns (uint256) {
        return settings.pcRegFee;
    }

    /// @notice Gets the registration fee for actors in PCs
    /// @return _actorInPcRegFee Registration fee for actors in PCs in FOREST tokens
    function getActorInPcRegFee() external view returns (uint256) {
        return settings.actorInPcRegFee;
    }

    /// @notice Gets the registration fee for offers in PCs
    /// @return _offerInPcRegFee Registration fee for offers in PCs in FOREST tokens
    function getOfferInPcRegFee() external view returns (uint256) {
        return settings.offerInPcRegFee;
    }

    /// @notice Gets the burn ratio
    /// @return _burnRatio Burn ratio
    function getBurnRatio() external view returns (uint256) {
        return settings.burnRatio;
    }

    /// @notice Gets the treasury address
    /// @return _treasuryAddr Treasury address
    function getTreasuryAddr() external view returns (address) {
        return settings.treasuryAddr;
    }

    /// @notice Gets the Forest token address
    /// @return _forestTokenAddr Forest token address
    function getForestTokenAddr() external view returns (address) {
        return address(forestToken);
    }

    /// @notice Gets the USDC token address
    /// @return _usdcTokenAddr USDC token address
    function getUsdcTokenAddr() external view returns (address) {
        return address(usdcToken);
    }

    /// @notice Gets the slasher address
    /// @return _slasherAddr Slasher address
    function getSlasherAddr() external view returns (address) {
        return slasherAddr;
    }

    /// @notice Gets an actor by ID
    /// @param _id ID of the actor
    /// @return _actor Actor
    function getActorById(uint24 _id) external view returns (ForestCommon.Actor memory) {
        return actorsMap[actorIdToAddrMap[_id]];
    }

    /// @notice Gets the billing address of an actor by ID
    /// @param _id ID of the actor
    /// @return _billingAddr Billing address
    function getActorBillingAddressById(uint24 _id) external view returns (address) {
        return actorsMap[actorIdToAddrMap[_id]].billingAddr;
    }
}
