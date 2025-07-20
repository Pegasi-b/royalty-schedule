# Royalty Schedule Smart Contract

A time-locked smart contract for recurring royalty payments on the Stacks blockchain, built with Clarity. This contract enables automated, scheduled distributions of STX tokens to beneficiaries over time.

## Overview

The Royalty Schedule contract allows creators, publishers, or rights holders to set up automated royalty payment schedules that release funds to beneficiaries at predetermined intervals. Each payment is time-locked and can only be claimed after a specified number of blocks have passed.

## Key Features

- ⏰ **Time-Locked Payments**: Payments are released based on block height intervals
- 🔄 **Recurring Distributions**: Automated scheduling for multiple payments
- 🎯 **Multiple Beneficiaries**: Support for different royalty schedules per beneficiary
- 🛡️ **Security Controls**: Owner-only management functions with comprehensive validations
- 📊 **Payment Tracking**: Complete history of all payments and schedules
- ⚡ **Batch Processing**: Claim multiple due payments in a single transaction
- 🚨 **Emergency Controls**: Emergency withdrawal capabilities for contract owner

## Contract Architecture

### Data Structures

#### Royalty Schedules
Each schedule contains:
- `beneficiary`: The principal who can claim payments
- `amount-per-payment`: STX amount per payment (in microSTX)
- `payment-interval`: Number of blocks between payments
- `next-payment-block`: Block height when next payment becomes available
- `total-payments`: Total number of payments in the schedule
- `payments-made`: Number of payments already claimed
- `is-active`: Whether the schedule is currently active
- `creator`: Principal who created the schedule

#### Payment History
Tracks each payment with:
- `amount`: Payment amount
- `block-height`: Block when payment was made
- `timestamp`: Unix timestamp of the payment

## Usage Guide

### 1. Deploy the Contract

Deploy the contract to the Stacks blockchain. The deploying address becomes the contract owner.

### 2. Create Royalty Schedules

Only the contract owner can create new royalty schedules:

```clarity
;; Create a schedule for monthly royalties
;; 100 STX every 4320 blocks (~30 days), starting in 144 blocks (~1 day)
;; Total of 12 payments (1 year)
(contract-call? .royalty-schedule create-royalty-schedule 
  'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX975CN1QP 
  u100000000    ;; 100 STX in microSTX
  u4320         ;; ~30 days in blocks
  u144          ;; ~1 day delay
  u12)          ;; 12 total payments
```

### 3. Fund the Contract

Add STX tokens to cover the scheduled payments:

```clarity
;; Fund with 1500 STX (extra buffer for 12 x 100 STX payments)
(contract-call? .royalty-schedule fund-contract u1500000000)
```

### 4. Claim Payments

Beneficiaries can claim their payments when due:

```clarity
;; Claim payment for schedule ID 1
(contract-call? .royalty-schedule claim-payment u1)

;; Or batch claim up to 5 due payments at once
(contract-call? .royalty-schedule batch-claim-payments u1 u5)
```

### 5. Monitor Schedules

Check schedule status and payment history:

```clarity
;; Get schedule details
(contract-call? .royalty-schedule get-schedule u1)

;; Check if payment is due
(contract-call? .royalty-schedule is-payment-due u1)

;; Get schedule status summary
(contract-call? .royalty-schedule get-schedule-status u1)

;; Check payment history
(contract-call? .royalty-schedule get-payment-history u1 u3)
```

## Function Reference

### Public Functions

#### `create-royalty-schedule`
**Owner Only** - Creates a new royalty payment schedule.

**Parameters:**
- `beneficiary` (principal): Address that can claim payments
- `amount-per-payment` (uint): Payment amount in microSTX
- `payment-interval` (uint): Blocks between payments
- `first-payment-delay` (uint): Blocks until first payment
- `total-payments` (uint): Number of payments in schedule

**Returns:** Schedule ID

#### `fund-contract`
Adds STX to the contract balance to cover payments.

**Parameters:**
- `amount` (uint): STX amount in microSTX

#### `claim-payment`
**Beneficiary Only** - Claims a single due payment.

**Parameters:**
- `schedule-id` (uint): ID of the schedule to claim from

**Returns:** Payment number

#### `batch-claim-payments`
**Beneficiary Only** - Claims multiple due payments at once.

**Parameters:**
- `schedule-id` (uint): ID of the schedule
- `max-claims` (uint): Maximum payments to claim (up to 10)

**Returns:** Number of payments claimed

#### `deactivate-schedule`
**Owner Only** - Temporarily disables a schedule.

**Parameters:**
- `schedule-id` (uint): Schedule to deactivate

#### `reactivate-schedule`
**Owner Only** - Re-enables a deactivated schedule.

**Parameters:**
- `schedule-id` (uint): Schedule to reactivate

#### `emergency-withdraw`
**Owner Only** - Withdraws STX from contract in emergencies.

**Parameters:**
- `amount` (uint): Amount to withdraw in microSTX

### Read-Only Functions

#### `get-schedule`
Returns complete schedule information.

#### `is-payment-due`
Checks if a payment is ready to be claimed.

#### `get-schedule-status`
Returns schedule status summary including remaining payments and blocks until next payment.

#### `get-contract-balance`
Returns current STX balance of the contract.

#### `get-payment-history`
Returns details of a specific payment.

## Error Codes

- `u100`: Owner-only function called by non-owner
- `u101`: Schedule or payment not found
- `u102`: Schedule already exists
- `u103`: Insufficient contract funds
- `u104`: Payment not yet due
- `u105`: All payments already claimed
- `u106`: Invalid amount (must be > 0)
- `u107`: Invalid interval (must be > 0)

## Use Cases

### 1. Content Creator Royalties
Set up recurring payments to content creators, musicians, or authors based on revenue sharing agreements.

### 2. Investment Distributions
Schedule regular dividend payments to investors or token holders.

### 3. Subscription Services
Create time-locked payment schedules for service providers or contractors.

### 4. Vesting Schedules
Implement token or equity vesting with scheduled releases over time.

### 5. Revenue Sharing
Automate revenue distribution among multiple stakeholders.

## Security Considerations

1. **Owner Privileges**: The contract owner has significant control including schedule management and emergency withdrawals
2. **Time Dependencies**: Payment timing depends on Stacks block production (~10 minutes per block)
3. **Balance Management**: Ensure sufficient contract balance before creating schedules
4. **Beneficiary Verification**: Only specified beneficiaries can claim their payments
5. **Immutable Schedules**: Once created, schedule parameters cannot be modified (only activated/deactivated)

## Block Time Reference

Stacks blocks are produced approximately every 10 minutes:
- 1 hour ≈ 6 blocks
- 1 day ≈ 144 blocks  
- 1 week ≈ 1,008 blocks
- 1 month ≈ 4,320 blocks
- 1 year ≈ 52,560 blocks

## Example Scenarios

### Monthly Creator Royalties
```clarity
;; 50 STX monthly for 2 years
(create-royalty-schedule artist-wallet u50000000 u4320 u144 u24)
```

### Quarterly Investor Distributions  
```clarity
;; 1000 STX quarterly for 5 years
(create-royalty-schedule investor-wallet u1000000000 u12960 u144 u20)
```

### Weekly Contractor Payments
```clarity
;; 25 STX weekly for 12 weeks
(create-royalty-schedule contractor-wallet u25000000 u1008 u0 u12)
```
