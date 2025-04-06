import heapq
import time
import math

# Define constants and target positions
TARGET = {
    1: (1, 1), 2: (1, 2), 3: (1, 3), 4: (1, 4),
    5: (2, 1), 6: (2, 2), 7: (2, 3), 8: (2, 4),
    9: (3, 1), 10: (3, 2), 11: (3, 3), 12: (3, 4),
    13: (4, 1), 14: (4, 2), 15: (4, 3)
}
DX = [0, 0, 1, -1]
DY = [1, -1, 0, 0]
SHIFT_MAP = [
    [0,  0,  0,  0,  0],
    [0, 60, 56, 52, 48],
    [0, 44, 40, 36, 32],
    [0, 28, 24, 20, 16],
    [0, 12, 8,  4,  0]
]

def array_to_int(a):
    num = 0
    for i in range(1, 5):
        for j in range(1, 5):
            num = (num << 4) | a[i][j]
    return num

def h(num):
    ans = 0
    for i in range(1,5):
        for j in range(1,5):
            shift = SHIFT_MAP[i][j]
            val = (num >> shift) & 0xF
            if val == 0:
                continue
            tx, ty = TARGET[val]
            ans += abs(i - tx) + abs(j - ty)
            # Row conflict check
            if i == tx:
                for jj in range(j + 1, 5):
                    shift_jj = SHIFT_MAP[i][jj]
                    val_jj = (num >> shift_jj) & 0xF
                    if val_jj == 0:
                        continue
                    tx_jj, ty_jj = TARGET[val_jj]
                    if tx_jj == i and ((ty < ty_jj) != (j < jj)):
                        ans += 2
            # Column conflict check
            if j == ty:
                for ii in range(i + 1, 5):
                    shift_ii = SHIFT_MAP[ii][j]
                    val_ii = (num >> shift_ii) & 0xF
                    if val_ii == 0:
                        continue
                    tx_ii, ty_ii = TARGET[val_ii]
                    if ty_ii == j and ((tx < tx_ii) != (i < ii)):
                        ans += 2
    return ans

def inversion_parity(a):
    # Compute inversion count plus blank row to check solvability
    nums = []
    blank_row = 0
    for i in range(1,5):
        for j in range(1,5):
            if a[i][j] != 0:
                nums.append(a[i][j])
            else:
                blank_row = 5 - i
    inv = 0
    for i in range(len(nums)):
        for j in range(i):
            if nums[j] > nums[i]:
                inv += 1
    return inv + blank_row

def int_to_pos(num):
    for i in range(1,5):
        for j in range(1,5):
            shift = SHIFT_MAP[i][j]
            if ((num >> shift) & 0xF) == 0:
                return (i, j)
    return (0, 0)

def main():
    # Read input and initialize board state
    a = [[0] * 5 for _ in range(5)]
    sx, sy = 0, 0
    for i in range(1, 5):
        row = list(map(int, input().split()))
        for j in range(1, 5):
            a[i][j] = row[j-1]
            if a[i][j] == 0:
                sx, sy = i, j
    if inversion_parity(a) % 2 == 0:
        print("Can't Solve")
        return

    start = array_to_int(a)
    start_f = h(start)
    explored = set()
    parent = {}
    parent[start] = -1

    q = []
    heapq.heappush(q, (start_f, 0, start, sx, sy, -1))
    node_count = 0
    start_time = time.time()

    while q:
        cur_f, g, state, x, y, par = heapq.heappop(q)
        if state in explored:
            continue
        parent[state] = par
        node_count += 1
        explored.add(state)
        if h(state) == 0:
            print(g)
            path = []
            def backtrace(s):
                if parent.get(s) == -1:
                    pos = int_to_pos(s)
                    path.append(f"({pos[0]},{pos[1]})")
                    return
                backtrace(parent[s])
                pos = int_to_pos(s)
                path.append(f"({pos[0]},{pos[1]})")
            backtrace(state)
            print("->".join(path))
            break

        for i in range(4):
            nx, ny = x + DX[i], y + DY[i]
            if 1 <= nx <= 4 and 1 <= ny <= 4:
                shift1 = SHIFT_MAP[x][y]
                shift2 = SHIFT_MAP[nx][ny]
                val2 = (state >> shift2) & 0xF
                mask = (0xF << shift1) | (0xF << shift2)
                new_state = state & ~mask
                new_state |= (val2 << shift1)
                if new_state not in explored and new_state not in parent:
                    new_g = g + 1
                    new_f = new_g + h(new_state)
                    heapq.heappush(q, (new_f, new_g, new_state, nx, ny, state))
        if node_count % 1000000 == 0:
            print(f"Nodes processed: {node_count}, Time elapsed: {time.time() - start_time}s")

    print(f"Total running time: {time.time() - start_time}s")
    print(f"Total nodes explored: {node_count}")

if __name__ == "__main__":
    main()

'''
样例一
1 2 4 8
5 7 11 10
13 15 0 3
14 6 9 12
answer:22

样例二
14 10 6 0
4 9 1 8
2 3 5 11
12 13 7 15

answer:49

样例三
5 1 3 4
2 7 8 12
9 6 11 15
0 13 10 14

answer:15

样例四
6 10 3 15
14 8 7 11
5 1 0 2
13 12 9 4

answer:48

样例五
11 3 1 7
4 6 8 2
15 9 10 13
14 12 5 0

answer:56

样例六
0 5 15 14
7 9 6 13
1 2 12 10
8 11 4 3

answer:62
'''
"""
initial_state = [
    ( 1, 2, 4, 8, 5, 7, 11, 10, 13, 15, 0, 3, 14, 6, 9, 12 ),
    ( 14, 10, 6, 0, 4, 9, 1, 8, 2, 3, 5, 11, 12, 13, 7, 15 ),
    ( 5, 1, 3, 4, 2, 7, 8, 12, 9, 6, 11, 15, 0, 13, 10, 14 ),
    ( 6, 10, 3, 15, 14, 8, 7, 11, 5, 1, 0, 2, 13, 12, 9, 4 ),
    ( 11, 3, 1, 7, 4, 6, 8, 2, 15, 9, 10, 13, 14, 12, 5, 0 ),
    ( 0, 5, 15, 14, 7, 9, 6, 13, 1, 2, 12, 10, 8, 11, 4, 3 ),
]
"""