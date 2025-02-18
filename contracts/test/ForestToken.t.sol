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

contract ForestTokenTest is Test {
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
    uint public PARAM_MAX_PCS_NUM = 3;
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

        imitateCommitAndReveal();
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

    function imitateCommitAndReveal() public {  
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

        // validator 1 tryies to reveal to early
        vm.startPrank(v1Addr);
        
        // now waits and reveals when the window is open
        vm.roll(slasher.getCurrentEpochEndBlockNum() + slasher.REVEAL_WINDOW()); // TODO: do an in-depth count by 1 check on windows to reveal and mint
        slasher.reveal(pc1Val1Hash, v1Addr, address(pc1), provScoresPc1Val1);
        slasher.reveal(pc2Val1Hash, v1Addr, address(pc2), provScoresPc2Val1);

        // validator 2 tries to reveal his results
        vm.startPrank(v2Addr);
        slasher.reveal(pc1Val2Hash, v2Addr, address(pc1), provScoresPc1Val2);
        slasher.reveal(pc2Val2Hash, v2Addr, address(pc2), provScoresPc2Val2);
    }

    function testPunishmentForNoValidatorReports() public { // TODO
        // Setup initial state and get balances
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
        uint256 initialTotalSupply = iForestToken.totalSupply();

        // Close epoch and emit rewards with validator reports
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);
        uint256 normalEmission = iForestToken.totalSupply() - initialTotalSupply;

        // Move to next epoch, but don't submit any validator reports
        epochToClose = slasher.getCurrentEpochEndBlockNum();
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        
        initialTotalSupply = iForestToken.totalSupply();
        iForestToken.emitRewards(epochToClose);
        uint256 punishedEmission = iForestToken.totalSupply() - initialTotalSupply;

        assertTrue(
            punishedEmission < normalEmission,
            "Emission without validator reports should be lower"
        );
    }

    function testTotalEmissionOverLongPeriod() public {
        uint256 initialSupply = iForestToken.totalSupply();
        uint256 totalEmitted = 0;
        uint256 lastEmission = 100000 * 10**18;

        // 1040 weeks = 20 years
        for(uint i = 0; i < 1040; i++) {
            vm.roll(block.number + ((7 * 24 * 60 * 60) / 2));
            uint256 emission = emitAndGetTotalEmitted();
            totalEmitted += emission;
            
            // Log emissions at key points
            if (i % 52 == 0) {
                console2.log("Block number:", block.number);
                console2.log("Emission amount at this point:", emission / 1e18);
                console2.log("Total emission at", i / 52, "years:", totalEmitted / 1e18);
                console2.log("--------------------------------");
                if (i % (52*4 - 1) == 0) {
                    assertGt(lastEmission, emission, "Emission should be less than the last halving's emission");
                    lastEmission = emission;
                }
            }
        }

        uint256 finalSupply = iForestToken.totalSupply();
        assertEq(finalSupply - initialSupply, totalEmitted, "Total emission calculation mismatch");
        assertApproxEqRel(totalEmitted, 21_000_000 * 10**18, 0.05e18); // Within 5% of 21M
        
        // Log percentage of total supply emitted
        console2.log("Percentage of 21M emitted after 1040 weeks:", (totalEmitted * 100) / (21_000_000 * 10**18), "%");   
    }

    // Helper function to emit rewards and return total emitted amount
    function emitAndGetTotalEmitted() internal returns (uint256) {
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
        uint256 initialSupply = iForestToken.totalSupply();
        
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);
        
        return iForestToken.totalSupply() - initialSupply;
    }

    function testEmitRewards() public {
        // get initial balances for all actors
        uint256 beforeTotalSupply = iForestToken.totalSupply();
        uint256 initialBalancePco1 = iForestToken.balanceOf(address(pco1Addr));
        uint256 initialBalancePco2 = iForestToken.balanceOf(address(pco2Addr));
        uint256 initialBalanceP1 = iForestToken.balanceOf(address(p1Addr));
        uint256 initialBalanceP2 = iForestToken.balanceOf(address(p2Addr));
        uint256 initialBalanceV1 = iForestToken.balanceOf(address(v1Addr));
        uint256 initialBalanceV2 = iForestToken.balanceOf(address(v2Addr));
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();

        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1); 
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);

        uint256 afterTotalSupply = iForestToken.totalSupply();
        uint256 afterBalancePco1 = iForestToken.balanceOf(address(pco1Addr));
        uint256 afterBalancePco2 = iForestToken.balanceOf(address(pco2Addr));
        uint256 afterBalanceP1 = iForestToken.balanceOf(address(p1Addr));
        uint256 afterBalanceP2 = iForestToken.balanceOf(address(p2Addr));
        uint256 afterBalanceV1 = iForestToken.balanceOf(address(v1Addr));
        uint256 afterBalanceV2 = iForestToken.balanceOf(address(v2Addr));

        assertGt(afterBalancePco1, initialBalancePco1);
        assertGt(afterBalancePco2, initialBalancePco2);
        assertGt(afterBalanceP1, initialBalanceP1);
        assertGt(afterBalanceP2, initialBalanceP2);
        assertGt(afterBalanceV1, initialBalanceV1);
        assertGt(afterBalanceV2, initialBalanceV2);

        uint256 balanceDiff = afterBalancePco1 - initialBalancePco1 + afterBalancePco2 - initialBalancePco2 + afterBalanceP1 - initialBalanceP1 + afterBalanceP2 - initialBalanceP2 + afterBalanceV1 - initialBalanceV1 + afterBalanceV2 - initialBalanceV2;
        assertEq(balanceDiff, 50400 * 10**18);
        assertEq(afterTotalSupply-beforeTotalSupply, 50400 * 10**18);
        
        // now roll and emit again with no validator scores
        beforeTotalSupply = iForestToken.totalSupply();
        initialBalancePco1 = iForestToken.balanceOf(address(pco1Addr));
        initialBalancePco2 = iForestToken.balanceOf(address(pco2Addr));
        initialBalanceP1 = iForestToken.balanceOf(address(p1Addr));
        initialBalanceP2 = iForestToken.balanceOf(address(p2Addr));
        initialBalanceV1 = iForestToken.balanceOf(address(v1Addr));
        initialBalanceV2 = iForestToken.balanceOf(address(v2Addr));
        epochToClose = slasher.getCurrentEpochEndBlockNum();

        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1); 
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);

        afterTotalSupply = iForestToken.totalSupply();
        afterBalancePco1 = iForestToken.balanceOf(address(pco1Addr));
        afterBalancePco2 = iForestToken.balanceOf(address(pco2Addr));
        afterBalanceP1 = iForestToken.balanceOf(address(p1Addr));
        afterBalanceP2 = iForestToken.balanceOf(address(p2Addr));
        afterBalanceV1 = iForestToken.balanceOf(address(v1Addr));
        afterBalanceV2 = iForestToken.balanceOf(address(v2Addr));

        assertGt(afterBalancePco1, initialBalancePco1);
        assertGt(afterBalancePco2, initialBalancePco2);
        assertGt(afterBalanceP1, initialBalanceP1);
        assertGt(afterBalanceP2, initialBalanceP2);
        assertEq(afterBalanceV1, initialBalanceV1);
        assertEq(afterBalanceV2, initialBalanceV2);

        balanceDiff = afterBalancePco1 - initialBalancePco1 + afterBalancePco2 - initialBalancePco2 + afterBalanceP1 - initialBalanceP1 + afterBalanceP2 - initialBalanceP2 + afterBalanceV1 - initialBalanceV1 + afterBalanceV2 - initialBalanceV2;
        assertApproxEqRel(balanceDiff, 50400 * 10**18, 0.005e18); 
        assertApproxEqRel(afterTotalSupply-beforeTotalSupply, 50400 * 10**18, 0.005e18); 
    }

    // In this situation the first two PCs that are created during setup should get tokens while the third one should get tokens but suffer punishment for no validators (it's revenue diminished by punishment_factor)
    function testEmitRewardsWithNoValidators() public {
        // Setup: Register a PC without any validators
        setupPcWithProvsAndAgreementButNoValidators();
        
        uint256 initialSupply = iForestToken.totalSupply();
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
        
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);
        
        uint256 finalSupply = iForestToken.totalSupply();
        console2.log("emited (3rd PC: provs and agreements but no validators)", finalSupply - initialSupply);
        assertGt(finalSupply - initialSupply, 0, "Should emit some tokens"); 
    }

    // In  this situation the first two PCs that are created during setup should get all of the tokens while the third one should not because it has no active agreements
    function testEmitRewardsWithNoValidatorsOrProviders() public {
        // Setup: Register a PC without any validators or providers
        setupEmptyPc();
        
        uint256 initialSupply = iForestToken.totalSupply();
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
        
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);
        
        uint256 finalSupply = iForestToken.totalSupply();
        console2.log("emited (3rd PC: empty: no provs, vals, agreements)", finalSupply - initialSupply);
        assertGt(finalSupply - initialSupply, 0, "Should emit some tokens");
    }

    // In this situation the first two PCs that are created during setup should get tokens while the third one should not because it has no active agreements
    function testEmitRewardsWithNoActiveAgreements() public {
        // Setup: Register PC with providers but no active agreements
        setupPcWithProvsButNoAgreementValidators();
        
        uint256 initialSupply = iForestToken.totalSupply();
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
       
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);
        
        uint256 finalSupply = iForestToken.totalSupply();
        console2.log("emited (3rd PC: provs but no agreements and validators)", finalSupply - initialSupply);
        assertGt(finalSupply - initialSupply, 0, "Should emit some tokens");
    }

    // function testEmitRewardsWithNoPcs() public {
    //     // Don't setup any PCs, try to emit directly
    //     // TODO: in the setup we already have some PCs
    //     uint256 initialSupply = iForestToken.totalSupply();
    //     uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
        
    //     vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
    //     slasher.closeEpoch();
    //     iForestToken.emitRewards(epochToClose);
        
    //     uint256 finalSupply = iForestToken.totalSupply();
    //     assertEq(finalSupply - initialSupply, 0, "Should not emit tokens when no PCs exist");
    // }

    // In this situation, the first two PCs that are created during setup should get tokens while the third one should not, The 3rd PC's tokens (based on its revenue) will simply not be emitted
    function testEmitRewardsWithZeroValidatorScores() public {
        // Close previous epoch
        vm.roll(slasher.getCurrentEpochEndBlockNum() + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        // Setup: Full PC setup but validators report zeros
        address pcAddr = setupPcWithProvsValsAgreements();
        
        uint256 initialSupply = iForestToken.totalSupply();
        uint256 epochToClose = slasher.getCurrentEpochEndBlockNum();
        // Submit zero scores from validators
        submitZeroScores(pcAddr);
        vm.roll(epochToClose + slasher.REVEAL_WINDOW() + 1);
        slasher.closeEpoch();
        iForestToken.emitRewards(epochToClose);
        
        uint256 finalSupply = iForestToken.totalSupply();
        console2.log("emited (3rd PC: provs, vals, agreements but all scores are 0)", finalSupply - initialSupply);
        assertGt(finalSupply - initialSupply, 0, "Should emit some tokens");
    }

    // Helper functions for test setup

    function setupPcWithProvsAndAgreementButNoValidators() internal returns (address) {
        // Setup PC with only providers
        vm.startPrank(pco1Addr);
        address pcAddr = registry.createProtocol(
            MAX_VALS_NUM,
            MAX_PROVS_NUM,
            MIN_COLLATERAL,
            VAL_REG_FEE,
            PROV_REG_FEE,
            OFFER_REG_FEE,
            TERM_UPDATE_DELAY,
            PROV_SHARE,
            VAL_SHARE,
            PC_OWNER_SHARE,
            DETAILS_LINK
        );
        IForestProtocol pc3 = IForestProtocol(pcAddr);

        vm.startPrank(p1Addr);
        pc3.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc3.registerOffer(p1Addr, 1, 3, offerDetailsLink);
        vm.stopPrank();

        vm.startPrank(p2Addr); 
        pc3.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc3.registerOffer(p2Addr, 2, 3, offerDetailsLink);
        vm.stopPrank();

        vm.startPrank(v1Addr);
        iUsdcToken.approve(pcAddr, 10*INITIAL_DEPOSIT);
        pc3.enterAgreement(0, INITIAL_DEPOSIT); // agreement id 0

        return pcAddr;
    }

    function setupEmptyPc() internal returns (address) {
        // Setup PC with no actors
        vm.startPrank(pco1Addr);
        address pcAddr = registry.createProtocol(
            MAX_VALS_NUM,
            MAX_PROVS_NUM,
            MIN_COLLATERAL,
            VAL_REG_FEE,
            PROV_REG_FEE,
            OFFER_REG_FEE,
            TERM_UPDATE_DELAY,
            PROV_SHARE,
            VAL_SHARE,
            PC_OWNER_SHARE,
            DETAILS_LINK
        );
        vm.stopPrank();

        return pcAddr;
    }

    function setupPcWithProvsButNoAgreementValidators() internal returns (address) {
        // Setup PC with providers but no agreements
        vm.startPrank(pco1Addr);
        address pcAddr = registry.createProtocol(
            MAX_VALS_NUM,
            MAX_PROVS_NUM,
            MIN_COLLATERAL,
            VAL_REG_FEE,
            PROV_REG_FEE,
            OFFER_REG_FEE,
            TERM_UPDATE_DELAY,
            PROV_SHARE,
            VAL_SHARE,
            PC_OWNER_SHARE,
            DETAILS_LINK
        );
        IForestProtocol pc3 = IForestProtocol(pcAddr);

        vm.startPrank(p1Addr);
        pc3.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc3.registerOffer(p1Addr, 1, 3, offerDetailsLink);
        vm.stopPrank();

        vm.startPrank(p2Addr); 
        pc3.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc3.registerOffer(p2Addr, 2, 3, offerDetailsLink);
        vm.stopPrank();

        return pcAddr;
    }

    function setupPcWithProvsValsAgreements() internal returns (address) {
        // Setup full PC but prepare for zero scores
        vm.startPrank(pco1Addr);
        address pcAddr = registry.createProtocol(
            MAX_VALS_NUM,
            MAX_PROVS_NUM,
            MIN_COLLATERAL,
            VAL_REG_FEE,
            PROV_REG_FEE,
            OFFER_REG_FEE,
            TERM_UPDATE_DELAY,
            PROV_SHARE,
            VAL_SHARE,
            PC_OWNER_SHARE,
            DETAILS_LINK
        );
        IForestProtocol pc3 = IForestProtocol(pcAddr);

        vm.startPrank(p1Addr);
        pc3.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc3.registerOffer(p1Addr, 1, 3, offerDetailsLink); // offer id 0
        vm.stopPrank();

        vm.startPrank(p2Addr); 
        pc3.registerActor(ForestCommon.ActorType.PROVIDER, INITIAL_COLLATERAL);
        pc3.registerOffer(p2Addr, 2, 3, offerDetailsLink); // offer id 1
        pc3.registerOffer(p2Addr, 2, 3, offerDetailsLink); // offer id 2
        pc3.registerOffer(p2Addr, 2, 3, offerDetailsLink); // offer id 3
        vm.stopPrank();

        vm.startPrank(v1Addr);
        pc3.registerActor(ForestCommon.ActorType.VALIDATOR, INITIAL_COLLATERAL);
        iUsdcToken.approve(pcAddr, 10*INITIAL_DEPOSIT);
        pc3.enterAgreement(0, INITIAL_DEPOSIT); // agreement id 0

        vm.startPrank(v2Addr);
        pc3.registerActor(ForestCommon.ActorType.VALIDATOR, INITIAL_COLLATERAL);
        iUsdcToken.approve(pcAddr, 10*INITIAL_DEPOSIT);
        pc3.enterAgreement(1, INITIAL_DEPOSIT); // agreement id 1
        pc3.enterAgreement(2, INITIAL_DEPOSIT); // agreement id 2

        return pcAddr;
    }

    function submitZeroScores(address _pcAddr) internal {
        // Submit zero scores from validators
        ForestSlasher.ProviderScore[] memory provScoresPc3Val1 = new ForestSlasher.ProviderScore[](1);
        ForestSlasher.ProviderScore[] memory provScoresPc3Val2 = new ForestSlasher.ProviderScore[](2);
        provScoresPc3Val1[0] = ForestSlasher.ProviderScore(2, 0, 0);
        provScoresPc3Val2[0] = ForestSlasher.ProviderScore(3, 0, 1);
        provScoresPc3Val2[1] = ForestSlasher.ProviderScore(3, 0, 2);
        bytes32 pc3Val1Hash = slasher.computeHash(provScoresPc3Val1);
        bytes32 pc3Val2Hash = slasher.computeHash(provScoresPc3Val2);

        // validator 1 commits scores for both pc 1 and 2
        vm.startPrank(v1Addr);
        slasher.commit(pc3Val1Hash, v1Addr, _pcAddr);
        // validator 2 does the same
        vm.startPrank(v2Addr);
        slasher.commit(pc3Val2Hash, v2Addr, _pcAddr);
        
        // now waits and reveals when the window is open
        vm.roll(slasher.getCurrentEpochEndBlockNum() + slasher.REVEAL_WINDOW()); // TODO: do an in-depth count by 1 check on windows to reveal and mint
        slasher.reveal(pc3Val2Hash, v2Addr, _pcAddr, provScoresPc3Val2);
        vm.startPrank(v1Addr);
        slasher.reveal(pc3Val1Hash, v1Addr, _pcAddr, provScoresPc3Val1);
    }
}