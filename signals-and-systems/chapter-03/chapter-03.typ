#show math.equation: set text(font: "Libertinus Math")

= 3.21

*_Solution._* Using the synthesis equation, we get

$
  x(t) = a_(1)e^(j omega_(0)t) + a_(-1)e^(-j omega_(0)t) + a_(5)e^(5j omega_(0)t) + a_(-5)e^(-5j omega_(0)t),
$

where $omega_(0) = (2pi)/T = pi/4$. Hence

$
  x(t) = -2sin(pi/4 t) + 4cos((5pi)/4 t) = -2cos(pi/4 t - pi/2) + 4cos((5pi)/4 t).
$

= 3.22

== (b)

*_Solution._* By equation (3.37),

$
  a_(k) = 1/T integral_(T)x(t)e^(-j k (2pi)/T t) d t = 1/2 integral_(-1)^(1)e^(-(j k pi + 1)t) d t = ((-1)^(k))/(2(j k pi + 1))(e - e^(-1)).
$

Hence

$
  x(t) = sum_(k = -oo)^(oo)((-1)^(k))/(2(j k pi + 1))(e - e^(-1))e^(j k pi t)
$

= 3.28

== (c)

*_Solution._* By equation (3.93),

$
  a_(k) = 1/4 sum_(n = 0)^(3) x[n]e^(-j k (2pi)/N n) = 1/4(1 + (1 - sqrt(2)/2)e^(-j k pi/2) + 0 + (1 - sqrt(2)/2)e^(-j k (3pi)/2)) = 1/4 + (2 - sqrt(2))/4cos pi/2k.
$

The figure below plots the magnitude and phase of $a_k$.

#figure(
  image("assets/3-28-c.png")
)

= 3.34

By equation (3.6),

$
  H(j omega) = integral_(-oo)^oo e^(-4 |tau|) e^(-j omega tau) d tau = integral_(-oo)^0 e^(4 tau) e^(-j omega tau) d tau + integral_0^oo e^(-4 tau) e^(-j omega tau) d tau = 1/(4 - j omega) + 1/(4 + j omega).
$

== (c)

*_Solution._* From the figure we can see that $T = 1, omega = 2 pi$, and when $-1/2 <= t <= 1/2$,

$
  x(t) = cases(
    1\, quad & -1/4 <= t <= 1/4,
    0\. quad & "otherwise",
  )
$

Hence

$
  a_k = integral_(-1/4)^(1/4) e^(-2 j k pi t) d t = (sin (k pi)/2)/(k pi),
$

$
  b_k = H(2 j k pi) a_k = 8/(16 + 4 k^2 pi^2) dot (sin (k pi)/2)/(k pi).
$

= 3.35

*_Solution._* Let $b_k = H(j k (2 pi)/T) a_k = H(j 14 k) a_k$ denote the Fourier series coefficients of $y(t)$. If $y(t) = x(t)$, then $b_k = a_k$ for all $k$. Since $H(j omega) = 0$ for $|omega| < 250$, $a_k$ must be zero for $|k| < floor.l 250/14 floor.r = 17$.
