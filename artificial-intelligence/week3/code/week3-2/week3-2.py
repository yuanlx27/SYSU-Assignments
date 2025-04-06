def MGU(formula1, formula2):
    def parse_formula(s):
        s = s.strip()
        idx = s.find('(')
        if idx == -1 or s[-1] != ')':
            raise ValueError("Invalid formula")
        pred = s[:idx]
        args_str = s[idx+1:-1]
        args = split_args(args_str)
        return pred, [parse_term(arg) for arg in args]
    
    def split_args(s):
        args = []
        current = []
        level = 0
        for c in s:
            if c == ',' and level == 0:
                args.append(''.join(current))
                current = []
            else:
                if c == '(':
                    level += 1
                elif c == ')':
                    level -= 1
                current.append(c)
        if current:
            args.append(''.join(current))
        return [arg.strip() for arg in args if arg.strip()]
    
    def parse_term(s):
        s = s.strip()
        if '(' in s:
            idx = s.find('(')
            func = s[:idx]
            args_str = s[idx+1:-1]
            args = split_args(args_str)
            return (func, [parse_term(arg) for arg in args])
        else:
            return s
    
    def is_variable(term):
        # 约定：无括号且长度大于1的标识符视为变量
        return isinstance(term, str) and len(term) > 1
    
    def apply_subst(term, subst):
        if isinstance(term, str):
            if is_variable(term) and term in subst:
                return apply_subst(subst[term], subst)
            else:
                return term
        else:
            func, args = term
            return (func, [apply_subst(arg, subst) for arg in args])
    
    def occurs_in(v, term, subst):
        term = apply_subst(term, subst)
        if term == v:
            return True
        if isinstance(term, tuple):
            return any(occurs_in(v, arg, subst) for arg in term[1])
        return False
    
    def unify(s, t, subst):
        s = apply_subst(s, subst)
        t = apply_subst(t, subst)
        if s == t:
            return subst
        if isinstance(s, str) and is_variable(s):
            if occurs_in(s, t, subst):
                raise Exception("Occurs check failed")
            subst[s] = t
            return subst
        if isinstance(t, str) and is_variable(t):
            if occurs_in(t, s, subst):
                raise Exception("Occurs check failed")
            subst[t] = s
            return subst
        if isinstance(s, tuple) and isinstance(t, tuple):
            if s[0] != t[0] or len(s[1]) != len(t[1]):
                raise Exception("Function mismatch")
            for s_arg, t_arg in zip(s[1], t[1]):
                subst = unify(s_arg, t_arg, subst)
            return subst
        raise Exception("Unification failed")
    
    def term_to_str(term):
        term = apply_subst(term, {})
        if isinstance(term, str):
            return term
        else:
            func, args = term
            return func + '(' + ','.join(term_to_str(arg) for arg in args) + ')'
    
    pred1, args1 = parse_formula(formula1)
    pred2, args2 = parse_formula(formula2)
    if pred1 != pred2 or len(args1) != len(args2):
        return {}
    subst = {}
    try:
        for t1, t2 in zip(args1, args2):
            subst = unify(t1, t2, subst)
        result = {var: term_to_str(term) for var, term in subst.items()}
        return result
    except Exception:
        return {}

print(MGU('P(xx,a)', 'P(b,yy)'))
print(MGU('P(a,xx,f(g(yy)))', 'P(zz,f(zz),f(uu))'))