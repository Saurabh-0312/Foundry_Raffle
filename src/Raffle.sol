//SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample raffle contract
 * @author  Saurabh singh
 * @notice This contract is for creating a sample raffle
 * @dev  Implements chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__notenoughETHsend();
    error Raffle_transferfail();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** type decleration */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /** state variable */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entrancefee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_rafflestate;

    /** Events */

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entrancefee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entrancefee = entrancefee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
    }

    function enterraffle() external payable {
        if (msg.value < i_entrancefee) {
            revert Raffle__notenoughETHsend();
        }

        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev this is function that the chainlink automation call to see if its time to preform an upkeep
     * following should be true for this to return true:
     * 1. the timr interval has passed between raffle runs
     * 2. the raffle is in open state
     * 3. the contract has eth aka players
     * 4. the subscription is funded with link
     */

    function checkUpKeep(
        bytes memory /* checkdata */
    ) public view returns (bool upKeepNeeded, bytes memory /* performdata */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = (RaffleState.OPEN == s_rafflestate);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "0x0");
    }

    function performUpKeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_rafflestate)
            );
        }

        s_rafflestate = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexofWinner = randomWords[0] % s_players.length;

        address payable winner = s_players[indexofWinner];

        //give money to winner
        s_recentWinner = winner;
        s_rafflestate = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_transferfail();
        }
    }

    /** Getter Function */
    function getEntranceFee() external view returns (uint256) {
        return i_entrancefee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_rafflestate;
    }

    function getPlayer(uint256 indexofplayer) external view returns (address) {
        return s_players[indexofplayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
