== 一、选择题

=== 1-4

ABCD

\

== 二、简答题

=== 1

系统调用的目的是让用户程序能够请求操作系统提供的服务．具体地说，系统调用是用户程序与操作系统内核之间的接口，用户程序通过系统调用可以访问底层硬件资源或执行特权操作，例如文件读写、进程控制、内存管理、设备管理等．系统调用确保了用户程序在安全可控的环境下运行，同时保护系统资源不被滥用．

=== 2

#[


==== 优点

+ *模块化和结构化设计*：

  分层方法将操作系统划分为多个层次，每一层只与相邻的上下层交互，结构清晰，易于理解和维护．各层功能独立，便于单独开发、测试和修改．

+ *简化开发和调试*：

  由于层次之间的接口明确，开发人员可以专注于某一层的实现，而不需要关心其他层的细节．调试时可以逐层排查问题，降低了调试复杂性．

+ *可移植性强*：

  底层硬件相关的部分通常放在最底层，上层与硬件无关，因此操作系统可以更容易地移植到不同的硬件平台上．

+ *增强可靠性和安全性*：

  每一层只需要信任相邻的上下层，减少了系统的复杂性，降低了错误传播的风险．可以通过分层隔离保护关键资源，提高系统的安全性．

+ *易于扩展*：

  新的功能可以通过添加新的层次来实现，而不会影响现有层次的结构．

==== 缺点

+ *性能开销大*：

  分层设计可能导致过多的层次间调用，增加上下文切换的开销，从而影响系统性能．每一层的操作可能需要通过多层传递，导致效率降低．

+ *设计复杂*：

  确定层次的划分和接口设计需要精心规划，如果层次划分不合理，可能会导致系统效率低下或功能冗余．某些功能可能难以严格划分到某一层中，导致设计上的困难．

+ *灵活性受限*：

  分层结构的严格性可能限制了某些优化操作，例如跨层次的直接访问可能会被禁止．

+ *可能引入冗余*：

  某些功能可能在多个层次中重复实现，导致代码冗余．

]

=== 3

+ *通过寄存器传递参数*：将参数直接存储在 CPU 的寄存器中，操作系统从寄存器中读取这些参数；

+ *通过内存块（或表）传递参数*：将参数存储在内存中的某个区域（如栈或堆），然后将该内存块的起始地址通过寄存器传递给操作系统；

+ *通过栈传递参数*：将参数压入程序栈中，操作系统从栈中读取参数．

=== 4

==== 优势

+ *模块化和简化内核设计*：

  微内核只包含最核心的功能，代码量少，结构清晰，易于维护和扩展．其他功能以独立的服务形式运行，模块化程度高．

+ *高可靠性和安全性*：

  由于大部分服务运行在用户态，一个服务的崩溃不会导致整个系统崩溃．微内核可以通过严格的权限控制保护核心功能，提高系统的安全性．

+ *可移植性强*：

  微内核与硬件相关的部分较少，便于移植到不同的硬件平台．

+ *灵活性高*：

  用户可以根据需要动态加载或卸载服务，定制操作系统的功能．支持多种操作系统服务共存（如不同的文件系统或网络协议栈）．

+ *易于调试和测试*：

  内核代码量少，易于调试和验证．用户态服务可以单独测试，降低了系统开发的复杂性．

==== 交互

在微内核架构中，用户程序和系统服务通过进程间通信（IPC）机制进行交互．

==== 缺点

+ *性能开销大*：

  由于用户程序和系统服务之间需要通过 IPC 机制通信，频繁的上下文切换和消息传递会导致性能下降．相比于宏内核，微内核的系统调用和 IPC 开销较大．

+ *设计复杂*：

  虽然微内核本身简单，但设计高效的 IPC 机制和用户态服务需要较高的技术水平．系统服务的划分和接口设计需要精心规划．

+ *兼容性问题*：

  某些现有的应用程序可能依赖于宏内核的特性，迁移到微内核架构可能需要修改应用程序．

+ *资源占用高*：

  每个用户态服务都需要独立的内存空间和资源，可能导致整体资源占用较高．

\

== 三、编程题

=== 1. 下载内核

下载 Linux 内核（版本 5.10.235）并解压：
```sh
curl -O https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.235.tar.xz
tar -x -f linux-5.10.235.tar.xz linux-5.10.235
```

=== 2. 创建系统调用

创建相关目录及文件：
```sh
cd linux-5.10.235
mkdir mycall && touch mycall/mycall.c
```
编辑 `mycall/mycall.c` 内容，实现一个成功输出 ```c "Hello world"``` 的系统调用：
```c
#include <linux/kernel.h>
#include <linux/syscalls.h>

SYSCALL_DEFINE1(mycall, char __user *, buf)
{
        printk("Hello world\n");
        return 0;
}
```
创建 `mycall/Makefile`，内容如下：
```make
obj-y := mycall.o
```
将 `mycall/` 添加到内核 `Makefile` 中：
```make
# ...
core-y                  += kernel/ certs/ mm/ fs/ ipc/ security/ crypto/ mycall/
# ...
```
将 `sys_mycall` 添加到 `arch/x86_64/entry/syscalls/syscall_64.tbl` 系统调用表：
```
335     64      mycall                  sys_mycall
```
将 sys_mycall 添加到头文件 `include/linux/syscalls.h` 末尾：
```c
// ...
asmlinkage long sys_mycall(char __user * buf);
#endif
```

=== 3. 编译并加载内核

之后编译内核．首先安装依赖：
```sh
sudo apt update && sudo apt install -y bc bison flex gcc libelf-dev libncurses5-dev libssl-dev pahole
```
然后运行
```sh
sudo make menuconfig
sudo make -j "$( nproc )"
```
最后运行
```sh
sudo make modules_install install && sudo reboot
```
安装内核并重启，重启时在 UEFI 界面选择 5.10.235 内核．

=== 4. 检验

重启后运行
```sh
uname -r
```
输出为
#figure(image(scaling: "smooth", "assets/HW-2/kernel.png"))
代表内核加载成功．

创建一个 `test_kernel.c` 文件，内容如下：
```c
#include <stdio.h>
#include <sys/syscall.h>
#include <unistd.h>

#define SYSCALL_ID 335

int main() {
    long result = syscall(SYSCALL_ID);
    if (result == -1) {
        perror("syscall failed");
        return 1;
    }
    return 0;
}
```
编译并运行：
```sh
gcc "test_kernel.c" -o "test_kernel" && ./test_kernel
```
再运行：
```sh
sudo dmesg | tail
```
输出（部分）为
#figure(image(scaling: "smooth", "assets/HW-2/syscall.png"))
代表系统调用创建并加载成功．