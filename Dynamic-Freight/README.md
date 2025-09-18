# Dynamic Freight Insurance Smart Contract

## Overview

The Dynamic Freight Insurance Smart Contract is a blockchain-based solution that adjusts insurance premiums in real-time based on cargo conditions during transport. The contract monitors environmental factors such as temperature, humidity, and shock levels to dynamically calculate risk and adjust insurance costs accordingly.

## Features

- **Real-time Premium Adjustment**: Insurance premiums are recalculated based on current cargo conditions
- **Multi-factor Risk Assessment**: Considers temperature, humidity, and shock levels
- **Sensor Integration**: Authorized sensors can update cargo conditions
- **Automated Claims Processing**: Streamlined claim filing and processing system
- **Policy Management**: Complete lifecycle management of insurance policies

## Architecture

### Core Components

1. **Policy Management**: Creation, tracking, and management of insurance policies
2. **Cargo Monitoring**: Registration and real-time monitoring of cargo conditions
3. **Risk Assessment**: Dynamic calculation of risk multipliers based on environmental conditions
4. **Premium Calculation**: Real-time adjustment of insurance premiums
5. **Claims Processing**: Filing and processing of insurance claims

### Data Structures

- **Insurance Policies**: Complete policy information including coverage, premiums, and status
- **Cargo Conditions**: Real-time environmental data for monitored cargo
- **Authorized Sensors**: Registry of authorized sensor principals

## Contract Constants

### Risk Multipliers
- Temperature (Optimal 15-25°C):
  - Low risk: 80% of base premium
  - High risk: 150% of base premium
- Humidity (Optimal ≤60%):
  - Low risk: 90% of base premium
  - High risk: 130% of base premium
- Shock (Threshold: 50G):
  - Low risk: 100% of base premium
  - High risk: 200% of base premium

### Policy Status
- Active: 1
- Expired: 2
- Claimed: 3

## Public Functions

### Sensor Management
- `authorize-sensor(sensor)`: Authorize a sensor principal (owner only)
- `revoke-sensor-authorization(sensor)`: Revoke sensor authorization (owner only)

### Cargo Management
- `register-cargo(temperature, humidity, shock)`: Register new cargo for monitoring
- `update-conditions(cargo-id, temperature, humidity, shock)`: Update cargo conditions (authorized sensors only)

### Policy Management
- `create-policy(cargo-value, duration-blocks, cargo-id)`: Create new insurance policy
- `update-premium(policy-id)`: Recalculate premium based on current conditions
- `pay-premium(policy-id)`: Pay current premium amount

### Claims Management
- `file-claim(policy-id, claim-amount)`: File insurance claim
- `process-claim(policy-id)`: Process approved claims (owner only)

## Read-Only Functions

- `get-policy(policy-id)`: Retrieve policy details
- `get-cargo-conditions(cargo-id)`: Get current cargo conditions
- `get-current-premium(policy-id)`: Get current premium amount
- `is-sensor-authorized(sensor)`: Check sensor authorization status
- `assess-risk(temperature, humidity, shock)`: Calculate risk multiplier for given conditions
- `get-total-policies()`: Get total number of policies created
- `get-total-cargo-registrations()`: Get total number of cargo registrations

## Usage Examples

### 1. Register Cargo
```clarity
(contract-call? .freight-insurance register-cargo u20 u45 u30)
;; Returns: (ok u1) - cargo ID 1
```

### 2. Create Insurance Policy
```clarity
(contract-call? .freight-insurance create-policy u100000 u1440 u1)
;; Insure cargo worth 100,000 microSTX for 1440 blocks (≈10 days)
```

### 3. Update Cargo Conditions (Authorized Sensor)
```clarity
(contract-call? .freight-insurance update-conditions u1 u28 u75 u45)
;; Update cargo 1: temperature 28°C, humidity 75%, shock 45G
```

### 4. Pay Premium
```clarity
(contract-call? .freight-insurance pay-premium u1)
;; Pay current premium for policy 1
```

### 5. File Claim
```clarity
(contract-call? .freight-insurance file-claim u1 u50000)
;; File claim for 50,000 microSTX on policy 1
```

## Error Codes

- `u100`: Unauthorized access
- `u101`: Policy not found
- `u102`: Policy expired
- `u103`: Invalid premium
- `u104`: Insufficient payment
- `u105`: Claim already processed
- `u106`: Invalid condition value
- `u107`: Policy already exists
- `u108`: Invalid duration
- `u109`: Cargo not found
- `u110`: Sensor not authorized

## Risk Assessment Logic

The contract calculates risk using a multi-factor approach:

1. **Temperature Risk**: Optimal range 15-25°C
2. **Humidity Risk**: Optimal ≤60%
3. **Shock Risk**: Threshold at 50G

Risk multipliers are combined: `(temp_multiplier × humidity_multiplier × shock_multiplier) ÷ 10000`

## Security Features

- **Access Control**: Owner-only functions for sensitive operations
- **Sensor Authorization**: Only authorized sensors can update conditions
- **Policy Validation**: Comprehensive validation of policy parameters
- **Claim Protection**: Prevention of duplicate claims

## Deployment Requirements

- Stacks blockchain compatible environment
- Clarity smart contract runtime
- STX tokens for premium payments and claims

## Integration Guidelines

### For Sensor Providers
1. Obtain authorization from contract owner
2. Implement condition reporting using `update-conditions`
3. Ensure data accuracy and timeliness

### For Insurance Providers
1. Deploy contract with appropriate base premium rates
2. Authorize trusted sensor networks
3. Monitor policy performance and claims

### For Cargo Owners
1. Register cargo before transport
2. Create insurance policy with appropriate coverage
3. Monitor premium changes and pay as required
4. File claims when necessary