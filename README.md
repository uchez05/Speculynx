# Speculynx

## Overview

**Speculynx** is a decentralized prediction market built in **Clarity**, allowing users to create, participate in, and resolve markets based on real-world events. Participants stake STX tokens on possible outcomes, and correct predictions are rewarded proportionally from the collective pool.

## Key Features

* **Market Creation:** Users can launch new markets by defining a question, number of outcomes, and resolution time.
* **Outcome Definition:** Market creators can define multiple possible outcomes for each market.
* **Staking Mechanism:** Participants can stake STX tokens on any outcome before the resolution deadline.
* **Market Resolution:** Only the market creator can finalize the event by selecting the winning outcome after the resolution block.
* **Reward Distribution:** Users who staked on the correct outcome can claim rewards based on their proportional stake.
* **Read-only Queries:** Functions to fetch market details, user positions, and status checks are available for transparency.

## Contract Components

### Data Structures

* **market-registry:** Stores market details including creator, question, resolution info, and total staked funds.
* **outcome-registry:** Records descriptions and total stakes per outcome.
* **position-registry:** Tracks user stakes per outcome per market.
* **market-counter:** Keeps count of total markets created.

### Error Constants

Defines errors such as missing data, invalid parameters, forbidden access, expired deadlines, and transfer failures.

### Core Functions

* **(new-market)** – Creates a new market with a question, number of outcomes, and resolution timeframe.
* **(add-outcome)** – Adds outcome options for a market (only callable by the market creator).
* **(place-stake)** – Allows users to stake STX tokens on an outcome before the resolution block.
* **(finalize-market)** – Marks the market as resolved and declares the winning outcome.
* **(claim-reward)** – Enables participants who chose the winning outcome to claim their proportional rewards.

### Read-Only Functions

* **(fetch-market-info)** – Retrieves market details.
* **(fetch-outcome-info)** – Retrieves outcome details.
* **(fetch-position)** – Shows user staking positions.
* **(fetch-market-count)** – Returns the total number of markets created.
* **(check-active)** – Verifies if a market is still open for participation.

## Summary

**Speculynx** promotes decentralized event forecasting by empowering users to create, fund, and resolve prediction markets transparently. With its secure staking, reward distribution, and resolution mechanisms, it ensures fairness and verifiable outcomes on the Stacks blockchain.
