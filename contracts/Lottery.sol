// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error Lottery__SendMoreToEnterLottery(uint256 value);
error Lottery__TransferFailed(address winner);
error Lottery__NotOpen();
error Lottery__UpkeepNotNeeded(uint256 status, uint256 numPlayers, uint256 balance, uint256 currentTimestamp);

/**
@title Lottery
@author Patrick Collins, Lim Chee Kin
@notice The contract handles a simple lottery game.
@dev The lottery is operated by chainlink time-based upkeep calling performUpkeep() regularly.
The frequency of upkeep calls is determined by schedule set in chainlink upkeep.
The intervalInSeconds determined interval between lottery rounds.
The VRF Coordinator is used as a ramdom number generator to pick random winner.
*/
contract Lottery is VRFConsumerBaseV2 {
    /* Type declarations */
    enum LotteryStatus {
        OPEN,
        CALCULATING
    }

    /* State variables */
    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    // Retrieve 1 random values in one request.
    uint32 private constant NUM_WORDS = 1;
    VRFCoordinatorV2Interface private immutable coordinator;
    LotteryStatus private _lotteryStatus;
    uint32 private immutable callbackGasLimit;
    uint64 private immutable subscriptionId;
    uint256 private immutable entranceFee;
    uint256 private immutable intervalInSeconds;
    bytes32 private immutable gasLane;
    uint256 private _lastTimestamp;
    address private _lastWinner;
    address payable[] private _players;

    /* Events */
    event LotteryEntered(address indexed player);
    event LotteryWinnerRequested(uint256 indexed requestId);
    event LotteryWinnerPicked(address indexed winner);

    /* Functions */
    /**
     * @notice Initializes the Lottery contract.
     * @param vrfCoordinatorV2Address_ The address of the VRF Coordinator V2.
     * @param subscriptionId_ The subscription ID to use for randomness requests.
     * @param gasLane_ The gas lane to use for randomness requests.
     * @param callbackGasLimit_ The gas limit to use for the callback function: fulfillRandomWords.
     * @param intervalInSeconds_ The interval between lottery rounds, in seconds.
     * @param entranceFee_ The fee required to enter the lottery.
     */
    constructor(
        address vrfCoordinatorV2Address_,
        uint64 subscriptionId_,
        bytes32 gasLane_,
        uint32 callbackGasLimit_,
        uint256 intervalInSeconds_,
        uint256 entranceFee_
    ) VRFConsumerBaseV2(vrfCoordinatorV2Address_) {
        coordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2Address_);
        subscriptionId = subscriptionId_;
        gasLane = gasLane_;
        callbackGasLimit = callbackGasLimit_;
        intervalInSeconds = intervalInSeconds_;
        entranceFee = entranceFee_;
        _lotteryStatus = LotteryStatus.OPEN;
        _lastTimestamp = block.timestamp;
    }

    /**
     * @notice Allows a user to enter the lottery by sending the entrance fee.
     * @dev Reverts if msg.value is less than the entrance fee required or the lottery is not open.
     */
    function enterLottery() external payable {
        if (msg.value < entranceFee) {
            revert Lottery__SendMoreToEnterLottery(msg.value);
        }
        if (_lotteryStatus != LotteryStatus.OPEN) {
            revert Lottery__NotOpen();
        }
        _players.push(payable(msg.sender));
        emit LotteryEntered(msg.sender);
    }

    /**
     * @notice Check if the lottery needs upkeep, and if so, request a random winner.
     * @dev Upkeep is needed if the lottery is open, time has passed since the last upkeep,
     * there are players, and there is a balance.
     * Reverts if upkeep is not needed.
     */
    function performUpkeep() external {
        bool upkeepNeeded = checkUpkeep();
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                uint256(_lotteryStatus),
                _players.length,
                address(this).balance,
                block.timestamp
            );
        } else {
            requestRandomWinner();
        }
    }

    /* View/Pure functions */
    /**
     * @notice View the entrance fee for the lottery.
     * @return The entrance fee in wei.
     */
    function getEntranceFee() external view returns (uint256) {
        return entranceFee;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return _players[index];
    }

    function getLastWinner() external view returns (address) {
        return _lastWinner;
    }

    function getLotteryStatus() external view returns (LotteryStatus) {
        return _lotteryStatus;
    }

    function getNumberOfPlayers() external view returns (uint256) {
        return _players.length;
    }

    /**
     * @notice View the timestamp of the lottery open.
     * @return The timestamp of the lottery open.
     */
    function getLastTimestamp() external view returns (uint256) {
        return _lastTimestamp;
    }

    /**
     * @notice View the interval for upkeep calls in seconds.
     * @return The interval for upkeep calls in seconds.
     */
    function getIntervalInSeconds() external view returns (uint256) {
        return intervalInSeconds;
    }

    /**
     * @notice Check if upkeep is needed for the lottery.
     * @dev Upkeep is needed if following conditions are met:
     * - The lottery is open
     * - Time has passed since the last upkeep
     * - There are players
     * - The lottery contract has balance.
     * @return upkeepNeeded True if upkeep is needed, false otherwise.
     */
    function checkUpkeep() public returns (bool upkeepNeeded) {
        bool isOpen = _lotteryStatus == LotteryStatus.OPEN;
        bool isTimePassed = block.timestamp - _lastTimestamp > intervalInSeconds;
        bool hasPlayers = _players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = isOpen && isTimePassed && hasPlayers && hasBalance;
        return upkeepNeeded;
    }

    /**
     * @notice Pick a random winner for the lottery and transfer them the balance.
     * @dev Uses the random number return from VRF Coordinator to select a winner
     * from the player list. Transfers the balance to the winner and emits a LotteryWinnerPicked event.
     * Reverts if transfer fund to the winner failed.
     */
    function fulfillRandomWords(uint256 /* requestId_, */, uint256[] memory randomWords_) internal override {
        uint256 indexOfWinner = randomWords_[0] % _players.length;
        address payable winner = _players[indexOfWinner];
        _lastWinner = winner;
        _lotteryStatus = LotteryStatus.OPEN;
        delete _players;
        _lastTimestamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed(winner);
        }
        emit LotteryWinnerPicked(winner);
    }

    /**
     * @notice Make a request to the VRF Coordinator to get a random number for picking the lottery winner.
     * @dev Changes the lottery status to CALCULATING and requests a random number from the VRF Coordinator.
     * Emits a LotteryWinnerRequested event with the request ID.
     * Reverts if the subscription is not set and funded.
     */
    function requestRandomWinner() private {
        _lotteryStatus = LotteryStatus.CALCULATING;
        // Will revert if subscription is not set and funded.
        uint256 requestId = coordinator.requestRandomWords(
            gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            NUM_WORDS
        );
        emit LotteryWinnerRequested(requestId);
    }
}
