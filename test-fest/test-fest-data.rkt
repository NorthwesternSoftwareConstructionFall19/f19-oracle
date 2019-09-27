#lang at-exp racket

(provide (all-defined-out)
         (struct-out test))

(define student-groups
  '("dummy-team"))

;; Travis kills any job running longer than 115 min
(define absolute-max-timeout-minutes 115)
;; or not producing output for 10 min
(define ci-output-timeout-minutes 10)

(define (oracle->student-timeout mins)
  (* 10 mins))

(define (group-name? s)
  (member s student-groups))

(define ((add-suffix suffix) str)
  (string-append str suffix))

(define group->test-repo-name (add-suffix "-tests"))
(define group->dev-repo-name (add-suffix "-dev"))

(define student-test-repos
  (map group->test-repo-name student-groups))
(define student-dev-repos
  (map group->dev-repo-name student-groups))

(define (repo->team-name repo-name)
  (match repo-name
    [(regexp #rx"(.*)-dev" (list _ name))
     name]
    [(regexp #rx"(.*)-tests" (list _ name))
     name]
    [else #f]))

(define (repo-name? name)
  (or (string=? name "oracle")
      (member (repo->team-name name) student-groups)))

(define/contract (repo-name->url name)
  (repo-name? . -> . string?)

  @~a{https://github.com/NorthwesternSoftwareConstructionFall19/@|name|.git})

(define max-number-tests 5)


(define input-file-rx #rx"(.*/)input-([0-9]+)")

(define (test-input-file? path)
  (regexp-match? input-file-rx path))

(define/contract (test-input-file->output-file path)
  (test-input-file? . -> . path-string?)
  (match path
    [(regexp input-file-rx (list _ path n))
     @~a{@|path|/output-@n}]
    [(? path?)
     (test-input-file->output-file (path->string path))]))

(define major-number? (and/c string? #rx"[0-9]+"))
(define minor-number? major-number?)
(define assign-number? (cons/c major-number? minor-number?))
(define/contract (assign-number->string a)
  (assign-number? . -> . string?)
  (match a
    [(cons major minor) @~a{@|major|.@|minor|}]))

(struct test (in out timeout-minutes) #:transparent)
(define test/c (struct/c test path-string? path-string? natural?))

(define test-set/c (hash/c repo-name? (listof test/c)))

(define path-to-existant-directory?
  (and/c path-string? directory-exists?))
(define path-to-existant-file?
  (and/c path-string? file-exists?))

(define (pretty-path path)
  (find-relative-path (simple-form-path ".")
                      (simple-form-path path)))