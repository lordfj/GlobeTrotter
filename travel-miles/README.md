# 🌍 GlobeTrotter Travel Rewards Platform

**Version:** 1.0.0
**Smart Contract Language:** Clarity
**Token:** `TRAVEL-MILES` (Fungible Token)

## ✈️ Overview

**GlobeTrotter** is a decentralized travel rewards platform built on the Stacks blockchain. It allows users to stake "miles", earn loyalty-based travel rewards, and redeem benefits based on tiered status levels. This platform uses a fungible token system (`TRAVEL-MILES`) to track and distribute loyalty incentives.

---

## 🔐 Key Features

* **Stake & Earn:** Stake miles to gain rewards over time.
* **Status Tiers:** Achieve Silver, Gold, or Diamond status based on total miles staked.
* **Bonus Multipliers:** Earn more based on commitment duration and tier level.
* **Reward Redemption:** Periodically redeem accumulated reward miles.
* **Cancellation Protocol:** Withdraw staked miles with a built-in waiting period.
* **Admin Controls:** Set maintenance mode or activate emergency protocol for security.

---

## 🪙 Token: TRAVEL-MILES

A fungible token used to represent reward miles accrued by travelers. Minted only during redemption and cannot be arbitrarily issued.

---

## 🧾 Data Structures

### `TravelerProfile`

Tracks user-specific information:

* `miles-staked`
* `reward-miles`
* `last-check-in`
* `status-tier` (1-3)
* `bonus-multiplier`
* `loyalty-score`

### `TravelPackage`

Tracks staked package and travel activity:

* `miles`
* `departure-block`
* `last-redemption`
* `commitment-period`
* `cancellation-request`
* `unredeemed-rewards`

### `StatusLevels`

Configures perks and requirements for each tier:

* `miles-requirement`
* `perks-multiplier`
* `special-access` (e.g., early booking, concierge access)

---

## 🎮 Usage Guide

### 1. Initialize Platform

```clojure
(initialize-platform)
```

Only callable by the `owner-address`. Sets up the three status levels (Silver, Gold, Diamond).

---

### 2. Stake Miles

```clojure
(stake-miles amount lock-duration)
```

Stake a certain amount of miles. Lock duration affects bonus multiplier.

* **Minimum Stake:** `1,000,000` units
* **Bonus Tiers:**

  * ≥ 2 months (`8640` blocks) → 1.5x
  * ≥ 1 month (`4320` blocks) → 1.25x
  * < 1 month → 1x

---

### 3. Redeem Rewards

```clojure
(redeem-rewards)
```

Redeem accumulated miles based on:

* Staked amount
* Bonus multiplier
* Time elapsed since last redemption

---

### 4. Request Cancellation

```clojure
(request-cancellation amount)
```

Initiates a waiting period (`1440` blocks = 24 hours) before withdrawal.

---

### 5. Finalize Cancellation

```clojure
(finalize-cancellation amount)
```

Complete the withdrawal after the cancellation period.

---

### 6. Platform Controls (Admin Only)

```clojure
(set-platform-status true/false)
(set-emergency-protocol true/false)
```

Used by the owner to toggle maintenance or emergency mode.

---

## ⚠️ Errors & Codes

| Code   | Description                      |
| ------ | -------------------------------- |
| `3001` | Unauthorized access              |
| `3002` | Destination unavailable          |
| `3003` | Invalid miles input              |
| `3004` | Insufficient balance             |
| `3005` | Booking or lock period violation |
| `3006` | No active membership found       |
| `3007` | Minimum stake not met            |
| `3008` | Platform under maintenance       |

---

## 🧠 Smart Logic Summary

* **Rewards Calculation:**

  ```
  base = (miles * blocks_elapsed * base_rate) / 1_000_000
  boosted = base * bonus_multiplier / 100
  ```
* **Tier Thresholds:**

  * Silver: 1M+
  * Gold: 5M+
  * Diamond: 10M+
* **Bonus Multiplier:**

  * Silver: 1x
  * Gold: 1.5x
  * Diamond: 2x

---

## 🔒 Security Considerations

* Admin-only functions use `tx-sender` checks.
* All external transfers wrapped in `try!` to prevent failures.
* `platform-maintenance` and `emergency-protocol` for halting operations when needed.

---

## 📦 Deployment Notes

* Must run `initialize-platform` after deployment.
* Ensure contract has STX for transfers if using real balances.
* Future enhancements may include governance and dynamic status logic.
