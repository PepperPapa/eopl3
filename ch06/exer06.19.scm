#lang eopl
;;; ---------------------- Environment (from section 3.2) ----------------------
(define member?
  (lambda (sym lst)
    (if (null? lst)
        #f
        (or (eqv? sym (car lst))
            (member? sym (cdr lst))))))
(define check-duplicates
  (lambda (lst)
    (cond ((null? lst) '())
          ((member? (car lst) (cdr lst)) (car lst))
          (else (check-duplicates (cdr lst))))))
(define empty-env?
  (lambda (env)
    (and (list? env)
         (not (null? env))
         (eqv? (car env) 'empty-env))))
(define extended-env?
  (lambda (env)
    (and (list? env)
         (not (null? env))
         (or (eqv? (car env) 'extend-env)
             (eqv? (car env) 'extend-env-rec)))))
(define environment?
  (lambda (env)
    (or (empty-env? env)
        (extended-env? env))))
(define empty-env
  (lambda () (list 'empty-env)))
(define extend-env
  (lambda (var val env)
    (list 'extend-env var val env)))
(define extend-env*
  (lambda (vars vals env)
    (let ((duplicate (check-duplicates vars))
          (var-len (length vars))
          (val-len (length vals)))
      (cond [(not (null? duplicate))
             (report-duplicate-id duplicate)]
            [(< var-len val-len)
             (report-argument-mismatch 'greater)]
            [(> var-len val-len)
             (report-argument-mismatch 'less)]
            [else
             (letrec ((extend-env*-inner
                       (lambda (vars vals env)
                         (cond [(null? vars)
                                env]
                               [else
                                (extend-env*-inner
                                 (cdr vars)
                                 (cdr vals)
                                 (list 'extend-env (car vars) (car vals) env))]))))
               (extend-env*-inner vars vals env))]))))
(define extend-env-rec
  (lambda (p-names p-vars p-bodies env)
    (let ((dup-name (check-duplicates p-names)))
      (if (null? dup-name)
          (list 'extend-env-rec (list p-names p-vars p-bodies) env)
          (report-duplicate-id dup-name)))))
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
      ((eqv? (car env) 'extend-env-rec)
       (let ((func (apply-env-rec search-var
                                  (car (cadr env))
                                  (cadr (cadr env))
                                  (caddr (cadr env)))))
         (if (null? func)
             (apply-env (caddr env) search-var)
             (let ((saved-p-vars (car func))
                   (saved-p-body (cadr func)))
               (proc-val (procedure saved-p-vars saved-p-body env))))))
      (else
       (report-invalid-env env)))))
;;; apply-env-rec : Sym x Listof(Sym) x Listof(Listof(Sym)) x Listof(Expression) ->
;;;                 ((Listof(Sym), Expression) | '(),
;;;                  (Listof(Sym),
;;;                   Listof(Listof(Sym)),
;;;                   Listof(Expression)))
(define apply-env-rec
  (lambda (var p-names p-vars p-bodies)
    (if (null? p-names)
        '()
        (if (eqv? var (car p-names))
            (list (car p-vars) (car p-bodies))
            (apply-env-rec var (cdr p-names) (cdr p-vars) (cdr p-bodies))))))
(define report-no-binding-found
  (lambda (search-var)
    (eopl:error 'apply-env "No binding for ~s" search-var)))
(define report-invalid-env
  (lambda (env)
    (eopl:error 'apply-env "Bad environment: ~s" env)))
(define report-argument-mismatch
  (lambda (symp)
    (eopl:error 'extend-env* "Argument number is ~s than parameter number" symp)))
(define report-duplicate-id
  (lambda (sym)
    (eopl:error 'extend-env* "Duplicate identifier ~s" sym)))
;;; ---------------------- Expval ----------------------
(define identifier? symbol?)
(define-datatype proc proc?
  (procedure
   (vars (list-of identifier?))
   (body expression?)
   (saved-env environment?)))
(define-datatype exp-val exp-val?
  (num-val
   (val number?))
  (bool-val
   (val boolean?))
  (proc-val
   (val proc?))
  (null-val)
  (pair-val
   (val1 exp-val?)
   (val2 exp-val?)))
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
(define expval->proc
  (lambda (value)
    (cases exp-val value
           (proc-val
            (proc1)
            proc1)
           (else
            (report-invalid-exp-value 'proc)))))
(define expval->null
  (lambda (value)
    (cases exp-val value
           (null-val
            ()
            '())
           (else
            (report-invalid-exp-value 'null)))))
(define expval->pair
  (lambda (value)
    (cases exp-val value
           (pair-val
            (val1 val2)
            (cons
             (cases exp-val val1
                    (num-val (num) num)
                    (bool-val (bool) bool)
                    (null-val () '())
                    (proc-val (proc1) proc1)
                    (pair-val (val3 val4) (expval->pair val1)))
             (cases exp-val val2
                    (num-val (num) num)
                    (bool-val (bool) bool)
                    (null-val () '())
                    (proc-val (proc1) proc1)
                    (pair-val (val3 val4) (expval->pair val2)))))
           (else
            (report-invalid-exp-value 'pair)))))
;; expval->schemeval : ExpVal -> SchemeVal
(define expval->schemeval
  (lambda (v)
    (cases exp-val v
           (num-val
            (num)
            num)
           (bool-val
            (bool)
            bool)
           (null-val
            ()
            (eopl:pretty-print '()))
           (pair-val
            (val1 val2)
            (expval->pair v))
           (proc-val
            (p)
            (cases proc p
                   (procedure
                    (var saved-env body)
                    `(λ (,var) ...)))))))
(define report-invalid-exp-value
  (lambda (type)
    (eopl:error
     'exp-val
     "Not a valid exp value of type ~s" type)))

;;; ---------------------- Syntax for the CPS-IN language ----------------------
;;; Program     ::= Expression
;;;                 a-program (exp1)
;;; Expression  ::= Number
;;;                 const-exp (num)
;;; Expression  ::= Identifier
;;;                 var-exp (var)
;;; Expression  ::= emptylist
;;;                 emptylist-exp ()
;;; Expression  ::= cons(Expression , Expression)
;;;                 cons-exp (exp1 exp2)
;;; Expression  ::= car (Expression)
;;;                 car-exp (exp1)
;;; Expression  ::= cdr (Expression)
;;;                 cdr-exp (exp1)
;;; Expression  ::= list ({Expression}{,}*)
;;;                 list-exp (exps)
;;; Expression  ::= null? (Expression)
;;;                 null?-exp (exp1)
;;; Expression  ::= add1 (Expression)
;;;                 add1-exp (exp1)
;;; Expression  ::= - (Expression, Expression)
;;;                 diff-exp (exp1, exp2)
;;; Expression  ::= * (Expression, Expression)
;;;                 mul-exp (exp1, exp2)
;;; Expression  ::= greater? (Expression, Expression)
;;;                 greater?-exp (exp1, exp2)
;;; Expression  ::= less? (Expression, Expression)
;;;                 less?-exp (exp1, exp2)
;;; Expression  ::= equal? (Expression, Expression)
;;;                 equal?-exp (exp1, exp2)
;;; Expression  ::= zero? (Expression)
;;;                 zero?-exp (exp1)
;;; Expression  ::= number? (Expression)
;;;                 number?-exp (exp1)
;;; Expression  ::= Expression
;;;                simple-exp->exp (simple-exp1)
;;; Expression  ::= if Expression then Expression else Expression
;;;                 if-exp (exp1 exp2 exp3)
;;; Expression  ::= let {Identifier = Expression}* in Expression
;;;                 let-exp (vars exps body)
;;; Expression  ::= letrec {Identifier (Identifier*,) = Expression}* in Expression
;;;                 letrec-exp (p-names b-vars p-bodies body)
;;; Expression  ::= (Expression Expression*)
;;;                 call-exp (rator rands)
;;; Parse Expression
(define let-scanner-spec
  '((white-sp (whitespace) skip)
    (identifier (letter (arbno (or letter digit "_" "-" "?"))) symbol)
    (number ((or (concat digit (arbno digit))
                 (concat "-" digit (arbno digit))
                 (concat (arbno digit) "." digit (arbno digit))
                 (concat "-" (arbno digit) "." digit (arbno digit))
                 (concat digit (arbno digit) "." (arbno digit))
                 (concat "-" digit (arbno digit) "." (arbno digit)))) number)
    (comment ("%" (arbno (not #\newline))) skip)))
(define let-grammar
  '((program (expression) a-program)
    (expression (number)
                const-exp)
    (expression (identifier)
                var-exp)
    (expression ("proc" "(" (separated-list identifier ",") ")" expression)
                proc-exp)
    (expression ("emptylist")
                emptylist-exp)
    (expression ("cons" "(" expression "," expression ")")
                cons-exp)
    (expression ("car" "(" expression ")")
                car-exp)
    (expression ("cdr" "(" expression ")")
                cdr-exp)
    (expression ("list" "(" (separated-list expression ",") ")")
                list-exp)
    (expression ("null?" "(" expression ")")
                null?-exp)
    (expression ("add1" "(" expression ")")
                add1-exp)
    (expression ("-" "(" expression "," expression ")")
                diff-exp)
    (expression ("*" "(" expression "," expression ")")
                mul-exp)
    (expression ("zero?" "(" expression ")")
                zero?-exp)
    (expression ("equal?" "(" expression "," expression ")")
                equal?-exp)
    (expression ("greater?" "(" expression "," expression ")")
                greater?-exp)
    (expression ("less?" "(" expression "," expression ")")
                less?-exp)
    (expression ("number?" "(" expression ")")
                number?-exp)
    (expression ("if" expression "then" expression "else" expression)
                if-exp)
    (expression ("let" (arbno identifier "=" expression) "in" expression)
                let-exp)
    (expression ("letrec" (arbno identifier "(" (separated-list identifier ",") ")" "=" expression) "in" expression)
                letrec-exp)
    (expression ("(" expression (arbno expression) ")")
                call-exp)))

;;; ---------------------- Evaluate OUT expression ----------------------
;;; tail-form-operand? : Exp -> Bool
(define tail-form-operand?
  (lambda (exp)
    (cases expression exp
           (const-exp
            (num)
            #t)
           (var-exp
            (var)
            #t)
           (proc-exp
            (vars body)
            #t)
           (emptylist-exp
            ()
            #t)
           (car-exp
            (exp1)
            (tail-form-operand? exp1))
           (cdr-exp
            (exp1)
            (tail-form-operand? exp1))
           (cons-exp
            (exp1 exp2)
            (and (tail-form-operand? exp1)
                 (tail-form-operand? exp2)))
           (list-exp
            (exps)
            ((list-of tail-form-operand?) exps))
           (null?-exp
            (exp1)
            (tail-form-operand? exp1))
           (add1-exp
            (exp1)
            (tail-form-operand? exp1))
           (diff-exp
            (exp1 exp2)
            (and (tail-form-operand? exp1)
                 (tail-form-operand? exp2)))
           (mul-exp
            (exp1 exp2)
            (and (tail-form-operand? exp1)
                 (tail-form-operand? exp2)))
           (equal?-exp
            (exp1 exp2)
            (and (tail-form-operand? exp1)
                 (tail-form-operand? exp2)))
           (greater?-exp
            (exp1 exp2)
            (and (tail-form-operand? exp1)
                 (tail-form-operand? exp2)))
           (less?-exp
            (exp1 exp2)
            (and (tail-form-operand? exp1)
                 (tail-form-operand? exp2)))
           (zero?-exp
            (exp1)
            (tail-form-operand? exp1))
           (number?-exp
            (exp1)
            (tail-form-operand? exp1))
           (else #f))))
(define tail-form-exp?
  (lambda (exp)
    (cases expression exp
           (if-exp
            (exp1 exp2 exp3)
            (and (tail-form-operand? exp1)
                 (tail-form-exp? exp2)
                 (tail-form-exp? exp3)))
           (let-exp
            (vars exps body)
            (and ((list-of tail-form-operand?) exps)
                 (tail-form-exp? body)))
           (letrec-exp
            (p-names p-vars p-bodies letrec-body)
            ((list-of tail-form-exp?) (cons letrec-body p-bodies)))
           (call-exp
            (rator rands)
            ((list-of tail-form-operand?) (cons rator rands)))
           (else
            (tail-form-operand? exp)))))
;;; tail-form? : Program -> Bool
(define tail-form?
  (lambda (prog)
    (cases program prog
           (a-program
            (exp)
            (tail-form-exp? exp)))))

;;; ---------------------- Sllgen operations ----------------------
(sllgen:make-define-datatypes let-scanner-spec let-grammar)
(define list-the-datatypes
  (lambda ()
    (sllgen:list-define-datatypes let-scanner-spec let-grammar)))
(define just-scan
  (sllgen:make-string-scanner let-scanner-spec let-grammar))
(define scan&parse
  (sllgen:make-string-parser let-scanner-spec let-grammar))
(define read-eval-print
  (sllgen:make-rep-loop
   "--> "
   tail-form?
   (sllgen:make-stream-parser let-scanner-spec let-grammar)))
(define run
  (lambda (exp)
    (tail-form? (scan&parse exp))))

(provide run)
