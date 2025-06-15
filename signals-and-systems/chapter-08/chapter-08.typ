#let proof(body) = block(width: 100%, inset: 8pt)[
  *_Proof._* #body
  #place(bottom + right, math.qed)
]
#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #body
]

= 8.24

== (a)

#proof[
  Since $s(t) = sum_(k = -oo)^oo delta(t - k T)$, we have

  $
    S(j omega) = (2 pi)/T sum_(k = -oo)^oo delta(omega - (2 pi k)/T) = omega_c sum_(k = -oo)^oo delta(omega - k omega_c).
  $

  Let $x_1(t) = x(t) s(t)$. Then

  $
    X_1(j omega) = 1/(2 pi) (X(j omega) * S(j omega)) = omega_c/(2 pi) sum_(k = -oo)^oo X(j (omega - k omega_c)).
  $

  Hence

  $
    Y(j omega) = X_1(j omega) H(j omega) = (A omega_c)/(2 pi) X(j (omega - omega_c)) + (A omega_c)/(2 pi) X(j (omega + omega_c)).
  $

  Applying the inverse Fourier transform, we obtain

  $
    y(t) = (A omega_c)/(2 pi) e^(j omega_c) x(t) + (A omega_c)/(2 pi) e^(-j omega_c) x(t) = (A omega_c)/pi x(t) cos omega_c t.
  $
]

== (b)

#proof[
  Using the same reasoning as in (a), but with $Delta != 0$, we obtain

  $
    y(t) = (A omega_c)/pi x(t) cos(omega_c t - omega_c Delta).
  $
]

== (c)

#solution[
  $ omega_M <= omega_c/2 = pi/T. $
]

= 8.34

#solution[
  Let $w(t)$ denote the output of the squarer. Then
  $
    w(t) = (x(t) + cos omega_c t)^2 = x^2(t) + cos^2 omega_c t + 2 x(t) cos omega_c t.
  $
  Our filter should reject $x^2(t) + cos^2 omega_c t$ and multiply the remainder by $1/2$. Therefore, we require
  $
    A = 1/2, quad omega_l = omega_c - omega_M > 2 omega_M, quad omega_h = omega_c + omega_M < 2 omega_c,
  $
  which implies $omega_M < omega_c/3$.
]
