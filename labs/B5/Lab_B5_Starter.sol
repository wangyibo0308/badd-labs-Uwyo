// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Lab B5 starter code. Students implement TODOs without changing BankRE.

// Exercise 1: Observe the fallback callback.
contract FallbackReceiver {
    event Log(string functionName, uint256 gasRemaining, uint256 value);

    fallback() external payable {
        emit Log("fallback", gasleft(), msg.value);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

contract FallbackSender {
    function call(address payable to) external payable {
        (bool sent, ) = to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
}

// Exercise 2: Intentionally vulnerable bank. Do not modify for Exercise 2.
contract BankRE {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // VULNERABLE: external call happens before balances[msg.sender] = 0.
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Ether transfer failed");
        balances[msg.sender] = 0;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

// This interface lets the same attacker target either BankRE or BankSafe.
interface IBankB5 {
    function deposit() external payable;
    function withdraw() external;
    function balances(address account) external view returns (uint256);
}

// Exercise 2: Complete this contract.
contract AttackerRE {
    IBankB5 public bank;

    constructor(address bankAddress) {
        bank = IBankB5(bankAddress);
    }

    function attack() external payable {
        // TODO: Deposit msg.value into bank, then withdraw.
        revert("TODO: implement attack");
    }

    // TODO: Implement an appropriate payable receive/fallback callback
    // that can reenter BankRE. You can add counters/events as evidence.

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

// Exercise 3: Implement a secure bank with the same external interface.
contract BankSafe {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        // TODO: Write a withdrawal routine that prevents reentrancy.
        revert("TODO: implement defense");
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
