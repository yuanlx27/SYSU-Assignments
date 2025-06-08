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

#import "@preview/codly:1.2.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/gentle-clues:1.2.0": *

#show: codly-init.with()



= 1 合并实验代码

`pkg/storage/src/common` 中提供了众多有关存储的底层结构：

- `block.rs` 提供了数据块的抽象，用于存储数据，内部为指定大小的 `u8` 数组。

- `device.rs` 目前只提供了块设备的抽象，提供分块读取数据的接口。

- `error.rs` 定义了文件系统、磁盘、文件名可能遇到的一系列错误，并定义了以 `FsError` 为错误类型的 `Result`。

- `filesystem.rs` 定义了文件系统的抽象，提供了文件系统的基本操作接口。

- `io.rs` 定义了 `Read`、`Write` 和 `Seek` 的行为，不过在本次实验中只实现 `Read`。

- `metadata.rs` 定义了统一的文件元信息，包含文件名、修改时间、大小等信息。

- `filehandle.rs` 定义了文件句柄，它持有一个实现了 `FileIO` trait 的字段，并维护了文件的元数据。

- `mount.rs` 定义了挂载点，它持有一个实现了 `Filesystem` trait 的字段，并维护了一个固定的挂载点路径，它会将挂载点路径下的文件操作请求转发给内部的文件系统。

`pkg/storage/src/partition/mod.rs` 中定义了 `Partition` 结构体，和 `PartitionTable` trait，用于统一块设备的分区表行为。

`pkg/kernel/src/drivers/ata` 中定义了 ATA 磁盘驱动的相关结构体和接口。

`pkg/kernel/src/drivers/filesystem` 中定义了根文件系统的挂载和初始化等操作。

= 2 MBR 分区表

我们在 `pkg/storage/src/partition/mbr/mod.rs` 的 `parse` 函数中，根据 MBR 的结构定义，按照对应的偏移量，提取四个 `MbrPartition` 并进行存储：
```Rust
impl<T, B> PartitionTable<T, B> for MbrTable<T, B>
where
    T: BlockDevice<B> + Clone,
    B: BlockTrait,
{
    fn parse(inner: T) -> FsResult<Self> {
        let mut block = B::default();
        inner.read_block(0, &mut block)?;

        let mut partitions = Vec::with_capacity(4);
        let buffer = block.as_ref();

        for i in 0..4 {
            partitions.push(
                // DONE: parse the mbr partition from the buffer - just ignore other fields for mbr
                MbrPartition::parse(
                    buffer[0x1BE + i * 16..0x1BE + (i + 1) * 16]
                        .try_into()
                        .unwrap(),
                )
            );

            if partitions[i].is_active() {
                trace!("Partition {}: {:#?}", i, partitions[i]);
            }
        }

        Ok(Self {
            inner,
            partitions: partitions.try_into().unwrap(),
            _block: PhantomData,
        })
    }

    // ...
}
```

在 `pkg/storage/src/partition/mbr/entry.rs` 中，我们定义了 `MbrPartition` 结构体，并实现了 `parse` 函数来解析 MBR 分区表中的分区信息：
```Rust
impl MbrPartition {
    /// Parse a partition entry from the given data.
    pub fn parse(data: &[u8; 16]) -> MbrPartition {
        MbrPartition {
            data: data.to_owned(),
        }
    }

    // DONE: define other fields in the MbrPartition
    //       - use `define_field!` macro
    //       - ensure you can pass the tests
    //       - you may change the field names if you want
    define_field!(u8, 0x00, status);
    define_field!(u8, 0x01, begin_head);
    define_field!(u8, 0x04, partition_type);
    define_field!(u8, 0x05, end_head);
    define_field!(u32, 0x08, begin_lba);
    define_field!(u32, 0x0C, total_lba);

    // NOTE: some fields are not aligned with byte.
    //       define your functions to extract values:
    //       - 0x02 - 0x03 begin sector & begin cylinder
    //       - 0x06 - 0x07 end sector & end cylinder
    pub fn is_active(&self) -> bool {
        self.status() == 0x80
    }
    pub fn begin_sector(&self) -> u8 {
        self.data[0x02] & 0x3f
    }
    pub fn begin_cylinder(&self) -> u16 {
        ((self.data[0x02] as u16 & 0xc0) << 2) | (self.data[0x03] as u16)
    }
    pub fn end_sector(&self) -> u8 {
        self.data[0x06] & 0x3f
    }
    pub fn end_cylinder(&self) -> u16 {
        ((self.data[0x06] as u16 & 0xc0) << 2) | (self.data[0x07] as u16)
    }
}
```

= 3 磁盘驱动

现在，我们来实现 ATA 磁盘驱动，使得内核能够通过它访问“真实”的虚拟磁盘，并读取并解析其中的数据。

为了在内核中使用 `storage` 包的内容，我们需要在 `Cargo.toml` 和 `pkg/kernel/Cargo.toml` 中添加依赖：
```TOML
[dependencies]
storage = { path = "pkg/storage", package = "ysos_storage" }
```
```TOML
[dependencies]
storage = { workspace = true }
```

== 3.1 发送命令

为了与磁盘进行交互，我们需要向磁盘发送命令：在 `drivers/ata/consts.rs` 中，我们定义了 `AtaCommand` 枚举，它表示了一系列的命令。

在本实验中，我们会实现 28-bit 模式下的 LBA 读写命令，并且还会使用到 `IdentifyDevice` 命令，用于获取磁盘的信息。

上述三个命令的调用过程比较类似，因此可以把发送命令并等待设备就绪的过程封装为一个函数，它被定义在 `drivers/ata/bus.rs` 中：
```Rust
impl AtaBus {
    // ...

    /// Writes the given command
    ///
    /// reference: https://wiki.osdev.org/ATA_PIO_Mode#28_bit_PIO
    fn write_command(&mut self, drive: u8, block: u32, cmd: AtaCommand) -> storage::FsResult {
        let bytes = block.to_le_bytes(); // a trick to convert u32 to [u8; 4]
        unsafe {
            // DONE: store the LBA28 address into four 8-bit registers
            //       - read the documentation for more information
            //       - enable LBA28 mode by setting the drive register
            // DONE: write the command register (cmd as u8)
            self.drive.write(0xE0 | (drive << 4) | (bytes[3] & 0x0F));
            self.sector_count.write(1); // just 1 sector for current implementation
            self.lba_low.write(bytes[0]);
            self.lba_mid.write(bytes[1]);
            self.lba_high.write(bytes[2]);
            self.command.write(cmd as u8);
        }

        if self.status().is_empty() {
            // unknown drive
            return Err(storage::DeviceError::UnknownDevice.into());
        }

        // DONE: poll for the status to be not BUSY
        self.poll(AtaStatus::BUSY, false);

        if self.is_error() {
            warn!("ATA error: {:?} command error", cmd);
            self.debug();
           return Err(storage::DeviceError::InvalidOperation.into());
        }

        // DONE: poll for the status to be not BUSY and DATA_REQUEST_READY
        self.poll(AtaStatus::BUSY, false);
        self.poll(AtaStatus::DATA_REQUEST_READY, true);

        Ok(())
    }
}
```

== 3.2 磁盘识别

在完成命令发送部分后，我们再实现 `identify_drive` 函数。我们直接调用上文实现好的 `write_command` 函数，根据规范，`block` 参数使用 `0` 进行传递。

识别出的磁盘会带有一个 512 字节的数据块，我们根据 ATA 规范，将这些数据解析为 `AtaDrive` 的相关信息。

```Rust
impl AtaBus {
    /// Identifies the drive at the given `drive` number (0 or 1).
    ///
    /// reference: https://wiki.osdev.org/ATA_PIO_Mode#IDENTIFY_command
    pub(super) fn identify_drive(&mut self, drive: u8) -> storage::FsResult<AtaDeviceType> {
        info!("Identifying drive {}", drive);

        // DONE: use `AtaCommand::IdentifyDevice` to identify the drive
        //       - call `write_command` with `drive` and `0` as the block number
        //       - if the status is empty, return `AtaDeviceType::None`
        //       - else return `DeviceError::Unknown` as `FsError`
        if self.write_command(drive, 0, AtaCommand::IdentifyDevice).is_err() {
            if self.status().is_empty() {
                return Ok(AtaDeviceType::None);
            } else {
                return Err(storage::DeviceError::Unknown.into());
            }
        }

        // DONE: poll for the status to be not BUSY
        self.poll(AtaStatus::BUSY, false);

        Ok(match (self.cylinder_low(), self.cylinder_high()) {
            // we only support PATA drives
            (0x00, 0x00) => AtaDeviceType::Pata(Box::new([0u16; 256].map(|_| self.read_data()))),
            // ignore the data as we don't support following types
            (0x14, 0xEB) => AtaDeviceType::PataPi,
            (0x3C, 0xC3) => AtaDeviceType::Sata,
            (0x69, 0x96) => AtaDeviceType::SataPi,
            _ => AtaDeviceType::None,
        })
    }
}
```

== 3.3 读写数据

虽然 ATA 驱动支持一次读取多个扇区，但从实现方便的角度，我们仍然采取每次写指令只读一块的方式，在编写 write_command 函数时将 `sector_count` 寄存器直接设为了 `1`。

经过上述函数的统一，读写磁盘的操作变得十分简单：在使用 `write_command` 指明需要进行的操作后，从 `data` 寄存器中每次 16 位地与 `buf` 进行数据交互。

我们先实现 `read_pio` 和 `write_pio` 函数：
```Rust
impl AtaBus {
    // ...

    /// Reads a block from the given drive and block number into the given buffer.
    ///
    /// reference: https://wiki.osdev.org/ATA_PIO_Mode#28_bit_PIO
    /// reference: https://wiki.osdev.org/IDE#Read.2FWrite_From_ATA_Drive
    pub(super) fn read_pio(
        &mut self,
        drive: u8,
        block: u32,
        buf: &mut [u8],
    ) -> storage::FsResult {
        self.write_command(drive, block, AtaCommand::ReadPio)?;

        // DONE: read the data from the data port into the buffer
        //       - use `buf.chunks_mut(2)`
        //       - use `self.read_data()`
        //       - ! pay attention to data endianness
        for chunk in buf.chunks_mut(2) {
            let data = self.read_data().to_le_bytes();
            chunk.clone_from_slice(&data);
        }

        if self.is_error() {
            debug!("ATA error: data read error");
            self.debug();
            Err(storage::DeviceError::ReadError.into())
        } else {
            Ok(())
        }
    }

    /// Writes a block to the given drive and block number from the given buffer.
    ///
    /// reference: https://wiki.osdev.org/ATA_PIO_Mode#28_bit_PIO
    /// reference: https://wiki.osdev.org/IDE#Read.2FWrite_From_ATA_Drive
    pub(super) fn write_pio(&mut self, drive: u8, block: u32, buf: &[u8]) -> storage::FsResult {
        self.write_command(drive, block, AtaCommand::WritePio)?;

        // DONE: write the data from the buffer into the data port
        //     - use `buf.chunks(2)`
        //     - use `self.write_data()`
        //     - ! pay attention to data endianness
        for chunk in buf.chunks(2) {
            let data = u16::from_le_bytes(chunk.try_into().unwrap());
            self.write_data(data);
        }

        if self.is_error() {
            debug!("ATA error: data write error");
            self.debug();
            Err(storage::DeviceError::WriteError.into())
        } else {
            Ok(())
        }
    }
}
```
之后再在 `pkg/kernel/src/drivers/ata/mod.rs` 中补充块设备的实现：
```Rust
impl BlockDevice<Block512> for AtaDrive {
    fn block_count(&self) -> storage::FsResult<usize> {
        // DONE: return the block count
        Ok(self.blocks as usize)
    }

    fn read_block(&self, offset: usize, block: &mut Block512) -> storage::FsResult {
        // DONE: read the block
        //       - use `BUSES` and `self` to get bus
        //       - use `read_pio` to get data
        BUSES[self.bus as usize]
            .lock()
            .read_pio(self.drive, offset as u32, block.as_mut())
    }

    fn write_block(&self, offset: usize, block: &Block512) -> storage::FsResult {
        // DONE: write the block
        //       - use `BUSES` and `self` to get bus
        //       - use `write_pio` to write data
        BUSES[self.bus as usize]
            .lock()
            .write_pio(self.drive, offset as u32, block.as_ref())
    }
}
```

= 4 FAT16 文件系统

== 4.1 BPB

首先，我们在 `pkg/storage/src/fs/fat16/bpb.rs` 中实现 `Fat16Bpb` 中内容的定义。BPB 作为存储整个 FAT 文件系统的关键信息的数据结构，可以让我们了解当前磁盘上文件系统的基本信息。

```Rust
impl Fat16Bpb {
    // DONE: define all the fields in the BPB
    //       - use `define_field!` macro
    //       - ensure you can pass the tests
    //       - you may change the field names if you want
    define_field!([ u8; 3 ], 0x00, jump_instruction); // jump instruction, no concern
    define_field!([ u8; 8 ], 0x03, oem_name); // OEM name, no concern
    define_field!(u16, 0x0B, bytes_per_sector);
    define_field!(u8, 0x0D, sectors_per_cluster);
    define_field!(u16, 0x0E, reserved_sector_count);
    define_field!(u8, 0x10, fat_count);
    define_field!(u16, 0x11, root_entries_count);
    define_field!(u16, 0x13, total_sectors_16);
    define_field!(u8, 0x15, media_descriptor); // less concerned
    define_field!(u16, 0x16, sectors_per_fat);
    define_field!(u16, 0x18, sectors_per_track); // less concerned
    define_field!(u16, 0x1A, track_count); // number of heads, less concerned
    define_field!(u32, 0x1C, hidden_sectors);
    define_field!(u32, 0x20, total_sectors_32);
    define_field!(u8, 0x24, drive_number);
    define_field!(u8, 0x25, reserved_flags);
    define_field!(u8, 0x26, boot_signature);
    define_field!(u32, 0x27, volume_id);
    define_field!([ u8; 11 ], 0x2B, volume_label); // 11 bytes for volume label
    define_field!([ u8; 8 ], 0x36, system_identifier); // 8 bytes for system identifier
    define_field!(u16, 0x1FE, trail); // bootable partition signature 0xAA55

    /// Attempt to parse a Boot Parameter Block from a 512 byte sector.
    pub fn new(data: &[u8]) -> FsResult<Fat16Bpb> {
        let data = data.try_into().unwrap();
        let bpb = Fat16Bpb { data };

        if bpb.data.len() != 512 || bpb.trail() != 0xAA55 {
            return Err(FsError::InvalidOperation);
        }

        Ok(bpb)
    }

    pub fn total_sectors(&self) -> u32 {
        if self.total_sectors_16() == 0 {
            self.total_sectors_32()
        } else {
            self.total_sectors_16() as u32
        }
    }
}
```

== 4.2 DirEntry

我们在 fs/fat16/direntry.rs 中实现 `DirEntry` 的内容，它是 FAT16 文件系统中的目录项，用于存储文件的元信息。

它的成员 `parse` 函数会接受一个 `&[u8]` 类型的数据块。我们根据 FAT 文件系统的规范，将这些数据解析为 `DirEntry` 结构体。
```Rust
impl DirEntry {
    // ...

    /// For Standard 8.3 format
    ///
    /// reference: https://osdev.org/FAT#Standard_8.3_format
    pub fn parse(data: &[u8]) -> FsResult<DirEntry> {
        let filename = ShortFileName::new(&data[..0x0B]);

        // DONE: parse the rest of the fields
        //       - ensure you can pass the test
        //       - you may need `prase_datetime` function
        let attributes = Attributes::from_bits_truncate(data[0x0B]);
        let created_time = prase_datetime(u32::from_le_bytes(data[0x0E..0x12].try_into().unwrap()));
        let accessed_time = prase_datetime(u32::from_le_bytes([ 0, 0, data[0x12], data[0x13] ]));
        let modified_time = prase_datetime(u32::from_le_bytes(data[0x16..0x1A].try_into().unwrap()));
        let cluster = (data[0x1A] as u32)
            | ((data[0x1B] as u32) << 8)
            | ((data[0x14] as u32) << 16)
            | ((data[0x15] as u32) << 24);
        let size = u32::from_le_bytes(data[0x1C..0x20].try_into().unwrap());

        Ok(DirEntry {
            filename,
            modified_time,
            created_time,
            accessed_time,
            cluster: Cluster(cluster),
            attributes,
            size,
        })
    }
}
```
与先前的 MBR 和 BPB 不同，`DirEntry` 并不持有 `data` 数据作为自身的字段，而是通过 `parse` 函数直接解析 `&[u8]`，并返回一个 `DirEntry` 的实例。

之后，我们给 `ShortFileName` 类型实现将日常使用的文件名转化为磁盘数据的 `parse` 函数：
```Rust
impl ShortFileName {
    // ...

    /// Parse a short file name from a string
    pub fn parse(name: &str) -> FsResult<ShortFileName> {
        // DONE: implement the parse function
        //       - use `FilenameError` and into `FsError`
        //       - use different error types for following conditions:
        //         - use 0x20 ' ' for right padding
        //         - check if the filename is empty
        //         - check if the name & ext are too long
        //         - period `.` means the start of the file extension
        //         - check if the period is misplaced (after 8 characters)
        //         - check if the filename contains invalid characters:
        //             [0x00..=0x1F, 0x20, 0x22, 0x2A, 0x2B, 0x2C, 0x2F, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x5B, 0x5C, 0x5D, 0x7C]
        for b in name.bytes() {
            match b {
                0x00..=0x20 | 0x22 | 0x2A..0x2D | 0x2F | 0x3A..0x40 | 0x5B..0x5E | 0x7C => {
                    return Err(FilenameError::InvalidCharacter.into());
                }
                _ => {}
            }
        }

        let name = name.to_uppercase();
        let segments: Vec<&str> = name.split('.').collect();
        match segments.len() {
            0 => Err(FilenameError::FilenameEmpty.into()),
            1 => {
                if segments[0].is_empty() {
                    return Err(FilenameError::MisplacedPeriod.into());
                }
                if segments[0].len() > 8 {
                    return Err(FilenameError::NameTooLong.into());
                }
                Ok(Self {
                    name: {
                        let mut arr = [ 0x20; 8 ];
                        arr[..segments[0].len()].copy_from_slice(segments[0].as_bytes());
                        arr
                    },
                    ext: [ 0x20; 3 ],
                })
            }
            2 => {
                if segments[0].is_empty() || segments[1].is_empty() {
                    return Err(FilenameError::MisplacedPeriod.into());
                }
                if segments[0].len() > 8 || segments[1].len() > 3 {
                    return Err(FilenameError::NameTooLong.into());
                }
                Ok(Self {
                    name: {
                        let mut arr = [ 0x20; 8 ];
                        arr[..segments[0].len()].copy_from_slice(segments[0].as_bytes());
                        arr
                    },
                    ext: {
                        let mut arr = [ 0x20; 3 ];
                        arr[..segments[1].len()].copy_from_slice(segments[1].as_bytes());
                        arr
                    },
                })
            }
            _ => Err(FilenameError::UnableToParse.into()),
        }
    }
}
```

== 4.3 Fat16Impl

在实现了上述文件系统的数据格式之后，我们再在 `pkg/storage/src/fs/fat16/impls.rs` 中实现需要的一系列函数：

- `cluster_to_sector`：将簇号转换为扇区号；
  ```Rust
      pub fn cluster_to_sector(&self, cluster: &Cluster) -> usize {
          match *cluster {
              Cluster::ROOT_DIR => self.first_root_dir_sector,
              Cluster(c) => {
                  // DONE: calculate the first sector of the cluster
                  // HINT: FirstSectorofCluster = ((N – 2) * BPB_SecPerClus) + FirstDataSector;
                  let first_sector_of_cluster = (c - 2) * self.bpb.sectors_per_cluster() as u32;
                  first_sector_of_cluster as usize + self.first_data_sector
              }
          }
      }
  ```

- `next_cluster`：获取下一个簇号；
  ```Rust
      // DONE: YOU NEED TO IMPLEMENT THE FILE SYSTEM OPERATIONS HERE
      //       - read the FAT and get next cluster
      //       - traverse the cluster chain and read the data
      //       - parse the path
      //       - open the root directory
      //       - ...
      //       - finally, implement the FileSystem trait for Fat16 with `self.handle`
      pub fn next_cluster(&self, cluster: &Cluster) -> FsResult<Cluster> {
          let fat_offset = cluster.0 as usize * 2;
          let block_size = Block512::size();
          let sector = self.fat_start + fat_offset / block_size;
          let offset = fat_offset % block_size;

          let mut block = Block::default();
          self.inner.read_block(sector, &mut block)?;

          let fat_entry = u16::from_le_bytes(block[offset..offset + 2].try_into().unwrap_or([ 0; 2 ]));
          match fat_entry {
              0xFFF7 => Err(FsError::BadCluster),
              0xFFF8 => Err(FsError::EndOfFile),
              f => Ok(Cluster(f as u32)),
          }
      }
  ```

- `find_entry_in_sector`：在指定的扇区中查找指定的文件名，`find_entry_in_dir`：在目录中查找指定的文件名；
  ```Rust
      fn find_entry_in_sector(&self, name: &ShortFileName, sector: usize) -> FsResult<DirEntry> {
          let mut block = Block::default();
          self.inner.read_block(sector, &mut block)?;

          for entry in 0..Block512::size() / DirEntry::LEN {
              let dir_entry = DirEntry::parse(&block[entry * DirEntry::LEN..(entry + 1) * DirEntry::LEN])
                  .map_err(|_| FsError::InvalidOperation)?;

              if dir_entry.is_eod() {
                  return Err(FsError::FileNotFound);
              } else if dir_entry.filename.matches(name) {
                  return Ok(dir_entry);
              }
          }

          Err(FsError::NotInSector)
      }
      fn find_entry_in_dir(&self, name: &str, dir: &Directory) -> FsResult<DirEntry> {
          let name = ShortFileName::parse(name)?;
          let size = match dir.cluster {
              Cluster::ROOT_DIR => self.bpb.root_entries_count() as usize * DirEntry::LEN,
              _ => self.bpb.sectors_per_cluster() as usize * Block512::size(),
          };

          let mut current_cluster = Some(dir.cluster);
          while let Some(cluster) = current_cluster {
              let current_sector = self.cluster_to_sector(&cluster);
              for sector in current_sector..current_sector + size {
                  if let Ok(entry) = self.find_entry_in_sector(&name, sector) {
                      return Ok(entry);
                  }
              }

              if cluster == Cluster::ROOT_DIR {
                  break;
              }

              current_cluster = self.next_cluster(&cluster).ok();
          }

          Err(FsError::FileNotFound)
      }
  ```

- `iterate_dir`：遍历目录中的文件信息；
  ```Rust
      pub fn iterate_dir<F>(&self, dir: &directory::Directory, mut func: F) -> FsResult
      where
          F: FnMut(&DirEntry),
      {
          if let Some(entry) = &dir.entry {
              trace!("Iterating directory: {}", entry.filename());
          }

          let mut current_cluster = Some(dir.cluster);
          let mut dir_sector_num = self.cluster_to_sector(&dir.cluster);
          let dir_size = match dir.cluster {
              Cluster::ROOT_DIR => self.first_data_sector - self.first_root_dir_sector,
              _ => self.bpb.sectors_per_cluster() as usize,
          };
          trace!("Directory size: {}", dir_size);

          let mut block = Block::default();
          let block_size = Block512::size();
          while let Some(cluster) = current_cluster {
              for sector in dir_sector_num..dir_sector_num + dir_size {
                  self.inner.read_block(sector, &mut block).unwrap();
                  for entry in 0..block_size / DirEntry::LEN {
                      let start = entry * DirEntry::LEN;
                      let end = (entry + 1) * DirEntry::LEN;

                      let dir_entry = DirEntry::parse(&block[start..end])?;

                      if dir_entry.is_eod() {
                          return Ok(());
                      } else if dir_entry.is_valid() && !dir_entry.is_long_name() {
                          func(&dir_entry);
                      }
                  }
              }
              current_cluster = if cluster != Cluster::ROOT_DIR {
                  match self.next_cluster(&cluster) {
                      Ok(n) => {
                          dir_sector_num = self.cluster_to_sector(&n);
                          Some(n)
                      }
                      _ => None,
                  }
              } else {
                  None
              }
          }
          Ok(())
      }
  ```

- `get_dir`：获取指定路径的所在目录，`get_entry`：获取指定路径的文件；
  ```Rust
      fn get_dir(&self, path: &str) -> FsResult<Directory> {
          let mut path = path.split('/');
          let mut current = Directory::root();

          while let Some(dir) = path.next() {
              if dir.is_empty() {
                  continue;
              }

              let entry = self.find_entry_in_dir(dir, &current)?;
              if entry.is_directory() {
                  current = Directory::from_entry(entry);
              } else if path.next().is_some() {
                  return Err(FsError::NotADirectory);
              } else {
                  break;
              }
          }

          Ok(current)
      }
      fn get_entry(&self, path: &str) -> FsResult<DirEntry> {
          let dir = self.get_dir(path)?;
          let name = path.rsplit('/').next().unwrap_or("");

          self.find_entry_in_dir(name, &dir)
      }
  ```

之后为 `Fat16` 实现 `Filesystem` trait：
```Rust
impl FileSystem for Fat16 {
    fn read_dir(&self, path: &str) -> FsResult<Box<dyn Iterator<Item = Metadata> + Send>> {
        // DONE: read dir and return an iterator for all entries
        let dir = self.handle.get_dir(path)?;

        let mut entries = Vec::new();
        self.handle.iterate_dir(&dir, |entry| {
            entries.push(entry.as_meta());
        })?;

        Ok(Box::new(entries.into_iter()))
    }

    fn open_file(&self, path: &str) -> FsResult<FileHandle> {
        // DONE: open file and return a file handle
        let entry = self.handle.get_entry(path)?;
        let handle = self.handle.clone();

        if entry.is_directory() {
            return Err(FsError::NotAFile);
        }

        Ok(FileHandle::new(entry.as_meta(), Box::new(File::new(handle, entry))))
    }

    fn metadata(&self, path: &str) -> FsResult<Metadata> {
        // DONE: read metadata of the file / dir
        Ok(self.handle.get_entry(path).unwrap().as_meta())
    }

    fn exists(&self, path: &str) -> FsResult<bool> {
        // DONE: check if the file / dir exists
        Ok(self.handle.get_entry(path).is_ok())
    }
}
```

最后在 `pkg/storage/src/fs/fat16/file.rs` 中为 `File` 实现 `Read` trait：
```Rust
impl Read for File {
    fn read(&mut self, buf: &mut [u8]) -> FsResult<usize> {
        // DONE: read file content from disk
        // CAUTION: file length / buffer size / offset
        //       - `self.offset` is the current offset in the file in bytes
        //       - use `self.handle` to read the blocks
        //       - use `self.entry` to get the file's cluster
        //       - use `self.handle.cluster_to_sector` to convert cluster to sector
        //       - update `self.offset` after reading
        //       - update `self.cluster` with FAT if necessary
        let length = self.length();

        if self.offset >= length {
            return Ok(0); // EOF
        }

        let bytes_per_cluster = {
            let sectors_per_cluster = self.handle.bpb.sectors_per_cluster() as usize;
            let bytes_per_sector = self.handle.bpb.bytes_per_sector() as usize;
            sectors_per_cluster * bytes_per_sector
        };

        let mut block = Block::default();
        let mut bytes_read = 0;
        while bytes_read < buf.len() && self.offset < length {
            let current_sector = {
                let cluster_sector = self.handle.cluster_to_sector(&self.current_cluster);
                let cluster_offset = (self.offset % bytes_per_cluster) / BLOCK_SIZE;
                cluster_sector + cluster_offset
            };

            self.handle.inner.read_block(current_sector, &mut block)?;

            let block_offset = self.offset % BLOCK_SIZE;
            let block_remain = BLOCK_SIZE - block_offset;

            let to_read = block_remain.min(buf.len() - bytes_read).min(length - self.offset);

            buf[bytes_read..bytes_read + to_read]
                .copy_from_slice(&block[block_offset..block_offset + to_read]);

            bytes_read += to_read;
            self.offset += to_read;

            if self.offset % bytes_per_cluster == 0 {
                if let Ok(next_cluster) = self.handle.next_cluster(&self.current_cluster) {
                    self.current_cluster = next_cluster;
                } else {
                    break;
                }
            }
        }

        Ok(bytes_read)
    }
}
```

= 5 接入操作系统

TODO
