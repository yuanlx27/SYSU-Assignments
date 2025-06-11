import numpy as np
import matplotlib.pyplot as plt

k = np.array([0, 1, 2, 3])
sqrt2 = np.sqrt(2)
a_k = 1/4 + ((2 - sqrt2)/4) * np.cos(np.pi/2 * k)

plt.figure(figsize=(10,4))

# Magnitude
plt.subplot(1, 2, 1)
plt.stem(k, np.abs(a_k))
plt.title('Magnitude of $a_k$')
plt.xlabel('k')
plt.ylabel('|a_k|')

# Phase
plt.subplot(1, 2, 2)
plt.stem(k, np.angle(a_k))
plt.title('Phase of $a_k$')
plt.xlabel('k')
plt.ylabel('Phase (radians)')
plt.yticks([0])

plt.tight_layout()
plt.savefig("3-28-c.png")
