;; Advanced Crowdfunding Contract

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROJECT-EXISTS (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INVALID-DEADLINE (err u102))
(define-constant ERR-PROJECT-NOT-FOUND (err u200))
(define-constant ERR-ALREADY-FUNDED (err u203))
(define-constant ERR-DEADLINE-PASSED (err u204))
(define-constant ERR-GOAL-NOT-REACHED (err u205))
(define-constant ERR-NOT-CREATOR (err u206))

;; Data Maps
(define-map projects {id: uint} {
  creator: principal,
  funding-goal: uint,
  deadline: uint,
  funds-raised: uint,
  milestones: (list 10 uint),
  status: (string-ascii 20),  ;; "active", "funded", "failed", "completed"
  milestone-index: uint
})

(define-map pledges {project-id: uint, backer: principal} {
  amount: uint,
  timestamp: uint,
  refunded: bool
})

(define-map project-milestones {project-id: uint, milestone-index: uint} {
  amount: uint,
  released: bool,
  approved-votes: uint,
  reject-votes: uint
})

;; Project Management
(define-public (create-project (id uint) (funding-goal uint) (deadline uint) (milestones (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? projects {id: id})) ERR-PROJECT-EXISTS)
    (asserts! (> funding-goal u0) ERR-INVALID-AMOUNT)
    (asserts! (> deadline (unwrap-panic (get-block-info? time u0))) ERR-INVALID-DEADLINE)
    
    (map-set projects {id: id} {
      creator: tx-sender,
      funding-goal: funding-goal,
      deadline: deadline,
      funds-raised: u0,
      milestones: milestones,
      status: "active",
      milestone-index: u0
    })
    
    ;; Initialize milestone tracking
    (let ((milestone-amounts milestones))
      (map initialize-milestone-tracking milestone-amounts))
    
    (ok id)))

;; Funding Functions
(define-public (pledge (project-id uint) (amount uint))
  (let ((project (unwrap! (map-get? projects {id: project-id}) ERR-PROJECT-NOT-FOUND))
        (current-time (unwrap-panic (get-block-info? time u0))))
    (begin
      (asserts! (> amount u0) ERR-INVALID-AMOUNT)
      (asserts! (< current-time (get deadline project)) ERR-DEADLINE-PASSED)
      (asserts! (is-eq (get status project) "active") ERR-ALREADY-FUNDED)
      
      ;; Update project funds
      (map-set projects {id: project-id}
        (merge project {funds-raised: (+ (get funds-raised project) amount)}))
      
      ;; Record pledge
      (map-set pledges 
        {project-id: project-id, backer: tx-sender}
        {amount: amount, timestamp: current-time, refunded: false})
      
      ;; Check if funding goal is reached and update status if necessary
      (if (>= (+ (get funds-raised project) amount) (get funding-goal project))
          (begin 
            (try! (update-project-status project-id "funded"))
            (ok amount))
          (ok amount)))))

;; Milestone Management
(define-public (release-milestone (project-id uint))
  (let ((project (unwrap! (map-get? projects {id: project-id}) ERR-PROJECT-NOT-FOUND))
        (current-milestone (get milestone-index project)))
    (begin
      (asserts! (is-eq tx-sender (get creator project)) ERR-NOT-CREATOR)
      (asserts! (is-eq (get status project) "funded") ERR-GOAL-NOT-REACHED)
      
      ;; Check if milestone voting passed
      (let ((milestone-data (unwrap! (map-get? project-milestones 
                                              {project-id: project-id, 
                                               milestone-index: current-milestone})
                                    ERR-PROJECT-NOT-FOUND)))
        (asserts! (> (get approved-votes milestone-data) (get reject-votes milestone-data)) ERR-NOT-AUTHORIZED)
        
        ;; Release milestone funds and update status
        (map-set project-milestones
          {project-id: project-id, milestone-index: current-milestone}
          (merge milestone-data {released: true}))
        
        (map-set projects {id: project-id}
          (merge project {milestone-index: (+ current-milestone u1)}))
        
        (ok true)))))

;; Voting Functions
(define-public (vote-on-milestone (project-id uint) (approve bool))
  (let ((project (unwrap! (map-get? projects {id: project-id}) ERR-PROJECT-NOT-FOUND))
        (pledge-data (unwrap! (map-get? pledges {project-id: project-id, backer: tx-sender}) ERR-NOT-AUTHORIZED))
        (current-milestone (get milestone-index project)))
    
    (let ((milestone-data (unwrap! (map-get? project-milestones 
                                            {project-id: project-id, 
                                             milestone-index: current-milestone})
                                  ERR-PROJECT-NOT-FOUND)))
      ;; Update votes based on pledge amount
      (if approve
          (map-set project-milestones
            {project-id: project-id, milestone-index: current-milestone}
            (merge milestone-data 
                   {approved-votes: (+ (get approved-votes milestone-data) (get amount pledge-data))}))
          (map-set project-milestones
            {project-id: project-id, milestone-index: current-milestone}
            (merge milestone-data 
                   {reject-votes: (+ (get reject-votes milestone-data) (get amount pledge-data))})))
      (ok true))))

;; Helper Functions
(define-private (initialize-milestone-tracking (amount uint))
  (begin
    (map-set project-milestones
      {project-id: amount, milestone-index: u0}
      {amount: amount,
       released: false,
       approved-votes: u0,
       reject-votes: u0})
    (ok true)))

(define-private (update-project-status (project-id uint) (new-status (string-ascii 20)))
  (let ((project (unwrap! (map-get? projects {id: project-id}) ERR-PROJECT-NOT-FOUND)))
    (begin
      (map-set projects {id: project-id}
        (merge project {status: new-status}))
      (ok true))))

;; Read-Only Functions
(define-read-only (get-project-details (project-id uint))
  (map-get? projects {id: project-id}))

(define-read-only (get-pledge-details (project-id uint) (backer principal))
  (map-get? pledges {project-id: project-id, backer: backer}))

(define-read-only (get-milestone-details (project-id uint) (milestone-index uint))
  (map-get? project-milestones {project-id: project-id, milestone-index: milestone-index}))
