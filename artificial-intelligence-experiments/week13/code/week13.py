import gymnasium as gym
import random
import math
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from collections import deque
import matplotlib.pyplot as plt

# Hyperparameters
BATCH_SIZE = 64
GAMMA = 0.99
EPS_START = 1.0
EPS_END = 0.05
EPS_DECAY = 500
TARGET_UPDATE = 10
MEMORY_CAPACITY = 10000
LR = 1e-3
NUM_EPISODES = 200

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class DQN(nn.Module):
    def __init__(self, num_inputs, num_outputs):
        super(DQN, self).__init__()
        self.layers = nn.Sequential(
            nn.Linear(num_inputs, 128),
            nn.ReLU(),
            nn.Linear(128, 128),
            nn.ReLU(),
            nn.Linear(128, num_outputs)
        )

    def forward(self, x):
        return self.layers(x)

class ReplayMemory:
    def __init__(self, capacity):
        self.memory = deque(maxlen=capacity)

    def push(self, transition):
        self.memory.append(transition)

    def sample(self, batch_size):
        return random.sample(self.memory, batch_size)

    def __len__(self):
        return len(self.memory)

def select_action(state, steps_done, policy_net, n_actions):
    eps_threshold = EPS_END + (EPS_START - EPS_END) * math.exp(-1. * steps_done / EPS_DECAY)
    if random.random() < eps_threshold:
        return torch.tensor([[random.randrange(n_actions)]], device=device, dtype=torch.long)
    with torch.no_grad():
        return policy_net(state).max(1)[1].view(1, 1)

def optimize_model(memory, policy_net, target_net, optimizer):
    if len(memory) < BATCH_SIZE:
        return
    transitions = memory.sample(BATCH_SIZE)
    batch = list(zip(*transitions))
    
    state_batch = torch.cat(batch[0])
    action_batch = torch.cat(batch[1])
    reward_batch = torch.cat(batch[2])
    non_final_mask = torch.tensor(tuple(map(lambda s: s is not None, batch[3])), device=device, dtype=torch.bool)
    non_final_next_states = torch.cat([s for s in batch[3] if s is not None]) if any(s is not None for s in batch[3]) else None
    
    state_action_values = policy_net(state_batch).gather(1, action_batch)
    
    next_state_values = torch.zeros(BATCH_SIZE, device=device)
    with torch.no_grad():
        if non_final_next_states is not None:
            next_state_values[non_final_mask] = target_net(non_final_next_states).max(1)[0]
    
    expected_state_action_values = (next_state_values * GAMMA) + reward_batch.squeeze()
    
    loss = nn.functional.mse_loss(state_action_values.squeeze(), expected_state_action_values)
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()

def main():
    env = gym.make('CartPole-v0')
    n_actions = env.action_space.n
    state_dim = env.observation_space.shape[0]
    
    policy_net = DQN(state_dim, n_actions).to(device)
    target_net = DQN(state_dim, n_actions).to(device)
    target_net.load_state_dict(policy_net.state_dict())
    target_net.eval()
    
    optimizer = optim.Adam(policy_net.parameters(), lr=LR)
    memory = ReplayMemory(MEMORY_CAPACITY)
    
    steps_done = 0
    episode_durations = []
    episode_rewards = []
    solved = False
    solved_episode = None
    extra_episodes = 10
    for i_episode in range(NUM_EPISODES):
        observation, info = env.reset()
        state = torch.tensor([observation], device=device, dtype=torch.float)
        total_reward = 0
        for t in range(1, 10000):
            action = select_action(state, steps_done, policy_net, n_actions)
            steps_done += 1
            next_state, reward, terminated, truncated, info = env.step(action.item())
            done = terminated or truncated
            total_reward += reward

            reward_tensor = torch.tensor([reward], device=device)
            if not done:
                next_state_tensor = torch.tensor([next_state], device=device, dtype=torch.float)
            else:
                next_state_tensor = None

            memory.push((state, action, reward_tensor, next_state_tensor))
            state = next_state_tensor if next_state_tensor is not None else None

            optimize_model(memory, policy_net, target_net, optimizer)
            if done:
                print("Episode {} finished after {} timesteps, total reward: {}".format(i_episode, t, total_reward))
                break
            episode_rewards.append(total_reward)
            if i_episode % TARGET_UPDATE == 0:
                target_net.load_state_dict(policy_net.state_dict())

            if total_reward == 200:
                if not solved:
                    solved = True
                    solved_episode = i_episode
                    print("Reward reached 200 at episode {}. Continuing for {} extra episodes to confirm convergence.".format(i_episode, extra_episodes))
            if solved and (i_episode - solved_episode) >= extra_episodes:
                print("Training converged at episode {} after extra iterations.".format(i_episode))
                break

    plt.figure()
    plt.plot(episode_rewards)
    plt.xlabel("Episode")
    plt.ylabel("Total Reward")
    plt.title("Reward Curve")
    plt.savefig("reward_curve.png")
    plt.show()
    env.close()

if __name__ == '__main__':
    main()
