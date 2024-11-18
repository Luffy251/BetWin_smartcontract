// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CustomBetting is Ownable, ReentrancyGuard {
    struct Bet {
        address creator;
        string description;
        uint256 totalPool;
        uint256 option1Pool;
        uint256 option2Pool;
        uint256 creationTime;
        uint256 endTime;         
        bool isResolved;
        uint8 winningOption;
    }

    mapping(uint256 => Bet) public bets;
    mapping(uint256 => mapping(address => mapping(uint8 => uint256))) public userBets;
    
    uint256 public nextBetId;
    uint256 public constant CREATOR_FEE_PERCENTAGE = 3;
    uint256 public constant MINIMUM_DURATION = 1 hours; 
    uint256 public constant MAXIMUM_DURATION = 30 days; 
    address public oracle;

    event BetCreated(uint256 indexed betId, address indexed creator, string description, uint256 endTime);
    event BetPlaced(uint256 indexed betId, address indexed better, uint8 option, uint256 amount);
    event BetResolved(uint256 indexed betId, uint8 winningOption);
    event Withdrawal(address indexed user, uint256 amount);

    constructor() {
        oracle = msg.sender; 
    }

    function createBet(string memory _description, uint256 _duration) external {
        require(_duration >= MINIMUM_DURATION, "Duration too short");
        require(_duration <= MAXIMUM_DURATION, "Duration too long");
        
        uint256 endTime = block.timestamp + _duration;
        uint256 betId = nextBetId++;
        
        bets[betId] = Bet({
            creator: msg.sender,
            description: _description,
            totalPool: 0,
            option1Pool: 0,
            option2Pool: 0,
            creationTime: block.timestamp,
            endTime: endTime,
            isResolved: false,
            winningOption: 0
        });

        emit BetCreated(betId, msg.sender, _description, endTime);
    }

    function placeBet(uint256 _betId, uint8 _option) external payable nonReentrant {
        require(_betId < nextBetId, "Bet does not exist");
        require(_option == 1 || _option == 2, "Invalid option");
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(block.timestamp < bets[_betId].endTime, "Betting period has ended");

        Bet storage bet = bets[_betId];
        bet.totalPool += msg.value;
        if (_option == 1) {
            bet.option1Pool += msg.value;
        } else {
            bet.option2Pool += msg.value;
        }

        userBets[_betId][msg.sender][_option] += msg.value;

        emit BetPlaced(_betId, msg.sender, _option, msg.value);
    }

    function resolveBet(uint256 _betId, uint8 _winningOption) external {
    require(_betId < nextBetId, "Bet does not exist");
    require(_winningOption == 1 || _winningOption == 2, "Invalid winning option");
    require(!bets[_betId].isResolved, "Bet already resolved");
    require(block.timestamp >= bets[_betId].endTime, "Betting period not yet ended");
    require(msg.sender == bets[_betId].creator, "Only creator can resolve bet");

    Bet storage bet = bets[_betId];
    bet.isResolved = true;
    bet.winningOption = _winningOption;

    emit BetResolved(_betId, _winningOption);
    }

    function claimWinnings(uint256 _betId) external nonReentrant {
        Bet storage bet = bets[_betId];
        require(bet.isResolved, "Bet not yet resolved");
        
        uint256 userBet = userBets[_betId][msg.sender][bet.winningOption];
        require(userBet > 0, "No winning bet found");

        uint256 winningPool = bet.winningOption == 1 ? bet.option1Pool : bet.option2Pool;
        uint256 winnings = (userBet * bet.totalPool) / winningPool;
        
        uint256 creatorFee = (winnings * CREATOR_FEE_PERCENTAGE) / 100;
        uint256 userWinnings = winnings - creatorFee;

        userBets[_betId][msg.sender][bet.winningOption] = 0;

        (bool success, ) = bet.creator.call{value: creatorFee}("");
        require(success, "Failed to send creator fee");

        (success, ) = msg.sender.call{value: userWinnings}("");
        require(success, "Failed to send winnings");

        emit Withdrawal(msg.sender, userWinnings);
    }

    function setOracle(address _newOracle) external onlyOwner {
        oracle = _newOracle;
    }

    receive() external payable {}
}