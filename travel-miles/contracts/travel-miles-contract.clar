;; GlobeTrotter Travel Rewards Platform - Alpha
;; Version 0.1

;; Primary Constants
(define-constant owner-address tx-sender)
(define-constant ERR-UNAUTHORIZED (err u3001))
(define-constant ERR-MILES-INVALID (err u3003))
(define-constant ERR-BALANCE-INSUFFICIENT (err u3004))

;; Loyalty Token Definition
(define-fungible-token TRAVEL-MILES)

;; System Status Variables
(define-data-var platform-maintenance bool false)

;; Membership Parameters
(define-data-var miles-pool uint u0)
(define-data-var base-reward-rate uint u500) ;; 5% standard rate (100 = 1%)
(define-data-var minimum-stake uint u1000000) ;; Minimum participation amount

;; Basic Data Structures
(define-map TravelerProfile
    principal
    {
        miles-staked: uint,
        reward-miles: uint,
        last-check-in: uint
    }
)

(define-map TravelPackage
    principal
    {
        miles: uint,
        departure-block: uint,
        last-redemption: uint
    }
)

;; Platform Initialization
(define-public (initialize-platform)
    (begin
        (asserts! (is-eq tx-sender owner-address) ERR-UNAUTHORIZED)
        (ok true)
    )
)

;; Stake miles - basic version
(define-public (stake-miles (amount uint))
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0
                }
                (map-get? TravelerProfile tx-sender)))
        )
        (asserts! (not (var-get platform-maintenance)) ERR-UNAUTHORIZED)
        (asserts! (>= amount (var-get minimum-stake)) ERR-MILES-INVALID)
        
        ;; Transfer miles to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update traveler profile
        (map-set TravelerProfile
            tx-sender
            {
                miles-staked: (+ (get miles-staked traveler-data) amount),
                reward-miles: (get reward-miles traveler-data),
                last-check-in: block-height
            }
        )
        
        ;; Update travel package details
        (map-set TravelPackage
            tx-sender
            {
                miles: amount,
                departure-block: block-height,
                last-redemption: block-height
            }
        )
        
        ;; Update miles pool
        (var-set miles-pool (+ (var-get miles-pool) amount))
        (ok true)
    )
)

;; Withdraw staked miles - basic version
(define-public (withdraw-miles (amount uint))
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0
                }
                (map-get? TravelerProfile tx-sender)))
            (current-staked (get miles-staked traveler-data))
        )
        (asserts! (not (var-get platform-maintenance)) ERR-UNAUTHORIZED)
        (asserts! (<= amount current-staked) ERR-BALANCE-INSUFFICIENT)
        
        ;; Transfer miles from contract
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        
        ;; Update traveler profile
        (map-set TravelerProfile
            tx-sender
            {
                miles-staked: (- current-staked amount),
                reward-miles: (get reward-miles traveler-data),
                last-check-in: block-height
            }
        )
        
        ;; Update miles pool
        (var-set miles-pool (- (var-get miles-pool) amount))
        (ok true)
    )
)

;; Redeem travel rewards based on staked miles - basic version
(define-public (redeem-rewards)
    (let
        (
            (traveler-data (default-to 
                {
                    miles-staked: u0,
                    reward-miles: u0,
                    last-check-in: u0
                }
                (map-get? TravelerProfile tx-sender)))
            (package-info (default-to
                {
                    miles: u0,
                    departure-block: u0,
                    last-redemption: u0
                }
                (map-get? TravelPackage tx-sender)))
            (blocks-elapsed (- block-height (get last-redemption package-info)))
            (staked-miles (get miles-staked traveler-data))
        )
        (asserts! (> staked-miles u0) ERR-BALANCE-INSUFFICIENT)
        
        ;; Calculate rewards
        (let
            (
                (total-miles (/ (* staked-miles blocks-elapsed (var-get base-reward-rate)) u1000000))
            )
            
            ;; Mint reward tokens
            (try! (ft-mint? TRAVEL-MILES total-miles tx-sender))
            
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
                        reward-miles: (+ (get reward-miles traveler-data) total-miles),
                        last-check-in: block-height
                    }
                )
            )
            
            (ok total-miles)
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
