;; Royalty Schedule - Recurring Royalty Payments Contract
;; A time-locked contract for scheduled royalty distributions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-not-due (err u104))
(define-constant err-already-claimed (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-invalid-interval (err u107))

;; Data Variables
(define-data-var next-schedule-id uint u1)

;; Data Maps
(define-map royalty-schedules
  { schedule-id: uint }
  {
    beneficiary: principal,
    amount-per-payment: uint,
    payment-interval: uint, ;; blocks between payments
    next-payment-block: uint,
    total-payments: uint,
    payments-made: uint,
    is-active: bool,
    creator: principal
  }
)

(define-map payment-history
  { schedule-id: uint, payment-number: uint }
  {
    amount: uint,
    block-height: uint,
    timestamp: uint
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

;; Read-only Functions
(define-read-only (get-schedule (schedule-id uint))
  (map-get? royalty-schedules { schedule-id: schedule-id })
)

(define-read-only (get-payment-history (schedule-id uint) (payment-number uint))
  (map-get? payment-history { schedule-id: schedule-id, payment-number: payment-number })
)

(define-read-only (get-next-schedule-id)
  (var-get next-schedule-id)
)

(define-read-only (is-payment-due (schedule-id uint))
  (match (get-schedule schedule-id)
    schedule
    (and 
      (get is-active schedule)
      (>= block-height (get next-payment-block schedule))
      (< (get payments-made schedule) (get total-payments schedule))
    )
    false
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-schedule-status (schedule-id uint))
  (match (get-schedule schedule-id)
    schedule
    (ok {
      payments-remaining: (- (get total-payments schedule) (get payments-made schedule)),
      next-payment-due: (get next-payment-block schedule),
      is-active: (get is-active schedule),
      blocks-until-next: (if (>= block-height (get next-payment-block schedule)) 
                           u0 
                           (- (get next-payment-block schedule) block-height))
    })
    err-not-found
  )
)

;; Public Functions

;; Create a new royalty schedule
(define-public (create-royalty-schedule 
  (beneficiary principal) 
  (amount-per-payment uint) 
  (payment-interval uint) 
  (first-payment-delay uint) 
  (total-payments uint))
  (let
    (
      (schedule-id (var-get next-schedule-id))
      (first-payment-block (+ block-height first-payment-delay))
    )
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (> amount-per-payment u0) err-invalid-amount)
    (asserts! (> payment-interval u0) err-invalid-interval)
    (asserts! (> total-payments u0) err-invalid-amount)
    
    ;; Create the schedule
    (map-set royalty-schedules
      { schedule-id: schedule-id }
      {
        beneficiary: beneficiary,
        amount-per-payment: amount-per-payment,
        payment-interval: payment-interval,
        next-payment-block: first-payment-block,
        total-payments: total-payments,
        payments-made: u0,
        is-active: true,
        creator: tx-sender
      }
    )
    
    ;; Increment the next schedule ID
    (var-set next-schedule-id (+ schedule-id u1))
    (ok schedule-id)
  )
)

;; Fund the contract
(define-public (fund-contract (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (stx-transfer? amount tx-sender (as-contract tx-sender))
  )
)

;; Claim a royalty payment
(define-public (claim-payment (schedule-id uint))
  (let
    (
      (schedule (unwrap! (get-schedule schedule-id) err-not-found))
      (payment-number (+ (get payments-made schedule) u1))
    )
    (asserts! (get is-active schedule) err-not-found)
    (asserts! (is-eq tx-sender (get beneficiary schedule)) err-owner-only)
    (asserts! (>= block-height (get next-payment-block schedule)) err-not-due)
    (asserts! (< (get payments-made schedule) (get total-payments schedule)) err-already-claimed)
    (asserts! (>= (get-contract-balance) (get amount-per-payment schedule)) err-insufficient-funds)
    
    ;; Transfer the payment
    (try! (as-contract (stx-transfer? (get amount-per-payment schedule) tx-sender (get beneficiary schedule))))
    
    ;; Record payment history
    (map-set payment-history
      { schedule-id: schedule-id, payment-number: payment-number }
      {
        amount: (get amount-per-payment schedule),
        block-height: block-height,
        timestamp: (unwrap-panic (get-block-info? time block-height))
      }
    )
    
    ;; Update the schedule
    (map-set royalty-schedules
      { schedule-id: schedule-id }
      (merge schedule {
        payments-made: payment-number,
        next-payment-block: (+ block-height (get payment-interval schedule)),
        is-active: (< payment-number (get total-payments schedule))
      })
    )
    
    (ok payment-number)
  )
)

;; Deactivate a royalty schedule (owner only)
(define-public (deactivate-schedule (schedule-id uint))
  (let
    (
      (schedule (unwrap! (get-schedule schedule-id) err-not-found))
    )
    (asserts! (is-contract-owner) err-owner-only)
    
    (map-set royalty-schedules
      { schedule-id: schedule-id }
      (merge schedule { is-active: false })
    )
    (ok true)
  )
)

;; Reactivate a royalty schedule (owner only)
(define-public (reactivate-schedule (schedule-id uint))
  (let
    (
      (schedule (unwrap! (get-schedule schedule-id) err-not-found))
    )
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (< (get payments-made schedule) (get total-payments schedule)) err-already-claimed)
    
    (map-set royalty-schedules
      { schedule-id: schedule-id }
      (merge schedule { is-active: true })
    )
    (ok true)
  )
)

;; Emergency withdraw (owner only)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (<= amount (get-contract-balance)) err-insufficient-funds)
    (as-contract (stx-transfer? amount tx-sender contract-owner))
  )
)

;; Batch claim multiple payments for a schedule
(define-public (batch-claim-payments (schedule-id uint) (max-claims uint))
  (let
    (
      (schedule (unwrap! (get-schedule schedule-id) err-not-found))
      (result (fold claim-if-due 
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) ;; max 10 payments at once
                { schedule-id: schedule-id, claims-made: u0, max-claims: max-claims }))
    )
    (asserts! (is-eq tx-sender (get beneficiary schedule)) err-owner-only)
    (asserts! (get is-active schedule) err-not-found)
    
    (ok (get claims-made result))
  )
)

;; Helper function for batch claiming
(define-private (claim-if-due (iteration uint) (state { schedule-id: uint, claims-made: uint, max-claims: uint }))
  (let
    (
      (schedule-id (get schedule-id state))
      (claims-made (get claims-made state))
      (max-claims (get max-claims state))
    )
    (if (and (< claims-made max-claims) (is-payment-due schedule-id))
      (match (claim-payment schedule-id)
        success (merge state { claims-made: (+ claims-made u1) })
        error state
      )
      state
    )
  )
)