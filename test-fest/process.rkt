#lang at-exp racket

(provide launch-process!
         wait/keep-ci-alive)

(require "util.rkt"
         "test-fest-data.rkt"
         "logger.rkt")

(define (containing-directory path)
  (define-values {dir _} (basename path #:with-directory? #t))
  dir)

(define/contract (launch-process! exe-path
                                  [args empty]
                                  #:stdin [stdin #f]
                                  #:stdout [stdout #f]
                                  #:run-with-racket? [run-with-racket? #f]
                                  #:run-in [run-in
                                            (containing-directory exe-path)])
  (->i ([exe-path path-to-existant-file?])
       ([args (listof string?)]
        #:stdin [stdin (or/c (and/c input-port? file-stream-port?) #f)]
        #:stdout [stdout (or/c (and/c output-port? file-stream-port?) #f)]
        #:run-with-racket? [run-with-racket? boolean?]
        #:run-in [run-in path-string?])
       (values [r1 subprocess?]
               [r2 (stdout)
                   (if (output-port? stdout)
                       false?
                       input-port?)]))

  (define-values {proc returned-stdout _1 _2}
    (parameterize ([current-directory run-in])
      (if run-with-racket?
          (subprocess/racket-bytecode (list stdout stdin 'stdout)
                                      exe-path
                                      args)
          (apply subprocess
                 stdout stdin 'stdout
                 'new
                 exe-path
                 args))))
  (values proc returned-stdout))

(define racket-exe (find-executable-path "racket"))

(define/contract (subprocess/racket-bytecode subprocess-args path exe-args)
  (list? path-to-existant-file? (listof string?) . -> . any)

  (call-with-extended-environment
   (hash "PLT_COMPILED_FILE_CHECK" "exists"
         "PLTCOMPILEDROOTS" "compiled/@(version):")
   (thunk (apply subprocess (append subprocess-args
                                    (list* racket-exe
                                           path
                                           exe-args))))))

;; Travis CI kills any job that has no output for 10 minutes; prevent that.
(define/contract (wait/keep-ci-alive proc timeout-seconds)
  (subprocess? (and/c real? positive?) . -> . (or/c subprocess? #f))

  (log-fest debug
            @~a{Waiting for process with timeout: @|timeout-seconds|s})
  (define output-thd
    (thread (thunk (let loop ()
                     (displayln ".")
                     (sleep (* 8 60))
                     (loop)))))
  (begin0 (sync/timeout timeout-seconds proc)
    (kill-thread output-thd))
  ;; (define waiting-period
  ;;   (min timeout-seconds ci-output-timeout-seconds))
  ;; (define rounds-to-wait
  ;;   (round-up (/ timeout-seconds waiting-period)))
  ;; (log-fest debug
  ;;           @~a{Waiting for @rounds-to-wait rounds of @|waiting-period|s})
  ;; (for/or ([i (in-range rounds-to-wait)])
  ;;   (displayln ".")
  ;;   (sync/timeout waiting-period proc))
  )
