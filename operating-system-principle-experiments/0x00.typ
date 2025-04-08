#import "@preview/codly:1.2.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/gentle-clues:1.2.0": *

#show: codly-init.with()

// Import the template...
#import "templates/report.typ": *
// and show it!
#show: report.with(
  title: "实验报告",
  subtitle: "实验零：实验准备",
  name: "元朗曦",
  stuid: "23336294",
  class: "计算机八班",
  major: "计算机科学与技术",
  institude: "计算机学院",
)

== 1 配置实验环境

  实验环境为 Arch Linux
  #figure(image("assets/0x00/fastfetch.png"))

  上的 Docker #emoji.whale 虚拟环境。

  === 1.1 安装项目开发环境

    根据实验要求编写 `Dockerfile` 如下：
    ```Dockerfile
    FROM ubuntu:22.04 AS build

    RUN apt-get update && apt-get install -y \
        build-essential \
        gdb \
        qemu-system-x86 \
        rustup \
        && rm -rf /var/lib/apt/lists/*
    ```
    编写 `docker-compose.yaml` 如下：
    ```yaml
    name: yatsenos

    services:
      dev:
        image: "yatsenos"
        container_name: "yatsenos_dev"
        volumes:
          - "./main:/app"
        working_dir: "/app"
        command: "sleep infinity"
    ```
    项目源码位于本地 `main` 文件夹中。

== 2 尝试使用 Rust 进行编程

  + 使用 Rust 编写一个程序，完成以下任务：
    - 创建一个函数 ```rs count_down(seconds: u64)```，该函数接收一个 u64 类型的参数，表示倒计时的秒数，每秒输出剩余的秒数，直到倒计时结束，然后输出 `Countdown finished!`。
    - 创建一个函数 ```rs read_and_print(file_path: &str)```，该函数接收一个字符串参数，表示文件的路径，使用 ```rs io::Result<()>``` 作为返回值，并使用 `?` 将错误向上传递。
    - 创建一个函数 ```rs file_size(file_path: &str) -> Result<u64, &str>```，该函数接收一个字符串参数，表示文件的路径。函数应该尝试打开文件，并在 ```rs Result``` 中返回文件大小。如果文件不存在，函数应该返回一个包含 `File not found!` 字符串的 ```rs Err```。
    - 在 ```rs main``` 函数中，按照如下顺序调用上述函数：
      - 首先调用 ```rs count_down(5)``` 函数进行倒计时；
      - 然后调用 ```rs read_and_print("/etc/hosts")``` 函数尝试读取并输出文件内容；
      - 最后使用 ```rs std::io``` 获取几个用户输入的路径，并调用 ```rs file_size``` 函数尝试获取文件大小，并处理可能的错误。
    ```rs
    use::std::thread;
    use::std::time::Duration;

    fn count_down(seconds: u64) {
        for i in (0..=seconds).rev() {
            println!("Remaining: {} second(s).", i);
            thread::sleep(Duration::from_secs(1));
        }
    
        println!("Countdown finished!");
    }
    
    use std::fs;
    use std::io;
  
    fn read_and_print(file_path: &str) -> io::Result<()> {
        let file = fs::read_to_string(file_path)?;
        println!("{}", file);

        Ok(())
    }
    
    fn file_size(file_path: &str) -> Result<u64, &str> {
        let metadata = fs::metadata(file_path).map_err(|_| "File not found!")?;

        Ok(metadata.len())
    }
    
    fn main() -> io::Result<()> {
        count_down(5);
    
        match read_and_print("/etc/hosts") {
            Err(e) => eprintln!("Error: {}", e),
            Ok(_) => println!("File read successfully!"),
        }
    
        let mut input = String::new();
    
        loop {
            io::stdin().read_line(&mut input)?;
    
            let file_path = input.trim();
    
            match file_size(file_path) {
                Err(e) => eprintln!("Error: {}", e),
                Ok(size) => println!("File size: {}B.", size)
            }
    
            input.clear();
        }
    }
    ```

  + 实现一个进行字节数转换的函数，并格式化输出：
    - 实现函数 ```rs humanized_size(size: u64) -> (f64, &'static str)``` 将字节数转换为人类可读的大小和单位；
    - 补全测试代码，使实现能够通过测试。
    ```rs
    #![allow(dead_code)]

    fn humanized_size(size: u64) -> (f64, &'static str) {
        const UNITS: [&str; 4] = [ "B", "KiB", "MiB", "GiB" ];
    
        let mut size = size as f64;
        let mut unit = UNITS[0];
    
        for &u in &UNITS {
            if size < 1024.0 {
                unit = u;
                break;
            }
            size /= 1024.0;
        }
    
        (size, unit)
    }
    
    fn main() {}
    
    #[cfg(test)]
    mod tests {
        use super::*;
    
        #[test]
        fn test_humanized_size() {
            let byte_size = 1554056;
    
            let (size, unit) = humanized_size(byte_size);
            assert_eq!("Size: 1.4821 MiB", format!("Size: {:.4} {}", size, unit));
        }
    }
    ```

  + 自行搜索学习如何利用现有的 ```rs crate``` 在终端中输出彩色的文字，输出一些带有颜色的字符串，并尝试直接使用 ```rs print!``` 宏输出一到两个相同的效果。尝试输出如下格式和内容：
    - `INFO: Hello, world!`，其中 `INFO:` 为绿色，后续内容为白色；
    - `WARNING: I'm a teapot!`，颜色为黄色，加粗，并为 `WARNING` 添加下划线；
    - `ERROR: KERNEL PANIC!!!`，颜色为红色，加粗，并尝试让这一行在控制行窗口居中。
    ```rs
    use colored::Colorize;
    use crossterm::terminal;
    
    fn main() -> Result<(), std::io::Error> {
        println!("{}, Hello world!", "INFO:".green());
        println!(
            "{}",
            format!("{}: I'm a teapot!", "WARNING".underline())
                .bold()
                .yellow()
        );
    
        let (width, _) = terminal::size()?;
        println!(
            "{:^width$}",
            "ERROR: KERNEL PANIC!!!".bold().red(),
            width = width as usize
        );
    
        Ok(())
    }
    ```
  
  + 使用 ```rs enum``` 对类型实现同一化，实现一个名为 `Shape` 的枚举，并为它实现 ```rs pub fn area(&self) -> f64``` 方法，用于计算不同形状的面积，并使之能够通过测试。
    ```rs
    #![allow(dead_code)]
    
    enum Shape {
      Circle { radius: f64 },
      Rectangle { width: f64, height: f64 },
    }
    
    impl Shape {
      pub fn area(&self) -> f64 {
          match self {
              Shape::Circle { radius } => std::f64::consts::PI * radius * radius,
              Shape::Rectangle { width, height } => width * height,
          }
      }
    }
    
    fn main() {}
    
    #[cfg(test)]
    mod tests {
      use super::*;
    
      #[test]
      fn test_area() {
          let rectangle = Shape::Rectangle {
              width: 10.0,
              height: 20.0,
          };
          let circle = Shape::Circle { radius: 10.0 };
    
          assert_eq!(rectangle.area(), 200.0);
          assert_eq!(circle.area(), 314.1592653589793);
      }
    }
    ```

  + 实现一个元组结构体 ```rs UniqueId(u16)```，使得每次调用 ```rs UniqueId::new()``` 时总会得到一个新的不重复的 ```rs UniqueId```，并使之能够通过测试。
    ```rs
    #![allow(dead_code)]
    
    use std::sync::atomic::{AtomicU16, Ordering};
    
    #[derive(Debug, PartialEq, Eq)]
    struct UniqueId(u16);
    
    impl UniqueId {
        fn new() -> Self {
            static COUNTER: AtomicU16 = AtomicU16::new(0);
            UniqueId(COUNTER.fetch_add(1, Ordering::Relaxed))
        }
    }
    
    fn main() {}
    
    #[cfg(test)]
    mod tests {
        use super::*;
    
        #[test]
        fn test_unique_id() {
            let id1 = UniqueId::new();
            let id2 = UniqueId::new();
            assert_ne!(id1, id2);
        }
    }
    ```

== 3 运行 UEFI Shell

=== 3.1 初始化仓库

  终端运行下列指令：
  ```sh
  # Clone the repository to local machine.
  git clone https://github.com/YatSenOS/YatSenOS-Tutorial-Volume-2.git ysos
  # Copy neccessary files and clean up the rest.
  mv ./ysos/src/0x00 ./main && rm -rf ./ysos
  # Start docker container "yatsenos_dev" and attach to it.
  docker compose up -d && docker compose exec dev /bin/bash
  ```

=== 3.2 
  终端运行：
  ```sh
  qemu-system-x86_64 -bios ./assets/OVMF.fd -net none -nographic
  ```
  得到如下输出：
  #local(number-format: none)[
    ```
    UEFI Interactive Shell v2.2
    EDK II
    UEFI v2.70 (EDK II, 0x00010000)
    Mapping table
         BLK0: Alias(s):
              PciRoot(0x0)/Pci(0x1,0x1)/Ata(0x0)
    Press ESC in 2 seconds to skip startup.nsh or any other key to continue.
    Shell> 
    ```
  ]
  符合预期。

== 4 YSOS 启动！

=== 4.1 配置 Rust Toolchain

  终端运行：
  ```rs
  rustup show
  ```
  以下载并安装 `rust-toolchain.toml` 中指定的工具链。
  #info()[
    为了 `rustup-v1.28.0` 中存在无法自动根据 `rust-toolchain.toml` 下载安装工具链的问题，我们弃用了 Rust 官方推荐的安装方式（使用 `curl` 安装），改为使用 Ubuntu 24.04 的包管理器安装系统自带的 `rustup-v1.26.0` 版本。然而在我们经历重重调试后终于在 Docker 中成功配置工具链后的二十分钟内，`rustup` 便紧急发布了 `v1.28.1` 版本修复了上述问题。
  ]

=== 4.2 运行第一个 UEFI 程序

  完善 pkg/boot/src/main.rs 中的代码，使用学号进行输出：
  ```rs
  #![no_std]
  #![no_main]
  
  #[macro_use]
  extern crate log;
  extern crate alloc;
  
  use core::arch::asm;
  use uefi::{Status, entry};
  
  #[entry]
  fn efi_main() -> Status {
      uefi::helpers::init().expect("Failed to initialize utilities");
      log::set_max_level(log::LevelFilter::Info);
  
      let std_num = 23336294;
  
      loop {
          info!("Hello World from UEFI bootloader! @ {}", std_num);
  
          for _ in 0..0x10000000 {
              unsafe {
                  asm!("nop");
              }
          }
      }
  }
  ```
  在项目根目录下运行 ```sh make run``` 或 ```sh python ysos.py run```，得到如下输出：
  #local(number-format: none)[
    ```
    BdsDxe: failed to load Boot0001 "UEFI QEMU DVD-ROM QM00003 " from PciRoot(0x0)/Pci(0x1,0x1)/Ata(Secondary,Master,0x0): Not Found
    BdsDxe: loading Boot0002 "UEFI QEMU HARDDISK QM00001 " from PciRoot(0x0)/Pci(0x1,0x1)/Ata(Primary,Master,0x0)
    BdsDxe: starting Boot0002 "UEFI QEMU HARDDISK QM00001 " from PciRoot(0x0)/Pci(0x1,0x1)/Ata(Primary,Master,0x0)
    [ INFO]: pkg/boot/src/main.rs@019: Hello World from UEFI bootloader! @ 23336294
    [ INFO]: pkg/boot/src/main.rs@019: Hello World from UEFI bootloader! @ 23336294
    ```
  ]
  符合预期。