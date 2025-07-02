;; Monitor Verification Contract
;; Validates and manages compliance monitors

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MONITOR_NOT_FOUND (err u101))
(define-constant ERR_MONITOR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Data Variables
(define-data-var next-monitor-id uint u1)

;; Data Maps
(define-map monitors
  { monitor-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    status: (string-ascii 16),
    created-at: uint,
    updated-at: uint,
    verification-hash: (buff 32)
  }
)

(define-map monitor-permissions
  { monitor-id: uint, principal: principal }
  { can-read: bool, can-write: bool, can-admin: bool }
)

;; Public Functions

;; Register a new compliance monitor
(define-public (register-monitor (name (string-ascii 64)) (description (string-ascii 256)) (verification-hash (buff 32)))
  (let ((monitor-id (var-get next-monitor-id)))
    (map-set monitors
      { monitor-id: monitor-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        status: "active",
        created-at: block-height,
        updated-at: block-height,
        verification-hash: verification-hash
      }
    )
    (map-set monitor-permissions
      { monitor-id: monitor-id, principal: tx-sender }
      { can-read: true, can-write: true, can-admin: true }
    )
    (var-set next-monitor-id (+ monitor-id u1))
    (print { event: "monitor-registered", monitor-id: monitor-id, owner: tx-sender })
    (ok monitor-id)
  )
)

;; Update monitor status
(define-public (update-monitor-status (monitor-id uint) (new-status (string-ascii 16)))
  (let ((monitor (unwrap! (map-get? monitors { monitor-id: monitor-id }) ERR_MONITOR_NOT_FOUND)))
    (asserts! (is-eq (get owner monitor) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq new-status "active") (is-eq new-status "inactive") (is-eq new-status "suspended")) ERR_INVALID_STATUS)
    (map-set monitors
      { monitor-id: monitor-id }
      (merge monitor { status: new-status, updated-at: block-height })
    )
    (print { event: "monitor-status-updated", monitor-id: monitor-id, status: new-status })
    (ok true)
  )
)

;; Grant permissions to a principal for a monitor
(define-public (grant-permissions (monitor-id uint) (principal principal) (can-read bool) (can-write bool) (can-admin bool))
  (let ((monitor (unwrap! (map-get? monitors { monitor-id: monitor-id }) ERR_MONITOR_NOT_FOUND)))
    (asserts! (is-eq (get owner monitor) tx-sender) ERR_UNAUTHORIZED)
    (map-set monitor-permissions
      { monitor-id: monitor-id, principal: principal }
      { can-read: can-read, can-write: can-write, can-admin: can-admin }
    )
    (print { event: "permissions-granted", monitor-id: monitor-id, principal: principal })
    (ok true)
  )
)

;; Verify monitor integrity
(define-public (verify-monitor (monitor-id uint) (verification-hash (buff 32)))
  (let ((monitor (unwrap! (map-get? monitors { monitor-id: monitor-id }) ERR_MONITOR_NOT_FOUND)))
    (let ((is-valid (is-eq (get verification-hash monitor) verification-hash)))
      (print { event: "monitor-verified", monitor-id: monitor-id, is-valid: is-valid })
      (ok is-valid)
    )
  )
)

;; Read-only Functions

;; Get monitor details
(define-read-only (get-monitor (monitor-id uint))
  (map-get? monitors { monitor-id: monitor-id })
)

;; Get monitor permissions for a principal
(define-read-only (get-permissions (monitor-id uint) (principal principal))
  (map-get? monitor-permissions { monitor-id: monitor-id, principal: principal })
)

;; Check if principal has read access
(define-read-only (has-read-access (monitor-id uint) (principal principal))
  (match (map-get? monitor-permissions { monitor-id: monitor-id, principal: principal })
    permissions (get can-read permissions)
    false
  )
)

;; Check if principal has write access
(define-read-only (has-write-access (monitor-id uint) (principal principal))
  (match (map-get? monitor-permissions { monitor-id: monitor-id, principal: principal })
    permissions (get can-write permissions)
    false
  )
)

;; Get next monitor ID
(define-read-only (get-next-monitor-id)
  (var-get next-monitor-id)
)
