#set text(
  font: "Noto Sans CJK SC",
  lang: "zh",
)

= 1

== (1)

$ P(macron(E) macron(S) macron(M) macron(B)) = P(macron(E)) P(macron(M)) P(macron(B)|macron(M)) P(macron(S)|macron(E) macron(M)) = dots = 0.4374. $

== (2)

$ P(B) = P(B|M) P(M) + P(B|macron(M)) P(macron(M)) = 1.0 times 0.1 + 0.1 times 0.9 = 0.19. $

== (3)

$ P(M|B) = (P(B|M) P(M))/(P(B)) = (1.0 times 0.1)/0.19 approx 0.53. $

== (4)

$ P(M|S B E) = (P(E) P(M) P(S|E M) P(B|M))/(P(E) P(B) (P(S|E M) P(M|B) + P(S|E macron(M)) P(macron(M)|B))) = dots approx 0.58. $

== (5)

由独立性知 $P(E|M) = P(E) = 0.4.$

= 2

首先计算整体熵：

$ "Entropy"(S) = -2/5 dot log_2(2/5) - -3/5 dot log_2(3/5) approx 0.97094. $

之后分别计算每个属性的信息增益：

$ "Entropy"("天气") = 2/5 dot 0 + 1/5 dot 0 + 2/5 dot 0 = 0, \
  "Gain"("天气") = "Entropy"(S) - "Entropy"("天气") approx 0.97. $

$ "Entropy"("高") = -2/3 dot log_2(2/3) - 1/3 dot log_2(1/3) approx 0.918, \
  "Entropy"("湿度") approx 3/5 dot 0.918 + 2/5 dot 0 approx 0.5508, \
  "Gain"("湿度") = "Entropy"(S) - "Entropy"("湿度") approx 0.42 $

故属性“天气”更适合作为根节点。

= 3

假设损失函数定义为：

$ L = 1/2(y - t)^2, $

则算法流程可用如下伪代码表示：
```C
// 前向传播
// 隐藏层神经元 h1
z1 = x1*w1 + x2*w2 = 1*0.5 + 0.5*1.5 = 1.25
h1 = ReLU(z1) = 1.25  // 因为 1.25 > 0

// 隐藏层神经元 h2
z2 = x1*w3 + x2*w4 = 1*2.3 + 0.5*3 = 3.8
h2 = ReLU(z2) = 3.8

// 输出层
net_y = h1*w5 + h2*w6 = 1.25*1 + 3.8*1 = 5.05
y = ReLU(net_y) = 5.05

// 计算损失 L = 1/2*(y - t)^2, 其中 t = 4

// 反向传播
// 输出节点梯度
delta_output = (y - t)*dReLU(net_y) = (5.05 - 4)*1 = 1.05

// 更新隐藏层到输出层的权重
dL/dw5 = delta_output * h1 = 1.05 * 1.25 = 1.3125
w5_new = w5 - 0.1*(1.3125) = 1 - 0.13125 = 0.86875

// 对隐藏层节点 h1 的梯度（只对 h1 求导）
delta_h1 = dReLU(z1) * (w5 * delta_output) = 1 * (1 * 1.05) = 1.05

// 对输入到 h1 的权重 w1 的梯度
dL/dw1 = delta_h1 * x1 = 1.05 * 1 = 1.05
w1_new = w1 - 0.1*(1.05) = 0.5 - 0.105 = 0.395
```

即经过一轮反向传播后，新权重为：
$ w_5^+ &approx 0.86875, \
  w_1^+ &approx 0.395. $

= 4

== (1)

采用步长 $S = 1$，填充 $P = 1$，对每个通道先填充 $0$ 得到 $5 times 5$ 矩阵。

- 卷积核 1 得到特征图 $Y_1$:
  ```
  2  6  6  2
  6  9  6  7
  6  6 12  4
  2  7  4  3
  ```

- 卷积核 2 得到特征图 $Y_2$:
  ```
  1 -3 -3  1
  3  0  3  2
  1  3  3  1
  3  8  5  4
  ```

输出尺寸验证：
$ "宽" = "高" = ((3 + 2 times 1 - 2) / 1) + 1 = 4 $
因此卷积结果均为 $4 times 4$。

== (2)

假设采用 $2 times 2$ 池化窗口、步长 $2$。

对 $Y_1$ 进行池化：

- 平均池化：
  ```
  5.75 5.25
  5.25 5.75
  ```

- 最大池化：
  ```
  9  7
  7 12
  ```

对 $Y_2$ 进行池化：

- 平均池化：
  ```
  0.25 0.75
  3.75 3.25
  ```

- 最大池化：
  ```
  3 3
  8 5
  ```
