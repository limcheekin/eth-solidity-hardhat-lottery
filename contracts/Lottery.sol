// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {KeeperCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
// import "hardhat/console.sol";

error Lottery__SendMoreToEnterLottery(uint256 value);
error Lottery__TransferFailed(address winner);
error Lottery__NotOpen();
error Lottery__UpkeepNotNeeded(
    uint256 status,
    uint256 numPlayers,
    uint256 balance,
    uint256 currentTimestamp
);

/* KeeperCompatibleInterface is not required for time-based automation */
contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */
    enum LotteryStatus {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable entranceFee;
    uint64 private immutable subscriptionId;
    address payable[] private _players;
    address private _lastWinner;
    LotteryStatus private _lotteryStatus;
    uint256 private _lastTimestamp;
    uint256 private immutable intervalInSeconds;
    VRFCoordinatorV2Interface private immutable coordinator;

    bytes32 private immutable gasLane;

    uint32 private immutable callbackGasLimit;

    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // For this example, retrieve 1 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 private constant NUM_WORDS = 1;

    /* Events */
    event LotteryEntered(address indexed player);
    event LotteryWinnerRequested(uint256 indexed requestId);
    event LotteryWinnerPicked(address indexed winner);

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
        entranceFee = entranceFee_;
        _lotteryStatus = LotteryStatus.OPEN;
        _lastTimestamp = block.timestamp;
        intervalInSeconds = intervalInSeconds_;
    }

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

    function checkUpkeep(
        bytes calldata /* checkData */
    ) public override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = _lotteryStatus == LotteryStatus.OPEN;
        bool isTimePassed = block.timestamp - _lastTimestamp > intervalInSeconds;
        bool hasPlayers = _players.length > 0;
        bool hasBalance = address(this).balance > 0;

        /*
        console.log(
            "isTimePassed %s = block.timestamp %s - _lastTimestamp %s",
            isTimePassed,
            block.timestamp,
            _lastTimestamp
        );
        */

        upkeepNeeded = isOpen && isTimePassed && hasPlayers && hasBalance;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata performData) external override {
        (bool upkeepNeeded, ) = checkUpkeep(performData);
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

    // Assumes the subscription is funded sufficiently.
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

    function fulfillRandomWords(
        uint256 /* requestId_, */,
        uint256[] memory randomWords_
    ) internal override {
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

    /* View/Pure functions */
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

    function getLastTimestamp() external view returns (uint256) {
        return _lastTimestamp;
    }

    function getIntervalInSeconds() external view returns (uint256) {
        return intervalInSeconds;
    }
}
