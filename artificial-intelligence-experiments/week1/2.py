def MatrixAdd(A, B):
    n = len(A)

    C = [ [0] * n for _ in range(n) ]
    for i in range(n):
        for j in range(n):
            C[i][j] += A[i][j] + B[i][j]

    return C

def MatrixMul(A, B):
    n = len(A)

    C = [ [0] * n for _ in range(n) ]
    for i in range(n):
        for j in range(n):
            for k in range(n):
                C[i][j] += A[i][k] * B[k][j]

    return C

n = int(input())

A = []
for i in range(n):
    row = list(map(int, input().split()))
    A.append(row)
B = []
for i in range(n):
    row = list(map(int, input().split()))
    B.append(row)

C, D = MatrixAdd(A, B), MatrixMul(A, B)
for row in C:
    print(row)
for row in D:
    print(row)
