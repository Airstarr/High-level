;; Prediction Market Betting Contract

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_MARKET (err u101))
(define-constant ERR_INVALID_BET_AMOUNT (err u102))
(define-constant ERR_MARKET_CLOSED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_MARKET_NOT_RESOLVED (err u105))

;; Data Variables
(define-data-var total-bets uint u0)

;; Maps
(define-map markets 
  { market-id: uint } 
  { 
    creator: principal,
    description: (string-ascii 256),
    options: (list 10 (string-ascii 64)),
    total-pool: uint,
    is-open: bool,
    winning-option: (optional uint)
  }
)

(define-map bets 
  { market-id: uint, better: principal } 
  {
    amount: uint,
    option: uint
  }
)

(define-map user-balances principal uint)

;; Private Functions
(define-private (transfer-stx (amount uint) (sender principal) (recipient principal))
  (stx-transfer? amount sender recipient)
)

;; Public Functions
(define-public (create-market (description (string-ascii 256)) (options (list 10 (string-ascii 64))))
  (let ((market-id (var-get total-bets)))
    (begin
      (asserts! (> (len options) u0) ERR_INVALID_MARKET)
      (map-set markets 
        { market-id: market-id }
        {
          creator: tx-sender,
          description: description,
          options: options,
          total-pool: u0,
          is-open: true,
          winning-option: none
        }
      )
      (var-set total-bets (+ market-id u1))
      (ok market-id)
    )
  )
)

(define-public (place-bet (market-id uint) (amount uint) (option uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR_INVALID_MARKET))
    (user-balance (default-to u0 (map-get? user-balances tx-sender)))
  )
    (begin
      (asserts! (get is-open market) ERR_MARKET_CLOSED)
      (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (> amount u0) ERR_INVALID_BET_AMOUNT)
      (asserts! (< option (len (get options market))) ERR_INVALID_BET_AMOUNT)
      
      (map-set bets 
        { market-id: market-id, better: tx-sender }
        { amount: amount, option: option }
      )
      (map-set markets
        { market-id: market-id }
        (merge market { total-pool: (+ (get total-pool market) amount) })
      )
      (map-set user-balances 
        tx-sender 
        (- user-balance amount)
      )
      (ok true)
    )
  )
)

(define-public (resolve-market (market-id uint) (winning-option uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) ERR_INVALID_MARKET)))
    (begin
      (asserts! (is-eq (get creator market) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (get is-open market) ERR_MARKET_CLOSED)
      (asserts! (< winning-option (len (get options market))) ERR_INVALID_BET_AMOUNT)
      
      (map-set markets
        { market-id: market-id }
        (merge market { 
          is-open: false,
          winning-option: (some winning-option)
        })
      )
      (ok true)
    )
  )
)

(define-public (claim-winnings (market-id uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR_INVALID_MARKET))
    (bet (unwrap! (map-get? bets { market-id: market-id, better: tx-sender }) ERR_INVALID_BET_AMOUNT))
    (winning-option (unwrap! (get winning-option market) ERR_MARKET_NOT_RESOLVED))
  )
    (begin
      (asserts! (not (get is-open market)) ERR_MARKET_NOT_RESOLVED)
      (asserts! (is-eq (get option bet) winning-option) ERR_INVALID_BET_AMOUNT)
      
      (let (
        (payout (/ (* (get amount bet) (get total-pool market)) (get amount bet)))
      )
        (map-delete bets { market-id: market-id, better: tx-sender })
        (map-set user-balances
          tx-sender
          (+ (default-to u0 (map-get? user-balances tx-sender)) payout)
        )
        (ok payout)
      )
    )
  )
)

(define-public (deposit-funds (amount uint))
  (let ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
    (begin
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set user-balances tx-sender (+ current-balance amount))
      (ok true)
    )
  )
)

(define-public (withdraw-funds (amount uint))
  (let ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
    (begin
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
      (map-set user-balances tx-sender (- current-balance amount))
      (ok true)
    )
  )
)

;; Read-only Functions
(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

(define-read-only (get-bet (market-id uint) (better principal))
  (map-get? bets { market-id: market-id, better: better })
)

(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)
