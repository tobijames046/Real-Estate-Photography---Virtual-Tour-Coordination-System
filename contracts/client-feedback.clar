;; Client Feedback Contract
;; Tracks client satisfaction and feedback collection

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-FEEDBACK-EXISTS (err u401))
(define-constant ERR-FEEDBACK-NOT-FOUND (err u402))
(define-constant ERR-INVALID-RATING (err u403))
(define-constant ERR-SURVEY-NOT-FOUND (err u404))
(define-constant ERR-INVALID-STATUS (err u405))

;; Data Variables
(define-data-var next-feedback-id uint u1)
(define-data-var next-survey-id uint u1)
(define-data-var next-dispute-id uint u1)

;; Data Maps
(define-map client-feedback
  { feedback-id: uint }
  {
    client: principal,
    property-id: uint,
    photographer-id: (optional uint),
    virtual-tour-id: (optional uint),
    service-type: (string-ascii 30),
    overall-rating: uint,
    quality-rating: uint,
    timeliness-rating: uint,
    communication-rating: uint,
    value-rating: uint,
    comments: (string-ascii 1000),
    would-recommend: bool,
    improvement-suggestions: (string-ascii 500),
    created-at: uint,
    is-verified: bool
  }
)

(define-map satisfaction-surveys
  { survey-id: uint }
  {
    property-id: uint,
    client: principal,
    survey-type: (string-ascii 30),
    questions: (list 20 (string-ascii 200)),
    responses: (list 20 (string-ascii 500)),
    completion-status: (string-ascii 20),
    sent-at: uint,
    completed-at: (optional uint),
    follow-up-required: bool
  }
)

(define-map feedback-analytics
  { period: uint, service-type: (string-ascii 30) }
  {
    total-responses: uint,
    avg-overall-rating: uint,
    avg-quality-rating: uint,
    avg-timeliness-rating: uint,
    avg-communication-rating: uint,
    avg-value-rating: uint,
    recommendation-rate: uint,
    response-rate: uint
  }
)

(define-map quality-improvements
  { improvement-id: uint }
  {
    feedback-id: uint,
    issue-category: (string-ascii 50),
    description: (string-ascii 500),
    priority: (string-ascii 20),
    assigned-to: (optional principal),
    status: (string-ascii 20),
    resolution: (optional (string-ascii 500)),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-map dispute-resolutions
  { dispute-id: uint }
  {
    feedback-id: uint,
    client: principal,
    service-provider: principal,
    dispute-type: (string-ascii 50),
    description: (string-ascii 1000),
    evidence: (list 10 (string-ascii 200)),
    status: (string-ascii 20),
    resolution: (optional (string-ascii 1000)),
    mediator: (optional principal),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

;; Read-only functions
(define-read-only (get-client-feedback (feedback-id uint))
  (map-get? client-feedback { feedback-id: feedback-id })
)

(define-read-only (get-satisfaction-survey (survey-id uint))
  (map-get? satisfaction-surveys { survey-id: survey-id })
)

(define-read-only (get-feedback-analytics (period uint) (service-type (string-ascii 30)))
  (map-get? feedback-analytics { period: period, service-type: service-type })
)

(define-read-only (calculate-client-satisfaction (client principal))
  (ok {
    total-feedback: u0, ;; Would count all feedback from client
    avg-rating: u0,
    recommendation-rate: u0,
    last-feedback-date: u0
  })
)

(define-read-only (get-service-quality-score (service-type (string-ascii 30)))
  (let (
    (analytics (map-get? feedback-analytics { period: block-height, service-type: service-type }))
  )
    (match analytics
      some-data (ok (get avg-overall-rating some-data))
      (ok u0)
    )
  )
)

;; Public functions
(define-public (submit-feedback
  (property-id uint)
  (photographer-id (optional uint))
  (virtual-tour-id (optional uint))
  (service-type (string-ascii 30))
  (overall-rating uint)
  (quality-rating uint)
  (timeliness-rating uint)
  (communication-rating uint)
  (value-rating uint)
  (comments (string-ascii 1000))
  (would-recommend bool)
  (improvement-suggestions (string-ascii 500))
)
  (let (
    (feedback-id (var-get next-feedback-id))
  )
    ;; Fixed HTML entities - replaced &lt; with < for proper Clarity syntax
    (asserts! (and (>= overall-rating u1) (<= overall-rating u5)) ERR-INVALID-RATING)
    (asserts! (and (>= quality-rating u1) (<= quality-rating u5)) ERR-INVALID-RATING)
    (asserts! (and (>= timeliness-rating u1) (<= timeliness-rating u5)) ERR-INVALID-RATING)
    (asserts! (and (>= communication-rating u1) (<= communication-rating u5)) ERR-INVALID-RATING)
    (asserts! (and (>= value-rating u1) (<= value-rating u5)) ERR-INVALID-RATING)

    (map-set client-feedback
      { feedback-id: feedback-id }
      {
        client: tx-sender,
        property-id: property-id,
        photographer-id: photographer-id,
        virtual-tour-id: virtual-tour-id,
        service-type: service-type,
        overall-rating: overall-rating,
        quality-rating: quality-rating,
        timeliness-rating: timeliness-rating,
        communication-rating: communication-rating,
        value-rating: value-rating,
        comments: comments,
        would-recommend: would-recommend,
        improvement-suggestions: improvement-suggestions,
        created-at: block-height,
        is-verified: false
      }
    )

    (var-set next-feedback-id (+ feedback-id u1))
    (ok feedback-id)
  )
)

(define-public (create-satisfaction-survey
  (property-id uint)
  (client principal)
  (survey-type (string-ascii 30))
  (questions (list 20 (string-ascii 200)))
)
  (let (
    (survey-id (var-get next-survey-id))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set satisfaction-surveys
      { survey-id: survey-id }
      {
        property-id: property-id,
        client: client,
        survey-type: survey-type,
        questions: questions,
        responses: (list),
        completion-status: "sent",
        sent-at: block-height,
        completed-at: none,
        follow-up-required: false
      }
    )

    (var-set next-survey-id (+ survey-id u1))
    (ok survey-id)
  )
)

(define-public (complete-survey
  (survey-id uint)
  (responses (list 20 (string-ascii 500)))
)
  (let (
    (survey (unwrap! (get-satisfaction-survey survey-id) ERR-SURVEY-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get client survey)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get completion-status survey) "sent") ERR-INVALID-STATUS)

    (map-set satisfaction-surveys
      { survey-id: survey-id }
      (merge survey {
        responses: responses,
        completion-status: "completed",
        completed-at: (some block-height)
      })
    )

    (ok true)
  )
)

(define-public (verify-feedback (feedback-id uint))
  (let (
    (feedback (unwrap! (get-client-feedback feedback-id) ERR-FEEDBACK-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set client-feedback
      { feedback-id: feedback-id }
      (merge feedback { is-verified: true })
    )

    (ok true)
  )
)

(define-public (create-quality-improvement
  (feedback-id uint)
  (issue-category (string-ascii 50))
  (description (string-ascii 500))
  (priority (string-ascii 20))
)
  (let (
    (feedback (unwrap! (get-client-feedback feedback-id) ERR-FEEDBACK-NOT-FOUND))
    (improvement-id (+ (var-get next-feedback-id) u1000)) ;; Simple ID generation
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set quality-improvements
      { improvement-id: improvement-id }
      {
        feedback-id: feedback-id,
        issue-category: issue-category,
        description: description,
        priority: priority,
        assigned-to: none,
        status: "open",
        resolution: none,
        created-at: block-height,
        resolved-at: none
      }
    )

    (ok improvement-id)
  )
)

(define-public (create-dispute
  (feedback-id uint)
  (service-provider principal)
  (dispute-type (string-ascii 50))
  (description (string-ascii 1000))
  (evidence (list 10 (string-ascii 200)))
)
  (let (
    (feedback (unwrap! (get-client-feedback feedback-id) ERR-FEEDBACK-NOT-FOUND))
    (dispute-id (var-get next-dispute-id))
  )
    (asserts! (is-eq tx-sender (get client feedback)) ERR-NOT-AUTHORIZED)

    (map-set dispute-resolutions
      { dispute-id: dispute-id }
      {
        feedback-id: feedback-id,
        client: tx-sender,
        service-provider: service-provider,
        dispute-type: dispute-type,
        description: description,
        evidence: evidence,
        status: "open",
        resolution: none,
        mediator: none,
        created-at: block-height,
        resolved-at: none
      }
    )

    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (update-analytics
  (period uint)
  (service-type (string-ascii 30))
  (total-responses uint)
  (avg-overall-rating uint)
  (avg-quality-rating uint)
  (avg-timeliness-rating uint)
  (avg-communication-rating uint)
  (avg-value-rating uint)
  (recommendation-rate uint)
  (response-rate uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set feedback-analytics
      { period: period, service-type: service-type }
      {
        total-responses: total-responses,
        avg-overall-rating: avg-overall-rating,
        avg-quality-rating: avg-quality-rating,
        avg-timeliness-rating: avg-timeliness-rating,
        avg-communication-rating: avg-communication-rating,
        avg-value-rating: avg-value-rating,
        recommendation-rate: recommendation-rate,
        response-rate: response-rate
      }
    )

    (ok true)
  )
)
