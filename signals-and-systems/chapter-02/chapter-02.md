# Chapter 2

## 2.20

$$
\int_{-\infty}^{\infty} u_{0}(t) \cos(t) \mathop{dt} = \cos(0) = 1. \tag{a}
$$

$$
\int_{0}^{5} \sin(2 \pi t) \delta(t + 3) \mathop{dt} = \int_{0}^{5} 0 = 0. \tag{b}
$$

$$
\int_{-5}^{5} u_{1}(1 - \tau) \cos(2 \pi \tau) \mathop{d \tau} = \int_{-5}^{1} \cos(2 \pi \tau) \mathop{d \tau} = \left.\frac{1}{2 \pi} \sin(2 \pi \tau)\right|_{-5}^{1} = 0. \tag{c}
$$

## 2.21

(a) By definition, we have

$$
y[n] = x[n] * h[n] = \sum_{k = -\infty}^{\infty} x[k] h[n - k].
$$

If $n < 0$, then $y[n] = 0$, otherwise

$$
y[n] = \beta^{n} \sum_{k = 0}^{n} \left(\frac{\alpha}{\beta}\right)^{k} = \frac{\beta^{n + 1} - \alpha^{n + 1}}{\beta - \alpha}.
$$

## 2.22

\(c\) The desired convolution is

$$
y(t) = \int_{-\infty}^{\infty} x(\pi \tau) h(t - \tau) \mathop{d\tau} = \int_{0}^{2} \sin(\pi \tau) h(t - \tau) \mathop{d\tau}.
$$

Hence

$$
y(t) = \begin{cases}
    0, & t < 1 \\
    \frac{2}{\pi} (1 - \cos(\pi (t - 1))), & 1 \leqslant t < 3 \\
    \frac{2}{\pi} (\cos(\pi (t - 3)) - 1), & 3 \leqslant t < 5 \\
    0. & 5 \leqslant t
\end{cases}
$$

## 2.28

\(c\) Not causal because $h[n] > 0$ for $n < 0$. Unstable because $\sum_{-\infty}^{0} \left(\frac{1}{2}\right)^{n} = \infty$.
