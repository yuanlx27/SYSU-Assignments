// Import the template...
#import "templates/report.typ": *
// and show it!
#show: report.with(
  title: "实验报告",
  subtitle: "实验六：硬盘驱动与文件系统",
  name: "元朗曦",
  stuid: "23336294",
  class: "计算机八班",
  major: "计算机科学与技术",
  institude: "计算机学院",
)

#import "@preview/codly:1.3.0": *
#show: codly-init

#import "@preview/codly-languages:0.1.8": *
#codly(languages: codly-languages)

#import "@preview/gentle-clues:1.2.0": *



= 合并实验代码

在 `pkg/kernel/src/proc/vm` 中：

- `heap.rs` 添加了 `Heap` 结构体，用于管理堆内存。

- `mod.rs` 添加了堆内存、ELF 文件映射的初始化和清理函数。

= 帧分配器的内存回收

在进行帧分配器初始化的过程中，内核从 BootLoader 获取到了一个 `MemoryMap` 数组，其中包含了所有可用的物理内存区域，并且内核使用 `into_iter()` 将这一数据结构的所有权交给了一个迭代器。

迭代器是懒惰的，只有在需要时才会进行计算，因此系统在进行逐帧分配时，并没有额外的内存开销。但是，当需要进行内存回收时，我们就需要额外的数据结构来记录已经分配的帧，以便进行再次分配。

相对于真实的操作系统，本实验中的内存回收是很激进的：能回收时就回收，不考虑回收对性能的影响。在实际的操作系统中，内存回收是一个复杂的问题，需要考虑到内存的碎片化、内存的使用情况、页面的大小等细节；进而使用标记清除、分段等策略来减少内存回收的频率和碎片化。

因此对于本实验的帧分配器来说，内存回收的操作是非常简单的，只需要将已经分配的帧重新加入到可用帧的集合中即可。

在 `pkg/kernel/src/memory/frames.rs`，中，修改 `BootInfoFrameAllocator` 结构体，添加一个 `recycled` 字段，用 `Vec` 存储已经分配的帧，以便进行内存回收：
```rust
/// A FrameAllocator that returns usable frames from the bootloader's memory map.
pub struct BootInfoFrameAllocator {
    size: usize,
    used: usize,
    frames: BootInfoFrameIter,
    recycled: Vec<PhysFrame>,
}
```
之后为 `BootInfoFrameAllocator` 实现 `allocate_frame` 和 `deallocate_frame` 方法：
```rust
unsafe impl FrameAllocator<Size4KiB> for BootInfoFrameAllocator {
    fn allocate_frame(&mut self) -> Option<PhysFrame> {
        // Try to recycle a frame first.
        if let Some(frame) = self.recycled.pop() {
            Some(frame)
        } else {
            self.used += 1;
            self.frames.next()
        }
    }
}

impl FrameDeallocator<Size4KiB> for BootInfoFrameAllocator {
    unsafe fn deallocate_frame(&mut self, frame: PhysFrame) {
        // DONE: deallocate frame (not for lab 2)
        self.recycled.push(frame);
    }
}
```

= 用户程序的内存统计

在目前的实现中，用户程序在进程结构体中记录的内存区域只有栈区，堆区由内核进行代劳，同时 ELF 文件映射的内存区域也从来没有被释放过，无法被其他程序复用。

相较于 Linux，本实验并没有将内存管理抽象为具有上述复杂功能的结构：用户程序的内存占用严格等同于其虚拟内存大小，并且所有页面都会被加载到物理内存中，不存在文件映射等概念，只有堆内存和栈内存是可变的。

因此，内存统计的实现并没有太多细节，只需要统计用户程序的栈区和堆区的大小即可。

在 `pkg/kernel/src/proc/vm/{stack,heap}.rs` 中，分别为 `Stack` 和 `Heap` 实现 `memory_usage` 方法来获取内存占用字节数。
```rust
// for Stack
pub fn memory_usage(&self) -> u64 {
    self.usage * crate::memory::PAGE_SIZE
}
```
```rust
// for Heap
pub fn memory_usage(&self) -> u64 {
    self.end.load(Ordering::Relaxed) - self.base.as_u64()
}
```
那么根据上述讨论，对本实验的内存统计而言，只剩下了 ELF 文件映射的内存区域和页表的内存占用。为实现简单，本部分忽略页表的内存占用，只统计 ELF 文件映射的内存占用。

获取用户程序 ELF 文件映射的内存占用的最好方法是在加载 ELF 文件时记录内存占用，这需要对 `elf` 模块中的 `load_elf` 函数进行修改：
```rust
/// Load & Map ELF file
///
/// for each segment, load code to new frame and set page table
pub fn load_elf(
    elf: &ElfFile,
    physical_offset: u64,
    page_table: &mut impl Mapper<Size4KiB>,
    frame_allocator: &mut impl FrameAllocator<Size4KiB>,
    user_access: bool,
) -> Result<Vec<PageRangeInclusive>, MapToError<Size4KiB>> {
    trace!("Loading ELF file...{:?}", elf.input.as_ptr());
    elf.program_iter()
        .filter(|segment| segment.get_type().unwrap() == program::Type::Load)
        .map(|segment| {
            load_segment(
                elf,
                physical_offset,
                &segment,
                page_table,
                frame_allocator,
                user_access,
            )
        })
        .collect()
}

// load segments to new allocated frames
fn load_segment(
    elf: &ElfFile,
    physical_offset: u64,
    segment: &program::ProgramHeader,
    page_table: &mut impl Mapper<Size4KiB>,
    frame_allocator: &mut impl FrameAllocator<Size4KiB>,
    user_access: bool,
) -> Result<PageRangeInclusive, MapToError<Size4KiB>> {
    let virt_start_addr = VirtAddr::new(segment.virtual_addr());
    let start_page = Page::containing_address(virt_start_addr);

    // ...

    let end_page = Page::containing_address(virt_start_addr + mem_size - 1u64);
    Ok(Page::range_inclusive(start_page, end_page))
}
```

之后在 `pkg/kernel/src/proc/vm/mod.rs` 中为 `ProcessVm` 实现 `load_elf_code` 方法，在加载 ELF 文件时记录内存占用：
```rust
fn load_elf_code(&mut self, elf: &ElfFile, mapper: MapperRef, alloc: FrameAllocatorRef) {
    // DONE: make the `load_elf` function return the code pages
    self.code = elf::load_elf(elf, *PHYSICAL_OFFSET.get().unwrap(), mapper, alloc, true).unwrap();

    // DONE: calculate code usage
    self.code_usage = self.code.iter().map(|range| range.size()).sum();
}
```

为了便于测试和观察，我们在 `pkg/kernel/src/proc/manager.rs` 的 `print_process_list` 和 `pkg/kernel/src/proc/process.rs` 中 `Process` 的 `fmt` 实现中，添加打印内存占用的功能：
```rust
impl ProcessManager {
    pub fn print_process_list(&self) {
        let mut output = String::from("  PID | PPID | Process Name |  Ticks  |  Memory  | Status\n");

        // ...

        let alloc = get_frame_alloc_for_sure();
        let frames_used = alloc.frames_used();
        let frames_recycled = alloc.frames_recycled();
        let frames_total = alloc.frames_total();

        let used = (frames_used - frames_recycled) * PAGE_SIZE as usize;
        let total = frames_total * PAGE_SIZE as usize;

        output += &format_usage("Memory", used, total);
        drop(alloc);

        // ...
    }

    // ...
}

// A helper function to format memory usage
fn format_usage(name: &str, used: usize, total: usize) -> String {
    let (used_float, used_unit) = humanized_size(used as u64);
    let (total_float, total_unit) = humanized_size(total as u64);

    format!(
        "{:<6} : {:>6.*} {:>3} / {:>6.*} {:>3} ({:>5.2}%)\n",
        name,
        2,
        used_float,
        used_unit,
        2,
        total_float,
        total_unit,
        used as f32 / total as f32 * 100.0
    )
}

```
```rust
impl core::fmt::Display for Process {
    fn fmt(&self, f: &mut core::fmt::Formatter) -> core::fmt::Result {
        let inner = self.inner.read();
        let (size, unit) = humanized_size(inner.proc_vm.as_ref().map_or(0, |vm| vm.memory_usage()));
        write!(
            f,
            " #{:-3} | #{:-3} | {:12} | {:7} | {:>5.1}{} | {:?}",
            self.pid.0,
            inner.parent().map(|p| p.pid.0).unwrap_or(0),
            inner.name,
            inner.ticks_passed,
            size,
            unit,
            inner.status
        )?;
        Ok(())
    }
}
```

= 用户程序的内存释放

在经过上述的讨论和实现后，目前进程的内存管理已经包含了栈区、堆区和 ELF 文件映射三部分，但是在进程退出时，这些内存区域并没有被释放，内存没有被回收，无法被其他程序复用。

不过，在我们实现了帧分配器的内存回收、进程的内存统计后，进程退出时的内存释放也将得以实现。

== 页表上下文的伏笔

在之前的实验中，我们定义了 `PageTableContext` 结构体：
```rust
pub struct PageTableContext {
    pub reg: Arc<Cr3RegValue>,
}
```
我们使用 `Arc` 这个“原子引用计数”类型来确定当前页表被多少个进程共享，从而保证在释放内存时，只有在最后一个进程退出时才释放共享的内存。

在 `pkg/kernel/src/proc/paging.rs` 中，为 `PageTableContext` 添加一个 `using_count` 方法，用于获取当前页表被引用的次数：
```rust
pub fn using_count(&self) -> usize {
    Arc::strong_count(&self.reg)
}
```

== 内存释放的实现

为了模块化设计，我们先为 `Stack` 实现 `clean_up` 函数，由于栈是一块连续的内存区域，且进程间不共享栈区，因此在进程退出时直接释放栈区的页面即可。
```rust
    pub fn clean_up(
        &mut self,
        // following types are defined in
        //   `pkg/kernel/src/proc/vm/mod.rs`
        mapper: MapperRef,
        dealloc: FrameAllocatorRef,
    ) -> Result<(), UnmapError> {
        if self.usage == 0 {
            warn!("Stack is empty, no need to clean up.");
            return Ok(());
        }

        // DONE: unmap stack pages with `elf::unmap_pages`
        let range = self.range.start.start_address().as_u64();
        elf::unmap_pages(range, self.usage, mapper, dealloc, true)?;

        self.usage = 0;

        Ok(())
    }
```

接下来为 `ProcessVm` 实现 `clean_up` 方法，依次释放栈区、堆区和 ELF 文件映射的内存区域：

+ 释放栈区：调用 `Stack` 的 `clean_up` 方法；

+ 如果当前页表被引用次数为 1，则进行共享内存的释放，否则跳至第 7 步；

+ 释放堆区：调用 `Heap` 的 `clean_up` 方法（后续实现）；

+ 释放 ELF 文件映射的内存区域：根据记录的 `code` 页面范围数组，依次调用 `elf::unmap_range` 函数，并进行页面回收。

+ 清理页表：调用 `mapper` 的 `clean_up` 函数，这将清空全部无页面映射的一至三级页表。

+ 清理四级页表：直接回收 `PageTableContext` 的 `reg.addr` 所指向的页面。

+ 统计内存回收情况，并输出调试信息。

```rust
pub(super) fn clean_up(&mut self) -> Result<(), UnmapError> {
    let mapper = &mut self.page_table.mapper();
    let dealloc = &mut *get_frame_alloc_for_sure();

    let start_count = dealloc.frames_recycled();

    // DONE: implement the `clean_up` function for `Stack`
    self.stack.clean_up(mapper, dealloc)?;

    if self.page_table.using_count() == 1 {
        // free heap
        // DONE: implement the `clean_up` function for `Heap`
        self.heap.clean_up(mapper, dealloc)?;

        // free code
        for page_range in self.code.iter() {
            elf::unmap_range(*page_range, mapper, dealloc, true)?;
        }

        unsafe {
            // free P1-P3
            mapper.clean_up(dealloc);

            // free P4
            dealloc.deallocate_frame(self.page_table.reg.addr);
        }
    }

    // DONE: maybe print how many frames are recycled
    let end_count = dealloc.frames_recycled();

    debug!("Recycled {} frames.", end_count - start_count);

    Ok(())
}
```

= 内核的内存统计

类似于用户进程的加载过程，我们可以通过在内核加载时记录内存占用来实现内核的初步内存统计，即在 BootLoader 中实现这一功能。

首先，在 `pkg/boot/src/lib.rs` 中，定义一个 `KernelPages` 类型，用于传递内核的内存占用信息，并将其添加到 `BootInfo` 结构体的定义中：
```rust
pub type KernelPages = ArrayVec<PageRangeInclusive, 8>;

pub struct BootInfo {
    // ...

    /// Kernel pages
    pub kernel_pages: KernelPages,
}
```

并在 `pkg/boot/src/main.rs` 中，将 `load_elf` 函数返回的内存占用信息传递至 `BootInfo` 结构体中：
```rust
#[entry]
fn boot_main() -> Status {
    // ...

    let vec_ranges = elf::load_elf(
        &elf,
        config.physical_memory_offset,
        &mut page_table,
        &mut UEFIFrameAllocator,
        false,
    ).expect("Failed to load kernel ELF");

    if vec_ranges.len() > 8 {
        panic!("Too many kernel pages: {}", vec_ranges.len());
    }

    // ...

    // construct BootInfo
    let bootinfo = BootInfo {
        memory_map: mmap.entries().copied().collect(),
        physical_memory_offset: config.physical_memory_offset,
        system_table,
        loaded_apps: apps,
        kernel_pages,
    };

    // align stack to 8 bytes
    let stacktop = config.kernel_stack_address + config.kernel_stack_size * 0x1000 - 8;

    jump_to_entry(&bootinfo, stacktop);
}

```

成功加载映射信息后，将其作为 `ProcessManager` 的初始化参数，用于构建 `kernel` 进程：
```rust
/// init process manager
pub fn init(boot_info: &'static BootInfo) {
    let proc_vm = ProcessVm::new(PageTableContext::new()).init_kernel_vm(&boot_info.kernel_pages);

    trace!("Init kernel vm: {:#?}", proc_vm);

    // kernel process
    let kproc = Process::new(String::from("kernel"), None, Some(proc_vm), None);
    let app_list = boot_info.loaded_apps.as_ref();
    manager::init(kproc, app_list);

    info!("Process Manager Initialized.");
}

```

= 内核栈的自动增长

我们在实验三中简单实现了用户进程的栈区自动增长，但是内核的栈区并没有进行相应的处理，这将导致内核栈溢出时无法进行自动增长，从而导致内核崩溃。

为了在之前的实验中避免这种情况，我们通过 BootLoader 直接为内核分配了 512 \* 4 KiB = 2 MiB 的栈区来避免可能的栈溢出问题。但这明显是不合理的，因为内核的栈区并不需要这么大的空间。

与其分配一个固定大小的栈区，不如在缺页中断的基础上实现一个简单的栈区自动增长机制，当栈区溢出时，自动为其分配新的页面。

需要用到的配置项为 `kernel_stack_auto_grow`，对它的行为进行如下约定：

- 默认为 `0`，这时内核栈区所需的全部页面（页面数量为 `kernel_stack_size`）将会在内核加载时一次性分配。

- 当这一参数为非零值时，表示内核栈区的初始化页面数量，从栈顶开始向下分配这一数量的初始化页面，并交由内核进行自己的栈区管理。

```rust
let (stack_start, stack_size) = if config.kernel_stack_auto_grow > 0 {
    let init_size = config.kernel_stack_auto_grow;
    let bottom_offset = (config.kernel_stack_size - init_size) * 0x1000;
    let init_bottom = config.kernel_stack_address + bottom_offset;
    (init_bottom, init_size)
} else {
    (config.kernel_stack_address, config.kernel_stack_size)
};
```

最后在 `pkg/kernel/src/lib.rs` 中添加测试：
```rust
pub fn init(boot_info: &'static BootInfo) {
    // ...

    info!("Test stack grow.");

    grow_stack();

    info!("Stack grow test done.");
}

#[inline(never)]
#[unsafe(no_mangle)]
pub fn grow_stack() {
    const STACK_SIZE: usize = 1024 * 4;
    const STEP: usize = 64;

    let mut array = [0u64; STACK_SIZE];
    info!("Stack: {:?}", array.as_ptr());

    // test write
    for i in (0..STACK_SIZE).step_by(STEP) {
        array[i] = i as u64;
    }

    // test read
    for i in (0..STACK_SIZE).step_by(STEP) {
        assert_eq!(array[i], i as u64);
    }
}
```

= 用户态堆

最后，为了提供给用户程序更多的内存管理能力，还需要实现一个系统调用 `sys_brk`，用于调整用户程序的堆区大小。

下面对 `brk` 系统调用的参数和行为进行简单的约定。

在用户态中，考虑下列系统调用函数封装：`brk` 系统调用的参数是一个可为 `None` 的“指针”，表示用户程序希望调整的堆区结束地址，用户参数采用 `0` 表示 `None`，返回值采用 `-1` 表示操作失败。
```rust
// in "pkg/lib/src/syscall.rs"
#[inline(always)]
pub fn sys_brk(addr: Option<usize>) -> Option<usize> {
    const BRK_FAILED: usize = !0;
    match syscall!(Syscall::Brk, addr.unwrap_or(0)) {
        BRK_FAILED => None,
        ret => Some(ret),
    }
}
```
在内核中，`brk` 系统调用的处理函数如下：将用户传入的参数转换为内核的 `Option<VirtAddr>` 类型进行传递，并使用相同类型作为返回值。
```rust
// in "pkg/kernel/src/interrupt/syscall/service.rs"
pub fn sys_brk(args: &SyscallArgs) -> usize {
    let new_heap_end = if args.arg0 == 0 {
        None
    } else {
        Some(VirtAddr::new(args.arg0 as u64))
    };
    match brk(new_heap_end) {
        Some(new_heap_end) => new_heap_end.as_u64() as usize,
        None => !0,
    }
}
```
```rust
// in "pkg/kernel/src/proc/mod.rs"
pub fn brk(addr: Option<VirtAddr>) -> Option<VirtAddr> {
    x86_64::instructions::interrupts::without_interrupts(|| {
        // NOTE: `brk` does not need to get write lock
        get_process_manager().current().read().brk(addr)
    })
}
```

之后为 `Heap` 实现 `brk` 方法：

- 如果参数为 `None`，则表示用户程序希望获取当前的堆区结束地址，即返回 `end` 的值；

- 如果参数不为 `None`，则检查用户传入的目标地址是否合法，即是否在 `[HEAP_START, HEAP_END]` 区间内，如果不合法，直接返回 `None`。

```rust
pub fn brk(
    &self,
    new_end: Option<VirtAddr>,
    mapper: MapperRef,
    alloc: FrameAllocatorRef,
) -> Option<VirtAddr> {
    // DONE: if new_end is None, return the current end address
    let Some(new_end) = new_end else {
        return Some(VirtAddr::new(self.end.load(Ordering::Relaxed)));
    };

    // DONE: check if the new_end is valid (in range [base, base + HEAP_SIZE])
    if new_end < self.base || self.base + HEAP_SIZE < new_end {
        error!("Heap::brk: new end is out of range");
        return None;
    }

    // DONE: calculate the difference between the current end and the new end
    let cur_end = self.end.load(Ordering::Acquire);

    // Calculate pages.
    let mut cur_end_page = Page::containing_address(VirtAddr::new(cur_end));
    if cur_end != self.base.as_u64() {
        cur_end_page += 1;
    }
    let mut new_end_page = Page::containing_address(new_end);
    if new_end != self.base {
        new_end_page += 1;
    }

    // DONE: print the heap difference for debugging
    debug!("Heap end addr: {:#x} -> {:#x}", cur_end, new_end.as_u64());
    debug!(
        "Heap end page: {:#x} -> {:#x}",
        cur_end_page.start_address().as_u64(),
        new_end_page.start_address().as_u64()
    );

    // DONE: do the actual mapping or unmapping
    match new_end_page.cmp(&cur_end_page) {
        core::cmp::Ordering::Greater => {
            let range = Page::range_inclusive(cur_end_page, new_end_page - 1);
            elf::map_range(range, mapper, alloc, true).ok()?;
        },
        core::cmp::Ordering::Less => {
            let range = Page::range_inclusive(new_end_page, cur_end_page - 1);
            elf::unmap_range(range, mapper, alloc, true).ok()?;
        },
        core::cmp::Ordering::Equal => {},
    }

    // DONE: update the end address
    self.end.store(new_end.as_u64(), Ordering::Release);

    Some(new_end)
}
```

最后为 `Heap` 实现 `clean_up` 方法，用于在进程退出时释放堆区的内存：
```rust
pub(super) fn clean_up(
    &self,
    mapper: MapperRef,
    dealloc: FrameAllocatorRef,
) -> Result<(), UnmapError> {
    if self.memory_usage() == 0 {
        return Ok(());
    }

    // DONE: load the current end address and **reset it to base** (use `swap`)
    let end_addr = self.end.swap(self.base.as_u64(), Ordering::Release);
    let start_page = Page::containing_address(self.base);
    let end_page = Page::containing_address(VirtAddr::new(end_addr));
    let range = Page::range_inclusive(start_page, end_page);

    // DONE: unmap the heap pages
    elf::unmap_range(range, mapper, dealloc, true)?;

    Ok(())
}

pub fn memory_usage(&self) -> u64 {
    self.end.load(Ordering::Relaxed) - self.base.as_u64()
}
```

= 思考题

+ 当在 Linux 中运行程序的时候删除程序在文件系统中对应的文件，会发生什么？程序能否继续运行？遇到未被映射的内存会发生什么？
  #info(title: "解答")[
    - 删除文件实际上是删除了目录中的引用（目录项），而不是立即清除磁盘上的数据。如果有进程正在使用这个文件，文件的 inode 和数据块不会马上被释放。只有当没有进程打开这个文件时，才会真正释放 inode 和数据块。

    - 程序可以继续运行。因为程序已经被加载到内存，不再依赖磁盘上原始的可执行文件。如果程序运行过程中需要加载动态库，而对应的文件被删除，且没有被加载到内存中，可能会失败，但已经加载进内存的部分同样不受影响。

    - 如果程序试图访问原本应该由文件支持的内存区域，而这些区域还没有被实际加载（懒加载），此时文件已被删除：

      - 只要文件未被关闭（即进程仍持有打开的文件描述符），内核依然可以提供数据，访问正常。

      - 如果文件句柄已经被关闭，且此时访问未映射区域，会导致页面错误（page fault），内核无法再从磁盘读取内容，进程会收到 SIGSEGV（段错误），进而崩溃。

  ]
