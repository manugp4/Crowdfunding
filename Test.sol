pragma solidity ^0.8.10;

contract Coin{
    address public minter;
    mapping(address=>uint) public balance;

    event Sent(address from, address to, uint amount);

    constructor () {
        minter = msg.sender;
    }

    function mint(address receiver, uint amount) public {
        balance[receiver] += amount;
    }

    function send(address receiver, uint amount) public {
        require(balance[msg.sender] >= amount);
        balance[msg.sender] -= amount;
        balance[receiver] += amount;
        emit Sent(msg.sender, receiver, amount);
    }
}