// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LearningHubStaking
 * @dev Contract for staking tokens to sponsor learning hubs
 */
contract LearningHubStaking is ReentrancyGuard, Ownable {
    IERC20 public stakingToken;
    
    struct Hub {
        string name;
        address owner;
        uint256 totalStaked;
        uint256 minimumStakeRequired;
        bool isActive;
    }
    
    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 hubId;
    }
    
    Hub[] public hubs;
    mapping(address => Stake[]) public userStakes;
    mapping(uint256 => mapping(address => bool)) public hubSponsors;
    
    event HubCreated(uint256 indexed hubId, string name, address owner);
    event Staked(address indexed user, uint256 hubId, uint256 amount);
    event Withdrawn(address indexed user, uint256 hubId, uint256 amount);
    event HubStatusChanged(uint256 indexed hubId, bool isActive);
    
    constructor(address _stakingToken, address initialOwner) 
        Ownable(initialOwner)  // Initialize Ownable with initial owner
    {
        stakingToken = IERC20(_stakingToken);
    }
    
    function createHub(string memory _name, uint256 _minimumStake) external {
        require(_minimumStake > 0, "Minimum stake must be greater than 0");
        
        hubs.push(Hub({
            name: _name,
            owner: msg.sender,
            totalStaked: 0,
            minimumStakeRequired: _minimumStake,
            isActive: true
        }));
        
        emit HubCreated(hubs.length - 1, _name, msg.sender);
    }
    
    function stake(uint256 _hubId, uint256 _amount) external nonReentrant {
        require(_hubId < hubs.length, "Hub does not exist");
        require(hubs[_hubId].isActive, "Hub is not active");
        require(_amount >= hubs[_hubId].minimumStakeRequired, "Amount below minimum stake");
        
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        
        userStakes[msg.sender].push(Stake({
            amount: _amount,
            timestamp: block.timestamp,
            hubId: _hubId
        }));
        
        hubs[_hubId].totalStaked += _amount;
        hubSponsors[_hubId][msg.sender] = true;
        
        emit Staked(msg.sender, _hubId, _amount);
    }
    
    function withdraw(uint256 _stakeIndex) external nonReentrant {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");
        
        Stake storage userStake = userStakes[msg.sender][_stakeIndex];
        require(userStake.amount > 0, "No stake to withdraw");
        
        uint256 amount = userStake.amount;
        uint256 hubId = userStake.hubId;
        
        userStake.amount = 0;
        hubs[hubId].totalStaked -= amount;
        hubSponsors[hubId][msg.sender] = false;
        
        stakingToken.transfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, hubId, amount);
    }
    
    function setHubStatus(uint256 _hubId, bool _isActive) external {
        require(_hubId < hubs.length, "Hub does not exist");
        require(msg.sender == hubs[_hubId].owner || msg.sender == owner(), "Not authorized");
        
        hubs[_hubId].isActive = _isActive;
        emit HubStatusChanged(_hubId, _isActive);
    }
    
    function getHubCount() external view returns (uint256) {
        return hubs.length;
    }
    
    function getUserStakes(address _user) external view returns (Stake[] memory) {
        return userStakes[_user];
    }
    
    function isHubSponsor(uint256 _hubId, address _user) external view returns (bool) {
        return hubSponsors[_hubId][_user];
    }
}