#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "proc.h"
#include "proc_parser.h"
#include "proc_scanner.h"

typedef struct ast_const_s {
    exp_type type;
    int num;
} ast_const_s, *ast_const_t;

typedef struct ast_var_s {
    exp_type type;
    symbol_t var;
} ast_var_s, *ast_var_t;

typedef struct ast_proc_s {
    exp_type type;
    symbol_t var;
    ast_node_t body;
} ast_proc_s, *ast_proc_t;

typedef struct ast_letrec_s {
    exp_type type;
    symbol_t p_name;
    symbol_t p_var;
    ast_node_t p_body;
    ast_node_t letrec_body;
} ast_letrec_s, *ast_letrec_t;

typedef struct ast_zero_s {
    exp_type type;
    ast_node_t exp1;
} ast_zero_s, *ast_zero_t;

typedef struct ast_if_s {
    exp_type type;
    ast_node_t cond;
    ast_node_t exp1;
    ast_node_t exp2;
} ast_if_s, *ast_if_t;

typedef struct ast_let_s {
    exp_type type;
    symbol_t id;
    ast_node_t exp1;
    ast_node_t exp2;
} ast_let_s, *ast_let_t;

typedef struct ast_diff_s {
    exp_type type;
    ast_node_t exp1;
    ast_node_t exp2;
} ast_diff_s, *ast_diff_t;

typedef struct ast_call_s {
    exp_type type;
    ast_node_t rator;
    ast_node_t rand;
} ast_call_s, *ast_call_t;

typedef struct proc_s {
    symbol_t id;
    ast_node_t body;
    env_t env;
} proc_s;

typedef struct exp_val_s {
    EXP_VAL type;
    union {
        boolean_t bv;
        int iv;
        proc_t pv;
    } val;
} exp_val_s;

typedef struct env_s {
    ENV_TYPE type;
} env_s;

typedef struct extend_env_s {
    ENV_TYPE type;
    symbol_t var;
    exp_val_t val;
    env_t env;
} extend_env_s, *extend_env_t;

typedef struct extend_rec_env_s {
    ENV_TYPE type;
    symbol_t p_name;
    symbol_t p_var;
    ast_node_t p_body;
    exp_val_t proc_val;
    env_t env;
} extend_rec_env_s, *extend_rec_env_t;

typedef struct continuation_s {
    CONT_TYPE type;
} continuation_s, *continuation_t;

typedef struct zero1_cont_s {
    CONT_TYPE type;
    continuation_t cont;
} zero1_cont_s, *zero1_cont_t;

typedef struct let_cont_s {
    CONT_TYPE type;
    symbol_t var;
    ast_node_t body;
    env_t *env;
    continuation_t cont;
} let_cont_s, *let_cont_t;

typedef struct if_test_cont_s {
    CONT_TYPE type;
    ast_node_t exp2;
    ast_node_t exp3;
    env_t *env;
    continuation_t cont;
} if_test_cont_s, *if_test_cont_t;

typedef struct diff1_cont_s {
    CONT_TYPE type;
    ast_node_t exp2;
    env_t *env;
    continuation_t cont;
} diff1_cont_s, *diff1_cont_t;

typedef struct diff2_cont_s {
    CONT_TYPE type;
    exp_val_t val;
    continuation_t cont;
} diff2_cont_s, *diff2_cont_t;

typedef struct rator_cont_s {
    CONT_TYPE type;
    ast_node_t exp;
    env_t *env;
    continuation_t cont;
} rator_cont_s, *rator_cont_t;

typedef struct rand_cont_s {
    CONT_TYPE type;
    exp_val_t val;
    continuation_t cont;
} rand_cont_s, *rand_cont_t;

typedef struct letrec_cont_s {
    CONT_TYPE type;
    env_t *env;
    continuation_t cont;
} letrec_cont_s, *letrec_cont_t;

typedef struct let2_cont_s {
    CONT_TYPE type;
    env_t *env;
    continuation_t cont;
} let2_cont_s, *let2_cont_t;

typedef struct apply_proc_cont_s {
    CONT_TYPE type;
    exp_val_t rator;
    exp_val_t rand;
    continuation_t cont;
} apply_proc_cont_s, *apply_proc_cont_t;

typedef struct apply_proc2_cont_s {
    CONT_TYPE type;
    env_t *env;
    continuation_t cont;
} apply_proc2_cont_s, *apply_proc2_cont_t;

void const_node_free(ast_const_t exp);
void var_node_free(ast_var_t exp);
void proc_node_free(ast_proc_t exp);
void letrec_node_free(ast_letrec_t exp);
void zero_node_free(ast_zero_t exp);
void if_node_free(ast_if_t exp);
void let_node_free(ast_let_t exp);
void diff_node_free(ast_diff_t exp);
void call_node_free(ast_call_t exp);
void report_ast_malloc_fail(const char* node_name);
void report_exp_val_malloc_fail(const char *val_type);
void report_invalid_exp_val(const char *val_type);
void report_no_binding_found(symbol_t search_var);
void report_invalid_env(env_t env);

symbol_t symbol_new(const char* name) {
    symbol_t s = malloc(sizeof(symbol_s));
    if (s) {
        s->name = malloc(strlen(name) + 1);
        if (s->name) {
            strcpy(s->name, name);
            return s;
        } else {
            free(s);
            report_ast_malloc_fail("symbol");
            exit(1);
        }
    } else {
        report_ast_malloc_fail("symbol");
        exit(1);
    }
}

ast_program_t new_ast_program(ast_node_t exp) {
    ast_program_t p = malloc(sizeof(ast_program_s));
    if (p) {
        p->exp = exp;
        return p;
    } else {
        report_ast_malloc_fail("program");
        exit(1);
    }
}

ast_node_t new_const_node(int num) {
    ast_const_t e = malloc(sizeof(ast_const_s));
    if (e) {
        e->type = CONST_EXP;
        e->num = num;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("const");
        exit(1);
    }
}

ast_node_t new_var_node(symbol_t id) {
    ast_var_t e = malloc(sizeof(ast_var_s));
    if (e) {
        e->type = VAR_EXP;
        e->var = id;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("var");
        exit(1);
    }
}

ast_node_t new_proc_node(symbol_t var, ast_node_t body) {
    ast_proc_t e = malloc(sizeof(ast_proc_s));
    if (e) {
        e->type = PROC_EXP;
        e->var = var;
        e->body = body;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("proc");
        exit(1);
    }
}

ast_node_t new_letrec_node(
    symbol_t p_name, symbol_t p_var, ast_node_t p_body, ast_node_t letrec_body) {
    ast_letrec_t e = malloc(sizeof(ast_letrec_s));
    if (e) {
        e->type = LETREC_EXP;
        e->p_name = p_name;
        e->p_var = p_var;
        e->p_body = p_body;
        e->letrec_body = letrec_body;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("letrec");
        exit(1);
    }
}

ast_node_t new_zero_node(ast_node_t exp) {
    ast_zero_t e = malloc(sizeof(ast_zero_s));
    if (e) {
        e->type = ZERO_EXP;
        e->exp1 = exp;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("zero");
        exit(1);
    }
}

ast_node_t new_if_node(ast_node_t cond, ast_node_t exp1, ast_node_t exp2) {
    ast_if_t e = malloc(sizeof(ast_if_s));
    if (e) {
        e->type = IF_EXP;
        e->cond = cond;
        e->exp1 = exp1;
        e->exp2 = exp2;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("if");
        exit(1);
    }
}

ast_node_t new_let_node(symbol_t id, ast_node_t exp1, ast_node_t exp2) {
    ast_let_t e = malloc(sizeof(ast_let_s));
    if (e) {
        e->type = LET_EXP;
        e->id = id;
        e->exp1 = exp1;
        e->exp2 = exp2;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("let");
        exit(1);
    }
}

ast_node_t new_diff_node(ast_node_t exp1, ast_node_t exp2) {
    ast_diff_t e = malloc(sizeof(ast_diff_s));
    if (e) {
        e->type = DIFF_EXP;
        e->exp1 = exp1;
        e->exp2 = exp2;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("diff");
        exit(1);
    }
}

ast_node_t new_call_node(ast_node_t exp1, ast_node_t exp2) {
    ast_call_t e = malloc(sizeof(ast_call_s));
    if (e) {
        e->type = CALL_EXP;
        e->rator = exp1;
        e->rand = exp2;
        return (ast_node_t)e;
    } else {
        report_ast_malloc_fail("call");
        exit(1);
    }
}

void report_ast_malloc_fail(const char* node_name) {
    fprintf(stderr, "failed to create a new %s ast node!\n", node_name);
    exit(1);
}

void ast_program_free(ast_program_t prgm) {
    if (prgm) {
        ast_free(prgm->exp);
        free(prgm);
    }
}

void ast_free(ast_node_t exp) {
    if (exp) {
        switch (exp->type) {
            case CONST_EXP: {
                const_node_free((ast_const_t)exp);
                break;
            }
            case VAR_EXP: {
                var_node_free((ast_var_t)exp);
                break;
            }
            case PROC_EXP: {
                proc_node_free((ast_proc_t)exp);
                break;
            }
            case LETREC_EXP: {
                letrec_node_free((ast_letrec_t)exp);
                break;
            }
            case ZERO_EXP: {
                zero_node_free((ast_zero_t)exp);
                break;
            }
            case IF_EXP: {
                if_node_free((ast_if_t)exp);
                break;
            }
            case LET_EXP: {
                let_node_free((ast_let_t)exp);
                break;
            }
            case DIFF_EXP: {
                diff_node_free((ast_diff_t)exp);
                break;
            }
            case CALL_EXP: {
                call_node_free((ast_call_t)exp);
                break;
            }
            default: {
                fprintf(stderr, "Unknown type of exp: %d", exp->type);
                exit(1);
            }
        }
    }
}

void const_node_free(ast_const_t exp) {
    free(exp);
}

void var_node_free(ast_var_t exp) {
    free(exp);
}

void proc_node_free(ast_proc_t exp) {
    ast_free(exp->body);
    free(exp);
}

void letrec_node_free(ast_letrec_t exp) {
    ast_free(exp->p_body);
    ast_free(exp->letrec_body);
    free(exp);
}

void zero_node_free(ast_zero_t exp) {
    ast_free(exp->exp1);
    free(exp);
}

void if_node_free(ast_if_t exp) {
    ast_free(exp->cond);
    ast_free(exp->exp1);
    ast_free(exp->exp2);
    free(exp);
}

void let_node_free(ast_let_t exp) {
    ast_free(exp->exp1);
    ast_free(exp->exp2);
    free(exp);
}

void diff_node_free(ast_diff_t exp) {
    ast_free(exp->exp1);
    ast_free(exp->exp2);
    free(exp);
}

void call_node_free(ast_call_t exp) {
    ast_free(exp->rator);
    ast_free(exp->rand);
    free(exp);
}

void symbol_free(symbol_t id) {
    if (id) {
        free(id->name);
        free(id);
    }
}

proc_t new_proc(symbol_t id, ast_node_t body, env_t env) {
    proc_t p = malloc(sizeof(proc_s));
    if (p) {
        p->id = id;
        p->body = body;
        p->env = env;
        return p;
    } else {
        report_exp_val_malloc_fail("procedure");
        exit(1);
    }
}

void proc_free(proc_t p) {
    free(p);
}

exp_val_t new_bool_val(boolean_t val) {
    exp_val_t ev = malloc(sizeof(exp_val_s));
    if (ev) {
        ev->type = BOOL_VAL;
        ev->val.bv = val;
        return ev;
    } else {
        report_exp_val_malloc_fail("bool");
        exit(1);
    }
}

exp_val_t new_int_val(int val) {
    exp_val_t ev = malloc(sizeof(exp_val_s));
    if (ev) {
        ev->type = NUM_VAL;
        ev->val.iv = val;
        return ev;
    } else {
        report_exp_val_malloc_fail("num");
        exit(1);
    }
}

exp_val_t new_proc_val(proc_t val) {
    exp_val_t ev = malloc(sizeof(exp_val_s));
    if (ev) {
        ev->type = PROC_VAL;
        ev->val.pv = val;
        return ev;
    } else {
        report_exp_val_malloc_fail("procedure");
        exit(1);
    }
}

exp_val_t copy_exp_val(exp_val_t val) {
    exp_val_t cv = malloc(sizeof(exp_val_s));
    if (cv) {
        if (val->type == PROC_VAL) {
            cv->type = PROC_VAL;
            cv->val.pv = new_proc(val->val.pv->id, val->val.pv->body, val->val.pv->env);
        } else {
            memcpy(cv, val, sizeof(*val));
        }
        return cv;
    } else {
        fprintf(stderr, "failed to copy a exp value!\n");
        exit(1);
    }
}

void print_exp_val(exp_val_t val) {
    switch (val->type) {
        case NUM_VAL: {
            printf("%d\n", val->val.iv);
            break;
        }
        case BOOL_VAL: {
            printf("%s\n", val->val.bv == TRUE ? "#t" : "#f");
            break;
        }
        case PROC_VAL: {
            printf("(procedure (%s) ...)\n", val->val.pv->id->name);
            break;
        }
        default: {
            fprintf(stderr, "not a valid exp val: %d!\n", val->type);
            break;
        }
    }
}

void exp_val_free(exp_val_t val) {
    if (val) {
        if (val->type == PROC_VAL) {
            proc_free(val->val.pv);
        }
        free(val);
    }
}

boolean_t expval_to_bool(exp_val_t val) {
    if (val->type == BOOL_VAL) {
        return val->val.bv;
    } else {
        report_invalid_exp_val("boolean");
        exit(1);
    }
}

int expval_to_int(exp_val_t val) {
    if (val->type == NUM_VAL) {
        return val->val.iv;
    } else {
        report_invalid_exp_val("number");
        exit(1);
    }
}

proc_t expval_to_proc(exp_val_t val) {
    if (val->type == PROC_VAL) {
        return val->val.pv;
    } else {
        report_invalid_exp_val("procedure");
        exit(1);
    }
}

env_t empty_env() {
    env_t env = malloc(sizeof(env_s));
    if (env) {
        env->type = EMPTY_ENV;
        return env;
    } else {
        fprintf(stderr, "failed to create a new empty env!\n");
        exit(1);
    }
}

env_t extend_env(symbol_t var, exp_val_t val, env_t env) {
    extend_env_t e = malloc(sizeof(extend_env_s));
    if (e) {
        e->type = EXTEND_ENV;
        e->var = var;
        e->val = val;
        e->env = env;
        return (env_t)e;
    } else {
        fprintf(stderr, "failed to create a new extend env!\n");
        exit(1);
    }
}

env_t extend_env_rec(symbol_t p_name, symbol_t p_var, ast_node_t p_body, env_t env) {
    extend_rec_env_t e = malloc(sizeof(extend_rec_env_s));
    if (e) {
        e->type = EXTEND_REC_ENV;
        e->p_name = p_name;
        e->p_var = p_var;
        e->p_body = p_body;
        e->proc_val = NULL;
        e->env = env;
        return (env_t)e;
    } else {
        fprintf(stderr, "failed to create a new extend rec env!\n");
        exit(1);
    }
}

exp_val_t apply_env(env_t env, symbol_t var) {
    switch (env->type) {
        case EMPTY_ENV: {
            report_no_binding_found(var);
            exit(1);
        }
        case EXTEND_ENV: {
            extend_env_t e = (extend_env_t)env;
            if (strcmp(e->var->name, var->name) == 0) {
                return e->val;
            } else {
                return apply_env(e->env, var);
            }
        }
        case EXTEND_REC_ENV: {
            extend_rec_env_t e = (extend_rec_env_t)env;
            if (strcmp(e->p_name->name, var->name) == 0) {
                if (e->proc_val) {
                    return e->proc_val;
                } else {
                    e->proc_val = new_proc_val(new_proc(e->p_var, e->p_body, env));
                    return e->proc_val;
                }
            } else {
                return apply_env(e->env, var);
            }
        }
        default: {
            report_invalid_env(env);
            exit(1);
        }
    }
}

env_t env_pop(env_t env) {
    switch (env->type) {
        case EMPTY_ENV: {
            free(env);
            return NULL;
        }
        case EXTEND_ENV: {
            extend_env_t e = (extend_env_t)env;
            exp_val_free(e->val);
            env_t next = e->env;
            free(e);
            return next;
        }
        case EXTEND_REC_ENV: {
            extend_rec_env_t e = (extend_rec_env_t)env;
            exp_val_free(e->proc_val);
            env_t next = e->env;
            free(e);
            return next;
        }
        default: {
            report_invalid_env(env);
            exit(1);
        }
    }
}

void value_of_program(ast_program_t prgm) {
    env_t e = empty_env();
    env_t *current_env = &e;
    continuation_s c = { END_CONT };
    exp_val_t val = value_of_k(prgm->exp, current_env, &c);
    print_exp_val(val);
    exp_val_free(val);
    while(*current_env) {
        *current_env = env_pop(*current_env);
    }
}

exp_val_t value_of(ast_node_t node, env_t *env) {
    switch (node->type) {
        case CONST_EXP: {
            ast_const_t exp = (ast_const_t)node;
            return new_int_val(exp->num);
        }
        case VAR_EXP: {
            ast_var_t exp = (ast_var_t)node;
            return copy_exp_val(apply_env(*env, exp->var));
        }
        case PROC_EXP: {
            ast_proc_t exp = (ast_proc_t)node;
            return new_proc_val(new_proc(exp->var, exp->body, *env));
        }
        case LETREC_EXP: {
            ast_letrec_t exp = (ast_letrec_t)node;
            *env = extend_env_rec(exp->p_name, exp->p_var, exp->p_body, *env);
            exp_val_t val = value_of(exp->letrec_body, env);
            *env = env_pop(*env);
            return val;
        }
        case ZERO_EXP: {
            ast_zero_t exp = (ast_zero_t)node;
            exp_val_t val1 = value_of(exp->exp1, env);
            if (expval_to_int(val1) == 0) {
                exp_val_free(val1);
                return new_bool_val(TRUE);
            } else {
                exp_val_free(val1);
                return new_bool_val(FALSE);
            }
        }
        case IF_EXP: {
            ast_if_t exp = (ast_if_t)node;
            exp_val_t val1 = value_of(exp->cond, env);
            if (expval_to_bool(val1)) {
                exp_val_free(val1);
                return value_of(exp->exp1, env);
            } else {
                exp_val_free(val1);
                return value_of(exp->exp2, env);
            }
        }
        case LET_EXP: {
            ast_let_t exp = (ast_let_t)node;
            exp_val_t val1 = value_of(exp->exp1, env);
            *env = extend_env(exp->id, val1, *env);
            exp_val_t val2 = value_of(exp->exp2, env);
            *env = env_pop(*env);
            return val2;
        }
        case DIFF_EXP: {
            ast_diff_t exp = (ast_diff_t)node;
            exp_val_t val1 = value_of(exp->exp1, env);
            exp_val_t val2 = value_of(exp->exp2, env);
            int diff_val = expval_to_int(val1) - expval_to_int(val2);
            exp_val_free(val2);
            exp_val_free(val1);
            return new_int_val(diff_val);
        }
        case CALL_EXP: {
            ast_call_t exp = (ast_call_t)node;
            exp_val_t rator_val = value_of(exp->rator, env);
            exp_val_t rand_val = value_of(exp->rand, env);
            exp_val_t call_val = apply_procedure(expval_to_proc(rator_val), rand_val);
            exp_val_free(rand_val);
            exp_val_free(rator_val);
            return call_val;
        }
        default: {
            fprintf(stderr, "unknown type of expression: %d\n", node->type);
            exit(1);
        }
    }
}

exp_val_t apply_procedure(proc_t proc1, exp_val_t val) {
    env_t env = extend_env(proc1->id, copy_exp_val(val), proc1->env);
    env_t *current_env = &env;
    exp_val_t call_val = value_of(proc1->body, current_env);
    env_pop(*current_env);
    return call_val;
}

void report_exp_val_malloc_fail(const char *val_type) {
    fprintf(stderr, "failed to create a new %s exp value!\n", val_type);
}

void report_invalid_exp_val(const char *val_type) {
    fprintf(stderr, "not a valid exp val of type %s!\n", val_type);
}

void report_no_binding_found(symbol_t search_var) {
    fprintf(stderr, "no binding for %s\n", search_var->name);
}

void report_invalid_env(env_t env) {
    fprintf(stderr, "bad environment: %p", env);
}

exp_val_t apply_cont(continuation_t cont, exp_val_t val) {
    switch(cont->type) {
        case END_CONT: {
            printf("End of computation.\n");
            return val;
        }
        case ZERO1_CONT: {
            zero1_cont_t zc = (zero1_cont_t)cont;
            if (expval_to_int(val) == 0) {
                exp_val_free(val);
                return apply_cont(zc->cont, new_bool_val(TRUE));
            } else {
                exp_val_free(val);
                return apply_cont(zc->cont, new_bool_val(FALSE));
            }
        }
        case LET_CONT: {
            let_cont_t l1c = (let_cont_t)cont;
            *l1c->env = extend_env(l1c->var, val, *l1c->env);
            let2_cont_s l2c = { LET2_CONT, l1c->env, l1c->cont };
            return value_of_k(l1c->body, l1c->env, (continuation_t)(&l2c));
        }
        case LET2_CONT: {
            let2_cont_t l2c = (let2_cont_t)cont;
            *l2c->env = env_pop(*l2c->env);
            return apply_cont(l2c->cont, val);
        }
        case LETREC_CONT: {
            letrec_cont_t lrc = (letrec_cont_t)cont;
            *lrc->env = env_pop(*lrc->env);
            return apply_cont(lrc->cont, val);
        }
        case IF_TEST_CONT: {
            if_test_cont_t ic = (if_test_cont_t)cont;
            if (expval_to_bool(val)) {
                exp_val_free(val);
                return value_of_k(ic->exp2, ic->env, ic->cont);
            } else {
                exp_val_free(val);
                return value_of_k(ic->exp3, ic->env, ic->cont);
            }
        }
        case DIFF1_CONT: {
            diff1_cont_t d1c = (diff1_cont_t)cont;
            diff2_cont_s d2c = { DIFF2_CONT, val, d1c->cont };
            return value_of_k(d1c->exp2, d1c->env, (continuation_t)(&d2c));
        }
        case DIFF2_CONT: {
            diff2_cont_t d2c = (diff2_cont_t)cont;
            int diff_val = expval_to_int(d2c->val) - expval_to_int(val);
            exp_val_free(val);
            exp_val_free(d2c->val);
            return apply_cont(d2c->cont, new_int_val(diff_val));
        }
        case RATOR_CONT: {
            rator_cont_t rtc = (rator_cont_t)cont;
            rand_cont_s rnc = { RAND_CONT, val, rtc->cont };
            return value_of_k(rtc->exp, rtc->env, (continuation_t)(&rnc));
        }
        case RAND_CONT: {
            rand_cont_t rnc = (rand_cont_t)cont;
            apply_proc_cont_s apc = { APPLY_PROC_CONT, rnc->val, val, rnc->cont };
            return apply_procedure_k(expval_to_proc(rnc->val), val, (continuation_t)(&apc));
        }
        case APPLY_PROC_CONT: {
            apply_proc_cont_t apc = (apply_proc_cont_t)cont;
            exp_val_free(apc->rator);
            exp_val_free(apc->rand);
            return apply_cont(apc->cont, val);
        }
        case APPLY_PROC2_CONT: {
            apply_proc2_cont_t ap2c = (apply_proc2_cont_t)cont;
            env_pop(*ap2c->env);
            return apply_cont(ap2c->cont, val);
        }
        default: {
            fprintf(stderr, "unknown type of continuation: %d", cont->type);
            exit(1);
        }
    }
}

exp_val_t apply_procedure_k(proc_t proc1, exp_val_t val, continuation_t cont) {
    env_t env = extend_env(proc1->id, copy_exp_val(val), proc1->env);
    apply_proc2_cont_s ap2c = { APPLY_PROC2_CONT, &env, cont };
    return value_of_k(proc1->body, &env, (continuation_t)(&ap2c));
}

exp_val_t value_of_k(ast_node_t node, env_t *env, continuation_t cont) {
    switch (node->type) {
        case CONST_EXP: {
            ast_const_t exp = (ast_const_t)node;
            return apply_cont(cont, new_int_val(exp->num));
        }
        case VAR_EXP: {
            ast_var_t exp = (ast_var_t)node;
            return apply_cont(cont, copy_exp_val(apply_env(*env, exp->var)));
        }
        case PROC_EXP: {
            ast_proc_t exp = (ast_proc_t)node;
            return apply_cont(cont, new_proc_val(new_proc(exp->var, exp->body, *env)));
        }
        case LETREC_EXP: {
            ast_letrec_t exp = (ast_letrec_t)node;
            *env = extend_env_rec(exp->p_name, exp->p_var, exp->p_body, *env);
            letrec_cont_s lrc = { LETREC_CONT, env, cont };
            return value_of_k(exp->letrec_body, env, (continuation_t)(&lrc));
        }
        case ZERO_EXP: {
            ast_zero_t exp = (ast_zero_t)node;
            zero1_cont_s zc = { ZERO1_CONT, cont };
            return value_of_k(exp->exp1, env, (continuation_t)(&zc));
        }
        case IF_EXP: {
            ast_if_t exp = (ast_if_t)node;
            if_test_cont_s ic = { IF_TEST_CONT, exp->exp1, exp->exp2, env, cont };
            return value_of_k(exp->cond, env, (continuation_t)(&ic));
        }
        case LET_EXP: {
            ast_let_t exp = (ast_let_t)node;
            let_cont_s lc = { LET_CONT, exp->id, exp->exp2, env, cont };
            return value_of_k(exp->exp1, env, (continuation_t)(&lc));
        }
        case DIFF_EXP: {
            ast_diff_t exp = (ast_diff_t)node;
            diff1_cont_s dc = { DIFF1_CONT, exp->exp2, env, cont };
            return value_of_k(exp->exp1, env, (continuation_t)(&dc));
        }
        case CALL_EXP: {
            ast_call_t exp = (ast_call_t)node;
            rator_cont_s rc = { RATOR_CONT, exp->rand, env, cont };
            return value_of_k(exp->rator, env, (continuation_t)(&rc));
        }
        default: {
            fprintf(stderr, "unknown type of expression: %d\n", node->type);
            return new_int_val(0);
        }
    }
    return new_int_val(0);
}

int main(int argc, char *argv[]) {
    yyscan_t scaninfo = NULL;
    ast_program_t prgm = NULL;
    if (yylex_init_extra(symtab, &scaninfo) == 0) {
        int v = yyparse(scaninfo, symtab, &prgm);
        if (v == 0) {
            value_of_program(prgm);
        }
        ast_program_free(prgm);
        yylex_destroy(scaninfo);
        symbol_table_free(symtab);
        return 0;
    } else {
        fprintf(stderr, "Failed to initialize scanner!\n");
        exit(1);
    }
}