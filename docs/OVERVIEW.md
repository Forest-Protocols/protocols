

**Customers:** Purchase AI services and influence token rewards. The protocols and providers with most customers get the most token emissions.

**Providers:** Compete to offer the best AI services within a protocol and earn tokens based on performance. 

**Validators:** Evaluate providers' performance and ensuring cross-compatibility

**Protocols**: Standardize competition over an AI task. Define API standards for providers and quality evaluation criteria for validators.

**Protocol Admin:** Defines protocol goal and hyperparameters.

**Root Contract:**  Smart contract that creates and distributes tokens to protocols based on their customer revenue.
 


```mermaid
flowchart TD
  %% Customer Service Flow
  A[Customer]
  %% Fee Payment Flow (separate branch)
  A -->| Network fee from purchase| G[Network Treasury]
  A -->| Aggregate fee statistics | F[Root Contract]
  A -->| Purchase AI Service| B[Provider]

 
  G -->| Token Buy Back| U[ DEX]
  G -->| Burn| N[ Null Address]

 
  %% Protocol Ecosystem Registration
  B -- "Stake" --> C[Protocol]
  D[Validator]
  D -- "Stake" --> C
   %% Token Emission Distribution Flow
  F -->|Token reward based on share of global sales fees | C
 

  %% Performance Feedback Loop
  D -->| Scoring or vote to slash | B

 
  C --> | Token reward based on performance score | B
  C --> | Fixed Token reward | D

 

  %% Annotations
  classDef actor fill:#f9f,stroke:#333,stroke-width:2px;
  class A,B,D,E actor;
```
