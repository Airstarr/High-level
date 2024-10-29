;; prediction-market-core
;; Core functionality for prediction markets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-already-initialized (err u101))
(define-constant err-not-initialized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-market-closed (err u104))
(define-constant err-already-resolved (err u105))
(define-constant err-insufficient-balance (err u106))
(define-constant err-no-payout (err u107))
(define-constant err-market-not-found (err u108))
(define-constant err-too-early (err u109))

;; Configuration constants
(define-constant min-bet u1000000) ;; 1 STX minimum bet
(define-constant market-creation-fee u1000000) ;; 1 STX to create market
(define-constant fee-percentage u5) ;; 0.5%
(define-constant fee-denominator u1000)

;; Data variables
(define-data-var contract-initialized bool false)
(define-data-var total-markets uint u0)
(define-data-var accumulated-fees uint u0)

;; Data maps
(define-map markets uint {
    creator: principal,
    description: (string-utf8 256),
    resolution-time: uint,
    resolved: bool,
    outcome: (optional bool),
    total-yes-amount: uint,
    total-no-amount: uint,
    creation-time: uint,
    active: bool
})

(define-map market-bets { market-id: uint, better: principal } {
    yes-amount: uint,
    no-amount: uint,
    claimed: bool
})

;; Private functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner))

(define-private (calculate-fee (amount uint))
    (/ (* amount fee-percentage) fee-denominator))

(define-private (validate-market-exists (market-id uint))
    (match (map-get? markets market-id)
        market (ok market)
        err-market-not-found))

(define-private (validate-market-active (market-id uint))
    (match (map-get? markets market-id)
        market (if (get active market)
                  (ok market)
                  err-market-closed)
        err-market-not-found))

;; Read-only functions
(define-read-only (get-market (market-id uint))
    (map-get? markets market-id))

(define-read-only (get-market-bet (market-id uint) (better principal))
    (map-get? market-bets { market-id: market-id, better: better }))

(define-read-only (get-accumulated-fees)
    (var-get accumulated-fees))

(define-read-only (get-total-markets)
    (var-get total-markets))

(define-read-only (is-market-active (market-id uint))
    (match (map-get? markets market-id)
        market (get active market)
        false))

;; Public functions
(define-public (initialize-contract)
    (begin
        (asserts! (is-contract-owner) err-unauthorized)
        (asserts! (not (var-get contract-initialized)) err-already-initialized)
        (var-set contract-initialized true)
        (ok true)))

(define-public (create-market (description (string-utf8 256)) (resolution-time uint))
    (let (
        (market-id (+ (var-get total-markets) u1))
        (current-time (unwrap! (get-block-info? time u0) err-invalid-params))
    )
        ;; Validations
        (asserts! (var-get contract-initialized) err-not-initialized)
        (asserts! (> (len description) u0) err-invalid-params)
        (asserts! (> resolution-time current-time) err-invalid-params)
        
        ;; Charge market creation fee
        (try! (stx-transfer? market-creation-fee tx-sender (as-contract tx-sender)))
        
        ;; Create market
        (map-set markets market-id {
            creator: tx-sender,
            description: description,
            resolution-time: resolution-time,
            resolved: false,
            outcome: none,
            total-yes-amount: u0,
            total-no-amount: u0,
            creation-time: current-time,
            active: true
        })
        
        (var-set total-markets market-id)
        (ok market-id)))

(define-public (place-bet (market-id uint) (bet-yes bool) (amount uint))
    (let (
        (market (unwrap! (validate-market-active market-id) err-market-closed))
        (current-time (unwrap! (get-block-info? time u0) err-invalid-params))
    )
        ;; Validations
        (asserts! (>= amount min-bet) err-invalid-params)
        (asserts! (not (get resolved market)) err-market-closed)
        (asserts! (< current-time (get resolution-time market)) err-market-closed)
        
        ;; Process bet
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update market bets
        (match (map-get? market-bets {market-id: market-id, better: tx-sender})
            prev-bet 
                (map-set market-bets 
                    {market-id: market-id, better: tx-sender}
                    {
                        yes-amount: (if bet-yes (+ (get yes-amount prev-bet) amount) (get yes-amount prev-bet)),
                        no-amount: (if bet-yes (get no-amount prev-bet) (+ (get no-amount prev-bet) amount)),
                        claimed: false
                    })
            ;; No previous bet
            (map-set market-bets 
                {market-id: market-id, better: tx-sender}
                {
                    yes-amount: (if bet-yes amount u0),
                    no-amount: (if bet-yes u0 amount),
                    claimed: false
                }))
        
        ;; Update market totals
        (map-set markets market-id
            (merge market {
                total-yes-amount: (if bet-yes (+ (get total-yes-amount market) amount) (get total-yes-amount market)),
                total-no-amount: (if bet-yes (get total-no-amount market) (+ (get total-no-amount market) amount))
            }))
            
        (ok true)))

(define-public (resolve-market (market-id uint) (outcome bool))
    (let ((market (unwrap! (validate-market-exists market-id) err-market-not-found)))
        ;; Validations
        (asserts! (is-eq (get creator market) tx-sender) err-unauthorized)
        (asserts! (not (get resolved market)) err-already-resolved)
        (asserts! (>= (unwrap! (get-block-info? time u0) err-invalid-params) 
                     (get resolution-time market)) 
                 err-too-early)
        
        ;; Update market
        (map-set markets market-id
            (merge market {
                resolved: true,
                outcome: (some outcome)
            }))
        
        (ok true)))

(define-public (claim-payout (market-id uint))
    (let (
        (market (unwrap! (validate-market-exists market-id) err-market-not-found))
        (bet (unwrap! (map-get? market-bets {market-id: market-id, better: tx-sender}) err-no-payout))
    )
        ;; Validations
        (asserts! (get resolved market) err-market-closed)
        (asserts! (not (get claimed bet)) err-no-payout)
        
        (match (get outcome market)
            outcome (let (
                (won-amount (if outcome 
                               (get yes-amount bet)
                               (get no-amount bet)))
                (total-pot (+ (get total-yes-amount market) (get total-no-amount market)))
                (payout (if (> won-amount u0)
                          (/ (* won-amount total-pot) 
                             (if outcome 
                                 (get total-yes-amount market)
                                 (get total-no-amount market)))
                          u0))
                (fee (calculate-fee payout))
            )
                ;; Update bet to claimed
                (map-set market-bets 
                    {market-id: market-id, better: tx-sender}
                    (merge bet {claimed: true}))
                
                ;; Transfer payout minus fee
                (if (> payout u0)
                    (begin
                        (var-set accumulated-fees (+ (var-get accumulated-fees) fee))
                        (as-contract
                            (try! (stx-transfer? (- payout fee) tx-sender tx-sender)))
                        (ok payout))
                    (ok u0)))
            err-market-not-found))
)
(define-public (withdraw-fees)
    (let ((fees (var-get accumulated-fees)))
        (asserts! (is-contract-owner) err-unauthorized)
        (asserts! (> fees u0) err-no-payout)
        
        (var-set accumulated-fees u0)
        (as-contract
            (try! (stx-transfer? fees contract-owner tx-sender)))
        (ok fees)))

;; Emergency functions
(define-public (pause-market (market-id uint))
    (begin
        (asserts! (is-contract-owner) err-unauthorized)
        (try! (validate-market-exists market-id))
        (map-set markets market-id 
            (merge (unwrap-panic (get-market market-id))
                  {active: false}))
        (ok true)))

(define-public (resume-market (market-id uint))
    (begin
        (asserts! (is-contract-owner) err-unauthorized)
        (try! (validate-market-exists market-id))
        (map-set markets market-id 
            (merge (unwrap-panic (get-market market-id))
                  {active: true}))
        (ok true)))