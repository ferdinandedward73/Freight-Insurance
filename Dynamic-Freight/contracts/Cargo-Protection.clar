;; Dynamic Freight Insurance Smart Contract
;; Adjusts insurance premiums based on real-time cargo conditions

;; Error constants for validation and authorization
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-POLICY-NOT-FOUND (err u101))
(define-constant ERR-POLICY-EXPIRED (err u102))
(define-constant ERR-INVALID-PREMIUM (err u103))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u104))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u105))
(define-constant ERR-INVALID-CONDITION-VALUE (err u106))
(define-constant ERR-POLICY-ALREADY-EXISTS (err u107))
(define-constant ERR-INVALID-DURATION (err u108))
(define-constant ERR-CARGO-NOT-FOUND (err u109))
(define-constant ERR-SENSOR-NOT-AUTHORIZED (err u110))
(define-constant ERR-INVALID-INPUT (err u111))

;; Contract owner principal
(define-constant CONTRACT-OWNER tx-sender)

;; Risk multipliers for different condition ranges (scaled by 100 for precision)
(define-constant TEMPERATURE-MULTIPLIER-LOW u80)     ;; 20% reduction for optimal temperature
(define-constant TEMPERATURE-MULTIPLIER-HIGH u150)   ;; 50% increase for extreme temperature
(define-constant HUMIDITY-MULTIPLIER-LOW u90)        ;; 10% reduction for optimal humidity  
(define-constant HUMIDITY-MULTIPLIER-HIGH u130)      ;; 30% increase for high humidity
(define-constant SHOCK-MULTIPLIER-LOW u100)          ;; No change for low shock
(define-constant SHOCK-MULTIPLIER-HIGH u200)         ;; 100% increase for high shock

;; Condition thresholds
(define-constant TEMPERATURE-OPTIMAL-MIN u15)        ;; 15C minimum optimal
(define-constant TEMPERATURE-OPTIMAL-MAX u25)        ;; 25C maximum optimal
(define-constant HUMIDITY-OPTIMAL-MAX u60)           ;; 60% maximum optimal humidity
(define-constant SHOCK-THRESHOLD u50)                ;; G-force threshold for high shock

;; Base premium rate (in microSTX per cargo value unit)
(define-constant BASE-PREMIUM-RATE u50)

;; Policy status constants
(define-constant POLICY-STATUS-ACTIVE u1)
(define-constant POLICY-STATUS-EXPIRED u2)
(define-constant POLICY-STATUS-CLAIMED u3)

;; Maximum values for input validation
(define-constant MAX-CARGO-ID u1000000)
(define-constant MAX-POLICY-ID u1000000)

;; Data structure for insurance policies
(define-map insurance-policies 
    { policy-id: uint }
    {
        policyholder: principal,
        cargo-value: uint,
        base-premium: uint,
        current-premium: uint,
        start-block: uint,
        end-block: uint,
        status: uint,
        total-paid: uint,
        claim-amount: uint,
        cargo-id: uint
    }
)

;; Data structure for cargo conditions
(define-map cargo-conditions
    { cargo-id: uint }
    {
        temperature: uint,      ;; Temperature in Celsius
        humidity: uint,         ;; Humidity percentage
        shock-level: uint,      ;; Shock/vibration level
        last-updated: uint,     ;; Block height of last update
        owner: principal
    }
)

;; Map to track authorized sensor principals
(define-map authorized-sensors { sensor: principal } { authorized: bool })

;; Policy counter for unique policy IDs
(define-data-var policy-counter uint u0)

;; Cargo counter for unique cargo IDs
(define-data-var cargo-counter uint u0)

;; Input validation functions
(define-private (is-valid-principal (p principal))
    (not (is-eq p 'SP000000000000000000002Q6VF78))  ;; Check for null principal
)

(define-private (is-valid-cargo-id (cargo-id uint))
    (and (> cargo-id u0) (<= cargo-id MAX-CARGO-ID))
)

(define-private (is-valid-policy-id (policy-id uint))
    (and (> policy-id u0) (<= policy-id MAX-POLICY-ID))
)

;; Function to authorize sensor principals (only contract owner)
(define-public (authorize-sensor (sensor principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-valid-principal sensor) ERR-INVALID-INPUT)
        (ok (map-set authorized-sensors { sensor: sensor } { authorized: true }))
    )
)

;; Function to revoke sensor authorization (only contract owner)
(define-public (revoke-sensor-authorization (sensor principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-valid-principal sensor) ERR-INVALID-INPUT)
        (ok (map-set authorized-sensors { sensor: sensor } { authorized: false }))
    )
)

;; Function to register new cargo for monitoring
(define-public (register-cargo (initial-temperature uint) (initial-humidity uint) (initial-shock uint))
    (let (
        (new-cargo-id (+ (var-get cargo-counter) u1))
    )
        (asserts! (<= initial-temperature u100) ERR-INVALID-CONDITION-VALUE)
        (asserts! (<= initial-humidity u100) ERR-INVALID-CONDITION-VALUE)
        (asserts! (<= initial-shock u200) ERR-INVALID-CONDITION-VALUE)
        
        (var-set cargo-counter new-cargo-id)
        (map-set cargo-conditions 
            { cargo-id: new-cargo-id }
            {
                temperature: initial-temperature,
                humidity: initial-humidity,
                shock-level: initial-shock,
                last-updated: block-height,
                owner: tx-sender
            }
        )
        (ok new-cargo-id)
    )
)

;; Function to calculate risk multiplier based on conditions
(define-private (calculate-risk-multiplier (temperature uint) (humidity uint) (shock-level uint))
    (let (
        (temp-multiplier 
            (if (and (>= temperature TEMPERATURE-OPTIMAL-MIN) (<= temperature TEMPERATURE-OPTIMAL-MAX))
                TEMPERATURE-MULTIPLIER-LOW
                TEMPERATURE-MULTIPLIER-HIGH
            )
        )
        (humidity-multiplier
            (if (<= humidity HUMIDITY-OPTIMAL-MAX)
                HUMIDITY-MULTIPLIER-LOW
                HUMIDITY-MULTIPLIER-HIGH
            )
        )
        (shock-multiplier
            (if (<= shock-level SHOCK-THRESHOLD)
                SHOCK-MULTIPLIER-LOW
                SHOCK-MULTIPLIER-HIGH
            )
        )
        (combined-multiplier (/ (* (* temp-multiplier humidity-multiplier) shock-multiplier) u10000))
    )
        combined-multiplier
    )
)

;; Function to create new insurance policy
(define-public (create-policy (cargo-value uint) (duration-blocks uint) (cargo-id uint))
    (let (
        (new-policy-id (+ (var-get policy-counter) u1))
        (base-premium (/ (* cargo-value BASE-PREMIUM-RATE) u1000))
        (validated-cargo-id cargo-id)  ;; Store validated input
    )
        ;; Input validation
        (asserts! (> cargo-value u0) ERR-INVALID-PREMIUM)
        (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
        (asserts! (is-valid-cargo-id validated-cargo-id) ERR-INVALID-INPUT)
        
        (let (
            (cargo-data (unwrap! (map-get? cargo-conditions { cargo-id: validated-cargo-id }) ERR-CARGO-NOT-FOUND))
            (risk-multiplier (calculate-risk-multiplier 
                (get temperature cargo-data)
                (get humidity cargo-data)
                (get shock-level cargo-data)
            ))
            (initial-premium (/ (* base-premium risk-multiplier) u100))
        )
            (asserts! (is-eq tx-sender (get owner cargo-data)) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-none (map-get? insurance-policies { policy-id: new-policy-id })) ERR-POLICY-ALREADY-EXISTS)
            
            (var-set policy-counter new-policy-id)
            (map-set insurance-policies 
                { policy-id: new-policy-id }
                {
                    policyholder: tx-sender,
                    cargo-value: cargo-value,
                    base-premium: base-premium,
                    current-premium: initial-premium,
                    start-block: block-height,
                    end-block: (+ block-height duration-blocks),
                    status: POLICY-STATUS-ACTIVE,
                    total-paid: u0,
                    claim-amount: u0,
                    cargo-id: validated-cargo-id
                }
            )
            (ok new-policy-id)
        )
    )
)

;; Function to update cargo conditions (only authorized sensors)
(define-public (update-conditions (cargo-id uint) (temperature uint) (humidity uint) (shock-level uint))
    (let (
        (validated-cargo-id cargo-id)  ;; Store validated input
        (sensor-auth (default-to { authorized: false } (map-get? authorized-sensors { sensor: tx-sender })))
    )
        ;; Input validation
        (asserts! (is-valid-cargo-id validated-cargo-id) ERR-INVALID-INPUT)
        (asserts! (get authorized sensor-auth) ERR-SENSOR-NOT-AUTHORIZED)
        (asserts! (<= temperature u100) ERR-INVALID-CONDITION-VALUE)
        (asserts! (<= humidity u100) ERR-INVALID-CONDITION-VALUE)
        (asserts! (<= shock-level u200) ERR-INVALID-CONDITION-VALUE)
        
        (let (
            (cargo-data (unwrap! (map-get? cargo-conditions { cargo-id: validated-cargo-id }) ERR-CARGO-NOT-FOUND))
        )
            (map-set cargo-conditions 
                { cargo-id: validated-cargo-id }
                {
                    temperature: temperature,
                    humidity: humidity,
                    shock-level: shock-level,
                    last-updated: block-height,
                    owner: (get owner cargo-data)
                }
            )
            (ok true)
        )
    )
)

;; Function to recalculate and update premium based on current conditions
(define-public (update-premium (policy-id uint))
    (let (
        (validated-policy-id policy-id)  ;; Store validated input
    )
        ;; Input validation
        (asserts! (is-valid-policy-id validated-policy-id) ERR-INVALID-INPUT)
        
        (let (
            (policy-data (unwrap! (map-get? insurance-policies { policy-id: validated-policy-id }) ERR-POLICY-NOT-FOUND))
            (cargo-data (unwrap! (map-get? cargo-conditions { cargo-id: (get cargo-id policy-data) }) ERR-CARGO-NOT-FOUND))
            (risk-multiplier (calculate-risk-multiplier 
                (get temperature cargo-data)
                (get humidity cargo-data)
                (get shock-level cargo-data)
            ))
            (new-premium (/ (* (get base-premium policy-data) risk-multiplier) u100))
        )
            (asserts! (is-eq (get status policy-data) POLICY-STATUS-ACTIVE) ERR-POLICY-EXPIRED)
            (asserts! (< block-height (get end-block policy-data)) ERR-POLICY-EXPIRED)
            
            (map-set insurance-policies 
                { policy-id: validated-policy-id }
                (merge policy-data { current-premium: new-premium })
            )
            (ok new-premium)
        )
    )
)

;; Function to pay premium (callable by policyholder)
(define-public (pay-premium (policy-id uint))
    (let (
        (validated-policy-id policy-id)  ;; Store validated input
    )
        ;; Input validation
        (asserts! (is-valid-policy-id validated-policy-id) ERR-INVALID-INPUT)
        
        (let (
            (policy-data (unwrap! (map-get? insurance-policies { policy-id: validated-policy-id }) ERR-POLICY-NOT-FOUND))
            (premium-amount (get current-premium policy-data))
        )
            (asserts! (is-eq tx-sender (get policyholder policy-data)) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-eq (get status policy-data) POLICY-STATUS-ACTIVE) ERR-POLICY-EXPIRED)
            (asserts! (< block-height (get end-block policy-data)) ERR-POLICY-EXPIRED)
            
            (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
            
            (map-set insurance-policies 
                { policy-id: validated-policy-id }
                (merge policy-data { total-paid: (+ (get total-paid policy-data) premium-amount) })
            )
            (ok premium-amount)
        )
    )
)

;; Function to file insurance claim
(define-public (file-claim (policy-id uint) (claim-amount uint))
    (let (
        (validated-policy-id policy-id)  ;; Store validated input
    )
        ;; Input validation
        (asserts! (is-valid-policy-id validated-policy-id) ERR-INVALID-INPUT)
        (asserts! (> claim-amount u0) ERR-INVALID-PREMIUM)
        
        (let (
            (policy-data (unwrap! (map-get? insurance-policies { policy-id: validated-policy-id }) ERR-POLICY-NOT-FOUND))
        )
            (asserts! (is-eq tx-sender (get policyholder policy-data)) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-eq (get status policy-data) POLICY-STATUS-ACTIVE) ERR-POLICY-EXPIRED)
            (asserts! (is-eq (get claim-amount policy-data) u0) ERR-CLAIM-ALREADY-PROCESSED)
            (asserts! (<= claim-amount (get cargo-value policy-data)) ERR-INVALID-PREMIUM)
            
            (map-set insurance-policies 
                { policy-id: validated-policy-id }
                (merge policy-data { 
                    claim-amount: claim-amount,
                    status: POLICY-STATUS-CLAIMED
                })
            )
            (ok true)
        )
    )
)

;; Function to process claim payout (only contract owner for now - could be automated)
(define-public (process-claim (policy-id uint))
    (let (
        (validated-policy-id policy-id)  ;; Store validated input
    )
        ;; Input validation
        (asserts! (is-valid-policy-id validated-policy-id) ERR-INVALID-INPUT)
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        
        (let (
            (policy-data (unwrap! (map-get? insurance-policies { policy-id: validated-policy-id }) ERR-POLICY-NOT-FOUND))
            (claim-amount (get claim-amount policy-data))
        )
            (asserts! (is-eq (get status policy-data) POLICY-STATUS-CLAIMED) ERR-POLICY-NOT-FOUND)
            (asserts! (> claim-amount u0) ERR-INVALID-PREMIUM)
            
            (try! (as-contract (stx-transfer? claim-amount tx-sender (get policyholder policy-data))))
            (ok claim-amount)
        )
    )
)

;; Read-only function to get policy details
(define-read-only (get-policy (policy-id uint))
    (if (is-valid-policy-id policy-id)
        (map-get? insurance-policies { policy-id: policy-id })
        none
    )
)

;; Read-only function to get cargo conditions
(define-read-only (get-cargo-conditions (cargo-id uint))
    (if (is-valid-cargo-id cargo-id)
        (map-get? cargo-conditions { cargo-id: cargo-id })
        none
    )
)

;; Read-only function to get current premium for a policy
(define-read-only (get-current-premium (policy-id uint))
    (if (is-valid-policy-id policy-id)
        (match (map-get? insurance-policies { policy-id: policy-id })
            policy-data (some (get current-premium policy-data))
            none
        )
        none
    )
)

;; Read-only function to check if sensor is authorized
(define-read-only (is-sensor-authorized (sensor principal))
    (if (is-valid-principal sensor)
        (match (map-get? authorized-sensors { sensor: sensor })
            sensor-data (get authorized sensor-data)
            false
        )
        false
    )
)

;; Read-only function to get risk assessment for given conditions
(define-read-only (assess-risk (temperature uint) (humidity uint) (shock-level uint))
    (if (and (<= temperature u100) (<= humidity u100) (<= shock-level u200))
        (some (calculate-risk-multiplier temperature humidity shock-level))
        none
    )
)

;; Read-only function to get total policies count
(define-read-only (get-total-policies)
    (var-get policy-counter)
)

;; Read-only function to get total cargo registrations
(define-read-only (get-total-cargo-registrations)
    (var-get cargo-counter)
)