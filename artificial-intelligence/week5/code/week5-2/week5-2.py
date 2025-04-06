import heapq
import time

def heuristic(state):
    def manhattan_distance(state):
        distance = 0
        for i in range(4):
            for j in range(4):
                tile = state[i * 4 + j]
                if tile == 0: continue
                target_i, target_j = divmod(tile - 1, 4)
                distance += abs(i - target_i) + abs(j - target_j)
        return distance

    def linear_conflict(state):
        conflict = 0
        for i in range(4):
            for j in range(4):
                x = state[i * 4 + j]
                if x == 0: continue
                target_i, target_j = divmod(x - 1, 4)
                if target_i == i and j < target_j:
                    conflict += 2
        return conflict

    return manhattan_distance(state) * 2 + linear_conflict(state)

def get_neighbors(state):
    # Find blank (0) position and generate moves
    zero_index = state.index(0)
    i, j = divmod(zero_index, 4)
    neighbors = []
    for di, dj in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        new_i, new_j = i + di, j + dj
        if 0 <= new_i < 4 and 0 <= new_j < 4:
            new_index = new_i * 4 + new_j
            new_state = list(state)
            new_state[zero_index], new_state[new_index] = new_state[new_index], new_state[zero_index]
            neighbors.append(tuple(new_state))
    return neighbors

def reconstruct_path(came_from, current):
    path = [current]
    while current in came_from:
        current = came_from[current]
        path.append(current)
    return path[::-1]

def goal_state():
    # Goal state: tiles 1-15 and blank as 0
    return tuple(range(1, 16)) + (0,)

def a_star(start):
    open_set = []
    heapq.heappush(open_set, (heuristic(start), 0, start))
    came_from = {}
    g_score = {start: 0}
    visited = set()

    while open_set:
        _, current_cost, current = heapq.heappop(open_set)
        if current == goal_state():
            return reconstruct_path(came_from, current)
        if current in visited:
            continue
        visited.add(current)
        for neighbor in get_neighbors(current):
            tentative_g = current_cost + 1
            if tentative_g < g_score.get(neighbor, float('inf')):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f_score = tentative_g + heuristic(neighbor)
                heapq.heappush(open_set, (f_score, tentative_g, neighbor))
    return None

def main():
    start = (1, 2, 3, 4,
             5, 6, 7, 8,
             9, 10, 11, 12,
             13, 15, 14, 0)
    print("Initial state:")
    t0 = time.time()
    path = a_star(start)
    t1 = time.time()
    if path is None:
        print("No solution found.")
    else:
        print("Solution found in", len(path)-1, "moves")
        print("Elapsed time:", t1 - t0, "seconds")

if __name__ == '__main__':
    main()
