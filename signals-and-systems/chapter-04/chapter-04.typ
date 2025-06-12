#import "@preview/lilaq:0.3.0" as lq

#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #body
]

= 4.21

== (g)

#solution[
  By equation (4.9),

  $
    X(j omega) = integral_(-2)^(-1) -e^(-j omega t) dif t + integral_(-1)^1 t e^(-j omega t) dif t + integral_1^2 e^(-j omega t) dif t = (2 j)/omega (cos 2 omega - (sin omega)/omega).
  $
]

== (h)

#solution[
  Let $x_1(t) = sum_(k = -oo)^oo delta(t - 2 k)$. Then

  $
    x(t) = 2 x_1(t) + x_1(t - 1).
  $

  Hence

  $
    X(j omega) = X_1(j omega) (2 + e^(-j omega)) = pi sum_(k = -oo)^oo delta(omega - k pi) (2 + (-1)^k).
  $
]

= 4.22

== (a)

#solution[
  Let

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
]

== (d)

#solution[
  Since

  $
    e^(j omega_0 t) <-->^cal(F) 2 pi delta(omega - omega_0),
  $

  we have

  $
    x(t) = 1/pi (e^(j t) - e^(-j t)) + 3/(2 pi) (e^(j 2 pi t) + e^(-j 2 pi t)) = 2/pi sin t + 3/pi cos 2 pi t.
  $
]

= 4.25

== (a)

#solution[
  Let $x_1(t) = x(t + 1)$. Then $x_1(t)$ is a real and even signal. Hence $X_1(j omega)$ is also real and even. This implies that $angle.spheric X_1(j omega) = 0$. Since $X_1(j omega) = e^(j omega) X(j omega)$, we have $angle.spheric X(j omega) = -omega$.
]

== (b)

#solution[
  $
    X(j 0) = integral_(-oo)^oo x(t) dif t = 7.
  $
]

== (c)

#solution[
  $
    integral_(-oo)^oo X(j omega) dif omega = lr(integral_(-oo)^oo X(j omega) e^(j omega t) dif omega|)_(t = 0) = 2 pi x(0) = 4 pi.
  $
]

== (d)

#solution[
  Let

  $
    x_1(t) = cases(
      1\, quad & |t| < 1,
      0\, quad & "otherwise",
    )
  $

  and $x_2(t) = x_1(t + 1)$. Then the given integral is

  $
    integral_(-oo)^oo X(j omega) X_2(j omega) dif omega = lr(2 pi (x(t) * y(t))|)_(t = 0) = 7 pi.
  $
]

= 4.28

== (a)

#solution[
  We know that

  $
    p(t) = sum_(n = -oo)^oo a_n e^(j n omega_0 t) <-->^cal(F) P(j omega) = 2 pi sum_(n = -oo)^oo a_n delta(omega - n omega_0).
  $

  Hence

  $
    Y(j omega) = 1/(2 pi) (X(j omega) * P(j omega)) = sum_(n = -oo)^oo a_n X(j (omega - n omega_0)).
  $
]

= 4.35

== (a)

#solution[
  $
    norm(H(j omega)) = sqrt((a - j omega)/(a + j omega) dot ((a - j omega)/(a + j omega))^*) = sqrt((a - j omega)/(a + j omega) dot (a + j omega)/(a - j omega)) = 1.
  $

  $
    angle.spheric H(j omega) = angle.spheric(a - j omega) - angle.spheric(a + j omega) = -arctan omega/a - arctan omega/a = -2 arctan omega/a.
  $

  $
    H(j omega) = (2 a)/(a + j omega) - 1 quad => quad h(t) = 2 a e^(a t) u(t) - delta(t).
  $
]

== (b)

#solution[
  Since $a = 1$, we have

  $
    norm(H(j omega)) = 1, quad angle.spheric H(j omega) = -2 arctan omega.
  $

  Hence

  $
    y(t) &= cos(t/sqrt(3) - 2 arctan 1/sqrt(3)) + cos(t - 2 arctan 1) + cos(sqrt(3) t - 2 arctan sqrt(3)) \
         &= cos(t/sqrt(3) - pi/3) + cos(t - pi/2) + cos(sqrt(3) t - (2 pi)/3).
  $

  #let xs = lq.linspace(0, 10)
  #let sqrt3 = calc.sqrt(3)
  #figure(
    lq.diagram(
      width: 10cm,
      lq.plot(
        xs,
        xs.map(x => calc.cos(x / sqrt3) + calc.cos(x) + calc.cos(sqrt3 * x)),
        mark: none,
        label: [$x(t)$],
      )
    ),
  )
  #figure(
    lq.diagram(
      width: 10cm,
      lq.plot(
        xs,
        xs.map(x => calc.cos(x / sqrt3 - calc.pi / 3) + calc.cos(x - calc.pi / 2) + calc.cos(sqrt3 * x - 2 * calc.pi / 3)),
        mark: none,
        label: [$y(t)$],
      )
    ),
  )
]

= 4.36

== (a)

#solution[
  The frequency response is

  $
    H(j omega) = Y(j omega)/X(j omega) = (2/(1 + j omega) - 2/(4 + j omega))/(1/(1 + j omega) + 1/(3 + j omega)) = (3 (3 + j omega))/((2 + j omega) (4 + j omega)).
  $
]

== (b)

#solution[
  The impulse response is

  $
    h(t) = cal(F)^(-1) {H(j omega)} = cal(F)^(-1) lr({3/2 (1/(2 + j omega) + 1/(4 + j omega))}) = 3/2 (e^(-2 t) + e^(-4 t)) u(t).
  $
]

== (c)

#solution[
  Note that $a_0 = 9, a_1 = 3, b_0 = 8, b_1 = 6, b_2 = 1$. Hence the differencial equation is

  $
    9 x(t) + 3 (dif x(t))/(dif t) = 8 y(t) + 6 (dif y(t))/(dif t) + (dif^2 y(t))/(dif t^2).
  $
]
