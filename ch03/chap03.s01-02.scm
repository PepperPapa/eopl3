#lang eopl
;;;; section 3.2
;;; Environment(from section 3.2)
(define empty-env
  (lambda () (list 'empty-env)))
(define extend-env
  (lambda (var val env)
    (list 'extend-env var val env)))
(define apply-env
  (lambda (env search-var)
    (cond
      ((eqv? (car env) 'empty-env)
       (report-no-binding-found search-var))
      ((eqv? (car env) 'extend-env)
       (let ((saved-var (cadr env))
             (saved-val (caddr env))
             (saved-env (cadddr env)))
         (if (eqv? search-var saved-var)
             saved-val
             (apply-env saved-env search-var))))
      (else
       (report-invalid-env env)))))
(define report-no-binding-found
  (lambda (search-var)
    (eopl:error 'apply-env "No binding for ~s" search-var)))
(define report-invalid-env
  (lambda (env)
    (eopl:error 'apply-env "Bad environment: ~s" env)))
;;; Expval
(define-datatype exp-val exp-val?
  (num-val
   (val number?))
  (bool-val
   (val boolean?)))
(define expval->num
  (lambda (value)
    (cases exp-val value
           (num-val
            (number)
            number)
           (else
            (report-invalid-exp-value 'num)))))
(define expval->bool
  (lambda (value)
    (cases exp-val value
           (bool-val
            (boolean)
            boolean)
           (else
            (report-invalid-exp-value 'bool)))))
(define report-invalid-exp-value
  (lambda (type)
    (eopl:error
     'exp-val
     "No a valid exp value of type ~s" type)))
;;; ----- test -----
(define n1 (num-val 1))
(define b1 (bool-val #t))
(define b2 (bool-val #f))
;; (num-val #t)                            ; error
;; (bool-val 2)                            ; error
(expval->num n1)
;; (expval->num b1)                        ; error
;; (expval->num b2)                        ; error
;; (expval->bool n1)                       ; error
(expval->bool b1)
(expval->bool b2)
;;; Syntax for the LET language
;;; Program    ::= Expression
;;;                a-program (exp1)
;;; Expression ::= Number
;;;                const-exp (num)
;;; Expression ::= -(Expression , Expression)
;;;                diff-exp (exp1 exp2)
;;; Expression ::= zero? (Expression)
;;;                zero?-exp (exp1)
;;; Expression ::= if Expression then Expression else Expression
;;;                if-exp (exp1 exp2 exp3)
;;; Expression ::= Identifier
;;;                var-exp (var)
;;; Expression ::= let Identifier = Expression in Expression
;;;                let-exp (var exp1 body)
;;; Let program
;;;
;;; data types defined below are informative, because they will be automatically
;;; generated by SLLGEN
;; (define-datatype let-program let-program?
;;   (a-program
;;    (exp1 let-expression?)))
;; (define-datatype let-expresiion let-expression?
;;   (const-exp
;;    (num integer?))
;;   (diff-exp
;;    (exp1 let-expression?)
;;    (exp2 let-expression?))
;;   (zero?-exp
;;    (exp1 let-expression?))
;;   (if-exp
;;    (exp1 let-expression?)
;;    (exp2 let-expression?)
;;    (exp3 let-expression?))
;;   (var-exp
;;    (var symbol?))
;;   (let-exp
;;    (var symbol?)
;;    (exp1 let-expression?)
;;    (body let-expression?)))
;;; Parse Expression
(define let-scanner-spec
  '((white-sp (whitespace) skip)
    (identifier (letter (arbno (or letter digit))) symbol)
    (number ((or (concat digit (arbno digit))
                 (concat "-" digit (arbno digit))
                 (concat (arbno digit) "." digit (arbno digit))
                 (concat "-" (arbno digit) "." digit (arbno digit))
                 (concat digit (arbno digit) "." (arbno digit))
                 (concat "-" digit (arbno digit) "." (arbno digit)))) number)))
(define let-grammar
  '((program (expression) a-program)
    (expression (number)
                const-exp)
    (expression ("-" "(" expression "," expression ")")
                diff-exp)
    (expression ("zero?" "(" expression ")")
                zero?-exp)
    (expression ("if" expression "then" expression "else" expression)
                if-exp)
    (expression (identifier)
                var-exp)
    (expression ("let" identifier "=" expression "in" expression)
                let-exp)))
(sllgen:make-define-datatypes let-scanner-spec let-grammar)
(define list-the-datatypes
  (lambda ()
    (sllgen:list-define-datatypes let-scanner-spec let-grammar)))
(define just-scan
  (sllgen:make-string-scanner let-scanner-spec let-grammar))
(define scan&parse
  (sllgen:make-string-parser let-scanner-spec let-grammar))
;;; Evaluate Expression
(define value-of
  (lambda (exp env)
    (cases expression exp
           (const-exp
            (num)
            (num-val num))
           (var-exp
            (var)
            (apply-env env var))
           (diff-exp
            (exp1 exp2)
            (num-val (- (expval->num (value-of exp1 env))
                        (expval->num (value-of exp2 env)))))
           (zero?-exp
            (exp1)
            (bool-val (eqv? (expval->num (value-of exp1 env)) 0)))
           (if-exp
            (exp1 exp2 exp3)
            (if (expval->bool (value-of exp1 env))
                (value-of exp2 env)
                (value-of exp3 env)))
           (let-exp
            (var exp1 body)
            (value-of body (extend-env var (value-of exp1 env) env))))))
(define value-of--program
  (lambda (prog)
    (cases program prog
           (a-program
            (exp)
            (let ((val (value-of exp (empty-env))))
              (cases exp-val val
                     (num-val
                      (num)
                      num)
                     (bool-val
                      (bool)
                      bool)))))))
(define read-eval-print
  (sllgen:make-rep-loop
   "--> "
   value-of--program
   (sllgen:make-stream-parser let-scanner-spec let-grammar)))
(value-of--program
 (scan&parse "let x = 7 in
               let y = 2 in
                 let y = let x = -(x, 1) in -(x, y)
                   in -(-(x,8), y)"))
