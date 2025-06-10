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
```rust
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
```rust
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
```toml
[dependencies]
storage = { path = "pkg/storage", package = "ysos_storage" }
```
```toml
[dependencies]
storage = { workspace = true }
```

== 3.1 发送命令

为了与磁盘进行交互，我们需要向磁盘发送命令：在 `drivers/ata/consts.rs` 中，我们定义了 `AtaCommand` 枚举，它表示了一系列的命令。

在本实验中，我们会实现 28-bit 模式下的 LBA 读写命令，并且还会使用到 `IdentifyDevice` 命令，用于获取磁盘的信息。

上述三个命令的调用过程比较类似，因此可以把发送命令并等待设备就绪的过程封装为一个函数，它被定义在 `drivers/ata/bus.rs` 中：
```rust
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

```rust
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
```rust
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
```rust
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

```rust
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
```rust
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
```rust
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
  ```rust
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
  ```rust
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
  ```rust
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
  ```rust
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
  ```rust
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
```rust
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
```rust
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

我们结合 `AtaDrive`，将 `Partition` 作为参数，初始化一个 `Fat16` 结构体，并使用 `Mount` 将其存放在 `ROOTFS` 变量中。
```rust
pub fn init() {
    info!("Opening disk device...");

    let drive = AtaDrive::open(0, 0).expect("Failed to open disk device");

    // only get the first partition
    let part = MbrTable::parse(drive)
        .expect("Failed to parse MBR")
        .partitions()
        .expect("Failed to get partitions")
        .remove(0);

    info!("Mounting filesystem...");

    ROOTFS.call_once(|| Mount::new(Box::new(Fat16::new(part)), "/".into()));

    trace!("Root filesystem: {:#?}", ROOTFS.get().unwrap());

    info!("Initialized Filesystem.");
}
```

== 5.1 列出目录

我们为 shell 添加 `ls` 命令：
```rust
fn main() -> isize {
    let mut current_dir = String::from("/APP");

    loop {
        // ...

        match args[0] {
            // ...

            "ls" => {
                if args.len() < 2 {
                    sys_list_dir(current_dir.as_str());
                } else {
                    sys_list_dir(args[1]);
                }
            },

            // ...
        }
    }

    0
}
```

为了实现的便利，我们添加如下的系统调用，在内核态直接打印文件夹信息：
```rust
// path: &str (arg0 as *const u8, arg1 as len)
Syscall::ListDir => list_dir(&args),
```
在 `pkg/kernel/src/interrupt/syscall/service.rs` 中添加 `list_dir` 函数：
```rust
pub fn list_dir(args: &SyscallArgs) {
    if args.arg1 > 0x100 {
        warn!("list_dir: path too long");
        return;
    }

    let Some(path) = as_user_str(args.arg0, args.arg1) else {
        warn!("list_dir: path not exist");
        return;
    };

    crate::filesystem::ls(path);
}
```
它会调用 `crate::filesystem::ls` 函数来列出指定路径下的文件和目录：
```rust
pub fn ls(root_path: &str) {
    let iter = match get_rootfs().read_dir(root_path) {
        Ok(iter) => iter,
        Err(err) => {
            warn!("{:?}", err);
            return;
        }
    };

    // DONE: format and print the file metadata
    //       - use `for meta in iter` to iterate over the entries
    //       - use `crate::humanized_size_short` for file size
    //       - add '/' to the end of directory names
    //       - format the date as you like
    //       - do not forget to print the table header
    println!("  Size | Last Modified       | Name");

    for meta in iter {
        let (size, unit) = crate::humanized_size_short(meta.len as u64);
        println!(
            "{:>5.*}{} | {} | {}{}",
            1,
            size,
            unit,
            meta.modified
                .map(|t| t.format("%Y/%m/%d %H:%M:%S"))
                .unwrap_or(
                    DateTime::from_timestamp_millis(0)
                        .unwrap()
                        .format("%Y/%m/%d %H:%M:%S")
                ),
            meta.name,
            if meta.is_dir() { "/" } else { "" }
        );
    }
}
```

之后我们在 `pkg/lib/src/syscall.rs` 中补全用户态库，接入此系统调用：
```rust
#[inline(always)]
pub fn sys_list_dir(root: &str) {
    syscall!(Syscall::ListDir, root.as_ptr() as u64, root.len() as u64);
}
```

== 5.2 读取文件

我们约定，一个用户态程序在读取文件时需要遵循 `open` - `read` - `close` 过程。

在 `pkg/kernel/src/utils/resource.rs` 中扩展 `Resource` 枚举：
```rust
#[derive(Debug)]
pub enum Resource {
    Console(StdIO),
    File(FileHandle),
    Null,
}
```
之后在 `read` 和 `write` 函数中补充对应的分支：
```rust
impl Resource {
    pub fn read(&mut self, buf: &mut [u8]) -> Option<usize> {
        match self {
            Resource::Console(stdio) => match stdio {
                StdIO::Stdin => {
                    // DONE: just read from kernel input buffer
                    if let Some(ch) = try_pop_key() {
                        buf[0] = ch;
                        Some(1)
                    } else {
                        Some(0)
                    }
                }
                _ => None,
            },
            Resource::File(file) => file.read(buf).ok(),
            Resource::Null => Some(0),
        }
    }

    pub fn write(&mut self, buf: &[u8]) -> Option<usize> {
        match self {
            Resource::Console(stdio) => match *stdio {
                StdIO::Stdin => None,
                StdIO::Stdout => {
                    print!("{}", String::from_utf8_lossy(buf));
                    Some(buf.len())
                }
                StdIO::Stderr => {
                    warn!("{}", String::from_utf8_lossy(buf));
                    Some(buf.len())
                }
            },
            Resource::File(_) => None,
            Resource::Null => Some(buf.len()),
        }
    }
}
```
本实验对于写入操作不做要求。

我们添加 `open` 和 `close` 对应的系统调用，将功能拆分，逐层委派给下一级，在 `pkg/kernel/src/{interrupt/syscall/service,proc/{mod,manager,data},utils/resource}.rs`：
```rust
pub fn sys_open(args: &SyscallArgs) -> usize {
    let path = match as_user_str(args.arg0, args.arg1) {
        Some(path) => path,
        None => return 0,
    };

    match open(path) {
        Some(fd) => fd as usize,
        None => {
            warn!("sys_open: failed to open {path}");
            0
        }
    }
}

pub fn sys_close(args: &SyscallArgs) -> usize {
    close(args.arg0 as u8) as usize
}
```
```rust
pub fn open(path: &str) -> Option<u8> {
    x86_64::instructions::interrupts::without_interrupts(|| get_process_manager().open(path))
}
pub fn close(fd: u8) -> bool {
    x86_64::instructions::interrupts::without_interrupts(|| get_process_manager().close(fd))
}
```
```rust
impl ProcessManager {
    // ...

    pub fn open(&self, path: &str) -> Option<u8> {
        let stream = match get_rootfs().open_file(path) {
            Ok(file) => Resource::File(file),
            Err(_) => return None,
        };

        let fd = self.current().write().open(stream);
        Some(fd)
    }
    pub fn close(&self, fd: u8) -> bool {
        if fd < 3 {
            false
        } else {
            self.current().write().close(fd)
        }
    }
}
```
```rust
impl ProcessData {
    // ...

    pub fn open(&mut self, res: Resource) -> u8 {
        self.resources.write().open(res)
    }
    
    pub fn close(&mut self, fd: u8) -> bool {
        self.resources.write().close(fd)
    }
}
```
```rust
impl ResourceSet {
    // ...

    pub fn open(&mut self, res: Resource) -> u8 {
        let fd = self.handles.len() as u8;
        self.handles.insert(fd, Mutex::new(res));
        fd
    }

    pub fn close(&mut self, fd: u8) -> bool {
        self.handles.remove(&fd).is_some()
    }
}
```
然后我们在 `pkg/lib/src/syscall.rs` 中补全用户态库，接入对应的系统调用：
```rust
#[inline(always)]
pub fn sys_open(path: &str) -> u8 {
    syscall!(Syscall::Open, path.as_ptr() as u64, path.len() as u64) as u8
}

#[inline(always)]
pub fn sys_close(fd: u8) -> bool {
    syscall!(Syscall::Close, fd as u64) != 0
}
```

现在，我们可以在用户态程序中使用 `open` - `read` - `close` 的方式来读取文件内容了。我们为 shell 添加 `cat` 命令：
```rust
fn main() -> isize {
    let mut current_dir = String::from("/APP");

    loop {
        // ...

        match args[0] {
            // ...

            "cat" => {
                if args.len() < 2 {
                    println!("Usage: cat <file>");
                    continue;
                }

                let path = if args[1].starts_with('/') {
                    // Absolute path
                    String::from(args[1])
                } else {
                    // Relative path
                    if current_dir.ends_with('/') {
                        format!("{}{}", current_dir, args[1])
                    } else {
                        format!("{}/{}", current_dir, args[1])
                    }
                }
                .to_ascii_uppercase();

                let fd = sys_open(path.as_str());

                if fd == 0 {
                    errln!("Invalid path");
                    continue;
                }

                let mut buf = vec![ 0; 3072 ];
                loop {
                    if let Some(bytes) = sys_read(fd, &mut buf) {
                        print!("{}", core::str::from_utf8(&buf[..bytes]).expect("Invalid UTF-8"));
                        if bytes < buf.len() {
                            break;
                        }
                    } else {
                        errln!("Failed to read file");
                        break;
                    }
                }

                sys_close(fd);
            },

            // ...
        }
    }

    0
}
```

由于我们仅使用一个 `current_dir` 变量来记录当前目录，我们可以很容易地实现 `cd` 命令：
```rust
fn main() -> isize {
    let mut current_dir = String::from("/APP");

    loop {
        // ...

        match args[0] {
            // ...

            "cd" => {
                if args.len() < 2 {
                    println!("Usage: cd <directory>");
                    continue;
                }

                let path = if args[1].starts_with('/') {
                    // Absolute path
                    String::from(args[1])
                } else {
                    // Relative path
                    format!("{}/{}", &current_dir, args[1])
                }
                .to_ascii_uppercase();

                let mut canonical: Vec<&str> = Vec::new();
                for segment in path.split('/') {
                    match segment {
                        "" | "." => continue,
                        ".." => {
                            if ! canonical.is_empty() {
                                canonical.pop();
                            }
                        },
                        _ => canonical.push(segment),

                    }
                }

                current_dir = String::from("/") + &canonical.join("/");
            },

            // ...
        }
    }

    0
}
```

我们添加一个 `hello.txt` 文件来测试我们的 shell 命令：

#figure(
  image("assets/0x06/shell-commands.png", width: 50%),
  caption: "Shell 命令测试",
)

= 6 探索 Linux 文件系统

+ procfs

  在 `/proc` 中，你可以找到一系列的文件和文件夹，探索他们并回答如下问题：

  - 解释 `/proc` 下的数字目录代表什么，其内部存在什么内容？
    
	#info(title: "解答")[
      `/proc` 下的每个数字目录名称都是一个正在运行的进程的 PID。每个数字目录里包含了该进程的相关信息和状态文件，例如 `/proc/[PID]/cmdline` 存储了进程的命令行参数，`/proc/[PID]/status` 存储了进程的状态信息等。
    ]

  - `/proc/cpuinfo` 和 `/proc/meminfo` 存储了哪些信息？
    
	#info(title: "解答")[
      - `/proc/cpuinfo` 存储了 CPU 的信息，包括型号、核心数、频率等；
      - `/proc/meminfo` 存储了内存的使用情况，包括总内存、可用内存、缓存等。
    ]

  - `/proc/loadavg` 和 `/proc/uptime` 存储了哪些信息？
    
	#info(title: "解答")[
      - `/proc/loadavg` 存储了系统的平均负载信息，包括过去 1 分钟、5 分钟和 15 分钟的平均负载，正在运行的进程数/总进程数，以及最近运行的进程的 PID；
      - `/proc/uptime` 存储了系统的运行时间和空闲时间。
    ]

  - 尝试读取 `/proc/interrupts` 文件，你能够从中获取到什么信息？
    
	#info(title: "解答")[
      `/proc/interrupts` 文件显示了自系统启动以来各中断源（如硬件设备中断、定时器中断等）被处理的次数。其内容包括每个 CPU 核心处理的各类中断的累计次数，以及对应的中断号、中断类型和来源（如设备名称）。
    ]

  - 尝试读取 `/proc/self/status` 文件，你能够从中获取到什么信息？
    
	#info(title: "解答")[
      `/proc/self/status` 文件包含了当前进程（即读取该文件的进程）的状态信息，包括进程的 PID、状态、内存使用情况、线程数、优先级等。它提供了关于进程运行状态的详细信息。
    ]

  - 尝试读取 `/proc/self/smaps` 文件，你能够从中获取到什么信息？
    
	#info(title: "解答")[
      `/proc/self/smaps` 文件提供了当前进程的内存映射信息，包括每个内存区域的起始地址、结束地址、权限、偏移量、设备号、`inode` 号、以及该区域的大小和使用情况（如私有、共享等）。它详细描述了进程如何使用内存。
    ]

  - 结合搜索，回答 ```sh echo 1 > /proc/sys/net/ipv4/ip_forward``` 有什么用？尝试据此命令，从系统调用角度，解释 “一切皆文件” 的优势。
    
	#info(title: "解答")[
      该命令将数字 1 写入 `/proc/sys/net/ipv4/ip_forward` 文件，作用是立即开启 Linux 内核的 IPv4 包转发功能。这使得该主机可以作为路由器进行 IP 包的转发。

      “一切皆文件”的优势：

      - 通过简单的文件操作，用户和程序无需特殊的系统调用或工具，就可以读取和修改内核参数。这极大地简化了系统的管理和自动化脚本编写。

      - 内核参数的交互接口与普通文件一致，统一了接口风格，降低了学习和运维成本。

      - 动态生效，无需重启系统或重载模块，提高了系统的灵活性和可用性。
    ]

+ devfs

  Linux 将设备也作为“文件”，默认挂载于 `/dev` 目录下，探索他们并回答如下问题：

  - `/dev/null`、`/dev/zero`、`/dev/random` 和 `/dev/urandom` 分别有什么作用？
    
	#info(title: "解答")[
      - `/dev/null` 是一个特殊的设备文件，任何写入它的数据都会被丢弃，读取时返回 EOF。它常用于丢弃不需要的输出。

      - `/dev/zero` 是一个特殊的设备文件，读取时会返回无限的零字节数据，写入数据会被忽略。它常用于初始化内存或创建空文件。

      - `/dev/random` 提供了高质量的随机数生成，但在熵池耗尽时会阻塞，直到有足够的熵可用。

      - `/dev/urandom` 也是一个随机数生成设备，但不会阻塞，即使熵池耗尽也会继续提供伪随机数。它通常用于需要随机数但不要求高安全性的场景。
    ]

  - 尝试运行 `head /dev/kmsg` 并观察输出，结合搜索引擎，解释这一文件的作用。
    
	#info(title: "解答")[
      `/dev/kmsg` 是一个特殊的设备文件，用于访问内核日志消息。运行 `head /dev/kmsg` 会显示内核日志的前几行，通常包括系统启动信息、驱动加载信息和其他内核事件。它允许用户空间程序读取内核产生的日志消息，便于调试和监控系统状态。
    ]

  - `/dev/sdX` 和 `/dev/sdX1` （X 为一个字母，1 为数字）是什么？有什么区别？如果你正在使用的 Linux 系统中不存在这样的文件，请找到功能类似的文件，并解释。
    
	#info(title: "解答")[
      `/dev/sdX` 通常代表一个物理磁盘（SATA）设备，例如 `/dev/sda`、`/dev/sdb` 等，而 `/dev/sdX1` 则代表该磁盘上的第一个分区。区别在于前者是整个磁盘设备，后者是磁盘上的一个具体分区。

      如果你的系统中没有这样的文件，可以查看 `/dev/nvmeXnY`（如 `/dev/nvme0n1`），它们代表 NVMe SSD 设备和分区，功能类似。
    ]

  - `/dev/ttyX`、`/dev/loopX`、`/dev/srX` 分别代表什么设备？
    
	#info(title: "解答")[
      - `/dev/ttyX` 代表一个虚拟终端设备，X 是数字（如 `/dev/tty1`），用于与用户交互的控制台。

      - `/dev/loopX` 代表一个环回设备（loop device），允许将文件作为块设备使用，通常用于挂载 ISO 镜像或其他文件系统镜像。

      - `/dev/srX` 代表光盘驱动器（如 CD-ROM 或 DVD-ROM），X 是数字（如 `/dev/sr0`），用于访问光盘上的数据。
    ]

  - 列出 `/dev/disk` 下的目录，尝试列出其中的“软连接”，这样的设计有什么好处？
    
	#info(title: "解答")[
      `/dev/disk` 下的目录通常包括 `by-id`、`by-label`、`by-uuid` 等，这些目录下的软连接指向具体的磁盘设备（如 `/dev/sda1`）。这样的设计有以下好处：

      - *一致性*：软连接提供了一种一致的方式来引用设备，无论设备名称如何变化（如重新插拔或更改顺序），都可以通过 ID、标签或 UUID 访问。

      - *易用性*：用户和脚本可以使用更具描述性的名称（如标签或 UUID）来引用设备，而不必关心实际的设备名称。

      例如在 `/etc/fstab` 中，一般使用 UUID 来挂载分区，这样即使设备名称变化，挂载仍然有效。
    ]

  - 尝试运行 `lsblk` 命令，根据你的输出，解释其中的内容。
    
	#info(title: "解答")[
      输出如下：
      ```
      NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
      nvme0n1     259:0    0 953.9G  0 disk
      ├─nvme0n1p1 259:1    0     1G  0 part /boot
      ├─nvme0n1p2 259:2    0    96G  0 part [SWAP]
      ├─nvme0n1p3 259:3    0   853G  0 part /var/log
      │                                     /home
      │                                     /.snapshots
      │                                     /
      └─nvme0n1p4 259:4    0     1G  0 part
      nvme1n1     259:5    0 953.9G  0 disk
      ├─nvme1n1p1 259:6    0   512M  0 part
      ├─nvme1n1p2 259:7    0    16M  0 part
      ├─nvme1n1p3 259:8    0 752.8G  0 part
      ├─nvme1n1p4 259:9    0   546M  0 part
      └─nvme1n1p5 259:10   0   200G  0 part
      ```

      - `NAME` 列显示设备名称，如 `nvme0n1` 是第一个 NVMe 设备，`nvme0n1p1` 是该设备的第一个分区。

      - `MAJ:MIN` 列显示主设备号和次设备号，用于标识设备。

      - `RM` 列表示设备是否为可移动设备（1 表示是，0 表示否）。

      - `SIZE` 列显示设备或分区的大小。

      - `RO` 列表示设备是否为只读（1 表示是，0 表示否）。

      - `TYPE` 列显示设备类型，如 `disk` 表示磁盘，`part` 表示分区。

      - `MOUNTPOINTS` 列显示设备或分区的挂载点，如果未挂载则为空。
    ]
    #notify(title: "注")[
      上述输出中的 `nvme0n1p3` 分区被挂载在多个位置，这是 `btrfs` 文件系统的特性，它支持在分区中创建多个子卷，并将它们挂载到不同的目录下。各子卷可以独立管理，提供灵活的存储和备份方案。
    ]

+ tmpfs

  在 Linux 中 `/dev/shm`、`/run` 或者 `/var/run` 目录下，存储了一个特殊的文件系统，它是一个内存文件系统，探索它并回答如下问题：

  - 列出这些目录，尝试找到扩展名为 `pid` 的文件。应用程序如何利用它们确保某个程序只运行一个实例？
    
	#info(title: "解答")[
      这些目录下的 `pid` 文件通常包含了正在运行的进程的 PID。应用程序启动时会检查指定的 pid 文件是否存在以及里面的 PID 是否有效。如果文件存在且 PID 有效，应用程序可以认为该实例已经在运行，从而避免启动多个实例。这种机制通常用于守护进程或需要确保单实例运行的应用程序。
    ]

  - 列出这些目录，尝试找到扩展名为 `lock` 的文件。应用程序如何利用它们确保某个资源只被一个程序访问？
    
	#info(title: "解答")[
      这些目录下的 `lock` 文件通常用于实现文件锁定机制。应用程序在访问某个资源（如文件或设备）时，会尝试创建一个对应的 `lock` 文件。如果创建成功，表示该资源当前未被其他程序占用，应用程序可以安全地访问该资源。如果 `lock` 文件已存在，应用程序可以认为资源正在被其他程序使用，从而避免冲突。这种机制常用于防止多个进程同时修改同一文件或设备。
    ]

  - 列出这些目录，尝试找到扩展名为 `sock` 或 `socket` 的文件。应用程序如何利用它们实现进程间通信？
    
	#info(title: "解答")[
      这些目录下的 `sock` 或 `socket` 文件通常是 Unix 域套接字，用于实现进程间通信（IPC）。应用程序可以通过创建和连接这些套接字文件来进行数据交换。一个进程可以创建一个套接字并监听连接，另一个进程可以连接到这个套接字进行通信。这种方式提供了高效的本地通信机制，适用于需要在同一主机上运行的进程之间传递数据。
    ]

  - `tmpfs` 的存在对于操作系统有什么作用？尝试从性能、安全性、系统稳定性几方面进行回答。
    
	#info(title: "解答")[
      `tmpfs` 是一个临时文件系统，存储在内存中，具有以下作用：

      - *性能*：由于数据存储在内存中，读写速度非常快，适合存储临时数据和缓存，提高了系统的响应速度。

      - *安全性*：`tmpfs` 中的数据在系统重启后会丢失，这减少了敏感数据的持久化风险，适合存储不需要长期保存的临时文件。

      - *系统稳定性*：`tmpfs` 可以动态调整大小，根据实际使用情况分配内存，有助于避免磁盘空间不足导致的系统崩溃或性能下降。
    ]

+ 在完全手动安装一个 Linux 操作系统时，我们常常会将待安装的磁盘（分区）格式化后，使用 mount 挂载于 /mnt 目录下。之后，可以使用 chroot 切换根目录，在“新的操作系统”中进行安装后期的工作。

  然而在 chroot /mnt 之前，还需要进行一些额外的挂载操作：
  ```sh
  mount proc /mnt/proc -t proc -o nosuid,noexec,nodev
  mount sys /mnt/sys -t sysfs -o nosuid,noexec,nodev,ro
  mount udev /mnt/dev -t devtmpfs -o mode=0755,nosuid
  # ...
  ```

  尝试解释上述举例的的挂载命令，思考为什么需要这样的挂载操作？如果不进行这些操作，在 chroot 之后会失去哪些能力？
  
	#info(title: "解答")[
    - ```sh mount proc /mnt/proc -t proc -o nosuid,noexec,nodev```：

      将 `/proc` 文件系统挂载到 `/mnt/proc`，提供内核和进程信息。选项 `nosuid` 防止设置用户 ID 位的程序执行，`noexec` 禁止执行文件，`nodev` 禁止设备文件的创建。

    - `mount sys /mnt/sys -t sysfs -o nosuid,noexec,nodev,ro`：

      将 `/sys` 文件系统挂载到 `/mnt/sys`，提供系统设备和内核信息。选项 `ro` 表示只读挂载。

    - `mount udev /mnt/dev -t devtmpfs -o mode=0755,nosuid`：

      将设备文件系统挂载到 `/mnt/dev`，允许访问设备文件。选项 `mode=0755` 设置权限，`nosuid` 防止设置用户 ID 位的程序执行。

    这些挂载操作是必要的，因为它们提供了对内核、进程和设备的访问能力。如果不进行这些操作，在 `chroot` 之后将无法访问系统信息、进程状态和设备文件，从而无法正常运行或管理新安装的操作系统。
  ]

= 7 思考题

+ 为什么在 `pkg/storage/lib.rs` 中声明了 `#![cfg_attr(not(test), no_std)]`，它有什么作用？哪些因素导致了 `kernel` 中进行单元测试是一个相对困难的事情？

  #info(title: "解答")[
    `#![cfg_attr(not(test), no_std)]` 的作用是当不是在测试环境中编译时，禁用标准库的使用，改为使用 `no_std` 环境。这是因为内核代码通常不依赖于标准库，而是依赖于核心库和其他特定的内核功能。

    在 `kernel` 中进行单元测试相对困难的原因包括：

    - 内核代码通常与硬件紧密耦合，难以模拟或隔离硬件行为。
    - 内核需要特定的运行环境，如中断处理、内存管理等，这些在用户态测试环境中难以实现。
    - 内核代码通常需要直接访问物理地址和设备，这在用户态测试中不可行。
  ]
  
+ 留意 `MbrTable` 的类型声明，为什么需要泛型参数 `T` 满足 `BlockDevice<B> + Clone`？为什么需要 `PhantomData<B>` 作为 `MbrTable` 的成员？在 `PartitionTable` trait 中，为什么需要 `Self: Sized` 约束？

  #info(title: "解答")[
    - `MbrTable` 的泛型参数 `T` 满足 `BlockDevice<B> + Clone` 是为了确保 `MbrTable` 可以操作任何实现了 `BlockDevice<B>` trait 的设备，并且可以克隆该设备的实例。这使得 `MbrTable` 可以在不同的块设备上工作，并且可以在需要时复制其状态。

    - `PhantomData<B>` 是一个零大小类型，用于告诉 Rust 编译器 `MbrTable` 结构体与泛型参数 `B` 有关联。它用于标记类型而不实际存储数据，确保类型系统正确地跟踪所有权和生命周期。

    - 在 `PartitionTable` trait 中，`Self: Sized` 约束是为了确保实现该 trait 的类型是一个具体的、已知大小的类型。这是因为某些 trait 方法可能需要知道具体类型的大小，以便进行内存布局和调用。
  ]

+ `AtaDrive` 为了实现 `MbrTable`，如何保证了自身可以实现 `Clone`？对于分离 `AtaBus` 和 `AtaDrive` 的实现，你认为这样的设计有什么好处？

  #info(title: "解答")[
    `AtaDrive` 能实现 `Clone` 的原因在于它的所有字段都支持 `Clone`。结构体上使用了 `#[derive(Clone)]` 属性。这意味着在实现 `MbrTable` 时，可以放心地对 `AtaDrive` 进行克隆，而不必担心无法复制 `bus` 或其他资源。

    将 `AtaBus` 与 `AtaDrive` 的实现分离带来了几个好处：

    - 分离关注点：`AtaBus` 负责管理 `ATA` 通道的低级操作（例如读写操作、处理硬件命令等），而 `AtaDrive` 则只关注驱动级别的逻辑和数据（例如识别驱动、存储设备信息等）。这样每个模块的职责都明确，维护起来更容易。

    - 更好的测试性和可复用性：分离后可以单独测试 `AtaBus` 的功能，而 `AtaDrive` 可以在不依赖具体硬件实现的情况下进行单元测试或模拟，有利于未来的扩展和重构。

    - 灵活性和抽象层次更高：抽象出 `ATA` 总线和驱动的不同职责，有助于以后支持更多种类的设备或接口（比如 `SATA`），只需要扩展或替换底层的总线实现，而上层的 `AtaDrive` 接口则保持一致。
  ]

+ 结合本次实验中的抽象和代码框架，简单解释和讨论如下写法的异同：

  + 函数声明：

    - ```rust fn f<T: Foo>(f: T) -> usize```

    - ```rust fn f(f: impl Foo) -> usize```

    - ```rust fn f(f: &dyn Foo) -> usize```

  + 结构体声明：

    - ```rust struct S<T: Foo> { f: T }```

    - ```rust struct S { f: Box<dyn Foo> }```

  #info(title: "解答")[
    - 函数声明中的 `T: Foo` 和 `impl Foo` 都表示泛型约束，前者是显式的泛型参数，后者是隐式的。两者都可以用于函数参数，但 `impl Foo` 更简洁且易于阅读。

    - `&dyn Foo` 表示一个动态分发的 trait 对象，它允许在运行时决定具体类型，而不是编译时确定。使用动态分发会有一定的性能开销，因为需要进行指针解引用和虚函数调用。

    - 结构体声明中的 `S<T: Foo>` 是一个泛型结构体，可以在实例化时指定具体类型，而 `S { f: Box<dyn Foo> }` 则使用了 trait 对象来存储任意实现了 `Foo` 的类型。这使得 `S` 可以存储不同的类型，但会牺牲一些类型安全性和性能。

    - 总结来说，使用泛型可以在编译时进行类型检查和优化，而使用 trait 对象则提供了更大的灵活性，但可能会带来运行时开销。
  ]

+ 文件系统硬链接和软链接的区别是什么？Windows 中的 “快捷方式” 和 Linux 中的软链接有什么异同？
  
  #info(title: "解答")[
    - *硬链接*：硬链接是指向同一文件数据块的多个目录项。它们共享相同的 inode，因此修改一个硬链接会影响所有指向同一数据块的链接。删除一个硬链接不会删除文件数据，只有当所有硬链接都被删除时，文件数据才会被释放。

    - *软链接（符号链接）*：软链接是一个指向另一个文件路径的特殊文件。它包含目标文件的路径，而不是直接指向数据块。软链接可以跨文件系统，并且可以指向不存在的文件（悬挂链接）。删除软链接不会影响目标文件，但如果目标文件被删除，软链接将失效。

    - *Windows 快捷方式*：Windows 中的快捷方式类似于 Linux 的软链接，但它们通常包含更多元数据，如图标、描述等。快捷方式可以指向任何类型的文件或程序，并且可以包含额外的属性和行为。

    - *异同点*：Linux 的软链接和 Windows 的快捷方式都提供了对目标文件的引用，但 Linux 的软链接更轻量级且直接，而 Windows 的快捷方式则更复杂，包含更多元数据和功能。
  ]

+ 日志文件系统（如 NTFS）与传统的非日志文件系统（如 FAT）在设计和实现上有哪些不同？在系统异常崩溃后，它的恢复机制、恢复速度有什么区别？

  #info(title: "解答")[
    - *日志文件系统*（如 NTFS）在每次修改文件系统时都会记录一个日志条目，描述即将进行的操作。这使得在系统异常崩溃后，可以通过回放日志来恢复文件系统到一致状态。日志文件系统通常具有更好的数据完整性和一致性。

    - *非日志文件系统*（如 FAT）则不记录操作日志，因此在崩溃后可能会导致数据丢失或文件系统损坏。恢复过程通常需要运行磁盘检查工具（如 CHKDSK），这可能需要较长时间，并且无法保证所有数据都能恢复。

    - 在恢复速度方面，日志文件系统通常能够更快地恢复，因为它只需回放日志，而非日志文件系统可能需要扫描整个磁盘以修复损坏的结构，这会耗费更多时间。
  ]
