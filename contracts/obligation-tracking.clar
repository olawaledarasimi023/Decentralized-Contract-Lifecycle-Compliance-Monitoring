;; Obligation Tracking Contract
;; Manages compliance obligations and their lifecycle

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_OBLIGATION_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STATUS (err u202))
(define-constant ERR_INVALID_PRIORITY (err u203))

;; Data Variables
(define-data-var next-obligation-id uint u1)

;; Data Maps
(define-map obligations
  { obligation-id: uint }
  {
    title: (string-ascii 128),
    description: (string-ascii 512),
    assignee: principal,
    status: (string-ascii 16),
    priority: (string-ascii 8),
    due-date: uint,
    created-at: uint,
    updated-at: uint,
    completion-percentage: uint,
    monitor-id: uint
  }
)

(define-map obligation-milestones
  { obligation-id: uint, milestone-id: uint }
  {
    title: (string-ascii 64),
    description: (string-ascii 256),
    due-date: uint,
    status: (string-ascii 16),
    completion-date: (optional uint)
  }
)

(define-map obligation-evidence
  { obligation-id: uint, evidence-id: uint }
  {
    evidence-type: (string-ascii 32),
    evidence-hash: (buff 32),
    submitted-by: principal,
    submitted-at: uint,
    verified: bool
  }
)

;; Public Functions

;; Create a new obligation
(define-public (create-obligation
  (title (string-ascii 128))
  (description (string-ascii 512))
  (assignee principal)
  (priority (string-ascii 8))
  (due-date uint)
  (monitor-id uint)
)
  (let ((obligation-id (var-get next-obligation-id)))
    (asserts! (or (is-eq priority "low") (is-eq priority "medium") (is-eq priority "high") (is-eq priority "critical")) ERR_INVALID_PRIORITY)
    (map-set obligations
      { obligation-id: obligation-id }
      {
        title: title,
        description: description,
        assignee: assignee,
        status: "pending",
        priority: priority,
        due-date: due-date,
        created-at: block-height,
        updated-at: block-height,
        completion-percentage: u0,
        monitor-id: monitor-id
      }
    )
    (var-set next-obligation-id (+ obligation-id u1))
    (print { event: "obligation-created", obligation-id: obligation-id, assignee: assignee })
    (ok obligation-id)
  )
)

;; Update obligation status
(define-public (update-obligation-status (obligation-id uint) (new-status (string-ascii 16)) (completion-percentage uint))
  (let ((obligation (unwrap! (map-get? obligations { obligation-id: obligation-id }) ERR_OBLIGATION_NOT_FOUND)))
    (asserts! (or (is-eq (get assignee obligation) tx-sender) (is-eq CONTRACT_OWNER tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq new-status "pending") (is-eq new-status "in-progress") (is-eq new-status "completed") (is-eq new-status "overdue")) ERR_INVALID_STATUS)
    (asserts! (<= completion-percentage u100) ERR_INVALID_STATUS)
    (map-set obligations
      { obligation-id: obligation-id }
      (merge obligation {
        status: new-status,
        completion-percentage: completion-percentage,
        updated-at: block-height
      })
    )
    (print { event: "obligation-status-updated", obligation-id: obligation-id, status: new-status, completion: completion-percentage })
    (ok true)
  )
)

;; Add milestone to obligation
(define-public (add-milestone
  (obligation-id uint)
  (milestone-id uint)
  (title (string-ascii 64))
  (description (string-ascii 256))
  (due-date uint)
)
  (let ((obligation (unwrap! (map-get? obligations { obligation-id: obligation-id }) ERR_OBLIGATION_NOT_FOUND)))
    (asserts! (or (is-eq (get assignee obligation) tx-sender) (is-eq CONTRACT_OWNER tx-sender)) ERR_UNAUTHORIZED)
    (map-set obligation-milestones
      { obligation-id: obligation-id, milestone-id: milestone-id }
      {
        title: title,
        description: description,
        due-date: due-date,
        status: "pending",
        completion-date: none
      }
    )
    (print { event: "milestone-added", obligation-id: obligation-id, milestone-id: milestone-id })
    (ok true)
  )
)

;; Complete milestone
(define-public (complete-milestone (obligation-id uint) (milestone-id uint))
  (let ((obligation (unwrap! (map-get? obligations { obligation-id: obligation-id }) ERR_OBLIGATION_NOT_FOUND))
        (milestone (unwrap! (map-get? obligation-milestones { obligation-id: obligation-id, milestone-id: milestone-id }) ERR_OBLIGATION_NOT_FOUND)))
    (asserts! (or (is-eq (get assignee obligation) tx-sender) (is-eq CONTRACT_OWNER tx-sender)) ERR_UNAUTHORIZED)
    (map-set obligation-milestones
      { obligation-id: obligation-id, milestone-id: milestone-id }
      (merge milestone {
        status: "completed",
        completion-date: (some block-height)
      })
    )
    (print { event: "milestone-completed", obligation-id: obligation-id, milestone-id: milestone-id })
    (ok true)
  )
)

;; Submit evidence for obligation
(define-public (submit-evidence
  (obligation-id uint)
  (evidence-id uint)
  (evidence-type (string-ascii 32))
  (evidence-hash (buff 32))
)
  (let ((obligation (unwrap! (map-get? obligations { obligation-id: obligation-id }) ERR_OBLIGATION_NOT_FOUND)))
    (map-set obligation-evidence
      { obligation-id: obligation-id, evidence-id: evidence-id }
      {
        evidence-type: evidence-type,
        evidence-hash: evidence-hash,
        submitted-by: tx-sender,
        submitted-at: block-height,
        verified: false
      }
    )
    (print { event: "evidence-submitted", obligation-id: obligation-id, evidence-id: evidence-id, submitted-by: tx-sender })
    (ok true)
  )
)

;; Read-only Functions

;; Get obligation details
(define-read-only (get-obligation (obligation-id uint))
  (map-get? obligations { obligation-id: obligation-id })
)

;; Get milestone details
(define-read-only (get-milestone (obligation-id uint) (milestone-id uint))
  (map-get? obligation-milestones { obligation-id: obligation-id, milestone-id: milestone-id })
)

;; Get evidence details
(define-read-only (get-evidence (obligation-id uint) (evidence-id uint))
  (map-get? obligation-evidence { obligation-id: obligation-id, evidence-id: evidence-id })
)

;; Check if obligation is overdue
(define-read-only (is-obligation-overdue (obligation-id uint))
  (match (map-get? obligations { obligation-id: obligation-id })
    obligation (and
      (> block-height (get due-date obligation))
      (not (is-eq (get status obligation) "completed"))
    )
    false
  )
)

;; Get next obligation ID
(define-read-only (get-next-obligation-id)
  (var-get next-obligation-id)
)
