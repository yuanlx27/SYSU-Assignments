// Import the template...
#import "templates/report.typ": *
// and show it!
#show: report.with(
  title: "实验报告",
  subtitle: "实验三：内核线程与多核异常",
  name: "元朗曦",
  stuid: "23336294",
  class: "计算机八班",
  major: "计算机科学与技术",
  institude: "计算机学院",
)

#import "@preview/codly:1.2.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/gentle-clues:1.2.0": *

#show: codly-init.with()



= 2 合并实验代码

在 `pkg/kernel/src/utils` 文件夹中，增量代码补充包含了如下的模块：

- `regs.rs`：对需要保存的一系列寄存器进行了封装，规定了其输出方式，补全了进程切换时需要使用的汇编代码及 `as_handler` 宏。

- `func.rs`：定义了用于测试执行的两个函数，其中 `test` 用以验证进程调度、并发的正确性，`huge_stack` 用以验证处理缺页异常的正确性。

在 `pkg/kernel/src/proc` 文件夹中，增量代码补充包含了如下的模块：

- `context.rs`：进程上下文的定义和实现，其中包含了加载、保存进程上下文的相关函数。

- `data.rs`：进程数据结构体的定义，这里存储的数据在进程被杀死后会被释放，包含了使用 Arc 保护的线程间共享的数据（子进程相关内容将在下次实验中使用）。

- `vm/{mod.rs,stack.rs}`：进程的虚拟内存管理，包含了栈空间的分配和释放函数，以及一些常量的定义。

- `manager.rs`：进程管理器的定义和实现，时钟中断最终会通过进程管理器来进行任务切换。

- `paging.rs`：进程页表的存储、切换所用数据，使用 `load` 函数加载进程页表到 Cr3 寄存器，使用 `clone` 函数来获得当前页表的副本，用于创建新进程。

- `pid.rs`：使用元组结构体将一个 `u16` 作为进程 ID，需要为 `new` 函数确保获取唯一的 PID。

- `processor.rs`：对处理器的抽象，使用 `AtomicU16` 来存储当前正在运行的进程的 PID，使用 `set_pid` 函数来设置当前进程的 PID，使用 `get_pid` 函数来获取当前进程的 PID。

- `process.rs`：进程结构体的核心实现，包含了进程的状态、调度计数、退出返回值、父子关系、中断上下文等内容，是管理进程的核心模块。

#warning(title: "注意")[
  增量代码在 `pkg/kernel/Cargo.toml` 中添加了对 `volatile` 包的依赖，但没有修改根目录的 `Cargo.toml`，这导致 `rust-analyzer` 在我们打开项目内的 Rust 代码时输出警告。

  解决办法是在根目录的 `Cargo.toml` 中 ```toml [workspace.dependencies]``` 块的末尾添加
  ```toml
    volatile = { version = "0.5.0", default-features = false }
  ```
]

= 3 进程管理器的初始化
