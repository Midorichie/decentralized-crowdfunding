(define-map projects {id: uint} {
  creator: principal, 
  funding-goal: uint, 
  deadline: uint, 
  funds-raised: uint, 
  milestones: (list 10 uint)
})

(define-map pledges {project-id: uint, backer: principal} {amount: uint})

(define-public (create-project (id uint) (funding-goal uint) (deadline uint) (milestones (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? projects {id: id})) (err u100))
    (asserts! (> funding-goal u0) (err u101))
    (asserts! (> deadline (unwrap-panic (get-block-info? time u0))) (err u102))
    (map-set projects {id: id} {
      creator: tx-sender, 
      funding-goal: funding-goal, 
      deadline: deadline, 
      funds-raised: u0, 
      milestones: milestones
    })
    (ok id)))

(define-public (pledge (project-id uint) (amount uint))
  (begin
    (asserts! (is-some (map-get? projects {id: project-id})) (err u200))
    (asserts! (> amount u0) (err u201))
    (let ((project (unwrap! (map-get? projects {id: project-id}) (err u202))))
      (asserts! (< (+ (get funds-raised project) amount) (get funding-goal project)) (err u203))
      (map-set projects {id: project-id} 
        (merge project {funds-raised: (+ (get funds-raised project) amount)}))
      (map-set pledges {project-id: project-id, backer: tx-sender} {amount: amount})
      (ok amount))))
