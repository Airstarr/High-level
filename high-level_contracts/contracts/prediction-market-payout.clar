
;; title: prediction-market-payout
;; version:
;; summary:
;; description:

;; Prediction Market Payout Management Contract

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_MARKET (err u101))
(define-constant ERR_MARKET_NOT_RESOLVED (err u102))
(define-constant ERR_ALREADY_CLAIMED (err u103))
(define-constant ERR_NO_PAYOUT (err u104))
(define-constant ERR_INSUFFICIENT_BALANCE (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))

;; Fee percentage (0.5%)
(define-constant FEE_PERCENTAGE u5)
(define-constant FEE_DENOMINATOR u1000)

;; Data Variables
(define-data-var total-fees uint u0)

;; Maps
(define-map market-payouts 
  { market-id: uint } 
  {
    total-pool: uint,
    winning-option: uint,
    is-resolved: bool
  }
)

(define-map user-bets 
  { market-id: uint, user: principal } 
  {
    amount: uint,
    option: uint,
    claimed: bool
  }
)

(define-map user-balances principal uint)

;; Private Functions
(define-private (calculate-fee (amount uint))
  (/ (* amount FEE_PERCENTAGE) FEE_DENOMINATOR)
)

(define-private (transfer-stx (amount uint) (sender principal) (recipient principal))
  (stx-transfer? amount sender recipient)
)

;; Public Functions
(define-public (resolve-market (market-id uint) (winning-option uint) (total-pool uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set market-payouts
      { market-id: market-id }
      {
        total-pool: total-pool,
        winning-option: winning-option,
        is-resolved: true
      }
    )
    (ok true)
  )
)

(define-public (claim-payout (market-id uint))
  (let (
    (market (unwrap! (map-get? market-payouts { market-id: market-id }) ERR_INVALID_MARKET))
    (bet (unwrap! (map-get? user-bets { market-id: market-id, user: tx-sender }) ERR_NO_PAYOUT))
  )
    (begin
      (asserts! (get is-resolved market) ERR_MARKET_NOT_RESOLVED)
      (asserts! (not (get claimed bet)) ERR_ALREADY_CLAIMED)
      (asserts! (is-eq (get option bet) (get winning-option market)) ERR_NO_PAYOUT)
      
      (let (
        (payout-amount (/ (* (get amount bet) (get total-pool market)) (get amount bet)))
        (fee-amount (calculate-fee payout-amount))
        (net-payout (- payout-amount fee-amount))
      )
        (map-set user-bets
          { market-id: market-id, user: tx-sender }
          (merge bet { claimed: true })
        )
        (map-set user-balances
          tx-sender
          (+ (default-to u0 (map-get? user-balances tx-sender)) net-payout)
        )
        (var-set total-fees (+ (var-get total-fees) fee-amount))
        (ok net-payout)
      )
    )
  )
)

(define-public (withdraw-balance (amount uint))
  (let (
    (user-balance (default-to u0 (map-get? user-balances tx-sender)))
  )
    (begin
      (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
      (map-set user-balances
        tx-sender
        (- user-balance amount)
      )
      (ok amount)
    )
  )
)

(define-public (withdraw-fees)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (let ((fee-amount (var-get total-fees)))
      (var-set total-fees u0)
      (try! (as-contract (stx-transfer? fee-amount (as-contract tx-sender) tx-sender)))
      (ok fee-amount)
    )
  )
)

;; Read-only Functions
(define-read-only (get-market-payout (market-id uint))
  (map-get? market-payouts { market-id: market-id })
)

(define-read-only (get-user-bet (market-id uint) (user principal))
  (map-get? user-bets { market-id: market-id, user: user })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-total-fees)
  (var-get total-fees)
)