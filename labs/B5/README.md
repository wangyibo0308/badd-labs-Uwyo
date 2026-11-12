# Lab B5: Reentrancy Attacks and Defenses

**Topic:** Smart-contract implementation security  
**Environment:** Remix IDE — Remix VM (local, simulated blockchain)  
**Total:** 100 points  
**Submission:** Solidity source code (`.sol`) and a brief evidence report with screenshots

## Overview

A **reentrancy attack** occurs when a contract makes an external call before completing a security-relevant state update, allowing the called contract to invoke the original contract again while its state is inconsistent. In this lab, you will observe Solidity's callback behavior, exploit an intentionally vulnerable bank, and implement and evaluate a defense.

The lab addresses **implementation-level vulnerabilities**: the bank's withdrawal procedure uses an unsafe ordering of operations. The broader lesson—how untrusted components interact with shared state—also applies to other distributed software.

### Learning outcomes

After completing this lab, you should be able to:

1. Explain when Solidity's `fallback()` and `receive()` functions run.
2. Identify a reentrancy vulnerability in a contract's control flow.
3. Implement an attacker contract that causes multiple withdrawals from one deposit.
4. Measure the impact using Ether balances and execution evidence.
5. Implement a defense and experimentally confirm that the attack no longer steals other users' funds.

## Experimental setup and safety

1. Open [Remix IDE](https://remix.ethereum.org/) and create a new Solidity file. You may start from the provided [`Lab_B5_Starter.sol`](https://github.com/wangyibo0308/badd-labs-Uwyo/blob/master/labs/B5/Lab_B5_Starter.sol).
2. In **Solidity Compiler**, use a stable Solidity `0.8.x` compiler with version **0.8.20 or later** (but below `0.9.0`). Record the compiler version in your report.
3. In **Deploy & Run Transactions**, select **Remix VM**, *not* Browser Extension, an injected wallet, a public testnet, or mainnet. This sandbox uses simulated Ether only.
4. Use a fresh Remix VM or fresh contract instances for each experiment so that old deposits cannot affect the results.
5. Use the Remix **Value** field to attach Ether when calling `payable` functions. The Value field is reset or changed as needed for each call; check it before every transaction.

**Important:** Use only the local simulation. Never run the attack against contracts you do not control.

## Exercise 1 — Observe a fallback function (20 points)

### Provided contracts

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
```

### Steps

1. Deploy `FallbackReceiver` and record its address, **R**.
2. Deploy `FallbackSender`.
3. Set Remix **Value** to **0.1 ether** and call `FallbackSender.call(R)`.
4. Expand the transaction details and inspect the emitted `Log` event. Call `FallbackReceiver.getBalance()` and record its value in wei (0.1 ether is `100000000000000000` wei).
5. Explain **why `fallback()` executed**, rather than another function. In your answer, mention the empty calldata and the absence of a `receive()` function.

**Evidence:** Screenshot showing the successful transaction's `Log` event and the receiver's balance; include both contract addresses if practical.

## Exercise 2 — Implement and reproduce a reentrancy attack (50 points)

### Vulnerable bank (provided; do not modify for Exercise 2)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BankRE {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // Deliberately vulnerable: external call before the state update.
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Ether transfer failed");

        balances[msg.sender] = 0;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
```

### Your task

Implement a second contract called `AttackerRE` that targets `BankRE`. Your contract must:

- Accept the target bank's address in its constructor.
- Expose a `payable` function named `attack()`.
- Deposit the Ether supplied to `attack()` into the target bank and then initiate a withdrawal.
- Handle incoming Ether with an appropriate payable callback and attempt to reenter the bank's withdrawal procedure before the bank clears the attacker's recorded balance.
- Provide a way to report the Ether held by `AttackerRE` after the experiment. You may also emit events or count callbacks to make the repeated calls observable.

You may add supporting state and helper functions. Do **not** modify `BankRE`, the victim's deposit, or Remix VM balances directly.

### Reproducible attack experiment

Use **two different externally owned accounts (EOAs)** in Remix. Let **C** represent an ordinary customer and **D** the account that deploys and invokes the attacker contract.

1. Deploy a fresh `BankRE` instance.
2. Select account **C**, set Value to **5 ether**, and call `BankRE.deposit()`. Confirm that `BankRE.getBalance()` is 5 ether and `BankRE.balances(C)` is 5 ether.
3. Select account **D** and deploy `AttackerRE`, passing the `BankRE` address to its constructor.
4. Set Value to **1 ether** and invoke `AttackerRE.attack()` from account **D**.
5. Record the transaction outcome, the bank's actual Ether balance, `BankRE.balances(C)`, and the attacker's actual Ether balance. Inspect transaction events or trace/debugger information for repeated withdrawals.

**Attack success criterion:** The attacker contract receives **more than the 1 ether it originally deposited**, causing the bank to lose some of account C's funds. In the reference scenario, a complete drain would leave `BankRE` with 0 ether and `AttackerRE` with 6 ether, while `balances(C)` still says 5 ether. A partial drain also demonstrates the vulnerability if it clearly exceeds the attacker's own deposit.

### Questions

1. Which exact operations in `BankRE.withdraw()` make the reentrancy possible? Identify the unsafe ordering.
2. Draw or describe the call sequence from `AttackerRE.attack()` to the bank and back to the attacker's callback, including at least **two** bank withdrawals.
3. Why does the bank's record of C's balance remain unchanged even if the bank no longer holds enough Ether to repay C?

**Evidence:** Screenshots of the initial 5-ether deposit, the attack transaction or callback events, and the before/after balances.

## Exercise 3 — Implement and evaluate a secure bank (30 points)

Create a new contract called `BankSafe` with **the same external interface** as `BankRE` (`deposit()`, `withdraw()`, and `balances(address)`; `getBalance()` is also recommended).

1. Implement at least one effective reentrancy defense. Possible approaches include the **checks-effects-interactions** (CEI) pattern or a reentrancy lock/guard. You may use more than one defense.
2. Explain your defense: identify the changed code and why a reentrant callback cannot withdraw the same balance repeatedly.
3. Repeat the 5-ether victim deposit and 1-ether attacker experiment from Exercise 2 with a **fresh** `BankSafe` instance. Deploy a new `AttackerRE` instance that targets `BankSafe`, but **do not change the attack logic**.
4. Confirm that no money belonging to account C is stolen. The attempted attack **may revert** or may terminate without stealing funds, depending on the defense and the callback's error handling. Either outcome is acceptable if the victim's funds remain safe.
5. Verify that the defense does not break legitimate use: on a fresh `BankSafe`, have an ordinary EOA deposit 1 ether and successfully withdraw it.

**Defense success criterion:** After the attack attempt, the bank still holds enough Ether to cover the 5 ether deposited by C, and C's recorded balance is unchanged. A legitimate customer's deposit and withdrawal must continue to work.

**Evidence:** Screenshots showing the outcome of the attack against `BankSafe`, the bank's remaining Ether and C's recorded balance, and a successful normal withdrawal.

## Record your observations

Fill in the table below, using **Ether** as the unit. A reverted transaction should be labeled *reverted*; report balances after the revert.

| Experiment | Bank Ether before attack | Bank Ether after attack | Attacker contract Ether after attack | `balances(C)` after attack | Attack transaction outcome |
|---|---:|---:|---:|---:|---|
| `BankRE` | | | | | |
| `BankSafe` | | | | | |

## Grading rubric

| Component | Points |
|---|---:|
| Exercise 1: correct execution and screenshot (10); callback explanation (10) | 20 |
| Exercise 2: attacker implementation (25); convincing exploit evidence (15); analysis of root cause and call sequence (10) | 50 |
| Exercise 3: correct defense (15); evidence that the same attack cannot steal funds (10); successful legitimate withdrawal (5) | 30 |
| **Total** | **100** |

## Deliverables

Submit:

1. **`LabB5.sol`** — plain-text Solidity code containing `FallbackReceiver`, `FallbackSender`, the unchanged `BankRE`, your `AttackerRE`, and your `BankSafe`. Do not submit source code as a screenshot only.
2. **`LabB5_Report.pdf`** (or the course's designated report format) — your completed results table, brief answers to the analysis questions, a one-paragraph defense explanation, the compiler version, and the required screenshots.

All measurements and screenshots must come from your own Remix VM experiments, not from a real blockchain or a wallet-connected network.
