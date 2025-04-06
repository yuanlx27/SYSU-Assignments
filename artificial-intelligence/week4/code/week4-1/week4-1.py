import copy
import re

class Formula:
    def __init__(self, ifnot, predicate, parameters):
        # ifnot: 0 means negated, 1 means positive
        self.ifnot = ifnot
        self.predicate = predicate
        self.parameters = parameters

    def __repr__(self):
        prefix = '~' if self.ifnot == 0 else ''
        return f"{prefix}{self.predicate}({','.join(self.parameters)})"

def list_to_str(clause):
    """Convert a clause (list of Formula) to its string representation."""
    return str(tuple(clause))

def clause_in_kb(clause, kb):
    """Return True if the clause already exists in the knowledge base."""
    return any(existing == clause for existing in kb)

def substitute_in_clause(clause, old, new):
    """Substitute all occurrences of parameter 'old' with 'new' in a clause."""
    new_clause = copy.deepcopy(clause)
    for f in new_clause:
        f.parameters = [new if p == old else p for p in f.parameters]
    return new_clause

def add_resolution_step(clause1_idx, clause2_idx, i_char, j_char, new_clause, step, result, unif_info=""):
    """Helper to build and record a resolution step."""
    step_label = f"{step[0]}"
    step[0] += 1
    # Format step; include subformula labels only if provided.
    step_text = f"{step_label} R[{clause1_idx}{i_char},{clause2_idx}{j_char}]{unif_info} = {list_to_str(new_clause)}"
    result.append(step_text)

def resolution(clause1, clause2, clause1_idx, clause2_idx, kb, step, result):
    m, n = len(clause1), len(clause2)
    for i in range(m):
        for j in range(n):
            # Check complementary: different sign and same predicate.
            if clause1[i].ifnot != clause2[j].ifnot and clause1[i].predicate == clause2[j].predicate:
                # Case 1: Parameters match exactly.
                if clause1[i].parameters == clause2[j].parameters:
                    new_clause = clause2[:j] + clause2[j+1:] + clause1[:i] + clause1[i+1:]
                    if not clause_in_kb(new_clause, kb):
                        kb.append(new_clause)
                        add_resolution_step(clause1_idx, clause2_idx,
                                            chr(i + 97) if m > 1 else '',
                                            chr(j + 97) if n > 1 else '',
                                            new_clause, step, result)
                        if new_clause == []:
                            return 0
                else:
                    # Case 2: Unification is necessary.
                    for k in range(len(clause1[i].parameters)):
                        # Determine which parameter is a constant (length > 1)
                        if len(clause1[i].parameters[k]) > len(clause2[j].parameters[k]):
                            fixed = substitute_in_clause(clause2, clause2[j].parameters[k], clause1[i].parameters[k])
                            new_clause = fixed[:j] + fixed[j+1:] + clause1[:i] + clause1[i+1:]
                            if not clause_in_kb(new_clause, kb):
                                kb.append(new_clause)
                                unif_info = f"{{{clause2[j].parameters[k]}={clause1[i].parameters[k]}}}"
                                add_resolution_step(clause1_idx, clause2_idx,
                                                    chr(i + 97) if m > 1 else '',
                                                    chr(j + 97) if n > 1 else '',
                                                    new_clause, step, result, unif_info)
                                if new_clause == []:
                                    return 0
                        elif len(clause2[j].parameters[k]) > len(clause1[i].parameters[k]):
                            fixed = substitute_in_clause(clause1, clause1[i].parameters[k], clause2[j].parameters[k])
                            new_clause = clause2[:j] + clause2[j+1:] + fixed[:i] + fixed[i+1:]
                            if not clause_in_kb(new_clause, kb):
                                kb.append(new_clause)
                                unif_info = f"{{{clause1[i].parameters[k]}={clause2[j].parameters[k]}}}"
                                add_resolution_step(clause1_idx, clause2_idx,
                                                    chr(i + 97) if m > 1 else '',
                                                    chr(j + 97) if n > 1 else '',
                                                    new_clause, step, result, unif_info)
                                if new_clause == []:
                                    return 0
    return 1

def str_to_formula(string):
    """Convert a string representation of a formula to a Formula object."""
    string = string.strip()
    ifnot = 0 if string.startswith('~') else 1
    content = string[1:] if string.startswith('~') else string
    predicate, params = content.split('(', 1)
    params = params.rstrip(')')
    parameters = [p.strip() for p in params.split(',')]
    return Formula(ifnot, predicate, parameters)

def to_list_of_formulas(kb):
    """Convert each clause in KB (a list of tuples of strings) to a list of Formula objects."""
    for i in range(len(kb)):
        kb[i] = [str_to_formula(s) for s in kb[i]]

def ResolutionFOL(kb):
    result = []
    kb = [list(clause) for clause in kb]  # Ensure KB is a list of lists.
    to_list_of_formulas(kb)
    step = [1]

    # Record initial clauses.
    for clause in kb:
        result.append(f"{step[0]} {list_to_str(clause)}")
        step[0] += 1

    # Pairwise resolution.
    for i in range(len(kb)):
        for j in range(i + 1, len(kb)):
            if resolution(kb[i], kb[j], i + 1, j + 1, kb, step, result) == 0:
                return result
    return result

if __name__ == "__main__":
    KBs = [
        {
            ('GradStudent(sue)',),
            ('~GradStudent(x)', 'Student(x)'),
            ('~Student(x)', 'HardWorker(x)'),
            ('~HardWorker(sue)',),
        },
        {
            ('A(tony)',),
            ('A(mike)',),
            ('A(john)',),
            ('L(tony,rain)',),
            ('L(tony,snow)',),
            ('~A(x)', 'S(x)', 'C(x)'),
            ('~C(y)', '~L(y,rain)'),
            ('L(z,snow)', '~S(z)'),
            ('~L(tony,u)', '~L(mike,u)'),
            ('L(tony,v)', 'L(mike,v)'),
            ('~A(w)', '~C(w)', 'S(w)'),
        },
        {
            ('On(tony,mike)',),
            ('On(mike,john)',),
            ('Green(tony)',),
            ('~Green(john)',),
            ('~On(xx,yy)', '~Green(xx)', 'Green(yy)'),
        },
    ]

    for idx, kb in enumerate(KBs, start=1):
        print(f"Steps for Knowledge Base {idx}:")
        steps = ResolutionFOL(kb)
        print("\n".join(steps))
        print()
