# Text to EVM Transaction (Text to EVM Action)

## Goal

Given a text description, the model should generate a valid Ethereum Virtual Machine (EVM) transaction. The description may include specific EVM addresses, ENS names, UNS names, or commercial names of DeFi products. The model should have a semantic understanding of popular contracts on the selected blockchain (e.g., EVM Mainnet, Base, Optimism, Arbitrum).

## Evaluation

Generated transactions will be evaluated for:
- **Accuracy**: The transaction must correctly reflect the described actions and interact with the specified contracts.  If the prompt included explicit EVM addresses, ENs names, UNS names or well used smart contract names then these should be recognized and included in the transaction 
- **Validity**: The transaction must be valid and executable on the specified blockchain.
- **Efficiency**: The transaction should minimize gas use and return to the user quickly. If there are multiple accurate and valid transactions they will be ranked by gas efficiency and response speed.

## Actions

### `generateTransaction()`
- **Params**:
  - `description` (string): Text description of the desired transaction. Max 4000 characters.
  - `blockchain` (string): The target blockchain described as a named string of supported listed chains(e.g., `eth mainnet`, `base`, `optimism`, `arbitrum` , `binance-bsc` , `polygon-pos`) 

- **Returns**:
  - `transaction` (hex):  Valid EVM transaction


## Performance Requirements
- Query response within 5 seconds.
- Rate limit of at least 1 request per 5seconds.
- Minimum 1000 API calls per subscription per month.

## Constraints
- The generated transactions must not interact with malicious or unauthorized contracts.
- The service must ensure the security and privacy of user data, including addresses and transaction details.
- The model should support popular DeFi products and contracts on the specified blockchain.
