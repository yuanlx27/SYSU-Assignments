import math
import random
import sys
import time

# Parse .tsp file (TSPLIB format)
def read_tsp(filename):
    coords = []
    with open(filename) as f:
        found = False
        for line in f:
            line = line.strip()
            if line.upper().startswith("NODE_COORD_SECTION"):
                found = True
                continue
            if found:
                if line == "EOF" or line == "":
                    continue
                parts = line.split()
                if len(parts) < 3:
                    continue
                coords.append((float(parts[1]), float(parts[2])))
    return coords

def distance(city1, city2):
    return math.hypot(city1[0] - city2[0], city1[1] - city2[1])

def tour_length(tour, cities):
    total = 0
    for i in range(len(tour)):
        total += distance(cities[tour[i]], cities[tour[(i+1) % len(tour)]])
    return total

def tournament_selection(population, fitnesses, k=5):
    selected = random.sample(list(zip(population, fitnesses)), k)
    selected.sort(key=lambda x: x[1])
    return selected[0][0]

def order_crossover(parent1, parent2):
    size = len(parent1)
    a, b = sorted(random.sample(range(size), 2))
    child = [None] * size
    child[a:b+1] = parent1[a:b+1]
    p2_index = (b + 1) % size
    c_index = (b + 1) % size
    while None in child:
        if parent2[p2_index] not in child:
            child[c_index] = parent2[p2_index]
            c_index = (c_index + 1) % size
        p2_index = (p2_index + 1) % size
    return child

def swap_mutation(tour, mutation_rate):
    tour = tour[:]
    for i in range(len(tour)):
        if random.random() < mutation_rate:
            j = random.randint(0, len(tour)-1)
            tour[i], tour[j] = tour[j], tour[i]
    return tour

def genetic_algorithm(cities, pop_size=100, mutation_rate=0.02, generations=500):
    num_cities = len(cities)
    population = [random.sample(range(num_cities), num_cities) for _ in range(pop_size)]
    best_tour = None
    best_length = float('inf')
    for gen in range(generations):
        fitnesses = [tour_length(tour, cities) for tour in population]
        for tour, fit in zip(population, fitnesses):
            if fit < best_length:
                best_length = fit
                best_tour = tour
        new_population = []
        for _ in range(pop_size):
            parent1 = tournament_selection(population, fitnesses)
            parent2 = tournament_selection(population, fitnesses)
            child = order_crossover(parent1, parent2)
            child = swap_mutation(child, mutation_rate)
            new_population.append(child)
        population = new_population
        if gen % 50 == 0:
            print(f"Generation {gen}: Best length = {best_length:.2f}")
    return best_tour, best_length

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python week5-4.py <path_to_tsp_file>")
        sys.exit(1)
    tsp_file = sys.argv[1]
    cities = read_tsp(tsp_file)
    if not cities:
        print("No cities found in the TSP file.")
        sys.exit(1)
    random.seed(42)
    start_time = time.perf_counter()
    best_tour, best_len = genetic_algorithm(cities, pop_size=200, mutation_rate=0.05, generations=500)
    elapsed = time.perf_counter() - start_time
    print("Best tour:", best_tour)
    print("Tour length: {:.2f}".format(best_len))
    print("Elapsed time: {:.2f} seconds".format(elapsed))
