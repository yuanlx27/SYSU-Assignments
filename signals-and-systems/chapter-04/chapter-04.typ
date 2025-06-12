//#show math.equation: set text(font: "Libertinus Math")

= 4.21

== (g)

*_Solution._* By equation (4.9),

$
  X(j omega) = integral_(-2)^(-1) -e^(-j omega t) dif t + integral_(-1)^1 t e^(-j omega t) dif t + integral_1^2 e^(-j omega t) dif t = (2 j)/omega (cos 2 omega - (sin omega)/omega).
$

== (h)

Let $x_1(t) = sum_(k = -oo)^oo delta(t - 2 k)$. Then

$
  x(t) = 2 x_1(t) + x_1(t - 1).
$

Hence

$
  X(j omega) = X_1(j omega) (2 + e^(-j omega)) = pi sum_(k = -oo)^oo delta(omega - k pi) (2 + (-1)^k).
$

= 4.22

== (a)

*_Solution._* Let

$
  x_1(t) = cases(
    1\, quad & |t| < 3,
    0\. quad & "otherwise",
  )
$

Then

$
  X_1(j omega) = (2 sin 3 omega)/omega.
$

Since $X(j omega) = X_1(j (omega - 2 pi))$, we have

$
  x(t) = e^(j 2 pi t) x_1(t) = cases(
    e^(j 2 pi t)\, quad & |t| < 3,
    0\. quad & "otherwise",
  )
$

== (d)

*_Solution._* Since

$
  e^(j omega_0 t) <-->^cal(F) 2 pi delta(omega - omega_0),
$

we have

$
  x(t) = 1/pi (e^(j t) - e^(-j t)) + 3/(2 pi) (e^(j 2 pi t) + e^(-j 2 pi t)) = 2/pi sin t + 3/pi cos 2 pi t.
$

= 4.25

== (a)

*_Solution._* Let $x_1(t) = x(t + 1)$. Then $x_1(t)$ is a real and even signal. Hence $X_1(j omega)$ is also real and even. This implies that $angle.spheric X_1(j omega) = 0$. Since $X_1(j omega) = e^(j omega) X(j omega)$, we have $angle.spheric X(j omega) = -omega$.

== (b)

*_Solution._* $X(j 0) = integral_(-oo)^oo x(t) dif t = 7$.

== (c)

*_Solution._* $integral_(-oo)^oo X(j omega) dif omega = lr(integral_(-oo)^oo X(j omega) e^(j omega t) dif omega|)_(t = 0) = 2 pi x(0) = 4 pi$.

== (d)

= 4.28

== (a)

= 4.35

= 4.36
