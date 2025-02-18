pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import "../src/ForestCommon.sol";
import {ForestRegistry} from "../src/ForestRegistry.sol";
import {ForestSlasher} from "../src/ForestSlasher.sol";
import {IForestProtocol} from "../src/interfaces/IForestProtocol.sol";
import "../src/interfaces/IForestToken.sol";

import {MockedUsdcToken} from "../src/MockedUsdcToken.sol";
import {ForestToken} from "../src/ForestToken.sol";

contract ForestSlasherTest is Test {
    ForestRegistry public registry;
    ForestSlasher public slasher;
    IERC20Metadata public iUsdcToken;
    IForestToken public iForestToken;

    address public p3Addr = address(10);
    address public p1Addr = address(1);
    address public p1BillAddr = address(2);
    address public p1OperatorAddr = address(3);
    address public p2Addr = address(4);
    address public p2BillAddr = address(5);
    address public p2OperatorAddr = address(6);
    address public user1 = address(7);
    address public user2 = address(8);
    address public user3 = address(9);
    address public v1Addr = address(12);
    address public v1BillAddr = address(13);
    address public v1OperatorAddr = address(14);
    address public v2Addr = address(15);
    address public v2BillAddr = address(16);
    address public v2OperatorAddr = address(17);
    address public pco1Addr = address(18);
    address public pco2Addr = address(19);
    string public providerDetailsLink = "https://provider.com";
    string public pcDetailsLink = "https://product.com";
    string public offerDetailsLink = "https://inventory.com";

    // Protocol Sample Params
    uint public PARAM_REVENUE_SHARE = 1000; //10.00%
    uint public PARAM_MAX_PCS_NUM = 2;
    uint public PARAM_ACTOR_REG_FEE = 1 ether;
    uint public PARAM_PC_REG_FEE = 10 ether;
    uint public PARAM_ACTOR_IN_PC_REG_FEE = 2 ether;
    uint public PARAM_OFFER_IN_PC_REG_FEE = 3 ether;
    address public PARAM_TREASURY_ADDR = address(11);
    uint public PARAM_BURN_RATIO = 2000; // 20.00%

    // PC Sample Params
    uint public constant MAX_VALS_NUM = 2;
    uint public constant MAX_PROVS_NUM = 2;
    uint public constant MIN_COLLATERAL = 10 ether;
    uint public constant VAL_REG_FEE = 1 ether;
    uint public constant PROV_REG_FEE = 2 ether;
    uint public constant OFFER_REG_FEE = 3 ether;
    uint public constant TERM_UPDATE_DELAY = 400;
    uint public constant PROV_SHARE = 4500;
    uint public constant VAL_SHARE = 4500;
    uint public constant PC_OWNER_SHARE = 1000;
    uint public constant PERFORMANCE_WEIGHT = 7000;
    uint public constant PRICE_WEIGHT = 1000;
    uint public constant PTP_WEIGHT = 1000;
    uint public constant POPULARITY_WEIGHT = 1000;
    string public constant DETAILS_LINK = "https://pc123.com";

    // Actor Sample Deploy Params
    uint public constant INITIAL_COLLATERAL = 10 ether;
    uint public constant INITIAL_DEPOSIT = 3 * 2 * 31 * 24 * 60 * 60;

    // Sample depoyment
    IForestProtocol pc1;
    IForestProtocol pc2;

    struct ProviderScore {
        uint24 provId; // we are using IDs to save on space, 24 bits vs 20*8 bits
        uint256 score;
        uint32 agreementId; 
    }

    enum CommitmentStatus {
        COMMITED,
        REVEALED
    }

    function setUp() public {
        MockedUsdcToken usdcContract = new MockedUsdcToken(address(this));
        iUsdcToken = IERC20Metadata(address(usdcContract));
        ForestToken forestContract = new ForestToken();
        iForestToken = IForestToken(address(forestContract));
        
        slasher = new ForestSlasher();
        registry = new ForestRegistry(address(slasher), address(iUsdcToken), address(iForestToken), PARAM_REVENUE_SHARE, PARAM_MAX_PCS_NUM, PARAM_ACTOR_REG_FEE, PARAM_PC_REG_FEE, PARAM_ACTOR_IN_PC_REG_FEE, PARAM_OFFER_IN_PC_REG_FEE, PARAM_TREASURY_ADDR, PARAM_BURN_RATIO);
        slasher.setRegistryAndForestAddr(address(registry));
        iForestToken.setRegistryAndSlasherAddr(address(registry));

        // deploy sample PCs
        fundAccountWithToken(pco1Addr, 1100);
        fundAccountWithToken(pco2Addr, 1100);
        
        vm.startPrank(pco1Addr);
        registry.registerActor(ForestCommon.ActorType.PC_OWNER, address(0), address(0), providerDetailsLink); // actor id 0
        address pcAddr = registry.createProtocol(MAX_VALS_NUM, MAX_PROVS_NUM, MIN_COLLATERAL, VAL_REG_FEE, PROV_REG_FEE, OFFER_REG_FEE, TERM_UPDATE_DELAY, PROV_SHARE, VAL_SHARE, PC_OWNER_SHARE, DETAILS_LINK);
        pc1 = IForestProtocol(pcAddr);

        vm.startPrank(pco2Addr);
        registry.registerActor(ForestCommon.ActorType.PC_OWNER, address(0), address(0), providerDetailsLink);  // actor id 1
        pcAddr = registry.createProtocol(MAX_VALS_NUM, MAX_PROVS_NUM, MIN_COLLATERAL, VAL_REG_FEE, PROV_REG_FEE, OFFER_REG_FEE, TERM_UPDATE_DELAY, PROV_SHARE, VAL_SHARE, PC_OWNER_SHARE, DETAILS_LINK);
        pc2 = IForestProtocol(pcAddr);

        // deploy sample providers and offers
        vm.startPrank(address(this));
        fundAccountWithToken(p1Addr, 1100);
        fundAccountWithToken(p2Addr, 1100);

        vm.startPrank(p1Addr);
        registry.registerActor(ForestCommon.ActorType.PROVIDER, address(0), address(0), providerDetailsLink);  // actor id 2
        pc1.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc2.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc1.registerOffer(p1Addr, 1, 3, offerDetailsLink); // offer id 0
        pc1.registerOffer(p1Addr, 2, 3, offerDetailsLink); // offer id 1
        pc2.registerOffer(p1Addr, 2, 3, offerDetailsLink); // offer id 0

        vm.startPrank(p2Addr);
        registry.registerActor(ForestCommon.ActorType.PROVIDER, address(0), address(0), providerDetailsLink);  // actor id 3
        pc1.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc2.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc1.registerOffer(p2Addr, 1, 3, offerDetailsLink); // offer id 2
        pc1.registerOffer(p2Addr, 2, 3, offerDetailsLink); // offer id 3
        pc2.registerOffer(p2Addr, 2, 3, offerDetailsLink); // offer id 1

        // deply sample agreements
        vm.startPrank(address(this));
        fundAccountWithToken(v1Addr, 11000);
        fundAccountWithToken(v2Addr, 11000);

        vm.startPrank(v1Addr);
        iUsdcToken.approve(address(pc1), 10*INITIAL_DEPOSIT);
        iUsdcToken.approve(address(pc2), 10*INITIAL_DEPOSIT);
        registry.registerActor(ForestCommon.ActorType.VALIDATOR, address(0), address(0), providerDetailsLink);  // actor id 4
        pc1.registerActor(ForestCommon.ActorType.VALIDATOR, INITIAL_COLLATERAL);
        pc2.registerActor(ForestCommon.ActorType.VALIDATOR, INITIAL_COLLATERAL);
        pc1.enterAgreement(0, INITIAL_DEPOSIT); // agreement id 0
        pc1.enterAgreement(1, INITIAL_DEPOSIT); // agreement id 1
        pc1.enterAgreement(2, INITIAL_DEPOSIT); // agreement id 2
        pc1.enterAgreement(3, INITIAL_DEPOSIT); // agreement id 3
        pc2.enterAgreement(0, INITIAL_DEPOSIT); // agreement id 0
        pc2.enterAgreement(1, INITIAL_DEPOSIT); // agreement id 1

        vm.startPrank(v2Addr);
        iUsdcToken.approve(address(pc1), 10*INITIAL_DEPOSIT);
        iUsdcToken.approve(address(pc2), 10*INITIAL_DEPOSIT);
        registry.registerActor(ForestCommon.ActorType.VALIDATOR, address(0), address(0), providerDetailsLink);  // actor id 5
        pc1.registerActor(ForestCommon.ActorType.VALIDATOR, INITIAL_COLLATERAL);
        pc2.registerActor(ForestCommon.ActorType.VALIDATOR, INITIAL_COLLATERAL);
        pc1.enterAgreement(0, INITIAL_DEPOSIT); // agreement id 4
        pc1.enterAgreement(1, INITIAL_DEPOSIT); // agreement id 5
        pc1.enterAgreement(2, INITIAL_DEPOSIT); // agreement id 6
        pc1.enterAgreement(3, INITIAL_DEPOSIT); // agreement id 7
        pc2.enterAgreement(0, INITIAL_DEPOSIT); // agreement id 2
        pc2.enterAgreement(1, INITIAL_DEPOSIT); // agreement id 3
    }

    function fundAccountWithToken(address _account, uint256 _amount) public {
        iUsdcToken.transfer(_account, _amount * 10 ** iUsdcToken.decimals());
        iForestToken.transfer(_account, _amount * 10 ** iForestToken.decimals());

        vm.startPrank(_account);
        iUsdcToken.approve(
            address(registry),
            _amount * 10 ** iUsdcToken.decimals()
        );
        iForestToken.approve(
            address(slasher),
            _amount * 10 ** iForestToken.decimals()
        );
        iForestToken.approve(
            address(registry),
            _amount * 10 ** iForestToken.decimals()
        );
        vm.stopPrank();
    }

    function testCommit() public {
        bytes32 pc1Val1Hash = keccak256("testResultsCidpc1v1");
        bytes32 pc2Val1Hash = keccak256("testResultsCidpc2v1");
        bytes32 pc1Val2Hash = keccak256("testResultsCidpc1v2");
        bytes32 pc2Val2Hash = keccak256("testResultsCidpc2v2");
        
        // validator 1 commits scores for both pc 1 and 2
        vm.startPrank(v1Addr);
        slasher.commit(pc1Val1Hash, v1Addr, address(pc1));
        slasher.commit(pc2Val1Hash, v1Addr, address(pc2));

        assertEq(slasher.getPcNumThisEpoch(), 2);
        assertEq(slasher.getEpochScoresGranular(address(pc1)).length, 1);
        assertEq(slasher.getEpochScoresGranular(address(pc2)).length, 1);
        assertEq(slasher.getHashToIndex(pc1Val1Hash), 0);
        assertEq(slasher.getHashToIndex(pc2Val1Hash), 0);

        // validator 2 does the same
        vm.startPrank(v2Addr);
        slasher.commit(pc1Val2Hash, v2Addr, address(pc1));
        slasher.commit(pc2Val2Hash, v2Addr, address(pc2));

        assertEq(slasher.getPcNumThisEpoch(), 2);
        assertEq(slasher.getEpochScoresGranular(address(pc1)).length, 2);
        assertEq(slasher.getEpochScoresGranular(address(pc2)).length, 2);
        assertEq(slasher.getHashToIndex(pc1Val2Hash), 1);
        assertEq(slasher.getHashToIndex(pc2Val2Hash), 1);

        // validator 2 attempts to commit again what he has already commited
        vm.expectPartialRevert(ForestCommon.CommitmentAlreadySubmitted.selector);
        slasher.commit(pc1Val2Hash, v2Addr, address(pc1));

        // validator 2 attempts to commit scores to an not registered pc
        vm.expectPartialRevert(ForestCommon.ObjectNotActive.selector);
        slasher.commit(keccak256("testResultsCidpc3"), v2Addr, address(123));

        // user 1 who isn't a validator attempts to commit scores to a pc
        vm.startPrank(user1);
        vm.expectPartialRevert(ForestCommon.OnlyOwnerOrOperatorAllowed.selector);
        slasher.commit(keccak256("testResultsCidpc1.12"), user1, address(pc1));
    }

    function testReveal() public {  
        // build score arrays for validator 1
        ForestSlasher.ProviderScore[] memory provScoresPc1Val1 = new ForestSlasher.ProviderScore[](4);
        ForestSlasher.ProviderScore[] memory provScoresPc2Val1 = new ForestSlasher.ProviderScore[](2);
        provScoresPc1Val1[0] = ForestSlasher.ProviderScore(2, 2, 0);
        provScoresPc1Val1[1] = ForestSlasher.ProviderScore(2, 3, 1);
        provScoresPc1Val1[2] = ForestSlasher.ProviderScore(3, 1, 2);
        provScoresPc1Val1[3] = ForestSlasher.ProviderScore(3, 1, 3);
        provScoresPc2Val1[0] = ForestSlasher.ProviderScore(2, 1, 0);
        provScoresPc2Val1[1] = ForestSlasher.ProviderScore(3, 1, 1);
        bytes32 pc1Val1Hash = slasher.computeHash(provScoresPc1Val1);
        bytes32 pc2Val1Hash = slasher.computeHash(provScoresPc2Val1);

        // build score arrays for validator 2
        ForestSlasher.ProviderScore[] memory provScoresPc1Val2 = new ForestSlasher.ProviderScore[](4);
        ForestSlasher.ProviderScore[] memory provScoresPc2Val2 = new ForestSlasher.ProviderScore[](2);
        provScoresPc1Val2[0] = ForestSlasher.ProviderScore(2, 4, 4);
        provScoresPc1Val2[1] = ForestSlasher.ProviderScore(2, 4, 5);
        provScoresPc1Val2[2] = ForestSlasher.ProviderScore(3, 1, 6);
        provScoresPc1Val2[3] = ForestSlasher.ProviderScore(3, 1, 7);
        provScoresPc2Val2[0] = ForestSlasher.ProviderScore(2, 1, 2);
        provScoresPc2Val2[1] = ForestSlasher.ProviderScore(3, 1, 3);
        bytes32 pc1Val2Hash = slasher.computeHash(provScoresPc1Val2);
        bytes32 pc2Val2Hash = slasher.computeHash(provScoresPc2Val2);

        // validator 1 commits scores for both pc 1 and 2
        vm.startPrank(v1Addr);
        slasher.commit(pc1Val1Hash, v1Addr, address(pc1));
        slasher.commit(pc2Val1Hash, v1Addr, address(pc2));
        // validator 2 does the same
        vm.startPrank(v2Addr);
        slasher.commit(pc1Val2Hash, v2Addr, address(pc1));
        slasher.commit(pc2Val2Hash, v2Addr, address(pc2));
        // for a later test
        slasher.commit(keccak256("randomHash"), v2Addr, address(pc1));

        // validator 1 tryies to reveal to early
        vm.startPrank(v1Addr);
        vm.expectPartialRevert(ForestCommon.InvalidState.selector);
        slasher.reveal(pc1Val1Hash, v1Addr, address(pc1), provScoresPc1Val1);
        
        // now waits and reveals when the window is open
        vm.roll(slasher.getCurrentEpochEndBlockNum() + slasher.REVEAL_WINDOW()); // TODO: do an in-depth count by 1 check on windows to reveal and mint
        slasher.reveal(pc1Val1Hash, v1Addr, address(pc1), provScoresPc1Val1);
        slasher.reveal(pc2Val1Hash, v1Addr, address(pc2), provScoresPc2Val1);

        // validator 2 tries to reveal his results
        vm.startPrank(v2Addr);
        slasher.reveal(pc1Val2Hash, v2Addr, address(pc1), provScoresPc1Val2);
        slasher.reveal(pc2Val2Hash, v2Addr, address(pc2), provScoresPc2Val2);

        assertEq(slasher.getEpochScoresGranular(address(pc1)).length, 3);
        assertEq(slasher.getEpochScoresGranular(address(pc2)).length, 2);
        assertEq(slasher.getEpochScoresGranular(address(pc1))[0].provScores.length, 4);
        assertEq(slasher.getEpochScoresGranular(address(pc1))[1].provScores.length, 4);
        assertEq(slasher.getEpochScoresGranular(address(pc2))[0].provScores.length, 2);
        assertEq(slasher.getEpochScoresGranular(address(pc2))[1].provScores.length, 2);

        // validator 2 tries to reveal what was already revealed
        vm.expectPartialRevert(ForestCommon.InvalidState.selector);
        slasher.reveal(pc1Val2Hash, v2Addr, address(pc1), provScoresPc1Val2);

        // validator 2 attemps to commit data and the reveal with provScores that do not match the commitment hash
        vm.expectPartialRevert(ForestCommon.InvalidAddress.selector);
        slasher.reveal(keccak256("randomHash"), v2Addr, address(pc1), provScoresPc1Val2);
    }

    function testCloseEpoch() public {
        testReveal();
        uint256 currentEpoch = slasher.getCurrentEpochEndBlockNum();
        vm.roll(currentEpoch + slasher.REVEAL_WINDOW() + 1); 
        slasher.closeEpoch();

        ForestSlasher.EpochScoreAggregate[] memory aggregates = slasher.getEpochScoresAggregate(currentEpoch);
        assertEq(slasher.getCurrentEpochEndBlockNum(), currentEpoch + slasher.EPOCH_LENGTH());
        assertEq(aggregates.length, 2);
        assertEq(aggregates[0].provRanks.length, 2); 
        assertEq(aggregates[0].valRanks.length, 2);
        assertEq(aggregates[1].provRanks.length, 2);
        assertEq(aggregates[1].valRanks.length, 2);
        assertEq(aggregates[0].revenueAtEpochClose, 12);
        assertEq(aggregates[1].revenueAtEpochClose, 8);
        // TODO: add more advanced test of aggregate scores
    }

//     // function testRevealNotAValidator() public {
//     //     vm.startPrank(v1Addr);
//     //     uint24 inventoryId = 0;
//     //     uint32 agreementId = testContract.enterAgreement(inventoryId, 1 * 2 * 31 * 24 * 60 * 60 * 2);
//     //     address testedProviderAddr = testContract.getAgreement(agreementId).providerOwnerAddr;
//     //     testSlasher.commit("testResultsCid", testedProviderAddr, inventoryId, agreementId);
//     //     vm.startPrank(user1);
//     //     vm.expectRevert();
//     //     testSlasher.reveal("testResultsCid", true);
//     // }

//     // function testRevealDifferentValidator() public {
//     //     vm.startPrank(v1Addr);
//     //     uint24 inventoryId = 0;
//     //     uint32 agreementId = testContract.enterAgreement(inventoryId, 1 * 2 * 31 * 24 * 60 * 60 * 2);
//     //     address testedProviderAddr = testContract.getAgreement(agreementId).providerOwnerAddr;
//     //     testSlasher.commit("testResultsCid", testedProviderAddr, inventoryId, agreementId);
//     //     vm.stopPrank();
//     //     vm.startPrank(v2Addr);
//     //     vm.expectRevert();
//     //     testSlasher.reveal("testResultsCid", true);
//     //     vm.stopPrank();
//     // }

//     // function testWithdrawProviderCollateralByAdmin() public {
//     //         uint256 depositedFunds = 100;
//     //         fundAccountWithToken(p1Addr, depositedFunds);
//     //         vm.startPrank(p1Addr);
//     //         registry.registerProvider(
//     //             address(0),
//     //             address(0),
//     //             100,
//     //             providerDetailsLink
//     //         );
//     //         vm.stopPrank();
//     //         vm.startPrank(address(this));
//     //         uint256 contractBalanceBefore = iUsdcToken.balanceOf(
//     //             address(registry)
//     //         );
//     //         registry.withdrawProviderCollateral(p1Addr, 50);
//     //         assertEq(
//     //             iUsdcToken.balanceOf(address(registry)),
//     //             contractBalanceBefore - 50
//     //         );
//     //         vm.startPrank(p2Addr);
//     //         vm.expectRevert();
//     //         registry.withdrawProviderCollateral(p1Addr, 50);
//     //     }

//     //     function testTopUpValidatorCollateral() public {
//     //         uint256 depositedFunds = 100;
//     //         fundAccountWithToken(p1Addr, depositedFunds);
//     //         vm.startPrank(p1Addr);

//     //         testRegisterValidatorWithOneProductWithCollateral();
//     //         uint256 validatorCollateralBalanceOfBefore = registry
//     //             .getActorCollateralBalanceOf(p1Addr);
//     //         registry.topUpValidatorCollateral(depositedFunds);
//     //         uint256 validatorCollateralBalanceOfAfter = registry
//     //             .getActorCollateralBalanceOf(p1Addr);
//     //         assertEq(
//     //             validatorCollateralBalanceOfAfter,
//     //             validatorCollateralBalanceOfBefore + depositedFunds
//     //         );
//     //     }

//     //     function testRevertTopUpValidatorCollateral() public {
//     //         fundAccountWithToken(p1Addr, 100);
//     //         vm.startPrank(p1Addr);
//     //         vm.expectRevert();
//     //         registry.topUpValidatorCollateral(100);
//     //         vm.expectRevert();
//     //         registry.topUpValidatorCollateral(0);
//     //     }

//     //     function testWithdrawValidatorCollateralByAdmin() public {
//     //         uint256 depositedFunds = 100;
//     //         fundAccountWithToken(p1Addr, depositedFunds);
//     //         vm.startPrank(p1Addr);
//     //         testRegisterValidatorWithOneProductNoCollateral();
//     //         registry.topUpValidatorCollateral(50);
//     //         vm.stopPrank();
//     //         vm.startPrank(address(this));
//     //         uint256 contractBalanceBefore = iUsdcToken.balanceOf(
//     //             address(registry)
//     //         );
//     //         registry.withdrawValidatorCollateral(p1Addr, 10);
//     //         assertEq(
//     //             iUsdcToken.balanceOf(address(registry)),
//     //             contractBalanceBefore - 10
//     //         );
//     //         vm.startPrank(p2Addr);
//     //         vm.expectRevert();
//     //         registry.withdrawValidatorCollateral(p1Addr, 10);
//     //     }
// }
}