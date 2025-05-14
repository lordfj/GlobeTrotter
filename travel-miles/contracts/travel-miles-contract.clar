;; GlobeTrotter Travel Rewards Platform - Beta
;; Version 0.5.0
;; Enhanced functionality with loyalty tiers and time-based incentives

;; Primary Constants
(define-constant owner-address tx-sender)
(define-constant ERR-UNAUTHORIZED (err u3001))
(define-constant ERR-DESTINATION-UNAVAILABLE (err u3002))
(define-constant ERR-MILES-INVALID (err u3003))
(define-constant ERR-BALANCE-INSUFFICIENT (err u3004))
(define-constant ERR-BOOKING-PERIOD (err u3005))
(define-constant ERR-NO-MEMBERSHIP (err u3006))
(define-constant ERR-MINIMUM-UNMET (err u3007))
(define-constant ERR-PLATFORM-MAINTENANCE (err u3008))

;; Loyalty Token Definition
(define-fungible-token TRAVEL-MILES)

;; System Status Variables
(define-data-var platform-maintenance bool false)
(define-data-var emergency-protocol bool false)

;; Membership Parameters
(define-data-var miles-pool uint u0)
(define-data-var base-reward-rate uint u500) ;; 5% standard rate (100 = 1%)
(define-data-var loyalty-bonus uint u100) ;; 1% bonus for longer membership
(define-data-var minimum-stake uint u1000000) ;; Minimum participation amount
(define-data-var cancellation-period uint u1440) ;; 24 hour waiting period in blocks

;; Enhanced Data Structures
(define-map TravelerProfile
    principal
    {
        miles-staked: uint,
        reward-miles: uint,
        last-check-in: uint,
        status-tier: uint,
        bonus-multiplier: uint
    }
)

(define-map TravelPackage
    principal
    {
        miles: uint,
        departure-block: uint,
        last-redemption: uint,
        commitment-period: uint,
        cancellation-request: (optional uint)
    }
)

(define-map StatusLevels
    uint  ;; status tier
    {
        miles-requirement: uint,
        perks-multiplier: uint
    }
)

;; Platform Initialization
(define-public (initialize-platform)
    (begin
        (asserts! (is-eq tx-sender owner-address) ERR-UNAUTHORIZED)
        
        ;; Configure status tiers
        (map-set StatusLevels u1 
            {
                miles-requirement: u1000000,  ;; 1M uMiles
                perks-multiplier: u100      ;; 1x
            })
        (map-set StatusLevels u2
            {
                miles-requirement: u5000000,  ;; 5M uMiles
                perks-multiplier: u150      ;; 1.5x
            })
        (map-set StatusLevels u3
            {
                miles-requirement: u10000000, ;; 10M uMiles
                perks-multiplier: u200      ;; 2x
            })
        
        (ok true)
    )
)

;; Stake miles with optional lock period
(define-public (stake-miles (amount uint) (lock-duration uint))
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0,
                    status-tier: u0,
                    bonus-multiplier: u100
                }
                (map-get? TravelerProfile tx-sender)))
        )
        (asserts! (not (var-get platform-maintenance)) ERR-PLATFORM-MAINTENANCE)
        (asserts! (>= amount (var-get minimum-stake)) ERR-MINIMUM-UNMET)
        
        ;; Transfer miles to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Calculate tier and multiplier
        (let
            (
                (new-total-staked (+ (get miles-staked traveler-data) amount))
                (status-level (determine-status-tier new-total-staked))
                (duration-bonus (calculate-duration-bonus lock-duration))
            )
            
            ;; Update travel package details
            (map-set TravelPackage
                tx-sender
                {
                    miles: amount,
                    departure-block: block-height,
                    last-redemption: block-height,
                    commitment-period: lock-duration,
                    cancellation-request: none
                }
            )
            
            ;; Update traveler profile with new tier data
            (map-set TravelerProfile
                tx-sender
                (merge traveler-data
                    {
                        miles-staked: new-total-staked,
                        status-tier: status-level,
                        bonus-multiplier: (* (tier-multiplier status-level) duration-bonus),
                        last-check-in: block-height
                    }
                )
            )
            
            ;; Update miles pool
            (var-set miles-pool (+ (var-get miles-pool) amount))
            (ok true)
        )
    )
)

;; Request cancellation process
(define-public (request-cancellation (amount uint))
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0,
                    status-tier: u0,
                    bonus-multiplier: u100
                }
                (map-get? TravelerProfile tx-sender)))
            (package-info (default-to
                {
                    miles: u0,
                    departure-block: u0,
                    last-redemption: u0,
                    commitment-period: u0,
                    cancellation-request: none
                }
                (map-get? TravelPackage tx-sender)))
            (current-staked (get miles-staked traveler-data))
            (active-commitment (get commitment-period package-info))
        )
        (asserts! (not (var-get platform-maintenance)) ERR-PLATFORM-MAINTENANCE)
        (asserts! (<= amount current-staked) ERR-BALANCE-INSUFFICIENT)
        
        ;; Check if commitment period is over
        (asserts! (<= active-commitment block-height) ERR-BOOKING-PERIOD)
        
        ;; Set cancellation timer
        (map-set TravelPackage
            tx-sender
            (merge package-info
                {
                    cancellation-request: (some block-height)
                }
            )
        )
        
        (ok block-height)
    )
)

;; Complete cancellation after waiting period
(define-public (finalize-cancellation (amount uint))
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0,
                    status-tier: u0,
                    bonus-multiplier: u100
                }
                (map-get? TravelerProfile tx-sender)))
            (package-info (default-to
                {
                    miles: u0,
                    departure-block: u0,
                    last-redemption: u0,
                    commitment-period: u0,
                    cancellation-request: none
                }
                (map-get? TravelPackage tx-sender)))
            (current-staked (get miles-staked traveler-data))
            (cancel-timestamp (get cancellation-request package-info))
        )
        (asserts! (not (var-get platform-maintenance)) ERR-PLATFORM-MAINTENANCE)
        (asserts! (<= amount current-staked) ERR-BALANCE-INSUFFICIENT)
        (asserts! (is-some cancel-timestamp) ERR-NO-MEMBERSHIP)
        
        ;; Check if cancellation period is over
        (asserts! (>= block-height (+ (default-to u0 cancel-timestamp) (var-get cancellation-period))) ERR-BOOKING-PERIOD)
        
        ;; Transfer miles from contract
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        
        ;; Calculate new tier after withdrawal
        (let
            (
                (new-total-staked (- current-staked amount))
                (status-level (determine-status-tier new-total-staked))
            )
            
            ;; Update traveler profile with new tier data
            (map-set TravelerProfile
                tx-sender
                (merge traveler-data
                    {
                        miles-staked: new-total-staked,
                        status-tier: status-level,
                        bonus-multiplier: (tier-multiplier status-level),
                        last-check-in: block-height
                    }
                )
            )
            
            ;; Reset cancellation request
            (map-set TravelPackage
                tx-sender
                (merge package-info
                    {
                        cancellation-request: none
                    }
                )
            )
            
            ;; Update miles pool
            (var-set miles-pool (- (var-get miles-pool) amount))
            (ok true)
        )
    )
)

;; Redeem travel rewards based on staked miles
(define-public (redeem-rewards)
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0,
                    status-tier: u0,
                    bonus-multiplier: u100
                }
                (map-get? TravelerProfile tx-sender)))
            (package-info (default-to
                {
                    miles: u0,
                    departure-block: u0,
                    last-redemption: u0,
                    commitment-period: u0,
                    cancellation-request: none
                }
                (map-get? TravelPackage tx-sender)))
            (blocks-elapsed (- block-height (get last-redemption package-info)))
            (staked-miles (get miles-staked traveler-data))
            (bonus-rate (get bonus-multiplier traveler-data))
        )
        (asserts! (> staked-miles u0) ERR-BALANCE-INSUFFICIENT)
        
        ;; Calculate rewards
        (let
            (
                (base-miles (/ (* staked-miles blocks-elapsed (var-get base-reward-rate)) u1000000))
                (boosted-miles (/ (* base-miles bonus-rate) u100))
            )
            
            ;; Mint reward tokens
            (try! (ft-mint? TRAVEL-MILES boosted-miles tx-sender))
            
            ;; Update travel package
            (map-set TravelPackage
                tx-sender
                (merge package-info
                    {
                        last-redemption: block-height
                    }
                )
            )
            
            ;; Update traveler profile
            (map-set TravelerProfile
                tx-sender
                (merge traveler-data
                    {
                        reward-miles: (+ (get reward-miles traveler-data) boosted-miles),
                        last-check-in: block-height
                    }
                )
            )
            
            (ok boosted-miles)
        )
    )
)

;; Helper Functions

;; Determine status tier based on staked miles
(define-private (determine-status-tier (miles-amount uint))
    (if (>= miles-amount u10000000)
        u3  ;; Diamond tier
        (if (>= miles-amount u5000000)
            u2  ;; Gold tier
            u1  ;; Silver tier
        )
    )
)

;; Get tier multiplier
(define-private (tier-multiplier (tier uint))
    (if (is-eq tier u3)
        u200  ;; Diamond 2x
        (if (is-eq tier u2)
            u150  ;; Gold 1.5x
            u100  ;; Silver 1x
        )
    )
)

;; Calculate duration bonus based on lock period
(define-private (calculate-duration-bonus (lock-period uint))
    (if (>= lock-period u8640)     ;; 2 months
        u150                        ;; 1.5x multiplier
        (if (>= lock-period u4320) ;; 1 month
            u125                    ;; 1.25x multiplier
            u100                    ;; 1x multiplier (no lock)
        )
    )
)

;; Administrative Functions

;; Set platform maintenance mode
(define-public (set-platform-status (maintenance bool))
    (begin
        (asserts! (is-eq tx-sender owner-address) ERR-UNAUTHORIZED)
        (var-set platform-maintenance maintenance)
        (ok maintenance)
    )
)

;; Activate emergency protocol
(define-public (set-emergency-protocol (activated bool))
    (begin
        (asserts! (is-eq tx-sender owner-address) ERR-UNAUTHORIZED)
        (var-set emergency-protocol activated)
        (ok activated)
    )
)
