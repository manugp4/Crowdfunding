// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IERC20.sol";

contract CrowdFunding {
    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        //uint32 startAt,
        uint32 campaignTime
    );
    //event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Reward(address indexed caller, uint random, uint amount);
    //event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint id, address indexed caller, uint amount);

    struct Campaign {
        // Creator of campaign
        address creator;
        // Amount of tokens to raise
        uint goal;
        // Total amount pledged
        uint pledged;
        // Timestamp of start of campaign
        uint startAt;
        // Timestamp of end of campaign
        uint endAt;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }

    ERC20 public immutable token;
    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint public count;
    // Mapping from id to Campaign
    mapping(uint => Campaign) public campaigns;
    // Mapping from campaign id => pledger => amount pledged
    mapping(uint => mapping(address => uint)) public pledgedAmount;

    uint randNonce = 0;

    constructor(address _token) {
        token = ERC20(_token);
    }

    function launch(uint _goal, uint32 _campaignTime) external {
        //require(_startAt >= block.timestamp, "start at < now");
        //require(_endAt >= _startAt, "end at < start at");
        //require(_endAt <= block.timestamp + 90 days, "end at > max duration");

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            //startAt: _startAt,
            startAt: block.timestamp,
            endAt: block.timestamp + _campaignTime,
            claimed: false
        });

        //emit Launch(count, msg.sender, _goal, _startAt, _endAt);
        emit Launch(count, msg.sender, _goal, _campaignTime);
    }

    /*function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "not creator");
        require(block.timestamp < campaign.startAt, "started");

        delete campaigns[_id];
        emit Cancel(_id);
    }*/

    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "Campaign not started");
        require(block.timestamp <= campaign.endAt, "Campaign ended");
        //require(campaign.pledged + _amount <= campaign.goal, "You're pledging more tokens than the goal")

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        if(_amount >= 50){
            randNonce++;
            //uint random = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty)) % 2);
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 2;
            if(random == 1){
                token.transferFrom(campaign.creator, msg.sender, 5);
                emit Reward(msg.sender, random, 5);
            }
        }

        emit Pledge(_id, msg.sender, _amount);
        
    }

    /*function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }*/

    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "You're not the creator of the campaign");
        require(block.timestamp > campaign.endAt, "Campaign not ended");
        require(campaign.pledged >= campaign.goal, "The goal has not been reached");
        require(!campaign.claimed, "Campaign already claimed");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.pledged);

        emit Claim(_id);
    }

    function refund(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "Campaign not ended");
        require(campaign.pledged < campaign.goal, "The goal has been reached so you can't claim");

        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
