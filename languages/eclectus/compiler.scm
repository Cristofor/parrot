; $Id$

; Generate driver and PAST for Eclectus

;; Helpers that emit PIR

; unique ids for registers
(define counter 1000)
(define (gen-unique-id)
  (set! counter (+ 1 counter))
  counter)

; Emit PIR that loads libs
(define emit-init
  (lambda ()
    (emit "
          # PIR generated by compiler.scm
          
          # The dynamics PMCs used by Eclectus are loaded
          .loadlib 'eclectus_group'
          
          # for devel
          .include 'library/dumper.pir'
          
          .namespace
          
          .sub '__onload' :init
              load_bytecode 'PGE.pbc'
              load_bytecode 'PGE/Text.pbc'
              load_bytecode 'PGE/Util.pbc'
              load_bytecode 'PGE/Dumper.pbc'
              load_bytecode 'PCT.pbc'
          .end
          " )))

; Emit PIR that prints the value returned by scheme_entry()
(define emit-driver
  (lambda ()
    (emit "
          .sub drive :main
          
              .local pmc val_ret
              ( val_ret ) = scheme_entry()
              # _dumper( val_ret, 'val_ret' )
          
              .local pmc op_say
              op_say = new 'PAST::Op'
              op_say.init( val_ret, 'name' => 'say', 'pasttype' => 'call' )
          
              .local pmc stmts
              stmts = new 'PAST::Stmts'
              stmts.'init'( op_say, 'name' => 'stmts' )
          
              # compile and evaluate
              .local pmc past_compiler
              past_compiler = new [ 'PCT::HLLCompiler' ]
              $P0 = split ' ', 'post pir evalpmc'
              past_compiler.'stages'( $P0 )
              past_compiler.'eval'(stmts)
          
          .end
          ")))

; emit the PIR library
(define emit-builtins
  (lambda ()
    (emit "
          .sub 'say'
              .param pmc args :slurpy
              if null args goto end
              .local pmc iter
              iter = new 'Iterator', args
          loop:
              unless iter goto end
              $P0 = shift iter
              print $P0
              goto loop
          end:
              say ''
              .return ()
          .end
          
          .sub 'infix:<'
              .param num a
              .param num b
              $I0 = islt a, b

              .return ($I0)
          .end

          .sub 'infix:<='
              .param num a
              .param num b
              $I0 = isle a, b

              .return ($I0)
          .end

          .sub 'infix:=='
              .param pmc a
              .param pmc b
              $I0 = cmp_num a, b
              $I0 = iseq $I0, 0
          
              .return ($I0)
          .end

          .sub 'infix:>='
              .param num a
              .param num b
              $I0 = isge a, b

              .return ($I0)
          .end

          .sub 'infix:>'
              .param num a
              .param num b
              $I0 = isgt a, b

              .return ($I0)
          .end

          ")))

;; recognition of forms

; forms represented by a scalar PMC
(define immediate?
  (lambda (x)
    (or (fixnum? x)
      (boolean? x)
      (char? x)
      (and (list? x) (= (length x) 0)))))

(define variable?
  (lambda (x) 
    (and (atom? x)
         (or (eq? x 'var-a)
             (eq? x 'var-b)))))

(define make-combination-predicate
  (lambda (name)
    (lambda (form)
      (and (pair? form)
           (eq? name (car form))))))

(define if?
  (make-combination-predicate 'if))

(define let?
  (make-combination-predicate 'let))


(define if-test
  (lambda (form)
    (car (cdr form))))

(define if-conseq
  (lambda (form)
    (car (cdr (cdr form)))))

(define if-altern
  (lambda (form)
    (car (cdr (cdr (cdr form))))))

; Support for primitive functions

; is x a primitive?
(define primitive?
  (lambda (x)
    (and (symbol? x) (getprop x '*is-prim*))))

; is x a call to a primitive? 
(define primcall?
  (lambda (x)
    (and (pair? x) (primitive? (car x)))))

; a primitive function is a symbol with the properties
; *is-prim*, *arg-count* and *emitter*
; implementatus of primitive functions are added
; with 'define-primitive'
(define-syntax define-primitive
  (syntax-rules ()
    [(_ (prim-name uid arg* ...) b b* ...)
     (begin
        (putprop 'prim-name '*is-prim*
          #t)
        (putprop 'prim-name '*arg-count*
          (length '(arg* ...)))
        (putprop 'prim-name '*emitter*
          (lambda (uid arg* ...) b b* ...)))]))

; implementation of fxadd1
(define-primitive (fxadd1 uid arg)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pirop "n_add")))
    (emit-expr arg)
    (emit-expr 1)))

; implementation of fx+
(define-primitive (fx+ uid arg1 arg2)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid 
    (quasiquote (@ (pirop "n_add")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of fxsub1
(define-primitive (fxsub1 uid arg)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pirop "n_sub")))
    (emit-expr arg)
    (emit-expr 1)))

; implementation of fx-
(define-primitive (fx- uid arg1 arg2)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pirop "n_sub")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of fxlogand
(define-primitive (fxlogand uid arg1 arg2)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pirop "n_band")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of fxlogor
(define-primitive (fxlogor uid arg1 arg2)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pirop "n_bor")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of char->fixnum
(define-primitive (char->fixnum uid arg)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "inline")
                   (inline "new %r, 'EclectusFixnum'\\nassign %r, %0\\n")))
    (emit-expr arg)))

; implementation of fixnum->char
(define-primitive (fixnum->char uid arg)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "inline")
                   (inline "new %r, 'EclectusCharacter'\\nassign %r, %0\\n")))
    (emit-expr arg)))

; implementation of char<
(define-primitive (char< uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:<")))
      (emit-expr arg1)
      (emit-expr arg2)) 
    (list "val_true")
    (list "val_false")))

; implementation of char<=
(define-primitive (char<= uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:<=")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of char=
(define-primitive (char= uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:==")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of char>
(define-primitive (char> uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:>")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of char>=
(define-primitive (char>= uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:>=")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of fxzero?
(define-primitive (fxzero? uid arg)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:==")))
      (emit-expr arg)
      (emit-expr 0))
    (list "val_true")
    (list "val_false")))

; implementation of fx<
(define-primitive (fx< uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:<")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of fx<=
(define-primitive (fx<= uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:<=")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of fx=
(define-primitive (fx= uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:==")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of fx>=
(define-primitive (fx>= uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:>=")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of fx>
(define-primitive (fx> uid arg1 arg2)
  (emit "
        .local pmc reg_cmp_~a
        reg_cmp_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "cmp_~a" uid)
      (quasiquote (@ (pasttype "chain") (name "infix:>")))
      (emit-expr arg1)
      (emit-expr arg2))
    (list "val_true")
    (list "val_false")))

; implementation of null?
(define-primitive (null? uid arg)
  (emit "
        .local pmc reg_inline_~a
        reg_inline_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "inline_~a" uid)
      (quasiquote (@ (pasttype "inline")
                     (inline "new %r, 'EclectusBoolean'\\nisa $I1, %0, 'EclectusEmptyList'\\n %r = $I1")))
      (emit-expr arg))
    (list "val_true")
    (list "val_false")))

; implementation of fixnum?
(define-primitive (fixnum? uid arg)
  (emit "
        .local pmc reg_inline_~a
        reg_inline_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "inline_~a" uid)
      (quasiquote (@ (pasttype "inline")
                     (inline "new %r, 'EclectusBoolean'\\nisa $I1, %0, 'EclectusFixnum'\\n %r = $I1")))
      (emit-expr arg))
    (list "val_true")
    (list "val_false")))

; implementation of boolean?
(define-primitive (boolean? uid arg)
  (emit "
        .local pmc reg_inline_~a
        reg_inline_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "inline_~a" uid)
      (quasiquote (@ (pasttype "inline")
                     (inline "new %r, 'EclectusBoolean'\\nisa $I1, %0, 'EclectusBoolean'\\n %r = $I1")))
          (emit-expr arg))
    (list "val_true")
    (list "val_false")))

; implementation of char?
(define-primitive (char? uid arg)
  (emit "
        .local pmc reg_inline_~a
        reg_inline_~a = new 'PAST::Op'
        " uid uid)
  (emit "
        .local pmc reg_~a
        reg_~a = new 'PAST::Op'
        " uid uid)
  (list
    uid
    (quasiquote (@ (pasttype "if")))
    (list
      (format "inline_~a" uid)
      (quasiquote (@ (pasttype "inline")
                     (inline "new %r, 'EclectusBoolean'\\nisa $I1, %0, 'EclectusCharacter'\\n %r = $I1")))
      (emit-expr arg))
    (list "val_true")
    (list "val_false")))

; a getter of '*emitter*'
(define primitive-emitter
  (lambda (x)
    (getprop x '*emitter*)))

(define emit-function-header
  (lambda (function-name)
    (emit (string-append ".sub " function-name))
    (emit "    .local pmc reg_val_true, reg_val_false")
    (emit "    reg_val_true  = reg_~a" (car (emit-expr #t)))
    (emit "    reg_val_false = reg_~a" (car (emit-expr #f)))))

(define emit-function-footer
  (lambda (reg)
    (emit "
            .return( reg_~a )
          .end
          " reg)))

(define emit-primcall
  (lambda (x)
    (let ([prim (car x)] [args (cdr x)])
      (apply (primitive-emitter prim) (gen-unique-id) args))))

; emit PIR for a scalar
(define emit-immediate
  (lambda (x)
    (let ([uid (gen-unique-id)])
      (emit ".local pmc reg_~a" uid)
      (cond
        [(fixnum? x)
         (emit "
               reg_~a = new 'PAST::Val'
               reg_~a.init( 'value' => ~a, 'returns' => 'EclectusFixnum' )
               " uid uid x)
         (list uid)]
        [(char? x)
         (emit "
               reg_~a = new 'PAST::Val'
               reg_~a.init( 'value' => ~a, 'returns' => 'EclectusCharacter' )
               " uid uid (char->integer x) )
         (list uid)]
        [(and (list? x) (= (length x) 0 ))
         (emit "
               reg_~a = new 'PAST::Val'
               reg_~a.init( 'value' => 0, 'returns' => 'EclectusEmptyList' )
               " uid uid)
         (list uid)]
        [(boolean? x)
           (if x 
             (emit "
                   reg_~a = new 'PAST::Val'
                   reg_~a.init( 'value' => 1, 'returns' => 'EclectusBoolean' )
                   " uid uid)
             (emit "
                   reg_~a = new 'PAST::Val'
                   reg_~a.init( 'value' => 0, 'returns' => 'EclectusBoolean' )
                   " uid uid))
         (list uid)]
        [(string? x)
         (emit "
               reg_~a = new 'PAST::Val'
               reg_~a.init( 'value' => \"'~a'\", 'returns' => 'EclectusString' )
               " uid uid x)
         (list uid)])
        )))

(define bindings
  (lambda (x)
    (cadr x)))

(define body
  (lambda (x)
    (caddr x)))

(define emit-variable
  (lambda (x uid)
    (emit-expr 13)))

(define emit-let
  (lambda (binds body uid )
     (if (null? binds)
       (emit-expr body)
       (begin
         (emit "
               .local pmc reg_let_var_~a
               reg_let_var_~a = new 'PAST::Var'
               reg_let_var_~a.init( 'name' => '~a', 'scope' => 'lexical', 'viviself' => 'Undef', 'isdecl' => 1 )

               .local pmc reg_let_copy_~a 
               reg_let_copy_~a = new 'PAST::Op'
               " uid uid uid (caar binds) uid uid )
         (emit "
               .local pmc reg_~a
               reg_~a = new 'PAST::Stmts'
               " uid uid)
         (list
           uid
           (list
             (format "let_copy_~a" uid)
             (quasiquote (@ (pasttype "copy") (lvalue "1")))
             (list
               (format "let_var_~a" uid))
             (emit-expr (cadar binds)))
           (emit-expr body))))))

(define emit-if
  (lambda (x uid)
    (emit "
          .local pmc reg_~a
          reg_~a = new 'PAST::Op'
          " uid uid )
    (list
      uid
      (quasiquote (@ (pasttype "if")))
      (emit-expr (if-test x))
      (emit-expr (if-conseq x))
      (emit-expr (if-altern x)))))
 
; emir PIR for an expression
(define emit-expr
  (lambda (x)
    ;(display "# ")(write x) (newline)
    (cond
      [(immediate? x) (emit-immediate x)]
      [(variable? x)  (emit-variable x (gen-unique-id))]
      [(let? x)       (emit-let (bindings x) (body x) (gen-unique-id))]
      [(if? x)        (emit-if x (gen-unique-id))]
      [(primcall? x)  (emit-primcall x)]
    ))) 

; transverse the program and rewrite
; "and" can be supported by transformation before compiling
; So "and" is implemented if terms of "if"
;
; Currently a new S-expression is generated,
; as I don't know how to manipulate S-expressions while traversing it
(define transform-and-or
  (lambda (tree)
    (cond [(atom? tree)
           tree]
          [(eqv? (car tree) 'and) 
           ( cond [(null? (cdr tree)) #t]
                  [(= (length (cdr tree)) 1) (transform-and-or (cadr tree))]
                  [else (quasiquote
                          (if
                           (unquote (transform-and-or (cadr tree)))
                           (unquote (transform-and-or (quasiquote (and (unquote-splicing (cddr tree))))))
                           #f))])]
          [(eqv? (car tree) 'or) 
           ( cond [(null? (cdr tree)) #f]
                  [(= (length (cdr tree)) 1) (transform-and-or (cadr tree))]
                  [else (quasiquote
                          (if
                           (unquote (transform-and-or (cadr tree)))
                           (unquote (transform-and-or (cadr tree)))
                           (unquote (transform-and-or (quasiquote (or (unquote-splicing (cddr tree))))))))])]
          [(eqv? (car tree) 'not) 
           (quasiquote (if (unquote (transform-and-or (cadr tree))) #f #t))]
          [else
           (map transform-and-or tree)]))) 

; eventually this will become a PIR generator
; for PAST as SXML
; currently it only handles the pushes
(define past-sxml->past-pir
  (lambda (past)
    ;(write (list "emit-pushes1:" past))(newline)
    ;(write (list "emit-pushes2:" (cdr past)))(newline)
     (for-each
       (lambda (daughter)
         (if (eq? '@ (car daughter))
           (for-each
             (lambda (key_val)
               ;(write (list "emit-pushes3:" daughter (cadr daughter) (caadr daughter)(cadadr daughter)))(newline)
               (emit "
                     reg_~a.init( '~a' => \"~a\" )
                     " (car past) (car key_val) (cadr key_val)))
               (cdr daughter))
             (emit "
                   reg_~a.push( reg_~a )
                   " (car past) (past-sxml->past-pir daughter))))
       (cdr past))
     (car past)))

; the actual compiler
(define compile-program
  (lambda (program)
    (emit-init)
    (emit-driver)
    (emit-builtins)
    (emit-function-header "scheme_entry")
    (emit-function-footer
      (past-sxml->past-pir
        (emit-expr
          (transform-and-or program))))))
