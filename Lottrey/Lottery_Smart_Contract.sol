// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract lottery is VRFConsumerBase, ReentrancyGuard {

    address payable internal admin;
    address[] internal participants;
    uint256 internal startTime;
    uint256 internal endTime;
    uint256 internal lotteryID;
    mapping(uint256 => address payable) internal lotteryHistory;

    // ChainLink Variables
    bytes32 internal keyHash; // identifies which Chainlink oracle to use
    uint internal fee;        // fee to get random number
    uint internal randomResult;

    // Events
    event ParticipantEntered(address indexed participant);
    event WinnerPicked(uint256 indexed lotteryId, address indexed winner);

    constructor(uint256 _startTime, uint256 _endTime) VRFConsumerBase(
        0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // VRF coordinator
        0x779877A7B0D9E8603169DdbD7836e478b4624789// LINK token address
    ) {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18;

        admin = payable(msg.sender);
        startTime = block.timestamp + _startTime;
        endTime = block.timestamp + _endTime;
        lotteryID = 1;
    }

    modifier _onlyAdmin {
        require(msg.sender == admin, "You are not an admin");
        _;
    }

    function participate() external payable nonReentrant {
        require(block.timestamp >= startTime, "Lottery Does not started yet");
        require(msg.value == 0.001 ether, "Minimum Amount is 0.001 ether");
        participants.push(payable(msg.sender));
        emit ParticipantEntered(msg.sender);
    }

    function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK in contract");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint randomness) internal override {
        randomResult = randomness;
    }

    function viewAdmin() external view returns (address) {
        return admin;
    }

    function getBalance() external view _onlyAdmin returns (uint256) {
        return address(this).balance;
    }

    function totalParticipants() external view _onlyAdmin returns (address[] memory) {
        return participants;
    }

    function getWinnerOfLottery(uint256 lotteryId) external view _onlyAdmin returns (address) {
        return lotteryHistory[lotteryId];
    }

    function lotteryStartsAt() external view returns (uint256) {
        return startTime;
    }

    function lotteryEndsAt() external view returns (uint256) {
        return endTime;
    }

    function lotteryParticipationMinimumAmount() external pure returns (uint256) {
        return 0.001 ether;
    }

    function adminRewards() external pure returns (string memory) {
        return "Admin is getting 2% of total collection";
    }

    function changeAdmin(address newAdmin) external {
        admin = payable(newAdmin);
    }

    function pickWinner() external _onlyAdmin nonReentrant {
        require(block.timestamp >= endTime, "Lottery Does not Ended Yet");
        getRandomNumber();
        uint256 index = randomResult % participants.length;
        uint256 adminAmount = (address(this).balance * 2) / 100;
        uint256 userAmount = address(this).balance - adminAmount;

        lotteryHistory[lotteryID] = payable(participants[index]);
        emit WinnerPicked(lotteryID, participants[index]);
        lotteryID++;

        payable(participants[index]).transfer(userAmount);
        payable(admin).transfer(adminAmount);

        participants = new address payable[](0);
    }
}
