# Prediction Market Smart Contract UI

## ABOUT

This smart contract implements a decentralized prediction market on the Stacks blockchain. Users can create markets, place bets, resolve markets, and claim payouts. The contract is designed to be fair, transparent, and efficient.

## Features

- Create prediction markets
- Place bets on market outcomes (Yes/No)
- Resolve markets
- Claim payouts for winning bets
- Fee system for contract sustainability

## Contract Details

- *Language*: Clarity
- *Blockchain*: Stacks
- *Minimum Bet*: 1 STX (1,000,000 microSTX)
- *Fee*: 0.5% of winnings

## Functions

### Public Functions

1. create-market: Create a new prediction market
2. place-bet: Place a bet on a market outcome
3. resolve-market: Resolve a market (only by market creator)
4. claim-payout: Claim winnings from a resolved market
5. withdraw-fees: Withdraw accumulated fees (only by contract owner)

### Read-only Functions

1. get-market-info: Get information about a specific market
2. get-user-bets: Get a user's bets for a specific market
3. get-accumulated-fees: Get the total accumulated fees


- Parameters:
  - Market ID (uint): The ID of the market
  - Bet outcome (bool): true for "Yes", false for "No"
  - Amount (uint): Bet amount in microSTX (minimum 1,000,000)

### Resolving a Market

To resolve a market (only by the market creator):

clarity
(contract-call? .prediction-market resolve-market u1 true)


- Parameters:
  - Market ID (uint): The ID of the market
  - Outcome (bool): true for "Yes", false for "No"

### Claiming a Payout

To claim a payout for a winning bet:

- Parameters:
  - Market ID (uint): The ID of the resolved market

### Withdrawing Fees

To withdraw accumulated fees (only by contract owner):

clarity
(contract-call? .prediction-market withdraw-fees)


## Error Codes

- ERR-UNAUTHORIZED (u100): Unauthorized action
- ERR-ALREADY-INITIALIZED (u101): Market already initialized
- ERR-NOT-INITIALIZED (u102): Market not initialized
- ERR-INVALID-BET (u103): Invalid bet parameters
- ERR-MARKET-CLOSED (u104): Market is closed for betting
- ERR-ALREADY-RESOLVED (u105): Market already resolved
- ERR-INSUFFICIENT-BALANCE (u106): Insufficient balance for bet
- ERR-NO-PAYOUT (u107): No payout available

## Security Considerations

- Only the market creator can resolve a market
- Markets can only be resolved after the specified resolution timestamp
- Minimum bet amount and description length to prevent spam
- Fee system to incentivize contract maintenance and prevent abuse

## Limitations

- Binary outcomes only (Yes/No)
- No partial withdrawals or bet cancellations
- Fixed fee percentage

## Future Improvements

- Multiple outcome support
- Dynamic fee adjustment
- Partial bet withdrawal
- Integration with external data sources for automated resolution

## AUTHOR
ESTHER OJO