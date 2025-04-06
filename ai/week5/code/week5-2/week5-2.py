import heapq
import time

# Constants for the puzzle
N = 4
GOAL = tuple(range(1, N * N)) + (0,)

def manhattan(state):
    total = 0
    for i, tile in enumerate(state):
        if tile:
            target_row, target_col = divmod(tile - 1, N)
            current_row, current_col = divmod(i, N)
            total += abs(target_row - current_row) + abs(target_col - current_col)
    return total

def neighbors(state):
    # Generate neighbor states with moves: up, down, left, right.
    i = state.index(0)
    row, col = divmod(i, N)
    for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
        new_row, new_col = row + dr, col + dc
        if 0 <= new_row < N and 0 <= new_col < N:
            j = new_row * N + new_col
            new_state = list(state)
            new_state[i], new_state[j] = new_state[j], new_state[i]
            yield tuple(new_state)

def a_star(start):
    # Standard A* algorithm.
    open_set = [(manhattan(start), 0, start, [])]
    visited = {start: 0}
    while open_set:
        est, cost, state, path = heapq.heappop(open_set)
        if state == GOAL:
            return path
        for nxt in neighbors(state):
            new_cost = cost + 1
            if nxt not in visited or new_cost < visited[nxt]:
                visited[nxt] = new_cost
                priority = new_cost + manhattan(nxt)
                heapq.heappush(open_set, (priority, new_cost, nxt, path + [nxt]))
    return None

def ida_star(start):
    # IDA* search: iterative deepening over DFS.
    threshold = manhattan(start)
    path = [start]
    def search(g, threshold, state, path):
        f = g + manhattan(state)
        if f > threshold:
            return f
        if state == GOAL:
            return "FOUND"
        min_threshold = float('inf')
        for nxt in neighbors(state):
            if nxt in path: continue
            path.append(nxt)
            temp = search(g+1, threshold, nxt, path)
            if temp == "FOUND":
                return "FOUND"
            if temp < min_threshold:
                min_threshold = temp
            path.pop()
        return min_threshold
    while True:
        temp = search(0, threshold, start, path)
        if temp == "FOUND":
            return path[1:]  # excluding initial state if desired
        if temp == float('inf'):
            return None
        threshold = temp


start = [
    ( 1, 2, 4, 8, 5, 7, 11, 10, 13, 15, 0, 3, 14, 6, 9, 12 ),
    ( 14, 10, 6, 0, 4, 9, 1, 8, 2, 3, 5, 11, 12, 13, 7, 15 ),
    ( 5, 1, 3, 4, 2, 7, 8, 12, 9, 6, 11, 15, 0, 13, 10, 14 ),
    ( 6, 10, 3, 15, 14, 8, 7, 11, 5, 1, 0, 2, 13, 12, 9, 4 ),
    ( 11, 3, 1, 7, 4, 6, 8, 2, 15, 9, 10, 13, 14, 12, 5, 0 ),
    ( 0, 5, 15, 14, 7, 9, 6, 13, 1, 2, 12, 10, 8, 11, 4, 3 ),
]

for idx, puzzle in enumerate(start, 1):
    print(f"Puzzle {idx}:")
    for algo_name, algo in (("A*", a_star), ("IDA*", ida_star)):
        t0 = time.perf_counter()
        solution = algo(puzzle)
        elapsed = time.perf_counter() - t0
        if solution is not None:
            print(f"  {algo_name} solved in {len(solution)} moves; Time: {elapsed:.6f} seconds")
        else:
            print(f"  {algo_name} found no solution; Time: {elapsed:.6f} seconds")
    print()
