;; Prediction Market Smart Contract

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-INITIALIZED (err u101))
(define-constant ERR-NOT-INITIALIZED (err u102))
(define-constant ERR-INVALID-BET (err u103))
(define-constant ERR-MARKET-CLOSED (err u104))
(define-constant ERR-ALREADY-RESOLVED (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))
(define-constant ERR-NO-PAYOUT (err u107))
(define-constant MINIMUM-BET-AMOUNT u1000000) ;; 1 STX
(define-constant FEE-PERCENTAGE u5) ;; 0.5%
(define-constant MIN-DESCRIPTION-LENGTH u10)

;; Data Variables
(define-data-var market-state (string-ascii 20) "uninitialized")
(define-data-var market-id uint u0)
(define-data-var market-creator principal CONTRACT-OWNER)
(define-data-var market-description (string-utf8 256) u"")
(define-data-var resolution-timestamp uint u0)
(define-data-var total-yes-amount uint u0)
(define-data-var total-no-amount uint u0)
(define-data-var market-outcome (optional bool) none)
(define-data-var accumulated-fees uint u0)

;; Data Maps
(define-map markets uint {
  creator: principal,
  description: (string-utf8 256),
  resolution-timestamp: uint,
  total-yes-amount: uint,
  total-no-amount: uint,
  outcome: (optional bool),
  state: (string-ascii 20)
})

(define-map user-bets { market-id: uint, user: principal } { yes-amount: uint, no-amount: uint })

;; Private Functions
(define-private (is-valid-description (description (string-utf8 256)))
  (>= (len description) MIN-DESCRIPTION-LENGTH)
)

(define-private (is-market-open (market-id-param uint))
  (let ((market (unwrap! (map-get? markets market-id-param) false)))
    (and 
      (is-eq (get state market) "active")
      (< block-height (get resolution-timestamp market))
    )
  )
)

(define-private (calculate-payout (bet-amount uint) (winning-pool uint) (losing-pool uint))
  (let (
    (total-pool (+ winning-pool losing-pool))
    (payout-ratio (/ (* bet-amount u100000000) winning-pool))
    (gross-payout (/ (* total-pool payout-ratio) u100000000))
    (fee (/ (* gross-payout FEE-PERCENTAGE) u1000))
  )
    (- gross-payout fee)
  )
)

(define-private (transfer-token (amount uint) (sender principal) (recipient principal))
  (begin
    (try! (stx-transfer? amount sender recipient))
    (ok true)
  )
)

;; Public Functions
(define-public (create-market (description (string-utf8 256)) (resolution-time uint))
  (let ((new-market-id (+ (var-get market-id) u1)))
    (asserts! (> resolution-time block-height) ERR-INVALID-BET)
    (asserts! (is-valid-description description) ERR-INVALID-BET)
    (map-set markets new-market-id {
      creator: tx-sender,
      description: description,
      resolution-timestamp: resolution-time,
      total-yes-amount: u0,
      total-no-amount: u0,
      outcome: none,
      state: "active"
    })
    (var-set market-id new-market-id)
    (ok new-market-id)
  )
)

(define-public (place-bet (market-id-param uint) (bet-yes bool) (amount uint))
  (let (
    (market (unwrap! (map-get? markets market-id-param) ERR-NOT-INITIALIZED))
    (user-bet (default-to { yes-amount: u0, no-amount: u0 } 
               (map-get? user-bets { market-id: market-id-param, user: tx-sender })))
    (user-balance (stx-get-balance tx-sender))
  )
    (asserts! (is-market-open market-id-param) ERR-MARKET-CLOSED)
    (asserts! (>= amount MINIMUM-BET-AMOUNT) ERR-INVALID-BET)
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)

    (if bet-yes
      (map-set markets market-id-param 
        (merge market { total-yes-amount: (+ (get total-yes-amount market) amount) }))
      (map-set markets market-id-param 
        (merge market { total-no-amount: (+ (get total-no-amount market) amount) }))
    )

    (map-set user-bets { market-id: market-id-param, user: tx-sender } 
      (merge user-bet { 
        yes-amount: (if bet-yes (+ (get yes-amount user-bet) amount) (get yes-amount user-bet)),
        no-amount: (if bet-yes (get no-amount user-bet) (+ (get no-amount user-bet) amount))
      })
    )

    (try! (transfer-token amount tx-sender (as-contract tx-sender)))
    (ok true)
  )
)

(define-public (resolve-market (market-id-param uint) (outcome bool))
  (let ((market (unwrap! (map-get? markets market-id-param) ERR-NOT-INITIALIZED)))
    (asserts! (is-eq tx-sender (get creator market)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state market) "active") ERR-ALREADY-RESOLVED)
    (asserts! (>= block-height (get resolution-timestamp market)) ERR-MARKET-CLOSED)

    (map-set markets market-id-param 
      (merge market { 
        outcome: (some outcome),
        state: "resolved"
      })
    )
    (ok true)
  )
)

(define-public (claim-payout (market-id-param uint))
  (let (
    (market (unwrap! (map-get? markets market-id-param) ERR-NOT-INITIALIZED))
    (user-bet (unwrap! (map-get? user-bets { market-id: market-id-param, user: tx-sender }) ERR-INVALID-BET))
    (outcome (unwrap! (get outcome market) ERR-NOT-INITIALIZED))
  )
    (asserts! (is-eq (get state market) "resolved") ERR-NOT-INITIALIZED)

    (let (
      (winning-amount (if outcome (get yes-amount user-bet) (get no-amount user-bet)))
      (winning-pool (if outcome (get total-yes-amount market) (get total-no-amount market)))
      (losing-pool (if outcome (get total-no-amount market) (get total-yes-amount market)))
    )
      (asserts! (> winning-amount u0) ERR-NO-PAYOUT)

      (let (
        (payout (calculate-payout winning-amount winning-pool losing-pool))
      )
        (map-delete user-bets { market-id: market-id-param, user: tx-sender })
        (var-set accumulated-fees (+ (var-get accumulated-fees) (- (+ winning-pool losing-pool) payout)))
        (try! (as-contract (transfer-token payout tx-sender tx-sender)))
        (ok payout)
      )
    )
  )
)

(define-public (withdraw-fees)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (let ((fees (var-get accumulated-fees)))
      (var-set accumulated-fees u0)
      (try! (as-contract (transfer-token fees tx-sender CONTRACT-OWNER)))
      (ok fees)
    )
  )
)

;; Read-only Functions
(define-read-only (get-market-info (market-id-param uint))
  (ok (unwrap! (map-get? markets market-id-param) ERR-NOT-INITIALIZED))
)

(define-read-only (get-user-bets (market-id-param uint) (user principal))
  (ok (default-to { yes-amount: u0, no-amount: u0 } 
      (map-get? user-bets { market-id: market-id-param, user: user })))
)

(define-read-only (get-accumulated-fees)
  (ok (var-get accumulated-fees))
)