def ResolutionProp(kb):
    """
    Implements propositional resolution.
    Input:
      kb: a set of clauses, each clause is a tuple of literals (e.g., ('A',), ('~A','B'))
    Output:
      A list of strings recording the resolution process.
    Resolution step format:
      "<step> R[clause1_idx{letter_if_applicable},clause2_idx{letter_if_applicable}]= <new_clause>"
      Literal labels (a, b, c, …) are added if a clause has multiple literals.
    """
    # Convert kb (set of tuples) to list of lists of literals.
    clauses = [list(clause) for clause in kb]
    steps = []
    step_counter = [1]

    # Record initial clauses.
    for clause in clauses:
        steps.append(f"{step_counter[0]} {tuple(clause)}")
        step_counter[0] += 1

    new_clause_generated = True
    while new_clause_generated:
        new_clause_generated = False
        n = len(clauses)
        for i in range(n):
            for j in range(i + 1, n):
                ci, cj = clauses[i], clauses[j]
                m, l = len(ci), len(cj)
                for idx_i, lit_i in enumerate(ci):
                    for idx_j, lit_j in enumerate(cj):
                        # Check if literals are complementary.
                        if (lit_i.startswith("~") and lit_i[1:] == lit_j) or (lit_j.startswith("~") and lit_j[1:] == lit_i):
                            # Build new clause by removing the resolved literals.
                            new_clause = [x for k, x in enumerate(ci) if k != idx_i] + [x for k, x in enumerate(cj) if k != idx_j]
                            # Remove duplicates (preserve order).
                            seen = []
                            new_clause = [x for x in new_clause if x not in seen and (seen.append(x) or True)]
                            # Skip if clause already exists.
                            if any(tuple(new_clause) == tuple(existing) for existing in clauses):
                                continue
                            clauses.append(new_clause)
                            new_clause_generated = True
                            # Determine literal labels: if clause has >1 literal, use letters; otherwise no label.
                            label_i = chr(idx_i + 97) if m > 1 else ''
                            label_j = chr(idx_j + 97) if l > 1 else ''
                            steps.append(f"{step_counter[0]} R[{i+1}{label_i},{j+1}{label_j}] = {tuple(new_clause)}")
                            step_counter[0] += 1
                            # Stop resolution if empty clause is derived.
                            if new_clause == []:
                                return steps
        # Loop until no new clause is generated.
    return steps

# ...existing code (if any)...
if __name__ == "__main__":
    # Example input:
    # KB: {('FirstGrade',), ('~FirstGrade','Child'), ('~Child',)}
    KB = {
        ('FirstGrade',),
        ('~FirstGrade', 'Child'),
        ('~Child',)
    }
    resolution_steps = ResolutionProp(KB)
    for line in resolution_steps:
        print(line)
