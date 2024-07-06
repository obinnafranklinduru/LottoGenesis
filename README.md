# LottoGenesis

## Overview

LottoGenesis is a decentralized lottery system built on the Ethereum blockchain. It leverages the transparency, security, and immutability of smart contracts to offer a fair and auditable lottery experience. The smart contract utilizes Chainlink VRF (Verifiable Random Function) for randomness and Chainlink Keepers for automation. The contract allows participants to enter the lottery, and at defined intervals, a random winner is selected to receive the accumulated prize pool.

## Features

- **Lottery Participation**: Users can enter the lottery by sending ETH.
- **Automated Draws**: Chainlink Keepers handle the timing of lottery draws.
- **Random Winner Selection**: Chainlink VRF ensures a provably fair random winner selection.

## Contract Details

- **Entrance Fee**: The fee required to enter the lottery.
- **Interval**: The time interval between each lottery draw.
- **Subscription ID**: Chainlink VRF subscription ID.
- **Callback Gas Limit**: Gas limit for the callback function from the VRF coordinator.

## How to Use

### Requirements

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - Ensure Git is installed by running `git --version`.
- [Foundry](https://getfoundry.sh/)
  - Ensure Foundry is installed by running `forge --version`.
- [Make](https://www.gnu.org/software/make/)
  - Ensure Make is installed by running `make --version`.

### Installation

Clone the repository and remove dependencies:

```bash
git clone https://github.com/obinnafranklinduru/LottoGenesis
cd LottoGenesis
make remove
```

install dependencies:

```bash
make install
```

Update dependencies to the latest versions:

```bash
make update
```

### Environment Variables

Create a `.env` file in the root directory and add your environment variables:

```plaintext
PRIVATE_KEY=XXXXXXXXX
RPC_URL=http://0.0.0.0:8545
ETHERSCAN_API_KEY=XXXX
```

### Deployment

Deploy the contract with the following parameters:

- `_entranceFee`: Fee to enter the lottery.
- `_interval`: Time interval between lottery draws.
- `_vrfCoordinator`: Address of the Chainlink VRF coordinator.
- `_keyHash`: Key hash for the VRF.
- `_subscriptionId`: Subscription ID for the VRF.
- `_callbackGasLimit`: Gas limit for the callback function.

### Enter the Lottery

To enter the lottery, participants need to send a transaction with enough ETH to cover the entrance fee.

```solidity
function enterLottoGenesis() public payable
```

### Check Upkeep

Checks if upkeep is needed for the lottery (i.e., time for a new draw).

```solidity
function checkUpkeep(bytes memory /* checkData */ ) public view override returns (bool upkeepNeeded, bytes memory /* performData */ )
```

### Perform Upkeep

Performs the upkeep by requesting random words from the VRF coordinator to select a winner.

```solidity
function performUpkeep(bytes calldata /* performData */ ) external override
```

### Fulfill Random Words

Fulfills the random words request and selects the winner.

```solidity
function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override
```

## Events

- **EnteredLottoGenesis**: Emitted when a player enters the lottery.
- **RequestedLottoGenesisWinner**: Emitted when a random winner request is made.
- **WinnerPicked**: Emitted when a winner is picked.
- **Withdrawal**: Emitted when the prize is transferred to the winner.

## Getter Functions

- `getsLottoGenesisState()`: Returns the current state of the lottery.
- `getNumWords()`: Returns the number of random words requested.
- `getRequestConfirmations()`: Returns the number of request confirmations.
- `getRecentWinner()`: Returns the address of the most recent winner.
- `getPlayer(uint256 index)`: Returns the address of a player by index.
- `getLastTimeStamp()`: Returns the timestamp of the last winner selection.
- `getInterval()`: Returns the interval between draws.
- `getEntranceFee()`: Returns the entrance fee.
- `getNumberOfPlayers()`: Returns the number of players in the lottery.

## Contributing

PRs are welcome!

```bash
git clone https://github.com/obinnafranklinduru/LottoGenesis
cd LottoGenesis
make help
```
