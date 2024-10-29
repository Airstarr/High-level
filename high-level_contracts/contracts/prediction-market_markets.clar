;; prediction-market-markets.clar
;; Market-specific functionality for prediction markets

;; Define the trait we're importing from core contract
(define-trait prediction-market-trait
  (
    ;; Format: (function-name (param-types) return-type)
    (create-market ((string-utf8 500) uint) (response uint uint))
  )
)


;; Constants for market management
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u200))
(define-constant err-invalid-market (err u201))
(define-constant err-invalid-resolution-time (err u202))
(define-constant err-market-already-resolved (err u203))
(define-constant err-market-not-resolved (err u204))
(define-constant err-invalid-status (err u205))
(define-constant err-market-closed (err u206))
(define-constant err-invalid-description (err u207))

;; Market status enumeration
(define-data-var market-status-map (string-ascii 20) "active")

;; Market Categories
(define-map market-categories uint (string-ascii 20))
(define-map category-markets (string-ascii 20) (list 500 uint))

;; Market metadata
(define-map market-metadata uint {
    title: (string-utf8 100),
    description: (string-utf8 500),
    category: (string-ascii 20),
    tags: (list 10 (string-ascii 20)),
    additional-info-url: (optional (string-utf8 256)),
    resolution-rules: (string-utf8 500)
})

;; Market timestamps
(define-map market-timestamps uint {
    created-at: uint,
    updated-at: uint,
    resolved-at: (optional uint),
    last-bet-at: (optional uint)
})

;; Market statistics
(define-map market-stats uint {
    total-participants: uint,
    total-volume: uint,
    yes-volume: uint,
    no-volume: uint,
    average-bet-size: uint
})

;; Private functions
(define-private (validate-market-metadata 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (category (string-ascii 20))
    (tags (list 10 (string-ascii 20)))
    (resolution-rules (string-utf8 500)))
    (begin
        (asserts! (> (len title) u0) err-invalid-description)
        (asserts! (> (len description) u0) err-invalid-description)
        (asserts! (> (len category) u0) err-invalid-description)
        (asserts! (> (len resolution-rules) u0) err-invalid-description)
        (ok true)))

(define-private (validate-resolution-time (resolution-time uint))
    (let ((current-time (unwrap! (get-block-info? time u0) err-invalid-resolution-time)))
        (asserts! (> resolution-time current-time) err-invalid-resolution-time)
        (ok true)))

(define-private (initialize-market-stats (market-id uint))
    (map-set market-stats market-id {
        total-participants: u0,
        total-volume: u0,
        yes-volume: u0,
        no-volume: u0,
        average-bet-size: u0
    }))

(define-private (add-to-category (category (string-ascii 20)) (market-id uint))
    (let ((current-markets (default-to (list) (map-get? category-markets category))))
        (ok (map-set category-markets 
            category
            (unwrap! (as-max-len? (append current-markets market-id) u500)
                     err-invalid-market))))
)

;; Public functions
(define-public (create-market-extended (
    core-contract <prediction-market-trait>)
    (title (string-utf8 100))
    (description (string-utf8 500))
    (resolution-time uint)
    (category (string-ascii 20))
    (tags (list 10 (string-ascii 20)))
    (additional-info-url (optional (string-utf8 256)))
    (resolution-rules (string-utf8 500)))
    (let ((current-time (unwrap! (get-block-info? time u0) err-invalid-market)))
        ;; Validate inputs
        (try! (validate-market-metadata title description category tags resolution-rules))
        (try! (validate-resolution-time resolution-time))
        
        ;; Create market in core contract
        (let ((market-id (unwrap! (contract-call? core-contract create-market description resolution-time)
                                err-invalid-market)))
            ;; Set market metadata
            (map-set market-metadata market-id {
                title: title,
                description: description,
                category: category,
                tags: tags,
                additional-info-url: additional-info-url,
                resolution-rules: resolution-rules
            })
            
            ;; Set market timestamps
            (map-set market-timestamps market-id {
                created-at: current-time,
                updated-at: current-time,
                resolved-at: none,
                last-bet-at: none
            })
            
            ;; Initialize market statistics
            (initialize-market-stats market-id)
            
            ;; Set market category and update category index
            (map-set market-categories market-id category)
            (try! (add-to-category category market-id))
            
            (ok market-id))))

;; Market update functions
(define-public (update-market-metadata (
    market-id uint)
    (title (string-utf8 100))
    (description (string-utf8 500))
    (category (string-ascii 20))
    (tags (list 10 (string-ascii 20)))
    (additional-info-url (optional (string-utf8 256)))
    (resolution-rules (string-utf8 500)))
    (let ((current-time (unwrap! (get-block-info? time u0) err-invalid-market))
          (old-category (unwrap! (map-get? market-categories market-id) err-invalid-market)))
        ;; Validate inputs
        (try! (validate-market-metadata title description category tags resolution-rules))
        
        ;; Update metadata
        (map-set market-metadata market-id {
            title: title,
            description: description,
            category: category,
            tags: tags,
            additional-info-url: additional-info-url,
            resolution-rules: resolution-rules
        })
        
        ;; Update timestamp
        (map-set market-timestamps market-id 
            (merge (unwrap! (map-get? market-timestamps market-id) err-invalid-market)
                  {updated-at: current-time}))
        
        ;; Update category if changed
        (if (not (is-eq category old-category))
            (begin
                (map-set market-categories market-id category)
                (try! (add-to-category category market-id)))
            true)
        
        (ok true)))

;; Market statistics functions
(define-public (update-market-stats (
    market-id uint)
    (bet-amount uint)
    (is-yes-bet bool))
    (let ((stats (unwrap! (map-get? market-stats market-id) err-invalid-market))
          (current-time (unwrap! (get-block-info? time u0) err-invalid-market)))
        
        ;; Update statistics
        (map-set market-stats market-id {
            total-participants: (+ (get total-participants stats) u1),
            total-volume: (+ (get total-volume stats) bet-amount),
            yes-volume: (if is-yes-bet (+ (get yes-volume stats) bet-amount) (get yes-volume stats)),
            no-volume: (if is-yes-bet (get no-volume stats) (+ (get no-volume stats) bet-amount)),
            average-bet-size: (/ (+ (get total-volume stats) bet-amount)
                               (+ (get total-participants stats) u1))
        })
        
        ;; Update last bet timestamp
        (map-set market-timestamps market-id 
            (merge (unwrap! (map-get? market-timestamps market-id) err-invalid-market)
                  {last-bet-at: (some current-time)}))
        
        (ok true)))

;; Read-only functions
(define-read-only (get-market-details (market-id uint))
    (ok {
        metadata: (map-get? market-metadata market-id),
        timestamps: (map-get? market-timestamps market-id),
        stats: (map-get? market-stats market-id),
        category: (map-get? market-categories market-id)
    }))

(define-read-only (get-markets-by-category (category (string-ascii 20)))
    (match (map-get? category-markets category)
        market-list (ok market-list)
        (ok (list))))

(define-read-only (get-market-status)
    (var-get market-status-map))

(define-read-only (get-market-metadata (market-id uint))
    (map-get? market-metadata market-id))

(define-read-only (get-market-timestamps (market-id uint))
    (map-get? market-timestamps market-id))

(define-read-only (get-market-stats (market-id uint))
    (map-get? market-stats market-id))

;; Market resolution timestamp functions
(define-public (record-market-resolution (market-id uint))
    (let ((current-time (unwrap! (get-block-info? time u0) err-invalid-market)))
        (map-set market-timestamps market-id 
            (merge (unwrap! (map-get? market-timestamps market-id) err-invalid-market)
                  {resolved-at: (some current-time)}))
        (ok true)))

;; Category management functions
(define-read-only (get-market-category (market-id uint))
    (map-get? market-categories market-id))

(define-read-only (get-category-market-count (category (string-ascii 20)))
    (match (map-get? category-markets category)
        market-list (ok (len market-list))
        (ok u0)))