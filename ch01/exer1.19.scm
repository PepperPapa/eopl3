#lang eopl
;;; list-set : list x n x x -> list
;;;
;;; usage: return a list with nth-element in lst replaced by x
(define list-set
  (lambda (lst n x)
    (if (null? lst)
        '()
        (if (eq? n 0)
            (cons x (cdr lst))
            (cons (car lst)
                  (list-set (cdr lst) (- n 1) x))))))

(equal? (list-set '(a b c d) 2 '(1 2))
        '(a b (1 2) d))
(equal? (list-ref (list-set '(a b c d) 3 '(1 5 10)) 3)
        '(1 5 10))
