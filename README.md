# VaultStream Protocol

### Autonomous Bitcoin Yield Orchestration on Stacks

---

## Overview

**VaultStream Protocol** is a next-generation **autonomous yield orchestration engine** built on the **Stacks blockchain**. It transforms passive Bitcoin holdings into **actively optimized, yield-bearing assets**, while ensuring **capital sovereignty** and **risk-controlled allocation**.

The protocol intelligently distributes user deposits across multiple DeFi strategies, continuously rebalancing capital based on protocol health, allocation limits, and user-defined constraints.

VaultStream brings **institutional-grade yield optimization** to everyday Bitcoin holders without compromising custody.

---

## Key Features

* **Multi-Protocol Orchestration**
  Dynamically allocates deposits across registered yield strategies with configurable APYs and allocation limits.

* **Capital Sovereignty**
  Users retain full control and custody of funds. Deposits and withdrawals are always permissionless.

* **Risk Management**

  * Allocation caps per protocol
  * Real-time protocol deactivation by contract owner
  * Time-based yield accrual with fair withdrawal handling

* **Automated Yield Calculation**
  Returns are computed based on block height, deposit amount, and protocol APY — ensuring predictable and transparent accruals.

* **Protocol Extensibility**
  Up to `MAX-PROTOCOLS` strategies can be registered, with flexible configurations for APY, allocation limits, and active status.

---

## System Overview

At a high level, VaultStream consists of three core layers:

1. **Protocol Registry**

   * Defines supported yield strategies.
   * Each protocol has a unique ID, base APY, and allocation percentage cap.

2. **User Deposit Layer**

   * Tracks user deposits per protocol.
   * Maintains deposit timestamps for yield accrual.

3. **Yield Engine & Risk Controls**

   * Continuously calculates time-weighted yield based on deposits and block height.
   * Enforces allocation caps, maximum deposit limits, and protocol deactivation when necessary.

---

## Contract Architecture

### Core Components

* **Error Constants**
  Robust error codes for predictable failure handling (e.g., `ERR-INVALID-PROTOCOL`, `ERR-PROTOCOL-LIMIT-REACHED`).

* **Data Structures**

  * `supported-protocols`: Registry of strategies.
  * `user-deposits`: Tracks user balances and deposit times.
  * `protocol-total-deposits`: Tracks protocol-level TVL.

* **State Variables**

  * `total-protocols`: Global counter for active registered strategies.

* **Validation Utilities**
  Private functions ensure inputs meet protocol constraints (e.g., deposit limits, APY bounds, string length).

* **Authorization**

  * Contract owner has exclusive rights to add/deactivate protocols.
  * All deposit/withdrawal operations are user-controlled.

### Key Public Functions

* **Protocol Management**

  * `add-protocol`: Register a new yield strategy.
  * `deactivate-protocol`: Temporarily disable a strategy.
  * `initialize-protocols`: Bootstrap with default strategies.

* **User Operations**

  * `deposit`: Allocate funds into a supported strategy.
  * `withdraw`: Retrieve funds plus accrued yield.

* **Yield Calculation**

  * `calculate-yield`: View accrued yield for a given user and protocol.

---

## Data Flow (Simplified)

1. **Deposit Flow**

   * User deposits → Validation checks → Allocation cap enforcement → Position recorded → Protocol TVL updated.

2. **Yield Accrual**

   * Yield is not pre-distributed.
   * On withdrawal or yield query, accrual is calculated based on deposit time and protocol APY.

3. **Withdrawal Flow**

   * User initiates withdrawal → Protocol yield calculated → Principal + yield returned → State updated.

---

## Initialization

VaultStream comes with two default strategies out-of-the-box:

* **StacksVault Prime** — 5.00% APY, 20% allocation cap.
* **Lightning Liquidity Pool** — 7.50% APY, 30% allocation cap.

Additional protocols can be registered by the contract owner up to `MAX-PROTOCOLS`.

---

## Security & Risk Considerations

* **Capital Limits** — Maximum deposit amount enforced per user.
* **Protocol Isolation** — Each protocol has strict allocation caps to avoid overexposure.
* **Fail-Safe Controls** — Protocol owner may deactivate unhealthy strategies.
* **Deterministic Yield** — All yield calculations are transparent, formula-driven, and time-weighted.

---

## Getting Started

1. Deploy the contract on the Stacks blockchain.
2. Call `initialize-protocols` to bootstrap strategies.
3. Users may then interact with `deposit`, `withdraw`, and `calculate-yield`.
4. Protocol owner may extend or deactivate protocols as needed.

---

## License

This project is released under the **MIT License**. See `LICENSE` for details.
