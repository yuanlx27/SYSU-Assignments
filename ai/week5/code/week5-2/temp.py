import heapq
import time

def is_solvable(state):
    inversions = 0
    blank_pos = state.index(0)
    for i in range(len(state)):
        for j in range(i + 1, len(state)):
            if state[i] != 0 and state[j] != 0 and state[i] > state[j]:
                inversions += 1
    row = blank_pos // 4
    blank_row_from_bottom = (3 - row) + 1  # 1-based row from the bottom
    return (inversions % 2) == (blank_row_from_bottom % 2)

def manhattan(state):
    distance = 0
    for i in range(16):
        if state[i] == 0:
            continue
        target_pos = state[i] - 1
        target_row, target_col = target_pos // 4, target_pos % 4
        current_row, current_col = i // 4, i % 4
        distance += abs(target_row - current_row) + abs(target_col - current_col)
    return distance

def get_successors(state):
    blank = state.index(0)
    row, col = blank // 4, blank % 4
    successors = []
    if row > 0:
        new_blank = blank - 4
        new_state = list(state)
        new_state[blank], new_state[new_blank] = new_state[new_blank], new_state[blank]
        successors.append(('U', tuple(new_state)))
    if row < 3:
        new_blank = blank + 4
        new_state = list(state)
        new_state[blank], new_state[new_blank] = new_state[new_blank], new_state[blank]
        successors.append(('D', tuple(new_state)))
    if col > 0:
        new_blank = blank - 1
        new_state = list(state)
        new_state[blank], new_state[new_blank] = new_state[new_blank], new_state[blank]
        successors.append(('L', tuple(new_state)))
    if col < 3:
        new_blank = blank + 1
        new_state = list(state)
        new_state[blank], new_state[new_blank] = new_state[new_blank], new_state[blank]
        successors.append(('R', tuple(new_state)))
    return successors

def a_star(initial_state):
    initial_state = tuple(initial_state)
    goal = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0)

    if initial_state == goal:
        return [], 0

    visited = {}
    heap = []
    heapq.heappush(heap, (manhattan(initial_state), 0, initial_state, []))
    visited[initial_state] = 0
    while heap:
        f, g, state, path = heapq.heappop(heap)
        if state == goal:
            return path, g
        if g > visited.get(state, float('inf')):
            continue
        for move, successor in get_successors(state):
            new_g = g + 1
            if successor in visited and visited[successor] <= new_g:
                continue
            visited[successor] = new_g
            new_h = manhattan(successor)
            new_f = new_g + new_h
            new_path = path + [move]
            heapq.heappush(heap, (new_f, new_g, successor, new_path))
    return None, None

def ida_star(initial_state):
    initial_state = tuple(initial_state)
    goal = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0)
    threshold = manhattan(initial_state)
    while True:
        result, next_threshold = search(initial_state, 0, threshold, [], set())
        if result is not None:
            return result, len(result)
        if next_threshold == float('inf'):
            return None, None
        threshold = next_threshold

def search(state, g, threshold, path, visited):
    h = manhattan(state)
    f = g + h
    if f > threshold:
        return None, f
    if state == (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0):
        return path, f
    min_threshold = float('inf')
    visited.add(state)
    for move, successor in get_successors(state):
        if successor in visited:
            continue
        new_path = path + [move]
        res, nt = search(successor, g + 1, threshold, new_path, visited.copy())
        if res is not None:
            return res, nt
        if nt < min_threshold:
            min_threshold = nt
    visited.discard(state)
    return None, min_threshold

if __name__ == "__main__":
    # Example initial state (solvable)
    # initial_state = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14, 0]
    initial_state = [
        ( 1, 2, 4, 8, 5, 7, 11, 10, 13, 15, 0, 3, 14, 6, 9, 12 ),
        ( 14, 10, 6, 0, 4, 9, 1, 8, 2, 3, 5, 11, 12, 13, 7, 15 ),
        ( 5, 1, 3, 4, 2, 7, 8, 12, 9, 6, 11, 15, 0, 13, 10, 14 ),
        ( 6, 10, 3, 15, 14, 8, 7, 11, 5, 1, 0, 2, 13, 12, 9, 4 ),
        ( 11, 3, 1, 7, 4, 6, 8, 2, 15, 9, 10, 13, 14, 12, 5, 0 ),
        ( 0, 5, 15, 14, 7, 9, 6, 13, 1, 2, 12, 10, 8, 11, 4, 3 ),
    ]

    for i, state in enumerate(initial_state):
        print(f"Puzzle {i+1}:")

        # # Check if the puzzle is solvable
        # if not is_solvable(state):
        #     print("  This puzzle is not solvable.")
        #     continue

        # Run A* algorithm
        start_time = time.time()
        a_path, a_length = a_star(state)
        a_time = time.time() - start_time
        
        # Run IDA* algorithm
        start_time = time.time()
        ida_path, ida_length = ida_star(state)
        ida_time = time.time() - start_time
        
        # Print results
        print("  A* Algorithm:")
        print(f"    Solution Length: {a_length}")
        print(f"    Steps: {a_path}", )
        print(f"    Time Elapsed: {a_time:.5f} seconds\n")
        
        print("  IDA* Algorithm:")
        print(f"    Solution Length: {ida_length}")
        print(f"    Steps: {ida_path}")
        print(f"    Time Elapsed: {ida_time:.5f} seconds")