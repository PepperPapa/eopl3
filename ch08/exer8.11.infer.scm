#lang eopl
(require "exer8.11.lang.scm")
(provide checked-type-of type-of type-of-program type-of-exp)

;;; ---------------------- Type Environment ----------------------
(define-datatype tenv tenv?
  (empty-tenv)
  (extend-tenv
   (saved-var identifier?)
   (saved-type type?)
   (saved-tenv tenv?))
  (extend-tenv-with-module
   (name identifier?)
   (interface interface?)
   (saved-env tenv?)))

;;; init-tenv : () -> Type
(define init-tenv
  (lambda ()
    (empty-tenv)))

(define apply-tenv
  (lambda (env var)
    (cases tenv env
           (empty-tenv
            ()
            (report-no-binding-type-found var))
           (extend-tenv
            (saved-var saved-type saved-tenv)
            (if (eq? var saved-var)
                saved-type
                (apply-tenv saved-tenv var)))
           (extend-tenv-with-module
            (m-name iface saved-tenv)
            (if (eq? var m-name)
                iface
                (apply-tenv saved-tenv var))))))

;;; lookup-qualified-var-in-tenv : Sym x Sym x Env -> Type
(define lookup-qualified-var-in-tenv
  (lambda (m-name var-name env)
    (let ((iface (lookup-module-name-in-tenv env m-name)))
      (cases interface iface
             (simple-iface
              (val-decls)
              (lookup-variable-name-in-decls var-name val-decls))))))

;;; lookup-variable-name-in-decls : Sym x Listof(Decl) -> Type
(define lookup-variable-name-in-decls
  (lambda (var-name var-decls)
    (cond [(null? var-decls) (report-no-binding-type-found var-name)]
          [else
           (cases declaration (car var-decls)
                  (val-decl
                   (saved-var saved-type)
                   (if (eq? var-name saved-var)
                       (optype->type saved-type)
                       (lookup-variable-name-in-decls
                        var-name
                        (cdr var-decls)))))])))

(define lookup-module-name-in-tenv
  (lambda (env m-name)
    (let ((ty (apply-tenv env m-name)))
      (if (interface? ty)
          ty
          (report-no-binding-type-module-found m-name)))))

(define report-no-binding-type-found
  (lambda (search-var)
    (eopl:error 'apply-tenv "No binding for ~s" search-var)))

(define report-no-binding-type-module-found
  (lambda (search-var)
    (eopl:error 'apply-tenv "No binding module for ~s" search-var)))

;;; ---------------------- Substitution ----------------------
;;; apply-one-subst : Type x Tvar x Type -> Type
(define apply-one-subst
  (lambda (ty0 tvar ty1)
    (cases type ty0
           (int-type () ty0)
           (bool-type () ty0)
           (proc-type
            (tv tb)
            (proc-type
             (apply-one-subst tv tvar ty1)
             (apply-one-subst tb tvar ty1)))
           (tvar-type
            (sn)
            (if (equal? ty0 tvar) ty1 ty0)))))

;;; apply-subst-to-type : Type x Subst -> Type
(define apply-subst-to-type
  (lambda (ty subst)
    (cases type ty
           (int-type () (int-type))
           (bool-type () (bool-type))
           (proc-type
            (t1 t2)
            (proc-type
             (apply-subst-to-type t1 subst)
             (apply-subst-to-type t2 subst)))
           (tvar-type
            (sn)
            (let ((tmp (assoc ty subst)))
              (if tmp
                  (cdr tmp)
                  ty))))))

;;; emtpty-subst : () -> Subst
(define substitution?
  (list-of
   (lambda (t)
     (if (pair? t)
         (and
          (tvar-type? (car t))
          (type? (cdr t)))
         #f))))

;;; emtpty-subst : () -> Subst
(define empty-subst
  (lambda () '()))

;;; extend-subst : Subst x Tvar x Type -> Subst
(define extend-subst
  (lambda (subst tvar ty)
    (cons (cons tvar ty)
          (map (lambda (p)
                 (let ((oldlhs (car p))
                       (oldrhs (cdr p)))
                   (cons oldlhs
                         (apply-one-subst oldrhs tvar ty))))
               subst))))

;;; ---------------------- Unifier ----------------------
;;; unifier : Type x Type x Subst x Exp -> Subst
(define unifier
  (lambda (ty1 ty2 subst exp)
    (let ((ty1 (apply-subst-to-type ty1 subst))
          (ty2 (apply-subst-to-type ty2 subst)))
      (cond [(equal? ty1 ty2) subst]
            [(tvar-type? ty1)
             (if (no-occurrence? ty1 ty2)
                 (extend-subst subst ty1 ty2)
                 (report-no-occurrence-violation ty1 ty2 exp))]
            [(tvar-type? ty2)
             (if (no-occurrence? ty2 ty1)
                 (extend-subst subst ty2 ty1)
                 (report-no-occurrence-violation ty2 ty1 exp))]
            [(and (proc-type? ty1) (proc-type? ty2))
             (let ((subst (unifier (proc-type->arg-type ty1)
                                   (proc-type->arg-type ty2)
                                   subst exp)))
               (let ((subst (unifier (proc-type->result-type ty1)
                                     (proc-type->result-type ty2)
                                     subst exp)))
                 subst))]
            [else (report-unification-failure ty1 ty2 exp)]))))

;;; no-occurrence? : Type x Type -> Bool
(define no-occurrence?
  (lambda (ty1 ty2)
    (cases type ty2
           (int-type () #t)
           (bool-type () #t)
           (proc-type
            (t1 t2)
            (and (no-occurrence? ty1 t1)
                 (no-occurrence? ty1 t2)))
           (tvar-type
            (sn)
            (not (equal? ty1 ty2))))))

;;; tvar-type? : Type -> Bool
(define tvar-type?
  (lambda (ty)
    (cases type ty
           (tvar-type (sn) #t)
           (else #f))))

;;; proc-type? : Type -> Bool
(define proc-type?
  (lambda (ty)
    (cases type ty
           (proc-type (t1 t2) #t)
           (else #f))))

;;; proc-type->arg-type : Type -> Type
(define proc-type->arg-type
  (lambda (ty)
    (cases type ty
           (proc-type (t1 t2) t1)
           (else #f))))

;;; proc-type->result-type : Type -> Type
(define proc-type->result-type
  (lambda (ty)
    (cases type ty
           (proc-type (t1 t2) t2)
           (else #f))))

(define report-unification-failure
  (lambda (ty1 ty2 exp)
    (eopl:error 'unification-failure
                "Type mismatch: ~s doesn't match ~s in ~s~%"
                (type-to-external-form ty1)
                (type-to-external-form ty2)
                exp)))

(define report-no-occurrence-violation
  (lambda (ty1 ty2 exp)
    (eopl:error 'check-no-occurence!
                "Can't unify: type variable ~s occurs in type ~s in expression ~s~%"
                (type-to-external-form ty1)
                (type-to-external-form ty2)
                exp)))

;;; ---------------------- Type Infer ----------------------
;;; optype->type : OptinalType -> Type
(define optype->type
  (lambda (otype)
    (cases optional-type otype
           (no-type () (fresh-tvar-type))
           (a-type (ty) ty))))

;;; fresh-tvar-type : () -> Type
(define serial-number 0)
(define fresh-tvar-type
  (lambda ()
    (set! serial-number (+ serial-number 1))
    (tvar-type serial-number)))

;;; check-equal-type! : Type x Type x Expression -> Unspecified
(define check-equal-type!
  (lambda (ty1 ty2 exp)
    (when (not (equal? ty1 ty2))
      (report-unequal-types ty1 ty2 exp))))
;;; report-unequal-types : Type x Type x Expression -> Unspecified
(define report-unequal-types
  (lambda (ty1 ty2 exp)
    (eopl:error 'check-equal-type!
                "Types didn't match: ~s != ~s in ~%~a"
                (type-to-external-form ty1)
                (type-to-external-form ty2)
                exp)))
(define type-to-external-form
  (lambda (ty)
    (cases type ty
           (int-type () 'int)
           (bool-type () 'bool)
           (proc-type (arg-type result-type)
                      (list (type-to-external-form arg-type)
                            '->
                            (type-to-external-form result-type)))
           (tvar-type (sn)
                      (string->symbol
                       (string-append
                        "ty"
                        (number->string sn)))))))

;;; ---------------------- Type Equation ----------------------
;;; Equation = Type x Type x Exp
(define-datatype equation equation?
  (an-equation
   (lhs type?)
   (rhs type?)
   (exp expression?)))

;;; equations-of-exp : Exp x Tvar x Tenv -> Listof(Equation)
(define equations-of-exp
  (lambda (exp tvar tenv)
    (cases expression exp
           (const-exp
            (num)
            (list (an-equation tvar (int-type) exp)))
           (zero?-exp
            (exp1)
            (let ((tvar1 (fresh-tvar-type)))
              (append
               (list
                (an-equation tvar (bool-type) exp)
                (an-equation tvar1 (int-type) exp))
               (equations-of-exp exp1 tvar1 tenv))))
           (diff-exp
            (exp1 exp2)
            (let ((tvar1 (fresh-tvar-type))
                  (tvar2 (fresh-tvar-type)))
              (append
               (list
                (an-equation tvar (int-type) exp)
                (an-equation tvar1 (int-type) exp)
                (an-equation tvar2 (int-type) exp))
               (equations-of-exp exp1 tvar1 tenv)
               (equations-of-exp exp2 tvar2 tenv))))
           (if-exp
            (exp1 exp2 exp3)
            (let ((tvar1 (fresh-tvar-type))
                  (tvar2 (fresh-tvar-type))
                  (tvar3 (fresh-tvar-type)))
              (append
               (list
                (an-equation tvar1 (bool-type) exp)
                (an-equation tvar tvar2 exp)
                (an-equation tvar tvar3 exp))
               (equations-of-exp exp1 tvar1 tenv)
               (equations-of-exp exp2 tvar2 tenv)
               (equations-of-exp exp3 tvar3 tenv))))
           (var-exp
            (var)
            (list (an-equation tvar (apply-tenv tenv var) exp)))
           (qualified-var-exp
            (m-name var-name)
            (list (an-equation tvar (lookup-qualified-var-in-tenv m-name var-name tenv) exp)))
           (let-exp
            (b-var b-exp let-body)
            (let ((tvar-bvar (fresh-tvar-type))
                  (tvar-bexp (fresh-tvar-type))
                  (tvar-body (fresh-tvar-type)))
              (append
               (list
                (an-equation tvar tvar-body exp)
                (an-equation tvar-bvar tvar-bexp exp))
               (equations-of-exp b-exp tvar-bexp tenv)
               (equations-of-exp let-body tvar-body (extend-tenv b-var tvar-bvar tenv)))))
           (proc-exp
            (var opty body)
            (let ((arg-type (optype->type opty))
                  (result-type (fresh-tvar-type)))
              (append
               (list
                (an-equation tvar (proc-type arg-type result-type) exp))
               (equations-of-exp body result-type (extend-tenv var arg-type tenv)))))
           (letrec-exp
            (result-otype p-name b-var arg-otype b-body letrec-body)
            (let ((result-type (optype->type result-otype))
                  (arg-type (optype->type arg-otype))
                  (letrec-body-type (fresh-tvar-type)))
              (let ((tenv-for-letrec-body
                     (extend-tenv p-name
                                  (proc-type arg-type result-type)
                                  tenv)))
                (append
                 (list
                  (an-equation tvar letrec-body-type exp))
                 (equations-of-exp b-body result-type
                                   (extend-tenv b-var arg-type tenv-for-letrec-body))
                 (equations-of-exp letrec-body letrec-body-type tenv-for-letrec-body)))))
           (call-exp
            (rator rand)
            (let ((rator-type (fresh-tvar-type))
                  (result-type (fresh-tvar-type)))
              (append
               (list
                (an-equation rator-type (proc-type result-type tvar) exp))
               (equations-of-exp rator rator-type tenv)
               (equations-of-exp rand result-type tenv))))
           )))

;;; add-module-defns-to-tenv : Listof(ModuleDefn) x TypeEnv -> TypeEnv
(define add-module-defns-to-tenv
  (lambda (m-defns env)
    (if (null? m-defns)
        env
        (cases module-defn (car m-defns)
               (a-module-definition
                (m-name expected-iface m-body)
                (let ((actual-iface (interface-of m-body env)))
                  (if (<:-iface actual-iface expected-iface env)
                      (let ((new-tenv
                             (extend-tenv-with-module
                              m-name
                              expected-iface
                              env)))
                        (add-module-defns-to-tenv (cdr m-defns) new-tenv))
                      (report-module-doesnt-satisfy-iface
                       m-name expected-iface actual-iface))))))))

;;; interface-of : ModuleBody x TypeEnv -> Intreface
(define interface-of
  (lambda (m-body env)
    (cases module-body m-body
           (defns-module-body
             (defns)
             (let ((info (defns-to-equations defns env)))
               (let ((subst (type-of-exp (car info) (empty-subst))))
                 (simple-iface (type-of-defns defns subst (cdr info)))))))))

;;; defns-to-equations : Listof(Defn) × TypeEnv → (Listof(Equation) . TypeEnv)
(define defns-to-equations
  (lambda (defns env)
    (let loop ((defns defns)
               (env env)
               (equas '()))
      (if (null? defns)
          (cons equas env)
          (cases definition (car defns)
                 (val-defn
                  (var exp)
                  (let ((tvar (fresh-tvar-type)))
                    (let ((new-equas (equations-of-exp exp tvar env)))
                      (loop
                       (cdr defns)
                       (extend-tenv var tvar env)
                       (append equas new-equas))))))))))

;;; type-of-module : Listof(Defn) x Subst x TypeEnv -> Listof(Decl)
(define type-of-defns
  (lambda (defns subst tenv)
    (if (null? defns)
        '()
        (cases definition (car defns)
               (val-defn
                (var exp)
                (let ((tvar (apply-tenv tenv var)))
                  (let ((ty (apply-subst-to-type tvar subst)))
                    (cons
                     (val-decl var (a-type ty))
                     (type-of-defns (cdr defns) subst tenv)))))))))

;;; <:-iface : Interface x Interface x TypeEnv -> Bool
(define <:-iface
  (lambda (iface1 iface2 tenv)
    (cases interface iface1
           (simple-iface
            (decls1)
            (cases interface iface2
                   (simple-iface
                    (decls2)
                    (<:-decls decls1 decls2 tenv)))))))

;;; <:-iface : Listof(Decl) x Listof(Decl) x TypeEnv -> Bool
(define <:-decls
  (lambda (decls1 decls2 tenv)
    (cond [(null? decls2) #t]
          [(null? decls1) #f]
          [else
           (let ((name1 (decl->name (car decls1)))
                 (name2 (decl->name (car decls2))))
             (if (eqv? name1 name2)
                 (and
                  (equal?
                   (decl->type (car decls1))
                   (decl->type (car decls2)))
                  (<:-decls (cdr decls1) (cdr decls2) tenv))
                 (<:-decls (cdr decls1) decls2 tenv)))])))

(define decl->name
  (lambda (decl)
    (cases declaration decl
           (val-decl
            (var-name var-type)
            var-name))))

(define decl->type
  (lambda (decl)
    (cases declaration decl
           (val-decl
            (var-name var-type)
            (optype->type var-type)))))

(define report-module-doesnt-satisfy-iface
  (lambda (m-name exptected-iface actual-iface)
    (eopl:error
     'add-module-defns-to-tenv
     "Module does not satisfy interface: ~s"
     (list 'error-in-defn-of-module: m-name
           'expected-type: exptected-iface
           'actual-type: actual-iface))))

(define type-of-program
  (lambda (prgm)
    (cases program prgm
           (a-program
            (m-defns exp)
            (set! serial-number 0)
            (let ((tvar (fresh-tvar-type))
                  (tenv (add-module-defns-to-tenv m-defns (empty-tenv))))
              (let ((equas (equations-of-exp exp tvar tenv)))
                (let ((subst (type-of-exp equas (empty-subst))))
                  (apply-subst-to-type tvar subst))))))))

;;; type-of-exp : Listof(Equation) x Subst -> Subst
(define type-of-exp
  (lambda (equas subst)
    (if (null? equas)
        subst
        (cases equation (car equas)
               (an-equation
                (lhs rhs exp)
                (let ((subst (unifier lhs rhs subst exp)))
                  (type-of-exp (cdr equas) subst)))))))

(define report-rator-not-a-proc-type
  (lambda (ty1 exp)
    (eopl:error 'type-of-exp
                "Expect a procedure, actual ~a: ~a"
                (type-to-external-form ty1)
                exp)))

(define type-of
  (lambda (prgm)
    (type-to-external-form (type-of-program prgm))))

;;; checked-type-of : String -> Type | String (for exception)
(require (only-in racket/base with-handlers exn:fail?))
(define checked-type-of
  (lambda (prgm)
    (with-handlers
        [(exn:fail? (lambda (en) 'error))]
      (type-of prgm))))
