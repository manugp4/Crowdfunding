// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IERC20.sol";

// import "@openzeppelin/contracts/utils/Strings.sol";

contract CrowdFunding {
    event Launch(
        uint256 id,
        address indexed creator,
        uint256 goal,
        uint32 campaignTime
    );
    event Pledge(uint256 indexed id, address indexed caller, uint256 amount);
    event Reward(address indexed caller, uint256 random, uint256 amount);
    event Claim(uint256 id);
    event Refund(uint256 id, address indexed caller, uint256 amount);

    struct Campaign {
        // Creator of campaign
        address creator;
        // Amount of tokens to raise
        uint256 goal;
        // Total amount pledged
        uint256 pledged;
        // Timestamp of start of campaign
        uint256 startAt;
        // Timestamp of end of campaign
        uint256 endAt;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }

    ERC20 public immutable token;
    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint256 public count;
    // Mapping from id to Campaign
    mapping(uint256 => Campaign) public campaigns;
    // Mapping from campaign id => pledger => amount pledged
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;

    uint256 randNonce = 0;

    constructor(address _token) {
        token = ERC20(_token);
    }

    function launch(uint256 _goal, uint32 _campaignTime) external {
        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            
            startAt: block.timestamp,
            endAt: block.timestamp + _campaignTime,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _campaignTime);
    }

    function pledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "Campaign not started");
        require(block.timestamp <= campaign.endAt, "Campaign ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        if (_amount >= 50) {
            randNonce++;
            //uint random = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty)) % 2);
            uint256 random = uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            ) % 2;
            if (random == 1) {
                token.transferFrom(campaign.creator, msg.sender, 5);
                emit Reward(msg.sender, random, 5);
            }
        }

        emit Pledge(_id, msg.sender, _amount);
    }

    function timeLeft(uint256 _id) public view returns (uint256) {
        Campaign memory campaign = campaigns[_id];
        return (campaign.endAt - block.timestamp);
    }

    function claim(uint256 _id) external {
        Campaign storage campaign = campaigns[_id];
        require(
            campaign.creator == msg.sender,
            "You're not the creator of the campaign"
        );
        require(block.timestamp > campaign.endAt, "Campaign not ended ");

        require(
            campaign.pledged >= campaign.goal,
            "The goal has not been reached"
        );

        require(!campaign.claimed, "Campaign already claimed");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.pledged);

        emit Claim(_id);
    }

    function refund(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "Campaign not ended");
        require(
            campaign.pledged < campaign.goal,
            "The goal has been reached so you can't claim"
        );

        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}