= 1

== (a)

_Solution._ Given $alpha = 1, gamma = 0.9$, by the Bellman equation, we have

$ Q_1(3, L) = R(3, L) + gamma dot max{ Q(2, U), Q(2, L), Q(2, R) } = 6.2 $

== (b)

_Solution._ Given $alpha = 0.2, gamma = 0.8$, we apply Temporal Difference learning to the path

$ 1 stretch(->, size: #2em)^R 2 stretch(->, size: #2em)^U 5 stretch(->, size: #2em)^R 6 $

- Step 1:

$ Q_1(1, R) = (1 - alpha)Q_1(1, R) + alpha(r + gamma dot max Q(2, alpha')) = 3.48 $

- Step 2:

$ Q_1(2, U) = (1 - alpha)Q_1(2, U) + alpha(r + gamma dot max Q(5, alpha')) = 5.88 $

- Step 3:

$ Q_1(5, R) = (1 - alpha)Q_1(5, R) + alpha(r + gamma dot max Q(6, alpha')) = 8.4 $



= 2

== (a)

_Solution._ Let $x$ denote node "?". By definition,

$ V_1(x) &= 0.5 times (10 + 0) + 0.5 times (1.02 + 0.2 times (-1.3) + 0.4 times 2.7 + 0.4 times V(x)) \
         &= 5.92 + 0.2 dot V(x) $

== (b)

_Solution._ We first label the nodes from up to down, left to right, starting from 0. Then, we have

$ Q_1(1, "Play") = -1 + 1 times (-2.3) = -3.3 $

$ Q_1(1, "Quit") = 0 + 1 times (-1.3) = -1.3 $

$ Q_1(2, "Play") = -1 + 1 times (-2.3) = -3.3 $

$ Q_1(2, "Study") = -2 + 1 times 2.7 = 0.7 $

$ Q_1(3, "Sleep") = 0 + 1 times 0 = 0 $

$ Q_1(3, "Study") = -2 + 1 times V(x) = V(x) - 2 $

$ Q_1(x, "Pub") = 1.02 + 1 times (0.2 times (-1.3) + 0.4 times 2.7 + 0.4 times V(x)) = 1.84 + 0.4 V(x) $

$ Q_1(x, "Study") = 10 + 1 times 0 = 10 $

= 3

== (a)

_Solution._ Assuming the initial values are all 0, we first calculate how the value of $s_1$ changes for each Markov Decision Process:

- For MDP 1:

$ V_(n + 1)(s_1) &= 1/(1 + 1) times (0 + V_(n)(s_1)) + 1/(1 + 1) times (1 + V_(n)(s_2)) \
  V_(n + 1)(s_2) &= 1/(1 + 1) times (0 + V_(n)(s_1)) + 1/(1 + 1) times (0 + V_(n)(s_2)) $

  Then we have $V_1(s_1) = 0.5, V_1(s_2) = 0$, and $V_(k)(s_1) - V_(k)(s_2) = 0.5$ for all $k > 0$. Hence

$ V_(n + 1)(s_1) = V_(n)(s_1) + 0.25 $

  for all $n > 0$. Therefore, we can make $V_(n)(s_1)$ reach infinity with MDP 1.

- For MDP 2:

$ V_(n + 1)(s_1) &= 1/(1 + 1) times (0 + V_(n)(s_1)) + 1/(1 + 1) times (0 + V_(n)(s_2)) \
  V_(n + 1)(s_2) &= 1/(1 + 1) times (1 + V_(n)(s_1)) + 1/(1 + 1) times (1 + V_(n)(s_2)) $

  Then we have $V_1(s_1) = 0, V_1(s_2) = 1$, and $V_(k)(s_1) - V_(k)(s_2) = -1$ for all $k > 0$. Hence

$ V_(n + 1)(s_1) = V_(n)(s_1) + 0.5 $

  for all $n > 0$. Therefore, we can make $V_(n)(s_1)$ reach infinity with MDP 2.
