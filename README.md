# Advanced Smart Escrow Contract

This project implements an advanced smart escrow contract on the Ethereum blockchain. The contract facilitates secure transactions between multiple buyers and sellers, with features for dispute resolution, partial fund releases, and staking.

## Features

- Multi-party escrow: Supports multiple buyers and sellers in a single agreement.
- Time-locked escrows: Agreements have an expiration date.
- Partial releases: Funds can be released partially.
- Dispute resolution: Allows for dispute initiation and resolution by an arbitrator.
- Staking mechanism: Parties can stake funds, which could be used for dispute resolution.
- Fee structure: A service fee is charged on fund releases.
- Cancellation with conditions: Agreements can be cancelled if not disputed or expired.

## Smart Contract Functions

- `createAgreement`: Create a new escrow agreement.
- `depositFunds`: Allow buyers to deposit funds into the escrow.
- `releaseFunds`: Release funds to sellers (requires approval from all buyers).
- `initiateDispute`: Start a dispute on an agreement.
- `resolveDispute`: Resolve a dispute (only callable by the contract owner).
- `cancelAgreement`: Cancel an agreement under certain conditions.
- `depositStake`: Allow parties to deposit a stake.

## Testing

The project includes a comprehensive test suite using the Brownie framework. To run the tests:

```
brownie test
```

## Deployment

To deploy the contract to a network:

```
brownie run scripts/deploy.py --network <network-name>
```

Replace `<network-name>` with the desired network (e.g., 'development', 'goerli', 'mainnet').

## Security Considerations

This contract handles financial transactions and should be **thoroughly** audited before use in a production environment. Do not use this in a production enviroment.

I added a few key security features, including:

- Use of OpenZeppelin's `ReentrancyGuard` for protection against reentrancy attacks.
- Use of SafeMath for arithmetic operations to prevent overflows.


