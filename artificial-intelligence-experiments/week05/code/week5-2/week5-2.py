import heapq, time

GOAL = ( 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0 )

def heruistic(state):
    def manhattan_distance(state):
        distance = 0
        for i in range(4):
            for j in range(4):
                if state[i * 4 + j] == 0: continue
                x, y = divmod(state[i * 4 + j] - 1, 4)
                distance += abs(x - i) + abs(y - j)
        return distance
    
    def linear_conflict(state):
        conflict = 0
        for i in range(4):
            for j in range(4):
                if state[i * 4 + j] == 0: continue
                x, y = divmod(state[i * 4 + j] - 1, 4)
                if i == x:
                    for k in range(j + 1, 4):
                        if state[i * 4 + k] == 0: continue
                        xx, yy = divmod(state[i * 4 + k] - 1, 4)
                        if xx == x and (y < yy) != (j < k):
                            conflict += 2
                if j == y:
                    for k in range(i + 1, 4):
                        if state[k * 4 + j] == 0: continue
                        xx, yy = divmod(state[k * 4 + j] - 1, 4)
                        if yy == y and (x < xx) != (i < k):
                            conflict += 2
        return conflict

    return manhattan_distance(state) + linear_conflict(state)

def a_star(start):
    node_count = 0
    start_time = time.time()

    start_x, start_y = divmod(start.index(0), 4)
    dst, que, vst = { start: 0 }, [ ( heruistic(start), 0, start, start_x, start_y, "" ) ], set()
    while que:
        f, g, state, x, y, p = heapq.heappop(que)
        if state == GOAL:
            return g, p
        
        if state in vst:
            continue
        vst.add(state)

        node_count += 1
        if node_count % 1000000 == 0:
            print(f"# Explored {node_count:09d} nodes, took {time.time() - start_time:03.6f} seconds.")

        for dx, dy, dp in [ ( -1, 0, "U" ), ( 1, 0, "D" ), ( 0, -1, "L" ), ( 0, 1, "R" ) ]:
            nx, ny, np = x + dx, y + dy, p + dp
            if not (0 <= nx < 4 and 0 <= ny < 4):
                continue
            i, ni = x * 4 + y, nx * 4 + ny

            new_state = list(state)
            new_state[i], new_state[ni] = new_state[ni], new_state[i]
            new_state = tuple(new_state)
            new_g, new_h = g + 1, heruistic(new_state)
            new_f = new_g + new_h

            if new_state not in dst or new_g < dst[new_state]:
                dst[new_state] = new_g
                heapq.heappush(que, ( new_f, new_g, new_state, nx, ny, np ))
    return -1, "NULL"

def ida_star(start):
    opposite = {"U": "D", "D": "U", "L": "R", "R": "L"}
    blank_index = start.index(0)
    start_x, start_y = divmod(blank_index, 4)

    def dfs(state, g, threshold, x, y, path, last_move):
        f = g + heruistic(state)
        if f > threshold:
            return f
        if state == GOAL:
            return (g, path)
        minimum = float("inf")
        for dx, dy, move in [(-1, 0, "U"), (1, 0, "D"), (0, -1, "L"), (0, 1, "R")]:
            if last_move and move == opposite[last_move]:
                continue  # avoid reversing the previous move
            nx, ny = x + dx, y + dy
            if not (0 <= nx < 4 and 0 <= ny < 4):
                continue
            i = x * 4 + y
            ni = nx * 4 + ny
            new_state = list(state)
            new_state[i], new_state[ni] = new_state[ni], new_state[i]
            new_state = tuple(new_state)
            result = dfs(new_state, g + 1, threshold, nx, ny, path + move, move)
            if isinstance(result, tuple):
                return result  # found solution
            if result < minimum:
                minimum = result
        return minimum

    threshold = heruistic(start)
    while True:
        result = dfs(start, 0, threshold, start_x, start_y, "", None)
        if isinstance(result, tuple):
            return result  # returns (number_of_steps, solution_path)
        if result == float("inf"):
            return -1, "NULL"
        threshold = result

testcases = [
    ( 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15 ),
    ( 1, 2, 4, 8, 5, 7, 11, 10, 13, 15, 0, 3, 14, 6, 9, 12 ),
    ( 14, 10, 6, 0, 4, 9, 1, 8, 2, 3, 5, 11, 12, 13, 7, 15 ),
    ( 5, 1, 3, 4, 2, 7, 8, 12, 9, 6, 11, 15, 0, 13, 10, 14 ),
    ( 6, 10, 3, 15, 14, 8, 7, 11, 5, 1, 0, 2, 13, 12, 9, 4 ),
    ( 11, 3, 1, 7, 4, 6, 8, 2, 15, 9, 10, 13, 14, 12, 5, 0 ),
    ( 0, 5, 15, 14, 7, 9, 6, 13, 1, 2, 12, 10, 8, 11, 4, 3 ),
]

for idx, state in enumerate(testcases):
    print(f"Test case {idx}:")
    for name, algo in [ ("A*", a_star), ("IDA*", ida_star) ]:
        t0 = time.time()
        len, moves = algo(state)
        t1 = time.time()
        print(f"{name} solved in {len} step(s), took {t1 - t0:.6f} second(s): {moves}")
    print("-" * 40)