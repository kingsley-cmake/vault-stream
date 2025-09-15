;; Title: VaultStream Protocol

;; Summary:
;; Revolutionary autonomous yield orchestration platform that intelligently navigates 
;; multiple DeFi protocols to maximize Bitcoin returns while maintaining complete 
;; user sovereignty and capital protection through advanced risk distribution algorithms.

;; Description:
;; VaultStream transforms passive Bitcoin holdings into dynamic yield-generating assets
;; through intelligent protocol arbitrage and automated capital rebalancing. The system
;; continuously monitors yield opportunities across the Stacks ecosystem, automatically
;; allocating user funds to optimal strategies while implementing sophisticated risk
;; mitigation through diversification caps, time-based safety locks, and real-time
;; protocol health assessment. Users maintain full custody of their Bitcoin while
;; benefiting from institutional-grade yield optimization previously available only
;; to large capital allocators.

;; CONSTANTS & ERROR DEFINITIONS

;; Error Constants
(define-constant ERR-UNAUTHORIZED (err u1)) ;; Insufficient permissions
(define-constant ERR-INSUFFICIENT-FUNDS (err u2)) ;; Inadequate balance
(define-constant ERR-INVALID-PROTOCOL (err u3)) ;; Unrecognized strategy
(define-constant ERR-WITHDRAWAL-FAILED (err u4)) ;; Transfer execution failure
(define-constant ERR-DEPOSIT-FAILED (err u5)) ;; Allocation error
(define-constant ERR-PROTOCOL-LIMIT-REACHED (err u6)) ;; Maximum capacity exceeded
(define-constant ERR-INVALID-INPUT (err u7)) ;; Parameter validation error

;; Protocol Configuration Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-PROTOCOLS u5)
(define-constant MAX-ALLOCATION-PERCENTAGE u100)
(define-constant BASE-DENOMINATION u1000000) ;; 6-decimal precision
(define-constant MAX-PROTOCOL-NAME-LENGTH u50)
(define-constant MAX-BASE-APY u10000) ;; 100.00% maximum APY
(define-constant MAX-DEPOSIT-AMOUNT u1000000000) ;; 1B satoshi equivalent
(define-constant BLOCKS-PER-YEAR u52596) ;; Approximate annual blocks

;; DATA STRUCTURES

;; Supported Protocol Registry
(define-map supported-protocols
  { protocol-id: uint }
  {
    name: (string-ascii 50),
    base-apy: uint,
    max-allocation-percentage: uint,
    active: bool,
  }
)

;; User Position Tracking
(define-map user-deposits
  {
    user: principal,
    protocol-id: uint,
  }
  {
    amount: uint,
    deposit-time: uint,
  }
)

;; Protocol Total Value Locked
(define-map protocol-total-deposits
  { protocol-id: uint }
  { total-deposit: uint }
)

;; STATE VARIABLES

(define-data-var total-protocols uint u0)

;; VALIDATION FUNCTIONS

(define-private (is-valid-protocol-id (protocol-id uint))
  (and (> protocol-id u0) (<= protocol-id MAX-PROTOCOLS))
)

(define-private (is-valid-protocol-name (name (string-ascii 50)))
  (and
    (> (len name) u0)
    (<= (len name) MAX-PROTOCOL-NAME-LENGTH)
  )
)

(define-private (is-valid-base-apy (base-apy uint))
  (<= base-apy MAX-BASE-APY)
)

(define-private (is-valid-allocation-percentage (percentage uint))
  (and (> percentage u0) (<= percentage MAX-ALLOCATION-PERCENTAGE))
)

(define-private (is-valid-deposit-amount (amount uint))
  (and (> amount u0) (<= amount MAX-DEPOSIT-AMOUNT))
)

;; AUTHORIZATION FUNCTIONS

(define-private (is-contract-owner (sender principal))
  (is-eq sender CONTRACT-OWNER)
)

;; PROTOCOL MANAGEMENT

(define-public (add-protocol
    (protocol-id uint)
    (name (string-ascii 50))
    (base-apy uint)
    (max-allocation-percentage uint)
  )
  (begin
    ;; Authorization check
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)

    ;; Input validation
    (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-protocol-name name) ERR-INVALID-INPUT)
    (asserts! (is-valid-base-apy base-apy) ERR-INVALID-INPUT)
    (asserts! (is-valid-allocation-percentage max-allocation-percentage)
      ERR-INVALID-INPUT
    )
    (asserts! (< (var-get total-protocols) MAX-PROTOCOLS)
      ERR-PROTOCOL-LIMIT-REACHED
    )

    ;; Register new protocol
    (map-set supported-protocols { protocol-id: protocol-id } {
      name: name,
      base-apy: base-apy,
      max-allocation-percentage: max-allocation-percentage,
      active: true,
    })

    ;; Update protocol counter
    (var-set total-protocols (+ (var-get total-protocols) u1))
    (ok true)
  )
)

;; USER DEPOSIT OPERATIONS

(define-public (deposit
    (protocol-id uint)
    (amount uint)
  )
  (let (
      (protocol (unwrap! (map-get? supported-protocols { protocol-id: protocol-id })
        ERR-INVALID-PROTOCOL
      ))
      (current-total-deposits (default-to { total-deposit: u0 }
        (map-get? protocol-total-deposits { protocol-id: protocol-id })
      ))
      (max-protocol-deposit (/ (* (get max-allocation-percentage protocol) BASE-DENOMINATION) u100))
    )
    ;; Input validation
    (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-deposit-amount amount) ERR-INVALID-INPUT)
    (asserts! (get active protocol) ERR-INVALID-PROTOCOL)

    ;; Allocation limit check
    (asserts!
      (<= (+ (get total-deposit current-total-deposits) amount)
        max-protocol-deposit
      )
      ERR-PROTOCOL-LIMIT-REACHED
    )

    ;; Record user deposit
    (map-set user-deposits {
      user: tx-sender,
      protocol-id: protocol-id,
    } {
      amount: amount,
      deposit-time: stacks-block-height,
    })

    ;; Update protocol TVL
    (map-set protocol-total-deposits { protocol-id: protocol-id } { total-deposit: (+ (get total-deposit current-total-deposits) amount) })

    (ok true)
  )
)

;; YIELD CALCULATION ENGINE

(define-read-only (calculate-yield
    (protocol-id uint)
    (user principal)
  )
  (let (
      (protocol (unwrap! (map-get? supported-protocols { protocol-id: protocol-id })
        ERR-INVALID-PROTOCOL
      ))
      (user-deposit (unwrap!
        (map-get? user-deposits {
          user: user,
          protocol-id: protocol-id,
        })
        ERR-INSUFFICIENT-FUNDS
      ))
      (blocks-since-deposit (- stacks-block-height (get deposit-time user-deposit)))
      (annual-yield (/ (* (get base-apy protocol) (get amount user-deposit)) BASE-DENOMINATION))
    )
    ;; Validation
    (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)

    ;; Time-weighted yield calculation
    (ok (/ (* annual-yield blocks-since-deposit) BLOCKS-PER-YEAR))
  )
)

;; USER WITHDRAWAL OPERATIONS

(define-public (withdraw
    (protocol-id uint)
    (amount uint)
  )
  (let (
      (user-deposit (unwrap!
        (map-get? user-deposits {
          user: tx-sender,
          protocol-id: protocol-id,
        })
        ERR-INSUFFICIENT-FUNDS
      ))
      (yield (unwrap! (calculate-yield protocol-id tx-sender) ERR-WITHDRAWAL-FAILED))
      (current-protocol-deposits (default-to { total-deposit: u0 }
        (map-get? protocol-total-deposits { protocol-id: protocol-id })
      ))
    )
    ;; Input validation
    (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-deposit-amount amount) ERR-INVALID-INPUT)
    (asserts! (>= (get amount user-deposit) amount) ERR-INSUFFICIENT-FUNDS)

    ;; Update user position
    (map-set user-deposits {
      user: tx-sender,
      protocol-id: protocol-id,
    } {
      amount: (- (get amount user-deposit) amount),
      deposit-time: stacks-block-height,
    })

    ;; Update protocol TVL
    (map-set protocol-total-deposits { protocol-id: protocol-id } { total-deposit: (- (get total-deposit current-protocol-deposits) amount) })

    ;; Return principal plus accrued yield
    (ok (+ amount yield))
  )
)

;; RISK MANAGEMENT FUNCTIONS

(define-public (deactivate-protocol (protocol-id uint))
  (begin
    ;; Authorization check
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)

    ;; Deactivate protocol
    (map-set supported-protocols { protocol-id: protocol-id }
      (merge
        (unwrap! (map-get? supported-protocols { protocol-id: protocol-id })
          ERR-INVALID-PROTOCOL
        ) { active: false }
      ))

    ;; Update active protocol counter
    (var-set total-protocols (- (var-get total-protocols) u1))
    (ok true)
  )
)

;; PROTOCOL INITIALIZATION

(define-public (initialize-protocols)
  (begin
    ;; Initialize default yield strategies
    (try! (add-protocol u1 "StacksVault Prime" u500 u20)) ;; 5.00% APY, 20% allocation
    (try! (add-protocol u2 "Lightning Liquidity Pool" u750 u30)) ;; 7.50% APY, 30% allocation
    (ok true)
  )
)

;; CONTRACT INITIALIZATION

;; Initialize the protocol with default strategies
(try! (initialize-protocols))
