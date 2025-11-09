;; Decentralized Prediction Market
;; Allows users to create markets for future events and bet on outcomes
;; Market creators define possible outcomes and set resolution date
;; Users can buy shares in outcomes, with payouts distributed to winners

;; Error constants
(define-constant error-not-found (err u100))
(define-constant error-access-denied (err u101))
(define-constant error-invalid-params (err u102))
(define-constant error-already-settled (err u103))
(define-constant error-deadline-passed (err u104))
(define-constant error-not-ready (err u105))
(define-constant error-no-position (err u106))
(define-constant error-insufficient-funds (err u107))
(define-constant error-transfer-failed (err u108))

(define-data-var next-market-id uint u0)

(define-map market-database
  { prediction-market-id: uint }
  {
    market-creator: principal,
    market-question: (string-ascii 256),
    choice-count: uint,
    settlement-block: uint,
    market-settled: bool,
    winning-choice: (optional uint),
    total-wagered: uint
  }
)

(define-map outcome-database
  { prediction-market-id: uint, choice-id: uint }
  {
    choice-description: (string-ascii 64),
    wagered-amount: uint
  }
)

(define-map user-position-database
  { prediction-market-id: uint, choice-id: uint, user-principal: principal }
  { wager-amount: uint }
)

;; Helper function to check if market exists and return it
(define-private (get-market (prediction-market-id uint))
  (map-get? market-database { prediction-market-id: prediction-market-id })
)

;; Helper function to check if outcome exists and return it
(define-private (get-outcome (prediction-market-id uint) (choice-id uint))
  (map-get? outcome-database { prediction-market-id: prediction-market-id, choice-id: choice-id })
)

;; Create a new prediction market
(define-public (new-market (market-question (string-ascii 256)) (choice-count uint) (blocks-until-settlement uint))
  (let
    ((prediction-market-id (var-get next-market-id))
     (settlement-block (+ block-height blocks-until-settlement)))
    
    ;; Validate parameters
    (asserts! (> choice-count u0) error-invalid-params)
    (asserts! (<= choice-count u100) error-invalid-params) ;; Reasonable upper limit
    (asserts! (> blocks-until-settlement u1000) error-invalid-params)
    (asserts! (> (len market-question) u0) error-invalid-params) ;; Question cannot be empty
    
    ;; Create the market
    (map-set market-database
      { prediction-market-id: prediction-market-id }
      {
        market-creator: tx-sender,
        market-question: market-question,
        choice-count: choice-count,
        settlement-block: settlement-block,
        market-settled: false,
        winning-choice: none,
        total-wagered: u0
      }
    )
    
    ;; Increment market counter
    (var-set next-market-id (+ prediction-market-id u1))
    
    (ok prediction-market-id)
  )
)

;; Define an outcome for a market
(define-public (add-outcome (prediction-market-id uint) (choice-id uint) (choice-description (string-ascii 64)))
  (let
    ((market (unwrap! (get-market prediction-market-id) error-not-found)))
    
    ;; Validate conditions
    (asserts! (is-eq tx-sender (get market-creator market)) error-access-denied)
    (asserts! (< choice-id (get choice-count market)) error-invalid-params)
    (asserts! (not (get market-settled market)) error-already-settled)
    (asserts! (> (len choice-description) u0) error-invalid-params) ;; Description cannot be empty
    
    ;; Check if outcome already exists to prevent overwriting
    (asserts! (is-none (map-get? outcome-database { prediction-market-id: prediction-market-id, choice-id: choice-id })) error-invalid-params)
    
    ;; Set the outcome
    (map-set outcome-database
      { prediction-market-id: prediction-market-id, choice-id: choice-id }
      { choice-description: choice-description, wagered-amount: u0 }
    )
    
    (ok true)
  )
)

;; Stake on a specific outcome
(define-public (place-stake (prediction-market-id uint) (choice-id uint) (wager-amount uint))
  (let
    ((market (unwrap! (get-market prediction-market-id) error-not-found))
     (outcome (unwrap! (get-outcome prediction-market-id choice-id) error-not-found))
     (user-wager-key { prediction-market-id: prediction-market-id, choice-id: choice-id, user-principal: tx-sender })
     (user-position (default-to { wager-amount: u0 } (map-get? user-position-database user-wager-key)))
     (total-wager-amount (+ (get wager-amount user-position) wager-amount))
     (new-wagered-amount (+ (get wagered-amount outcome) wager-amount))
     (new-total-wagered (+ (get total-wagered market) wager-amount)))
    
    ;; Validate conditions
    (asserts! (not (get market-settled market)) error-already-settled)
    (asserts! (< block-height (get settlement-block market)) error-deadline-passed)
    (asserts! (> wager-amount u0) error-invalid-params)
    
    ;; Check for overflow in wagering amounts
    (asserts! (>= total-wager-amount wager-amount) error-invalid-params) ;; Overflow check
    (asserts! (>= new-wagered-amount (get wagered-amount outcome)) error-invalid-params) ;; Overflow check
    (asserts! (>= new-total-wagered (get total-wagered market)) error-invalid-params) ;; Overflow check
    
    ;; Transfer STX from user to contract
    (unwrap! (stx-transfer? wager-amount tx-sender (as-contract tx-sender)) error-transfer-failed)
    
    ;; Update user position
    (map-set user-position-database user-wager-key { wager-amount: total-wager-amount })
    
    ;; Update outcome wagered amount
    (map-set outcome-database
      { prediction-market-id: prediction-market-id, choice-id: choice-id }
      (merge outcome { wagered-amount: new-wagered-amount })
    )
    
    ;; Update market total wagered
    (map-set market-database
      { prediction-market-id: prediction-market-id }
      (merge market { total-wagered: new-total-wagered })
    )
    
    (ok true)
  )
)

;; Resolve a market by setting the winning outcome
(define-public (finalize-market (prediction-market-id uint) (winning-choice uint))
  (let
    ((market (unwrap! (get-market prediction-market-id) error-not-found)))
    
    ;; Validate conditions
    (asserts! (is-eq tx-sender (get market-creator market)) error-access-denied)
    (asserts! (not (get market-settled market)) error-already-settled)
    (asserts! (>= block-height (get settlement-block market)) error-not-ready)
    (asserts! (< winning-choice (get choice-count market)) error-invalid-params)
    
    ;; Ensure the winning outcome actually exists (was defined)
    (asserts! (is-some (map-get? outcome-database { prediction-market-id: prediction-market-id, choice-id: winning-choice })) error-not-found)
    
    ;; Mark market as resolved
    (map-set market-database
      { prediction-market-id: prediction-market-id }
      (merge market { market-settled: true, winning-choice: (some winning-choice) })
    )
    
    (ok true)
  )
)

;; Claim winnings from a resolved market
(define-public (claim-reward (prediction-market-id uint))
  (let
    ((market (unwrap! (get-market prediction-market-id) error-not-found))
     (winning-choice (unwrap! (get winning-choice market) error-not-found))
     (user-wager-key { prediction-market-id: prediction-market-id, choice-id: winning-choice, user-principal: tx-sender })
     (user-position (unwrap! (map-get? user-position-database user-wager-key) error-no-position))
     (winning-choice-data (unwrap! (get-outcome prediction-market-id winning-choice) error-not-found)))
    
    ;; Validate conditions
    (asserts! (get market-settled market) error-already-settled)
    (asserts! (> (get wager-amount user-position) u0) error-no-position)
    
    ;; Calculate reward with proper division handling
    (let
      ((user-wager (get wager-amount user-position))
       (winning-choice-pool (get wagered-amount winning-choice-data))
       (total-wager-pool (get total-wagered market))
       (payout-amount (if (> winning-choice-pool u0)
                   (/ (* user-wager total-wager-pool) winning-choice-pool)
                   u0)))
      
      ;; Ensure payout is reasonable (not zero and not exceeding total pool)
      (asserts! (> payout-amount u0) error-invalid-params)
      (asserts! (<= payout-amount total-wager-pool) error-invalid-params)
      
      ;; Reset user position to prevent double claiming
      (map-set user-position-database user-wager-key { wager-amount: u0 })
      
      ;; Transfer winnings to user
      (unwrap! (as-contract (stx-transfer? payout-amount tx-sender tx-sender)) error-transfer-failed)
      
      (ok payout-amount)
    )
  )
)

;; Read-only functions for querying contract state

;; Get market information
(define-read-only (get-market-info (prediction-market-id uint))
  (map-get? market-database { prediction-market-id: prediction-market-id })
)

;; Get outcome information
(define-read-only (get-outcome-info (prediction-market-id uint) (choice-id uint))
  (map-get? outcome-database { prediction-market-id: prediction-market-id, choice-id: choice-id })
)

;; Get user position
(define-read-only (get-position (prediction-market-id uint) (choice-id uint) (user-principal principal))
  (map-get? user-position-database { prediction-market-id: prediction-market-id, choice-id: choice-id, user-principal: user-principal })
)

;; Get total number of markets
(define-read-only (get-market-count)
  (var-get next-market-id)
)

;; Check if market is active (not resolved and not expired)
(define-read-only (check-active (prediction-market-id uint))
  (match (map-get? market-database { prediction-market-id: prediction-market-id })
    market (and 
             (not (get market-settled market))
             (< block-height (get settlement-block market)))
    false
  )
)