//SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/deploy.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HeplerConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperconfig;
    uint256 entrancefee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deploy = new DeployRaffle();
        (raffle, helperconfig) = deploy.run();
        (
            entrancefee,
            interval,
            vrfCoordinator,
            gaslane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperconfig.activenetworkconfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitialStateIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////////////////////////////////////
    // enterRaffle                           //
    function testRaffleRevertWhenYouDontPayEnough() public {
        //arrange
        vm.prank(PLAYER);
        //Acc
        vm.expectRevert(Raffle.Raffle__notenoughETHsend.selector);
        raffle.enterraffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterraffle{value: entrancefee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterraffle{value: entrancefee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();
    }

    /////////////////////////////////////
    //   checkupkeep                   //

    function testCheckupKeepFalseIfItHasNoBalance() public {
        //arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        // assert
        assert(!upKeepNeeded);
    }

    function testCheckupKeepReturnFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        (bool upKeedNeeded, ) = raffle.checkUpKeep("");

        assert(upKeedNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);
    }

    ///////////////////////////////////////
    //      performupkeep                //

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpKeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpKeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entrancefee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        //act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
    }

    ///////////////////////////////////////
    //   fulfillRandomWords              //
    ///////////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        //arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulFillRandomWordsPicksAWinnerResersAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        //arrange

        uint256 additionalEntrance = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrance;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterraffle{value: entrancefee}();
        }

        uint256 prize = entrancefee * (additionalEntrance + 1);
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());

        console.log(raffle.getRecentWinner().balance);
        console.log(prize + STARTING_USER_BALANCE);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entrancefee
        );
    }
}
