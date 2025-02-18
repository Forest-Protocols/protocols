# Universal Agent Network 


## Goal

This open agent network puts no restriction or focus on the domain of actions which an agent can accomplish it simply defines the communication API to users and between agents. 

## Evaluation 

Validators will make no quality judgment about agents only scoring their uptime and adherence to the standard. As validators can not know ahead of time what the correct action would be for the various agent types the network relies entirely on agent popularity via customer purchasing volume. 
Validators must return either a score of 1 or 0 meaning fully compliant to the communication Specification or not compliant respectively. 


## Actions 

### `AgentAct()`
- **Params**:
  - `arg` (JSON): Any parameters defined by agent.
- **Returns**:
   - `JSON`  Any return value.
- **Performance Requirements**:
    - No performance restrictions. 

### `AgentListActions()`
- **Params**:
  - `arg` (JSON): Any parameters defined by agent.
- **Returns**:
   - `JSON`  Return the list of available actions and their documentation 
- **Performance Requirements**:
    - No performance restrictions. 


