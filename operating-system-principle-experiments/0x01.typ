#import "@preview/codly:1.2.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/gentle-clues:1.2.0": *

#show: codly-init.with()

// Import the template...
#import "templates/report.typ": *
// and show it!
#show: report.with(
  title: "实验报告",
  subtitle: "实验一：操作系统的启动",
  name: "元朗曦",
  stuid: "23336294",
  class: "计算机八班",
  major: "计算机科学与技术",
  institude: "计算机学院",
)

== 1 编译内核 ELF

与常规实验中直接将内核编译为二进制文件不同，本实验需要将内核编译为 ELF 格式的文件，并将它存储在 UEFI 可以访问的文件系统中。

在 `pkg/kernel` 目录下运行
```sh
cargo build --release
```
之后找到编译产物，为
```
target/x86_64-unknown-none/release/ysos_kernel
```
使用 ```sh readelf -h``` 命令查看其基本信息，输出
```
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           Advanced Micro Devices X86-64
  Version:                           0x1
  Entry point address:               0xffffff00000022d0
  Start of program headers:          64 (bytes into file)
  Start of section headers:          51736 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         7
  Size of section headers:           64 (bytes)
  Number of section headers:         12
  Section header string table index: 10
```
- 由 `Machine` 行可知其为 x86_64 架构，与配置文件一致。
- 由 `Entry` 行可知其入口点为 `0xffffff00000022d0`，由 `kernel.ld` 链接文件控制。

== 2 在 UEFI 中加载内核

=== 2.1 加载相关文件

+ 加载配置文件：加载配置文件，解析其中的内核栈大小、内核栈地址等内容；

  在 `pkg/boot/main.rs` 中对应位置作以下修改：
  ```rs
  // 1. Load config
  let mut file = open_file(CONFIG_PATH);
  let buf = load_file(&mut file);
  let config = config::Config::parse(buf);
  ```

+ 加载内核 ELF：根据配置文件中的信息，加载内核 ELF 文件到内存中，并将其加载为 `ElfFile` 以便进行后续的操作。

  在 `pkg/boot/main.rs` 中对应位置作以下修改：
  ```rs
  // 2. Load ELF files
  let mut file = open_file(config.kernel_path);
  let buf = load_file(&mut file);
  let elf = ElfFile::new(buf).unwrap();
  ```

#info()[
  加载相关文件后，```rs set_entry``` 函数会通过修改一个 ```rs static mut``` 变量来指定内核的入口点，因此是 ```rs unsafe``` 的。
]

=== 2.2 更新控制寄存器

  使用 `Cr0` 寄存器禁用根页表的写保护，在 `pkg/boot/main.rs` 中对应位置作以下修改：
  ```rs
  // DONE: root page table is readonly, disable write protect (Cr0)
  unsafe {
      Cr0::update(|f| f.remove(Cr0Flags::WRITE_PROTECT));
  }
  ```

=== 2.3 映射内核文件

  ```rs
  // DONE: map physical memory to specific virtual address offset
  elf::map_physical_memory(
      config.physical_memory_offset,
      max_phys_addr,
      &mut page_table,
      &mut UEFIFrameAllocator,
  );

  // DONE: load and map the kernel elf file
  let _ = elf::load_elf(
      &elf,
      config.physical_memory_offset,
      &mut page_table,
      &mut UEFIFrameAllocator,
  );

  // DONE: map kernel stack
  let _ = elf::map_range(
      config.kernel_stack_address,
      config.kernel_stack_size,
      &mut page_table,
      &mut UEFIFrameAllocator,
  );

  // DONE: recover write protect (Cr0)
  unsafe {
      Cr0::update(|f| f.insert(Cr0Flags::WRITE_PROTECT));
  }
  ```

=== 2.4 跳转执行

+ 退出启动时服务：通过调用 exit_boot_services 退出启动时服务，这样 UEFI 将会回收一些内存资源、退出对硬件的控制，从而将控制权交给内核。
+ 跳转到内核：通过调用 jump_to_entry 跳转到内核的入口点，开始执行内核代码。

  `pkg/boot/main.rs` 中相关内容如下：
  ```rs
  // 6. Exit boot and jump to ELF entry
  info!("Exiting boot services...");

  let mmap = unsafe { uefi::boot::exit_boot_services(MemoryType::LOADER_DATA) };
  // NOTE: alloc & log are no longer available

  // construct BootInfo
  let bootinfo = BootInfo {
      memory_map: mmap.entries().copied().collect(),
      physical_memory_offset: config.physical_memory_offset,
      system_table,
  };

  // align stack to 8 bytes
  let stacktop = config.kernel_stack_address + config.kernel_stack_size * 0x1000 - 8;

  jump_to_entry(&bootinfo, stacktop);
  ```

#info()[
  + `jump_entry` 函数负责将控制权从引导加载程序转移到内核，其中 `bootinfo` 变量包含了要传递给内核的参数。跳转后会执行 `entry_point!` 宏，导出一个名为 `start` 的外部函数，验证传入函数的签名是否正确（接受一个 `BootInfo` 引用并永不返回），然后使用 `boot_info` 参数来调用用户提供的函数。

  + 内核直接访问物理内存主要有以下几种方式：
  
    - 直接映射（Direct Mapping）
    
      内核在其虚拟地址空间中预留一块区域，将物理内存按照固定偏移量直接映射到这块区域内。这样，在访问对应虚拟地址时，会直接定位到相应的物理内存位置。例如，在 x86 平台上，经常将物理内存映射到内核区间（如 PAGE_OFFSET 所指向的区域）。
  
    - 页表重新映射
  
      通过操作页表，可以将虚拟地址和物理地址建立特定的映射关系。内核可以在运行时修改或增加映射，比如在需要访问特定硬件地址或共享内存时，临时改变某区域的映射方式。
  
    - 利用 I/O 内存映射接口（如 ioremap）
  
      对于访问硬件寄存器或内存映射 I/O 区域，许多内核（例如 Linux 内核）提供了 ioremap 等 API，将物理地址映射到内核虚拟地址，并供驱动程序使用。通常这种方法也是通过修改和建立页表映射来实现的。
  
    我们的代码中主要采用直接映射方式。

  + ELF 文件描述的是程序在静态链接时确定的各个段（例如代码段、数据段、BSS 段等）。由于栈是进程运行时动态分配的一块内存区域，大小和位置并非在编译或链接阶段确定，所以 ELF 文件中并不会描述栈的起始地址、大小或其他相关数据，而是在程序运行时由操作系统决定。

  + 内核或启动加载程序在系统启动或进程创建时，会为每个执行上下文分配一段内存作为栈空间。在内核环境下，早期就会预先在内存中为内核初始化一块区域作为内核栈，并在启动代码中将堆栈指针寄存器（如 x86 平台上的 ESP 或 RSP）设置为该区域的顶部。在用户进程中，loader（加载器）在设置程序的虚拟地址空间时，也会为代码以外的其它区域（包括栈）进行相应的分配和初始化。

  + 虽然从理论上讲，栈可以放在内存的任意一块区域，但实际上需要满足以下条件：
    - 合法性和安全性：必须处于有效的内存区域内，并且不能与程序的其它段（例如代码段、数据段）或操作系统内核使用的区域重叠。
    - 对齐要求：大多数架构对堆栈的起始地址和对齐有特定要求，以便在访问和调用函数时能快速而正确地计算地址。
    - 内存映射的一致性：在有分页特性的系统中，栈区域除了要合法之外，还要映射到实际的物理内存地址；同时在发生栈溢出、动态扩展时也需要考虑相应管理机制。
    因此，虽然理论上内存中可以选取任意区域作为栈，但实际中其位置和大小通常由内核或运行时环境预先固定下来，以满足资源管理和安全要求。
]

=== 2.5 调试内核

我们采用在终端中直接运行 `gdb` 的方式进行调试，调试界面如下：
#figure(image("assets/0x01/gdb.png"), caption: [])

- 运行 ```sh make build DBG_INFO=true``` 编译内核并开启调试信息；
- 运行 ```sh make debug``` 启动 QEMU 并进入调试模式；
- 在另一个终端中，运行 ```sh gdb -q``` 进入 GDB 调试环境；
- 依次运行
  ```
  file esp/KERNEL.ELF
  target remote localhost:1234
  b ysos_kernel::init
  ```
  加载内核文件，连接到 QEMU，并设置断点；
- 在 ```sh gdb``` 中运行 `c` 继续执行至断点处，汇编和符号正确。

#info()[
  在 `gdb` 中可以使用 `layout asm`，`layout reg`，`layout src` 进入对应模式查看汇编、寄存器、源码信息，键入 `Ctrl + x + a` 可以退出。`DEBUG_INFO=true` 参数会使编译代码时加入调试符号以供 `gdb` 调试。
]

== 3 UART 与日志输出

=== 3.1 串口驱动

我们将实现一个简单的串口驱动，并将其用于内核的日志输出。

==== 3.1.1 被保护的全局静态对象

在 Rust 中对全局变量的写入是一个 ```rs unsafe``` 操作，因为这是线程不安全的，如果直接使用全局静态变量，编译器会进行报错。但是对于 “串口设备” 这一类静态的全局对象我们确实需要进行一些数据存储，为了内存安全，就会不可避免的引入了互斥锁来进行保护。

#info()[
  在 `pkg/boot/src/lib.rs` 中的 `ENTRY` 同样是全局静态变量，使用了 ```rs unsafe``` 处理。
]

==== 3.1.2 串口驱动的设计

// 在考虑 IO 设备驱动（SerialPort）的设计时，我们需要考虑如下问题：
// + 为了描述驱动的状态，需要存储哪些数据？
// + 需要如何与硬件进行交互？
// + 与硬件交互的过程中，需要考虑哪些并发问题？
// + 驱动需要向内核提供哪些接口？

为了与串口设备进行交互，我们使用 COM1 端口，它的基地址为 `0x3F8`。

我们通过偏移量来访问串口设备的寄存器，使用 `x86_64` crate 中的 `Port` 类型与寄存器交互。串口设备的寄存器均为 8 位，故我们使用 ```rs u8``` 类型来进行读写操作。

==== 3.1.3 串口驱动的实现

串口设备的驱动实现主要由初始化、发送数据、接收数据三部分组成。

参考 #link("https://wiki.osdev.org/Serial_Ports")[Serial_Ports - OSDev] 中提供的如下示例代码，编写这部分驱动的 Rust 实现：

```rs
/// Initializes the serial port.
#[allow(clippy::identity_op)]
pub fn init(&self) {
    // DONE: Initialize the serial port
    const PORT: u16 = 0x3F8; // COM1

    unsafe {
        let mut port: Port<u8> = Port::new(PORT + 1);
        port.write(0x00); // Disable all interrupts.
        let mut port: Port<u8> = Port::new(PORT + 3);
        port.write(0x80); // Disable DLAB (set baud rate divisor).
        let mut port: Port<u8> = Port::new(PORT + 0);
        port.write(0x03); // Set divisor to 3 (lo byte) 38400 baud.
        let mut port: Port<u8> = Port::new(PORT + 1);
        port.write(0x00); //                  (hi byte).
        let mut port: Port<u8> = Port::new(PORT + 3);
        port.write(0x03); // 8 bits, no parity, one stop bit.
        let mut port: Port<u8> = Port::new(PORT + 2);
        port.write(0xC7); // Enable FIFO, clear them, with 14-byte threshold.
        let mut port: Port<u8> = Port::new(PORT + 4);
        port.write(0x0B); // IRQs enabled, RTS/DSR set.
        let mut port: Port<u8> = Port::new(PORT + 4);
        port.write(0x1E); // Set in loopback mode, test the serial chip.
        let mut port: Port<u8> = Port::new(PORT + 0);
        port.write(0xAE); // Test serial chip (send byte 0xAE and check if serial returns same byte).
        
        // Check if serial is faulty (i.e: not same byte as sent).
        if port.read() != 0xAE {
            panic!("Serial is falty.");
        };

        // If serial is not faulty set it in normal operation mode.
        let mut port: Port<u8> = Port::new(PORT + 4);
        port.write(0x0F);
    }
}

/// Sends a byte on the serial port.
#[allow(clippy::identity_op)]
pub fn send(&mut self, data: u8) {
    // DONE: Send a byte on the serial port
    const PORT: u16 = 0x3F8; // COM1

    unsafe {
        let mut rdi: Port<u8> = Port::new(PORT + 5);
        let mut rax: Port<u8> = Port::new(PORT + 0);

        while (rdi.read() & 0x20) == 0 {}
        rax.write(data);
    }
}

/// Receives a byte on the serial port no wait.
#[allow(clippy::identity_op)]
pub fn receive(&mut self) -> Option<u8> {
    // FIXME: Receive a byte on the serial port no wait
    const PORT: u16 = 0x3F8; // COM1

    unsafe {
        let mut rdi: Port<u8> = Port::new(PORT + 5);
        let mut rax: Port<u8> = Port::new(PORT + 0);

        if (rdi.read() & 0x01) == 0 {
            None
        } else {
            Some(rax.read())
        }
    }
}
```

==== 3.1.4 串口驱动的测试

运行 `make launch` 后得到如下输出：

#figure(image("assets/0x01/portest.png"), caption: [])

说明串口驱动已经成功初始化。

=== 3.2 日志输出

为了获取更好的日志管理，我们将使用 `log` crate 来进行日志输出，并将其输出接入到前文所实现的串口驱动中。

在 `pkg/kernel/src/utils/logger.rs` 中

```rs
pub fn init() {
    static LOGGER: Logger = Logger;
    log::set_logger(&LOGGER).unwrap();

    // DONE: Configure the logger
    log::set_max_level(log::LevelFilter::Trace);

    info!("Logger Initialized.");
}

impl log::Log for Logger {
    ...

    fn log(&self, record: &Record) {
        // DONE: Implement the logger with serial output
        let prefix = match record.level() {
            log::Level::Error => "\x1b[1;31mERROR:",
            log::Level::Warn => "\x1b[1;33mWARNING:",
            log::Level::Info => "\x1b[0;32mINFO:",
            log::Level::Debug => "\x1b[0;37mDEBUG:",
            log::Level::Trace => "\x1b[0;30mTRACE:",
        };
        println!("{} {} \x1b[0;39m", prefix, record.args());
    }

    ...
}
```

实现初始化和输出功能。对不同级别的日志，我们使用不同颜色加以区分，如图 2 中所示。

=== 3.3 Panic 处理

改写 `panic_handler`，使之能够输出 `panic` 发生的位置。

```rs
#[allow(dead_code)]
#[cfg_attr(target_os = "none", panic_handler)]
fn panic(info: &core::panic::PanicInfo) -> ! {
    // force unlock serial for panic output
    unsafe { SERIAL.get().unwrap().force_unlock() };

    if let Some(location) = info.location() {
        error!(
            "ERROR: panic at file '{}' line {}\n\n{:#?}",
            location.file(),
            location.line(),
            info
        );
    } else {
        error!("ERROR: panic!\n\n{:#?}", info);
    }

    loop {}
}
```