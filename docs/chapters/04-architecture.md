# Chapter 4 - System Architecture Overview

This chapter provides a comprehensive architectural overview of PDP-7 Unix, giving you a mental model of the entire system before diving into detailed implementation in later chapters. Think of this as a map that shows how all the pieces fit together—the relationships between kernel modules, the flow of data through the system, and the fundamental data structures that make it all work.

## 1. The Big Picture

PDP-7 Unix is remarkably simple compared to modern operating systems, yet it implements every essential feature: processes, files, devices, and memory management. The entire kernel consists of approximately 2,500 lines of assembly code organized into nine files.

### System Components Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER SPACE                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   init   │  │    sh    │  │    ed    │  │   ...    │       │
│  │ (pid=1)  │  │  (shell) │  │ (editor) │  │ (other)  │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │             │             │             │              │
│       └─────────────┴─────────────┴─────────────┘              │
│                          │                                      │
│                  System Call Interface                          │
│                     (26 calls)                                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────────┐
│                      KERNEL SPACE                               │
│  ┌─────────────────────────────────────────────────────────────┤
│  │  System Call Dispatcher (s1.s)                              │
│  │  - Entry/exit handling                                      │
│  │  - Process context switching                                │
│  │  - Swapping control                                         │
│  └────┬───────────────────────┬──────────────────┬─────────────┤
│       │                       │                  │             │
│  ┌────┴────────┐   ┌──────────┴────────┐   ┌────┴──────────┐  │
│  │ File System │   │    Process Mgmt   │   │   Device I/O  │  │
│  │   (s2,s6)   │   │      (s3)         │   │   (s3,s7)     │  │
│  └────┬────────┘   └──────────┬────────┘   └────┬──────────┘  │
│       │                       │                  │             │
│  ┌────┴───────────────────────┴──────────────────┴──────────┐  │
│  │           Low-Level Services (s4,s5)                      │  │
│  │  - Memory allocation (alloc/free)                         │  │
│  │  - Disk I/O (dskrd/dskwr)                                 │  │
│  │  - Block buffering                                        │  │
│  │  - Utility functions (copy/betwen)                        │  │
│  └────┬──────────────────────────────────────────────────────┘  │
│       │                                                          │
│  ┌────┴──────────────────────────────────────────────────────┐  │
│  │         Data Structures & Constants (s8.s)                │  │
│  │  - Process table (ulist)                                  │  │
│  │  - System data (sysdata)                                  │  │
│  │  - Manifest constants                                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Interrupt Handler (s7.s)                          │  │
│  │  - Clock ticks, keyboard, display, disk, paper tape       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Boot Loader (s9.s)                                │  │
│  │  - System initialization from cold boot                   │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────────┐
│                       HARDWARE                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   CPU    │  │  Memory  │  │   Disk   │  │ Devices  │       │
│  │  (18bit) │  │  (8K)    │  │(DECtape) │  │ (TTY,etc)│       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow Example: Reading a File

Here's how data flows through the system when a user program reads from a file:

```
1. User calls:  sys read; fd; buffer; count

2. Hardware trap → s1.s entry point (location 020)
   - Save user context (AC, MQ, registers)
   - Set .insys flag
   - Check if system call number is valid

3. Dispatch to .read (s2.s)
   - Validate buffer address and count
   - Call finac to get file descriptor
   - Call fget to retrieve file structure

4. File system layer (s6.s)
   - Call iget to load inode from disk
   - Determine which disk blocks contain data
   - Call pget to get physical block number
   - Call dskrd to read block into buffer

5. Disk I/O layer (s4.s)
   - Check disk buffer cache
   - If not cached, perform physical disk read
   - Call dskio to convert block number to track/sector
   - Call dsktrans to execute disk transfer

6. Copy data to user space
   - Transfer from dskbuf to user buffer
   - Update file position pointer
   - Update file structure

7. Return to user (s1.s: sysexit)
   - Write sysdata back to disk if needed
   - Restore user context
   - Clear .insys flag
   - Return to user space with byte count in AC
```

## 2. Kernel Organization

The kernel is organized into nine source files, each with a specific responsibility. This modular organization made development manageable even in 1969.

### Module Responsibilities

| File   | Lines | Primary Responsibility | Key Functions |
|--------|-------|------------------------|---------------|
| s1.s   | 193   | System call dispatcher | Entry/exit, swap control, dispatch table |
| s2.s   | 328   | File operations | open, close, read, write, link, unlink, chmod, chown |
| s3.s   | 347   | Process & device I/O | fork, exit, smes/rmes, device handlers (TTY, display) |
| s4.s   | 334   | Low-level utilities | alloc, free, copy, betwen, disk I/O, queues |
| s5.s   | 273   | Support functions | dskswap, access, fassign, sleep, icreat, display |
| s6.s   | 344   | File system core | iget, iput, namei, iread, iwrite, dget, dput |
| s7.s   | 350   | Interrupt handler | pibreak, device interrupts, wakeup |
| s8.s   | 208   | Data structures | Constants, process table, inode, directory |
| s9.s   | 112   | Boot loader | Cold boot, disk initialization, tape loading |
| **Total** | **2,489** | **Complete kernel** | **~200 functions** |

### Detailed Module Descriptions

#### s1.s - System Call Dispatcher and Kernel Entry/Exit

The heart of the kernel. Every system call enters through location `020` (octal), which is the system call trap vector. This file handles:

- **Entry sequence**: Save all user registers to `userdata` structure
- **Validation**: Check system call number is in valid range (0-26)
- **Dispatch**: Jump to appropriate handler via `swp` table
- **Swapping**: Decide when to swap processes in/out of memory
- **Exit sequence**: Restore user registers and return to user space

Key data structures:
```assembly
swp:        " System call jump table
   .save; .getuid; .open; .read; .write; .creat; .seek; .tell
   .close; .link; .unlink; .setuid; .rename; .exit; .time; .intrp
   .chdir; .chmod; .chown; badcal; .sysloc; badcal; .capt; .rele
   .status; badcal; .smes; .rmes; .fork
```

The swap algorithm checks `uquant` (time quantum) and calls `swap` when a process has used its allocation.

#### s2.s - File System System Calls

Implements the user-facing file system operations. These functions validate arguments, perform permission checks, and coordinate with s6.s for actual file system manipulation.

System calls implemented:
- `.open` - Open existing file for reading/writing
- `.creat` - Create new file
- `.close` - Close file descriptor
- `.read` - Read bytes from file
- `.write` - Write bytes to file
- `.seek` - Position file pointer
- `.tell` - Get current file position
- `.link` - Create directory link to file
- `.unlink` - Remove directory entry
- `.rename` - Change file name
- `.chmod` - Change file permissions
- `.chown` - Change file owner
- `.chdir` - Change current directory
- `.status` - Get file status (proto-stat)
- `.capt` - Capture display buffer
- `.rele` - Release display buffer

#### s3.s - Process Management and Device I/O

Handles process lifecycle and character device I/O:

**Process operations:**
- `.fork` - Create child process (copy-on-write via disk)
- `.exit` - Terminate process
- `.smes` - Send message to another process
- `.rmes` - Receive message (blocking)

**Device handlers:**
- `rttyi`/`wttyo` - Read/write teletype (console)
- `rkbdi`/`wdspo` - Read keyboard/write display (Type 340)
- `rppti`/`wppto` - Read/write paper tape punch

The `searchu` function iterates over the process table—used extensively for finding processes by state.

#### s4.s - Low-Level Services

The utility belt of the kernel. These functions are called by higher layers:

**Memory management:**
- `alloc` - Allocate disk block from free list
- `free` - Return disk block to free list

**Disk I/O:**
- `dskrd` - Read disk block into `dskbuf`
- `dskwr` - Write `dskbuf` to disk block
- `dskio` - Convert block number to track/sector, perform I/O
- `dsktrans` - Low-level disk transfer (retry on error)

**Utilities:**
- `copy` - Copy words from source to destination
- `copyz` - Zero-fill memory region
- `betwen` - Check if value is between two bounds
- `laci` - Load AC indirect (access arrays)

**Character queues:**
- `putchar` - Add character to device queue
- `getchar` - Remove character from device queue
- `takeq`/`putq` - Queue primitives

The disk buffer cache (`dskbs`, 4 buffers of 64 words each) reduces redundant disk reads.

#### s5.s - Support Functions

Helper functions that don't fit neatly into other categories:

- `dskswap` - Swap process memory to/from disk
- `access` - Check file permissions
- `fassign` - Allocate file descriptor
- `fget`/`fput` - Get/put file descriptor structure
- `forall` - Iterate over user buffer (for read/write)
- `sleep` - Block process on event
- `dslot` - Find empty directory slot
- `icreat` - Create new inode
- `dspput` - Put character to display
- `dspinit` - Initialize display
- `movdsp` - Move display buffer
- `arg` - Fetch system call argument
- `argname` - Fetch filename argument
- `seektell` - Common code for seek/tell
- `isown` - Check if user owns file

#### s6.s - File System Implementation

The core file system logic. These functions manipulate inodes, directories, and data blocks:

**Inode operations:**
- `iget` - Read inode from disk into memory
- `iput` - Write inode back to disk
- `itrunc` - Truncate file (free all blocks)
- `iread` - Read data from inode
- `iwrite` - Write data to inode

**Directory operations:**
- `namei` - Name-to-inode lookup (like modern `namei`)
- `dget` - Read directory entry
- `dput` - Write directory entry

**Block mapping:**
- `pget` - Get physical block number for logical block
  - Handles direct blocks (0-6)
  - Handles single-indirect blocks (block 0 points to indirect block)

The file system uses a simple but effective structure:
- Small files (≤7 blocks): Direct block pointers
- Large files (>7 blocks): First pointer becomes indirect block

#### s7.s - Interrupt Handler

All hardware interrupts vector to `pibreak` (program interrupt break). This massive interrupt handler checks every device:

**Devices handled:**
- **Disk** (dssf) - Disk operation complete
- **Display** (clsf) - Display interrupt
- **Clock** (lpb) - Line printer buffer (used as clock)
- **Teletype** (ksf/tsf) - Keyboard/printer flags
- **Paper tape** (rsf/psf) - Reader/punch flags
- **Card reader** (crsf) - Card reader flag
- **Dectape** (dpcf) - Tape control

For each interrupt, the handler:
1. Checks device status flag
2. Reads/writes data if ready
3. Calls `wakeup` to unblock waiting processes
4. Updates system time (`s.tim`)
5. Increments time quantum (`uquant`)

The `wakeup` function scans the process table and marks processes as ready if they're waiting on the specified event.

#### s8.s - Data Structures and Constants

The "header file" of PDP-7 Unix. Contains no executable code, only declarations:

**Manifest constants:**
```assembly
mnproc = 10        " Maximum processes
dspbsz = 270       " Display buffer size
ndskbs = 4         " Number of disk buffers
```

**Constants:**
- Decimal: `d0` through `d10`, `d33`, `d65`, etc.
- Octal: `o7`, `o12`, `o17`, `o20`, etc.
- Negative: `dm1` (-1), `dm3` (-3)

**Data structures:**
- `userdata` - Per-process user structure (64 words)
- `ulist` - Process table (10 entries, 4 words each)
- `inode` - In-core inode (12 words)
- `dnode` - Directory entry (8 words)
- `fnode` - File descriptor (3 words)
- `sysdata` - System-wide data (free blocks, time)

**Buffers:**
- `dskbuf` - Disk I/O buffer (64 words at location 07700)
- `dskbs` - Disk buffer cache (4×65 words)
- `dspbuf` - Display buffer (270 words)

#### s9.s - Boot Loader

Executed only during cold boot. This code:

1. **Zeros the inode list** (blocks 2-710)
2. **Builds free block list** (blocks 711-6399)
3. **Reads installation tape**, creating:
   - Inode 1: Root directory
   - Inode 2: /init program
   - Inode 3+: System files

The tape format is:
```
[count] [flags] [nlinks] [word1] [word2] ... [checksum]
```

After loading all files, it jumps to block 4096 (the /init program), starting the system.

### Why s1 through s9?

The numbering reflects the development order and logical layering:

- **s1**: First thing written—must enter/exit the kernel
- **s2-s3**: System calls that users need
- **s4**: Low-level utilities needed by s2-s3
- **s5**: Additional support needed
- **s6**: Complex file system logic
- **s7**: Interrupt handling (added after basic functionality worked)
- **s8**: Data declarations (extracted for clarity)
- **s9**: Boot loader (written last, runs first)

## 3. System Calls Overview

PDP-7 Unix implements 26 system calls, organized into three categories:

### Complete System Call Reference

#### File System Calls (15)

| Number | Name | Arguments | Returns | Description |
|--------|------|-----------|---------|-------------|
| 2 | open | filename, mode | fd | Open file for reading (mode=0) or writing (mode=1) |
| 4 | read | fd, buffer, count | nread | Read bytes from file into buffer |
| 5 | write | fd, buffer, count | nwritten | Write bytes from buffer to file |
| 6 | creat | filename, mode | fd | Create new file with permissions |
| 7 | seek | fd, offset, whence | position | Position file pointer |
| 8 | tell | fd, whence | position | Get file position |
| 9 | close | fd | 0/-1 | Close file descriptor |
| 10 | link | file1, file2, name | 0/-1 | Create directory link |
| 11 | unlink | filename | 0/-1 | Remove directory entry |
| 13 | rename | oldname, newname | 0/-1 | Rename file |
| 16 | chdir | dirname | 0/-1 | Change current directory |
| 17 | chmod | filename, mode | 0/-1 | Change file permissions |
| 18 | chown | filename, uid | 0/-1 | Change file owner |
| 24 | status | filename1, filename2, buffer | 0/-1 | Get file status into buffer |
| 27 | rmes | - | message | Receive inter-process message (blocking) |

#### Process Calls (6)

| Number | Name | Arguments | Returns | Description |
|--------|------|-----------|---------|-------------|
| 0 | save | - | - | Save process state to inode 1 |
| 1 | getuid | - | uid | Get user ID (negative = superuser) |
| 12 | setuid | uid | 0/-1 | Set user ID (superuser only) |
| 14 | exit | - | - | Terminate process (never returns) |
| 26 | smes | pid, msg | 0/-1 | Send message to process |
| 28 | fork | - | pid | Create child process |

#### System Calls (5)

| Number | Name | Arguments | Returns | Description |
|--------|------|-----------|---------|-------------|
| 15 | time | - | time (AC+MQ) | Get system time (36-bit value) |
| 20 | sysloc | symbol | address | Get kernel symbol address (for debugging) |
| 22 | capt | buffer | 0/-1 | Capture display output to buffer |
| 23 | rele | - | 0/-1 | Release display buffer |
| 21 | intrp | flag | 0/-1 | Set interrupt flag |

### System Call Categories

**File-oriented calls:**
- Basic I/O: `open`, `read`, `write`, `close`, `creat`
- File positioning: `seek`, `tell`
- Directory operations: `link`, `unlink`, `rename`, `chdir`
- Metadata: `chmod`, `chown`, `status`

**Process-oriented calls:**
- Lifecycle: `fork`, `exit`, `save`
- Identity: `getuid`, `setuid`
- IPC: `smes`, `rmes` (message passing)

**System-oriented calls:**
- Time: `time`
- Display: `capt`, `rele`
- Debugging: `sysloc`, `intrp`

### Calling Convention

All system calls use the same interface:

```assembly
" Pattern:
sys <number>
arg1
arg2
...

" Example: Read from file descriptor 3
sys read; 3; buffer; count
```

The `sys` macro generates:
```assembly
jms 020         " Jump to system call entry point
<number>        " System call number
```

Arguments immediately follow the system call number. The kernel's `arg` function fetches them:

```assembly
arg: 0
   lac u.rq+8 i     " Load argument
   isz u.rq+8       " Increment return address
   jmp arg i
```

## 4. File System Architecture

The PDP-7 Unix file system is the conceptual ancestor of all Unix file systems. It introduced the inode concept and hierarchical directories.

### High-Level Design

**Three-level structure:**

1. **Superblock** (block 1) - System-wide information
2. **Inode list** (blocks 2-710) - File metadata
3. **Data blocks** (blocks 711-6399) - File contents and directories

**Key innovations:**
- Inodes separate from directories
- Directory entries are just (name, inode number) pairs
- Small files use direct pointers, large files use indirect blocks
- Free block list managed in-memory with overflow to disk

### Disk Layout

```
Block Range  | Usage              | Description
─────────────┼────────────────────┼──────────────────────────────────
0-1          | Boot & System      | Block 0: unused
             |                    | Block 1: superblock (sysdata)
─────────────┼────────────────────┼──────────────────────────────────
2-710        | Inode List         | 709 blocks × 5 inodes/block = 3,545 inodes
             | (709 blocks)       | Each inode is 12 words
             |                    | Inode 0: unused
             |                    | Inode 1: root directory "/"
             |                    | Inode 2: /init
             |                    | Inode 3+: other files
─────────────┼────────────────────┼──────────────────────────────────
711-6399     | Data Blocks        | 5,689 blocks for file data and directories
             | (5,689 blocks)     | Each block is 64 words (128 bytes)
             |                    |
─────────────┴────────────────────┴──────────────────────────────────
Total: 6,400 blocks × 64 words × 2 bytes = 819,200 bytes ≈ 800 KB
```

### Inode Structure

The inode (index node) stores all file metadata:

```assembly
" inode structure (12 words)
inode:
   i.flags:  .=.+1    " File type and permissions
   i.dskps:  .=.+7    " Disk block pointers (7 blocks)
   i.uid:    .=.+1    " Owner user ID
   i.nlks:   .=.+1    " Number of directory links
   i.size:   .=.+1    " File size in words
   i.uniq:   .=.+1    " Unique ID (for cache coherency)
```

**i.flags format (18 bits):**
```
Bit 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
    │  │  │  │  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴─── Permissions (15 bits)
    │  │  │  └────────────────────────────────────────────── Reserved
    │  │  └───────────────────────────────────────────────── Directory (1=dir, 0=file)
    │  └──────────────────────────────────────────────────── Character device
    └─────────────────────────────────────────────────────── Large file (indirect)

Permissions:
  Bits 0-2:   Owner permissions (read=4, write=2, execute=1)
  Bits 3-5:   Group permissions (same)
  Bits 6-8:   Other permissions (same)
  Bits 9-14:  Reserved for future use
```

**i.dskps block pointers:**
- **Small files** (≤7 blocks): Each word is a direct block number
- **Large files** (>7 blocks):
  - i.dskps[0] points to indirect block
  - Indirect block contains up to 64 data block pointers
  - Maximum file size: 64 blocks × 64 words = 4,096 words

### Directory Structure

Directories are special files (i.flags bit 4 set) containing directory entries:

```assembly
" Directory entry structure (8 words)
dnode:
   d.i:     .=.+1    " Inode number
   d.name:  .=.+4    " Filename (4 words = 6 chars max)
   d.uniq:  .=.+1    " Unique ID (must match inode)
   .=.+2             " Padding to 8 words
```

**Filename encoding:**
- PDP-7 stores 2 characters per word (9 bits each)
- 4 words = 8 characters, but only 6 used (2 words for padding)
- Characters are 9-bit ASCII (not 7-bit)

**Example directory:**
```
Inode  Name         Uniq
─────  ──────────   ────
  1    "."          0001   " Current directory (root)
  1    ".."         0001   " Parent directory (also root)
  2    "init"       0002   " /init program
  3    "sh"         0003   " Shell
  4    "ed"         0004   " Editor
  0    (free slot)  0000   " Deleted entry
```

The `namei` (name-to-inode) function walks directories:
1. Start with current directory inode
2. Read directory data blocks
3. Compare each d.name with target name
4. If match found, return d.i (inode number)
5. Verify d.uniq matches i.uniq (prevents stale references)

### Free Block Management

The free list is managed with a clever two-level structure:

**In-memory portion (sysdata):**
```assembly
sysdata:
   s.nxfblk: .=.+1   " Next free block overflow list
   s.nfblks: .=.+1   " Number of free blocks in memory
   s.fblks:  .=.+10  " Free block numbers (up to 10)
   s.uniq:   .=.+1   " Unique ID counter
   s.tim:    .=.+2   " System time (36 bits)
```

**Free block algorithm:**

When allocating a block (`alloc`):
```
1. If s.nfblks > 0:
   - Decrement s.nfblks
   - Return s.fblks[s.nfblks]
2. Else if s.nxfblk ≠ 0:
   - Read s.nxfblk block into dskbuf
   - Copy 10 block numbers to s.fblks
   - Set s.nxfblk = dskbuf[0]
   - Set s.nfblks = 10
   - Go to step 1
3. Else:
   - Halt: "OUT OF DISK"
```

When freeing a block (`free`):
```
1. If s.nfblks < 10:
   - s.fblks[s.nfblks] = block
   - Increment s.nfblks
2. Else:
   - dskbuf[0] = s.nxfblk
   - Copy s.fblks[1..10] to dskbuf[1..10]
   - Write dskbuf to block
   - Set s.nxfblk = block
   - Set s.nfblks = 1
```

This design:
- Keeps common case (allocate/free) fast (no disk I/O)
- Handles overflow elegantly (linked list on disk)
- Requires only 14 words of memory for free list

### Example: Storing a 200-Word File

Let's trace how a 200-word file "hello.txt" is stored:

**Step 1: Create file**
```assembly
sys creat; filename; 0010   " Create with rw------- permissions
```

**Step 2: Find empty inode**
- `icreat` scans inodes starting at 20 (octal)
- Finds empty inode (i.flags < 0), say inode 42

**Step 3: Initialize inode 42**
```
i.flags:  040010     " Regular file, rw-------
i.dskps:  0 0 0 0 0 0 0   " No blocks allocated yet
i.uid:    1          " Owner UID
i.nlks:   -1         " One link (stored as -1)
i.size:   0          " Empty file
i.uniq:   137        " Unique ID from s.uniq
```

**Step 4: Add directory entry**
- Find empty slot in current directory
- Create entry: (42, "hello.txt", 137)

**Step 5: Write 200 words**
```assembly
sys write; fd; buffer; 200   " fd was returned by creat
```

- 200 words requires 4 blocks (64+64+64+8)
- `alloc` called 4 times, returns blocks: 5123, 5124, 5125, 5126

**Step 6: Update inode 42**
```
i.flags:  040010
i.dskps:  5123 5124 5125 5126 0 0 0
i.uid:    1
i.nlks:   -1
i.size:   200        " Updated
i.uniq:   137
```

**Disk usage:**
- Inode: 12 words in inode list
- Data: 4 blocks × 64 words = 256 words (56 unused)
- Directory entry: 8 words in parent directory
- Total overhead: 20 words + 56 unused = 76 words (38% overhead for small files)

## 5. Process Model

The process model is extremely simple: no virtual memory, no copy-on-write in memory. Processes are swapped between memory and disk.

### Process Table Structure

The process table (`ulist`) holds 10 process slots:

```assembly
" ulist - 10 processes × 4 words each = 40 words
ulist:
   0131000;1;0;0      " Process 0 (init)
   0031040;0;0;0      " Process 1 (free)
   0031100;0;0;0      " Process 2 (free)
   ...
   0031440;0;0;0      " Process 9 (free)
```

**Each 4-word entry format:**
```
Word 0: Process state and pointer
  Bits 17-15: State
    000 = Free (not used)
    001 = In memory, ready to run
    010 = Out of memory (swapped), not ready
    011 = Out of memory (swapped), ready
    100 = In memory, not ready (sleeping)
  Bits 14-0: Pointer to userdata structure

Word 1: Process ID (PID)

Word 2: Parent PID (or message source PID for rmes)

Word 3: Message data (for smes/rmes IPC)
```

### User Data Structure

Each process has a 64-word `userdata` structure that holds its complete state:

```assembly
userdata:
   u.ac:      0              " Saved accumulator
   u.mq:      0              " Saved MQ register
   u.rq:      .=.+9          " Saved registers 8,9,10-15
   u.uid:     -1             " User ID (-1 = superuser)
   u.pid:     1              " Process ID
   u.cdir:    3              " Current directory inode
   u.ulistp:  ulist          " Pointer to ulist entry
   u.swapret: 0              " Return address after swap
   u.base:    0              " System call work area
   u.count:   0              " System call work area
   u.limit:   0              " System call work area
   u.ofiles:  .=.+30         " Open file table (10 files × 3 words)
   u.dspbuf:  0              " Display buffer pointer
   u.intflg:  1              " Interrupt flag
   .=userdata+64
```

**u.ofiles file descriptor table:**
- 10 file descriptors maximum per process
- Each descriptor is 3 words:
  ```
  f.flags: Access mode (0=read, 1=write) and valid bit
  f.badd:  Current position in file
  f.i:     Inode number
  ```

### Process States

The state machine is simple but effective:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   START (fork)                                              │
│      │                                                      │
│      ▼                                                      │
│   ┌──────────────┐  quantum expired    ┌──────────────┐    │
│   │  In Memory   │ ──────────────────> │ Out, Ready   │    │
│   │    Ready     │                     │  (swapped)   │    │
│   │   (state 1)  │ <────────────────── │  (state 3)   │    │
│   └──────┬───────┘  swap in            └──────────────┘    │
│          │                                                  │
│          │ sleep()                                          │
│          ▼                                                  │
│   ┌──────────────┐  quantum expired    ┌──────────────┐    │
│   │  In Memory   │ ──────────────────> │Out, Not Ready│    │
│   │  Not Ready   │                     │  (swapped)   │    │
│   │  (state 4)   │ <────────────────── │  (state 2)   │    │
│   └──────┬───────┘  swap in            └──────────────┘    │
│          │             ▲                       │            │
│          │ wakeup()    │ sleep()               │            │
│          └─────────────┘                       │            │
│                                                │            │
│                                     wakeup()   │            │
│                                      ┌─────────┘            │
│                                      │                      │
│                                      ▼                      │
│                               ┌──────────────┐             │
│                               │Out, Ready    │             │
│                               │(swapped)     │             │
│                               │(state 3)     │             │
│                               └──────────────┘             │
│                                                             │
│                                 exit()                      │
│                                   │                         │
│                                   ▼                         │
│                                 FREE                        │
│                              (state 0)                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Swapping Mechanism

PDP-7 Unix uses **swapping** (not paging) because:
- Limited memory (8K words)
- Only one process runs at a time
- No memory protection hardware

**Swap algorithm:**

1. **When to swap:** Determined by `swap` routine called from system call entry
   - Check if a process is "out, ready" (state 3) → swap it in
   - Current process exhausted quantum → swap it out

2. **Swap out:**
   ```assembly
   - Set process state to "out, not ready" (state 2) or "out, ready" (state 3)
   - Call dskswap with mode 07000 (write)
   - Write userdata (64 words) to disk
   - Write user memory (4096 words) to disk
   - Total: 4160 words swapped out
   ```

3. **Swap in:**
   ```assembly
   - Call dskswap with mode 06000 (read)
   - Read userdata (64 words) from disk
   - Read user memory (4096 words) from disk
   - Set process state to "in, ready" (state 1)
   - Jump to u.swapret (resume execution)
   ```

**Swap location on disk:**
Each process has a dedicated swap area:
```
Process 0: blocks 0×020 = 0      (userdata) + 0×020+020 = 020   (memory)
Process 1: blocks 1×020 = 020    (userdata) + 1×020+020 = 0140  (memory)
Process 2: blocks 2×020 = 0140   (userdata) + 2×020+020 = 0260  (memory)
...
Process 9: blocks 9×020 = 01120  (userdata) + 9×020+020 = 01340 (memory)
```

Each process reserves 020 (octal) = 16 blocks = 1024 words:
- 64 words for userdata
- 4096 words for user memory
- Total: 4160 words (requires 65 blocks, but allocated 64—bug or compression?)

### Process Lifecycle

**1. fork() - Process Creation**

```assembly
.fork:
   jms lookfor; 0          " Find free process slot
      skp
      jms error
   dac 9f+t                " Save slot pointer
   isz uniqpid             " Generate unique PID
   lac uniqpid
   dac u.ac                " Child gets new PID in AC

   " Mark current process as "out, ready"
   lac o200000
   tad u.ulistp i
   dac u.ulistp i

   " Swap current process to disk
   jms dskswap; 07000      " Write to disk

   " Initialize child process entry
   lac 9f+t
   dac u.ulistp            " Point to child slot
   lac o100000
   xor u.ulistp i
   dac u.ulistp i          " Set child state to "in, not ready"

   " Set up child's PID and return value
   lac u.pid
   dac u.ac                " Parent returns child's PID
   lac uniqpid
   dac u.pid               " Child's PID

   " Child returns here after swap
   dzm u.intflg
   jmp sysexit
```

**Key insight:** fork() in PDP-7 Unix:
- Parent: Returns child PID, swapped out to disk
- Child: Returns parent PID (in u.ac), immediately swapped out
- No memory copying in RAM—disk is the "copy"

**2. exit() - Process Termination**

```assembly
.exit:
   lac u.dspbuf
   sna
   jmp .+3
   law dspbuf
   jms movdsp              " Release display if captured

   jms awake               " Wake parent (for wait())

   lac u.ulistp i
   and o77777              " Clear state bits
   dac u.ulistp i          " Mark as free (state 0)

   isz u.ulistp
   dzm u.ulistp i          " Clear PID

   jms swap                " Swap to another process (never returns)
```

Process termination:
- Releases resources (display buffer)
- Marks slot as free
- Never returns (swaps to another process)

**3. sleep() and wakeup() - Process Synchronization**

```assembly
sleep: 0
   " Mark current process as waiting on event
   lac o200000             " "out" bit
   lmq

   " Find self in ulist
   law ulist-1
   dac 8
1: lac u.ulistp i
   sad 8 i
   jmp 1f
   " Next entry...
   jmp 1b

1: tad o100000            " "not ready" bit
   dac u.ulistp i         " Mark as "in, not ready"

   lac sleep i            " Get event address
   dac 9f+t
   lac 9f+t i             " OR in wait bit
   omq
   dac 9f+t i

   isz sleep
   jmp sleep i
```

```assembly
wakeup: 0
   dac 9f+t               " Event address

   " Scan all processes
   -mnproc
   dac 9f+t+1

1: lac 9f+t
   ral                    " Rotate wait bits
   dac 9f+t
   sma                    " Check if waiting
   jmp 2f+2               " Not waiting, skip

   lac o700000            " Clear wait bits
2: tad ..                 " Modify ulist entry
   dac ..

   " Next process...
   isz 9f+t+1
   jmp 1b

   cla
   jmp wakeup i
```

The wait/wakeup mechanism:
- Each event has an address (like `sfiles+1` for TTY output)
- `sleep` sets a bit in that address corresponding to process number
- `wakeup` clears that bit and marks process ready
- Interrupt handler calls `wakeup` when devices become ready

## 6. Memory Map

The PDP-7 has only 8K words (16 KB) of memory. Every word counts.

### Complete Memory Layout

```
Address   | Region            | Size    | Description
──────────┼───────────────────┼─────────┼──────────────────────────────
00000     | Reserved          | 1 word  | Location 0: used by halt
00001-017 | Reserved          | 15 words| Unused
00020     | Syscall trap      | 1 word  | System call entry point
00021-077 | Reserved          | 47 words| Trap vectors
00100     | Kernel code start | ~2500   | s1.s through s9.s
          |                   | words   | All kernel code
──────────┼───────────────────┼─────────┼──────────────────────────────
~03000    | Kernel data       | ~500    | Process table, system data
          |                   | words   | buffers, variables
──────────┼───────────────────┼─────────┼──────────────────────────────
04000     | User memory start | 4096    | User program code and data
          | (decimal 2048)    | words   | (Swapped in/out by kernel)
          |                   |         |
          |                   |         | User programs run here
          |                   |         |
07677     | User memory end   |         |
──────────┼───────────────────┼─────────┼──────────────────────────────
07700     | dskbuf            | 64 words| Disk I/O buffer
07764     | dskbs[]           | 260 wds | Disk buffer cache (4×65)
10244     | Kernel stack      | varies  | Grows downward
──────────┼───────────────────┼─────────┼──────────────────────────────
17777     | End of memory     | (8K)    | Last address
──────────┴───────────────────┴─────────┴──────────────────────────────
```

### Kernel Memory Organization

**Low memory (00000-00077):**
- Hardware-defined trap vectors
- Location 020: System call entry (modified by kernel)

**Kernel code (00100-~03000):**
```
00100: coldentry           " Cold boot entry (s9.s)
00102: jms halt            " Halt on error
...
       s1.s code           " System dispatcher
       s2.s code           " File system calls
       s3.s code           " Process/device code
       s4.s code           " Utilities
       s5.s code           " Support functions
       s6.s code           " File system core
       s7.s code           " Interrupt handler
```

**Kernel data (~03000-03777):**
```
sysdata:                   " System-wide data (14 words)
   s.nxfblk, s.nfblks, s.fblks[10], s.uniq, s.tim[2]

ulist:                     " Process table (40 words)
   10 entries × 4 words

userdata:                  " Current process state (64 words)
   u.ac, u.mq, u.rq[9], u.uid, u.pid, u.cdir, ...
   u.ofiles[30]           " 10 file descriptors × 3 words

inode:                     " In-core inode (12 words)
dnode:                     " Directory entry buffer (8 words)
fnode:                     " File descriptor buffer (3 words)

sfiles[10]:                " Device wait queues
dspbuf[270]:               " Display buffer
q2[50×2]:                  " Character queues (50 entries)
```

### User Memory Layout

User programs have exactly 4096 words (04000-07677):

```
04000    Start of user program
         ┌─────────────────────────────────┐
         │  Program code (.text)           │
         │  - Loaded from inode            │
         │  - Executable instructions      │
         ├─────────────────────────────────┤
         │  Initialized data (.data)       │
         │  - Global variables             │
         │  - String constants             │
         ├─────────────────────────────────┤
         │  Uninitialized data (.bss)      │
         │  - Zeroed by loader             │
         ├─────────────────────────────────┤
         │  Heap (grows upward)            │
         │  ↓                              │
         │  ...                            │
         │  ↑                              │
         │  Stack (grows downward)         │
         │  - Return addresses             │
         │  - Local variables              │
         │  - Function arguments           │
         └─────────────────────────────────┘
07677    End of user memory
```

**No memory protection!**
- User programs can access kernel memory
- Crashes affect entire system
- Trust-based security model

### Special Memory Locations

Certain memory locations have special meaning:

```assembly
Location  | Symbol    | Purpose
──────────┼───────────┼─────────────────────────────────────
0         | (none)    | Used by halt: stores LAW instruction
1-7       | (various) | Temporary storage, scratch registers
8-9       | -         | Index registers (loop counters, pointers)
10-15     | -         | User registers (saved in u.rq)
020       | -         | System call trap vector (kernel modifies)
021       | -         | Return address from trap
```

**Register conventions:**
- **AC**: Accumulator (main working register)
- **MQ**: Multiplier-quotient (second working register)
- **8-9**: Kernel index registers (for loops, array access)
- **10-15**: User program registers (preserved across syscalls)

### Memory Usage Analysis

For a typical running system:

```
Component              | Words  | Percentage
───────────────────────┼────────┼───────────
Kernel code            | ~2,500 | 31%
Kernel data            | ~1,000 | 12%
User program (in core) |  4,096 | 50%
Disk buffers           |    324 | 4%
Kernel stack           |    ~80 | 1%
Unused/fragmented      |   ~200 | 2%
───────────────────────┼────────┼───────────
Total                  |  8,192 | 100%
```

**Memory pressure:**
- Only ONE user process can be in memory at a time
- Swapping is mandatory for multitasking
- Disk bandwidth is the limiting factor
- Typical swap time: ~500ms (depends on disk position)

## 7. Device I/O Architecture

PDP-7 Unix manages seven device types through a unified character-oriented interface.

### Device List

| Device   | Input  | Output | Buffer | Type      | Speed        |
|----------|--------|--------|--------|-----------|--------------|
| TTY      | KSF/KRB| TSF/TLS| Queue  | Character | 10 chars/sec |
| Keyboard | (KBD)  | -      | Queue  | Character | Typed input  |
| Display  | -      | CDF/BEG| Direct | Block     | 60 Hz refresh|
| Paper tape| RSF/RRB| PSF/PSA| Queue  | Character | 300 chars/sec|
| Disk     | DSSF   | DSSF   | Buffer | Block     | ~40 KB/sec   |
| Line clock| LPB   | -      | None   | Special   | 60 Hz        |
| Card reader| CRSF | -      | Queue  | Character | Rare         |

### Character vs. Block Devices

**Character devices** (TTY, keyboard, paper tape):
- One character at a time
- Managed by character queues (q2 structure)
- Interrupt-driven
- Buffering in kernel space

**Block devices** (disk, display):
- Fixed-size blocks (64 words for disk)
- DMA (Direct Memory Access) transfers
- Buffering with cache (disk) or direct (display)

### Character Queue Implementation

The `q2` structure implements circular linked lists for character buffering:

```assembly
" Queue structure (50 entries)
q2:
   .+2;0;.+2;0;.+2;0; ...    " Linked list nodes

" Each queue entry:
"   word 0: pointer to next entry (or 0 for end)
"   word 1: character data

" Queue header (in device sfiles entry):
"   q1: pointer to first entry (head)
"   q1+1: pointer to last entry (tail)
```

**Queue operations:**

`putq`: Add character to queue tail
```assembly
putq: 0
   " Allocate free queue entry
   " Link to tail (or make new head)
   " Store character
   jmp putq i
```

`takeq`: Remove character from queue head
```assembly
takeq: 0
   " Check if queue empty
   " Remove head entry
   " Update head pointer
   " Return character
   jmp takeq i
```

`putchar`: High-level put (allocates from free pool)
`getchar`: High-level get (returns to free pool)

### Buffering Strategy

**Why buffering matters:**
- Devices operate at different speeds
- CPU is much faster than I/O
- Buffering allows asynchronous operation

**Disk buffer cache (dskbs):**
```assembly
" Four 64-word buffers
dskbs: .=.+65+65+65+65     " 260 words total
```

Each buffer tracks:
- Block number (in first word)
- 64 words of data

**Cache algorithm (in dskrd):**
```assembly
dskrd: 0
   " Check if block already in cache
   jms srcdbs               " Search disk buffers
      jmp 1f                " Not found
   " Found - copy from cache
   jms copy; buffer; dskbuf; 64
   jmp 2f

1: " Not found - read from disk
   jms dskio; 06000         " Physical disk read

2: " Update cache (collapse oldest)
   jms collapse
   jmp dskrd i
```

The `collapse` routine implements a simple LRU-like policy:
- Recent reads stay in cache
- Oldest buffer is overwritten

**Display buffering:**
- Direct buffer at `dspbuf` (270 words)
- Written directly to display hardware
- Process can "capture" display with `capt` syscall
- Released with `rele` syscall

### Interrupt Handling Overview

All interrupts vector to `pibreak` (s7.s), which polls every device:

```assembly
pibreak:
   " Disk interrupt
   dpsf              " Disk status flag
   jmp 1f
   " ... handle disk ...

1: clsf              " Clock flag
   jmp 1f
   " ... handle clock ...

1: dssf              " Dectape flag
   jmp 1f
   " ... handle tape ...

   " ... (check all devices) ...

piret:
   lac 0
   ral
   lac .ac
   ion
   jmp 0 i           " Return from interrupt
```

**Interrupt flow:**
1. Hardware asserts interrupt signal
2. PC saved, jump to pibreak
3. Poll each device status flag
4. If device ready, transfer data
5. Call `wakeup` to unblock waiting process
6. Restore registers, return from interrupt

The polling approach is inefficient but simple. With only 7 devices and slow interrupt rates, it works fine.

### Device-Specific Handlers

**TTY (Teletype) - rttyi/wttyo**

Input (rttyi):
```assembly
rttyi:
   jms chkint1               " Check for interrupts
   lac d1                    " Device 1
   jms getchar               " Get from queue
      jmp 1f                 " Queue empty
   and o177                  " Mask to 7 bits
   jms betwen; o101; o132    " Check if uppercase
      skp
   tad o40                   " Convert to lowercase
   alss 9                    " Shift to high half
   jmp passone               " Return to user

1: jms sleep; sfiles+0       " Sleep on TTY input
   jms swap                  " Swap to other process
   jmp rttyi                 " Try again when woken
```

Output (wttyo):
```assembly
wttyo:
   jms chkint1               " Check interrupts
   jms forall                " Get character from user
   sna                       " End of buffer?
   jmp fallr                 " Yes, return
   lmq                       " Save character
   lac sfiles+1              " Check output ready flag
   spa                       " Ready?
   jmp 1f                    " No, wait
   xor o400000               " Clear ready flag
   dac sfiles+1
   lacq                      " Get character
   tls                       " Output to TTY
   sad o12                   " Newline?
   jms putcr                 " Add carriage return
   jmp fallr                 " Return

1: lacq
   dac char
   jms putchar               " Queue character
      skp
   jmp fallr
   jms sleep; sfiles+1       " Sleep on output ready
   jms swap
   jmp wttyo                 " Try again
```

**Display (Type 340) - wdspo**

```assembly
wdspo:
   jms chkint1               " Check interrupts
   jms forall                " Get character from user
   jms dspput                " Put to display buffer
      jmp fallr              " Buffer full, return
   jms sleep; sfiles+6       " Sleep on display ready
   jms swap
   jmp wdspo                 " Try again
```

The display uses a special hardware feature (BEG - begin display) that triggers DMA transfer of the entire display buffer.

**Disk - handled via s4.s functions**

Disk I/O is block-oriented, not character-oriented:
- `dskrd`/`dskwr` are called from file system
- Interrupt handler just sets `.dskb` flag
- No process sleeping on disk (synchronous I/O)

## 8. Boot and Initialization

The boot process is crucial to understanding how Unix comes alive from a cold start.

### Cold Boot Sequence

**Step 1: Hardware Bootstrap**
```
1. Power on PDP-7
2. Operator loads boot program from paper tape
3. Boot program reads block 0 from disk
4. Jump to location 00100 (coldentry in s9.s)
```

**Step 2: Kernel Initialization (s9.s)**
```assembly
coldentry:
   dzm 0100              " Mark not re-entrant
   caf                   " Clear all flags
   ion                   " Enable interrupts
   clon                  " Clear console (start fresh)
   law 3072              " Load display address
   wcga                  " Write CGA (graphics address)
   jms dspinit           " Initialize display buffer
   law dspbuf
   jms movdsp            " Move display buffer to hardware
```

**Step 3: Load System Data**
```assembly
   cla
   jms dskio; 06000      " Read block 1 (superblock)
   jms copy; dskbuf; sysdata; ulist-sysdata
```

This reads the superblock containing:
- Free block list (s.fblks)
- Unique ID counter (s.uniq)
- System time (s.tim)
- Process table state (ulist)

**Step 4: Load /init Program**
```assembly
   lac d3                " Inode 3 = /init
   jms namei; initf      " Resolve "init" filename
      jms halt           " Panic if not found
   jms iget              " Load inode into memory
   cla
   jms iread; 4096; 4096 " Read init program into user memory
   jmp 4096              " Jump to user memory, start init
```

**Init filename:**
```assembly
initf:
   <i>n;<i>t;< > ;< >   " "init" in 4-word format
```

**Step 5: /init Program Runs**

The /init program (written in assembler or B language):
```
1. Initialize terminal
2. Print login prompt
3. Read username
4. Fork and exec shell for user
5. Repeat
```

### Full Boot Flowchart

```
┌─────────────────────────────────────────────────────────────┐
│  POWER ON                                                   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Operator loads boot tape                                   │
│  - Paper tape reader                                        │
│  - ~50 words of bootstrap code                              │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Bootstrap reads disk block 0                               │
│  - Contains secondary boot loader                           │
│  - Loads kernel into memory                                 │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Jump to coldentry (00100)                                  │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Hardware initialization (s9.s)                             │
│  - Clear flags and console                                  │
│  - Initialize display                                       │
│  - Enable interrupts                                        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Load system data (sysdata, ulist)                          │
│  - Read block 1 (superblock)                                │
│  - Initialize free block list                               │
│  - Restore process table                                    │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Locate /init program                                       │
│  - Look up inode 3                                          │
│  - Load into user memory (4096-7677)                        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Jump to user memory (4096)                                 │
│  - /init program starts                                     │
│  - PID = 1, UID = -1 (superuser)                            │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  /init runs                                                 │
│  - Display login prompt                                     │
│  - Read username                                            │
│  - Fork shell process                                       │
│  - Wait for shell to exit                                   │
│  - Repeat                                                   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Shell executes user commands                               │
│  - Fork/exec for each command                               │
│  - Normal Unix operation                                    │
└─────────────────────────────────────────────────────────────┘
```

### Installation Boot (s9.s alternate path)

During initial installation, s9.s has additional code to read system files from paper tape:

```assembly
" After zeroing i-list and freeing blocks...
dzm ii                    " Start with inode 0
1:
   dzm sum                " Checksum accumulator
   jms getw               " Read word from tape
   sza                    " Zero means pause
   jmp .+3
   hlt                    " Halt for operator
   jmp 1b                 " Continue

   dac xx                 " Save word count
   isz ii                 " Next inode
   lac ii
   jms iget               " Get inode
   jms copyz; inode; 12   " Clear inode

   jms getw               " Read flags
   dac i.flags
   -1
   dac i.uid              " Superuser owns all files
   jms getw               " Read link count
   dac i.nlks

   " Read file contents from tape...
   " Write to disk using iwrite

   jmp 1b                 " Next file
```

**Tape format:**
```
[word_count] [flags] [nlinks] [data...] [checksum]
[word_count] [flags] [nlinks] [data...] [checksum]
...
[0] (end marker)
```

This creates the initial file system with:
- Inode 1: Root directory "/"
- Inode 2: /init
- Inode 3+: System utilities (sh, ed, as, etc.)

### Shutdown and Restart

There is no formal "shutdown" procedure. To stop the system:
1. Kill all user processes
2. `sys save` to write system state to inode 1
3. Halt the machine (power off)

To restart:
1. Power on
2. Boot from tape (reads inode 1)
3. System state restored
4. Processes resume (primitive hibernation)

## 9. Data Structures

Understanding the data structures is key to reading the source code. Here are the actual definitions from s8.s.

### Process Table (ulist)

```assembly
" ulist - 10 process slots, 4 words each
ulist:
   0131000;1;0;0      " Process 0: state=1 (in, ready), ptr=031000, pid=1
   0031040;0;0;0      " Process 1: state=0 (free), ptr=031040
   0031100;0;0;0      " Process 2: state=0 (free), ptr=031100
   0031140;0;0;0      " Process 3: state=0 (free), ptr=031140
   0031200;0;0;0      " Process 4: state=0 (free), ptr=031200
   0031240;0;0;0      " Process 5: state=0 (free), ptr=031240
   0031300;0;0;0      " Process 6: state=0 (free), ptr=031300
   0031340;0;0;0      " Process 7: state=0 (free), ptr=031340
   0031400;0;0;0      " Process 8: state=0 (free), ptr=031400
   0031440;0;0;0      " Process 9: state=0 (free), ptr=031440
```

**Word 0 breakdown (octal 0131000):**
```
0 1 3 1 0 0 0
│ └─┴─┴─┴─┴─┴─ Pointer: 031000 (points to userdata)
└─────────────  State: 001 (in memory, ready)
```

### User Data Structure (userdata)

```assembly
userdata:
   u.ac: 0                 " Saved accumulator
   u.mq: 0                 " Saved MQ register
   u.rq: .=.+9             " Saved registers 8,9,10-15
   u.uid: -1               " User ID (-1 = superuser, ≥0 = normal user)
   u.pid: 1                " Process ID
   u.cdir: 3               " Current directory inode (3 = root)
   u.ulistp: ulist         " Pointer to this process's ulist entry
   u.swapret: 0            " Return address after swap
   u.base: 0               " Syscall work: base address
   u.count: 0              " Syscall work: count
   u.limit: 0              " Syscall work: limit
   u.ofiles: .=.+30        " Open file table (10 files × 3 words each)
   u.dspbuf: 0             " Display buffer pointer (0 = not captured)
   u.intflg: 1             " Interrupt enable flag
   .=userdata+64           " Total: 64 words
```

**u.ofiles layout:**
```
u.ofiles+0:  f.flags, f.badd, f.i     " File descriptor 0
u.ofiles+3:  f.flags, f.badd, f.i     " File descriptor 1
u.ofiles+6:  f.flags, f.badd, f.i     " File descriptor 2
...
u.ofiles+27: f.flags, f.badd, f.i     " File descriptor 9
```

### Inode Structure

```assembly
ii: .=.+1              " Current inode number
inode:
   i.flags: .=.+1      " File type and permissions (18 bits)
   i.dskps: .=.+7      " Disk block pointers (7 words)
   i.uid: .=.+1        " Owner user ID
   i.nlks: .=.+1       " Number of links (stored as -n for n links)
   i.size: .=.+1       " File size in words
   i.uniq: .=.+1       " Unique ID (for cache coherency)
   .= inode+12         " Total: 12 words
```

**i.flags format:**
```
Bit:  17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      │  │  │  │  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴─── Permissions (15 bits)
      │  │  │  └────────────────────────────────────────────── Reserved
      │  │  └───────────────────────────────────────────────── Directory flag (020)
      │  └──────────────────────────────────────────────────── Character device (040)
      └─────────────────────────────────────────────────────── Large file/indirect (0200000)
```

**Example inode for a readable/writable file owned by user 1:**
```
ii:       42            " Inode number 42
i.flags:  040010        " Regular file, rw-------
i.dskps:  5123 5124 5125 0 0 0 0
i.uid:    1             " Owner UID
i.nlks:   -1            " One link
i.size:   150           " 150 words
i.uniq:   137           " Unique ID 137
```

### Directory Entry Structure

```assembly
di: .=.+1              " Current directory slot number
dnode:
   d.i: .=.+1          " Inode number
   d.name: .=.+4       " Filename (4 words = 6 chars)
   d.uniq: .=.+1       " Unique ID (must match inode's i.uniq)
   .= dnode+8          " Total: 8 words (2 words padding)
```

**Filename encoding:**
```
Word 0: [char1][char2]   " 9 bits each
Word 1: [char3][char4]
Word 2: [char5][char6]
Word 3: [padding]
```

**Example directory entry for "hello.txt":**
```
d.i:     42                " Points to inode 42
d.name:  <h>e;<l>l;<o>.; 0 " "hello." (truncated to 6 chars)
d.uniq:  137               " Must match inode 42's i.uniq
```

### File Descriptor Structure

```assembly
fnode:
   f.flags: .=.+1      " Access mode and valid bit
   f.badd: .=.+1       " Current byte address in file
   f.i: 0              " Inode number
```

**f.flags format:**
```
Bit 17: Valid (1=in use, 0=free)
Bit 16: Write mode (1=write, 0=read)
Bits 0-15: Reserved
```

**Example open file (fd 3, writing, position 100):**
```
u.ofiles+9:               " Offset for fd 3
   f.flags:  0600000      " Valid + write mode
   f.badd:   100          " Current position
   f.i:      42           " Inode 42
```

### System Data (sysdata)

```assembly
sysdata:
   s.nxfblk: .=.+1     " Next free block overflow list
   s.nfblks: .=.+1     " Number of free blocks in s.fblks
   s.fblks: .=.+10     " Free block numbers (cache of 10)
   s.uniq: .=.+1       " Unique ID counter (increments on file create)
   s.tim: .=.+2        " System time (36-bit, AC+MQ)
```

**Example sysdata at boot:**
```
s.nxfblk: 0            " No overflow yet
s.nfblks: 10           " 10 blocks in cache
s.fblks:  6399 6398 6397 6396 6395 6394 6393 6392 6391 6390
s.uniq:   142          " Next file will get uniq=143
s.tim:    01234567 023456  " Time since boot (arbitrary units)
```

The system writes `sysdata` to disk block 1 on every system call exit (if `.savblk` not set). This ensures consistency even if power fails.

### Constants and Manifests

```assembly
" Manifest constants
mnproc = 10            " Maximum number of processes
dspbsz = 270           " Display buffer size in words
ndskbs = 4             " Number of disk buffers

" Decimal constants
d0: 0
d1: 1
d2: 2
...
d10: 10

" Octal constants
o7: 07
o12: 012  (newline)
o15: 015  (carriage return)
o17: 017
o20: 020  (directory flag)
...
o200000: 0200000  (process "out" flag)

" Negative constants
dm1: -1
dm3: -3
```

### Memory Allocation Pattern

The kernel data structures are allocated sequentially in memory:

```
Address   Structure            Size
────────  ──────────────────   ──────
~03000    sysdata              14 words
~03016    ulist                40 words
~03060    userdata             64 words
~03144    inode                12 words
~03160    dnode                8 words
~03170    fnode                3 words
~03173    (work variables)     ~50 words
~03250    sfiles (wait queues) 10 words
~03262    dspbuf               270 words
~03556    q2 (char queues)     100 words
~03660    dskbs (disk cache)   260 words
~04150    (end of kernel data)
```

Total kernel memory: ~4,000 words (code + data)
Remaining for user: ~4,096 words

## 10. Naming Conventions

The PDP-7 Unix source code follows specific naming conventions that reflect both the hardware constraints and Ken Thompson's terse style.

### Why s1 through s9?

**Historical reasons:**
1. **Assembly required short filenames** - Early assemblers had filename length limits
2. **Sequential development** - Files numbered in rough order of creation
3. **Logical grouping** - Related functionality stayed together
4. **Load order** - Assembler concatenated files in order (s1, s2, ..., s9)

**Modern equivalent:**
```c
// If PDP-7 Unix were written in C today:
kern/entry.c      // s1.s - entry/exit
kern/file.c       // s2.s - file operations
kern/proc.c       // s3.s - process management
kern/util.c       // s4.s - utilities
kern/support.c    // s5.s - support functions
fs/inode.c        // s6.s - file system core
kern/trap.c       // s7.s - interrupt handler
kern/data.c       // s8.s - data structures
kern/boot.c       // s9.s - boot loader
```

### Symbol Naming Patterns

**System calls:** Prefixed with dot (`.`)
```assembly
.open, .read, .write, .fork, .exit
```

**Internal functions:** No prefix
```assembly
alloc, free, copy, betwen, iget, iput, namei
```

**Data structures:** First letter indicates type
```assembly
i.flags   " inode field
d.name    " directory field
f.badd    " file descriptor field
u.pid     " user data field
s.tim     " system data field
```

**Constants:**
```assembly
d0, d1, d2     " Decimal constants
o7, o12, o20   " Octal constants
dm1, dm3       " Decimal minus (negative)
```

**Temporary variables:** `9f+t` pattern
```assembly
t = 0          " At start of file
...
9f+t           " Refers to temp slot in array '9'
t = t+1        " Increment for next function
```

This creates function-local temporaries in the `9` array (defined in s8.s):
```assembly
9: .=.+t       " Allocate t words
```

### Label Naming

**Local labels:** Digits (1, 2, 1f, 1b)
```assembly
1:             " Label '1'
   ...
   jmp 1b      " Jump backward to '1'
   ...
   jmp 1f      " Jump forward to '1'
1:             " Reuse of label '1'
```

**Global labels:** Descriptive names
```assembly
coldentry:     " Cold boot entry point
pibreak:       " Program interrupt break
swap:          " Process swapper
```

**Special labels:**
```assembly
0f, 1f, 2f     " Forward reference to argument
..             " Special: self-reference (modified at runtime)
```

### Octal Address Conventions

**Why octal?** 18-bit words divide evenly into 6 octal digits:
```
Binary:  000 000 000 000 000 000   (18 bits)
Octal:    0   0   0   0   0   0    (6 digits)
Decimal: 0-262,143                 (awkward)
```

**Common addresses:**
```assembly
00000   " Memory start
00020   " System call trap vector
00100   " Kernel code start
04000   " User memory start (decimal 2048)
07700   " Disk buffer (dskbuf)
07777   " Near end of memory
17777   " Last address (8K - 1)
```

**Octal bit masks:**
```assembly
o17777  " Low 13 bits (8K address space)
o77777  " Low 15 bits
o177    " Low 7 bits (ASCII)
o777    " Low 9 bits (9-bit character)
```

### Function Call Conventions

**JMS (Jump to Subroutine):**
```assembly
" Caller:
   jms function
   " Return address stored in function[0]

" Callee:
function: 0
   ...
   jmp function i    " Return via stored address
```

**Return values:**
- Single value: Return in AC
- Two values: AC + MQ
- Multiple values: Store in caller-provided addresses

**Skip returns:** Indicate success/failure
```assembly
" Function that can fail:
function: 0
   ...
   isz function      " Skip return on success
   jmp function i    " Normal return (failure)

" Caller:
   jms function
      jmp error      " Taken if no skip
   " Success path
```

### Naming Evolution

**Early names (terse):**
```assembly
i, ii, di         " Inode, inode number, directory index
8, 9              " Index registers
t                 " Temporary counter
```

**Later names (more descriptive):**
```assembly
searchu, lookfor  " Process table search
argname, seektell " Higher-level operations
```

**The tradeoff:**
- Short names: Faster to type, fit in limited symbol table
- Long names: Easier to understand, self-documenting

Thompson favored extreme brevity. Modern standards prefer clarity.

## 11. Size and Complexity Analysis

Let's analyze the remarkable efficiency of PDP-7 Unix.

### Line Counts by Module

```
File  | Lines | Code | Comments | Blank | Code/Total
──────┼───────┼──────┼──────────┼───────┼───────────
s1.s  |  193  | 150  |   30     |  13   | 78%
s2.s  |  328  | 280  |   35     |  13   | 85%
s3.s  |  347  | 295  |   40     |  12   | 85%
s4.s  |  334  | 285  |   35     |  14   | 85%
s5.s  |  273  | 230  |   30     |  13   | 84%
s6.s  |  344  | 295  |   35     |  14   | 86%
s7.s  |  350  | 310  |   30     |  10   | 89%
s8.s  |  208  | 195  |   10     |   3   | 94%
s9.s  |  112  |  95  |   12     |   5   | 85%
──────┼───────┼──────┼──────────┼───────┼───────────
Total | 2,489 | 2,135|  257     |  97   | 86%
```

**Observations:**
- Very high code density (86% executable code)
- Minimal comments (10% of lines)
- Few blank lines (4%)
- s8.s is nearly all code (data declarations)

### Functionality Density

```
Category              | Functions | Lines | Lines/Function
──────────────────────┼───────────┼───────┼───────────────
System calls          |    26     |  600  |    23
File system core      |    15     |  700  |    47
Process management    |     8     |  400  |    50
Device I/O            |    12     |  350  |    29
Utilities             |    20     |  300  |    15
Interrupt handling    |     1     |  350  |   350
Boot/initialization   |     5     |  200  |    40
──────────────────────┼───────────┼───────┼───────────────
Total                 |   ~87     | 2,900 |    33
```

Average function size: **33 lines**

For comparison:
- Modern Linux kernel: ~100-200 lines per function average
- PDP-7 Unix: 33 lines per function
- Difference: 3-6x more compact

### Functionality per Line Metrics

Let's measure what each line of code achieves:

**System call implementation:**
```
26 system calls / 2,489 total lines = 96 lines per system call

But several system calls are trivial (getuid: 3 lines)
Complex system calls (fork, read, write): 50-100 lines each
```

**File system operations:**
```
Operations supported:
  - Inode read/write
  - Directory lookup
  - Block allocation/free
  - Large file support (indirect blocks)
  - Permission checking
  - Link/unlink

Lines of code: ~900 (s2.s + s6.s)
```

**Process management:**
```
Operations:
  - fork (create process)
  - exit (terminate)
  - swap (process switching)
  - sleep/wakeup (synchronization)
  - smes/rmes (IPC)

Lines of code: ~400 (s3.s, parts of s1.s)
```

**Device drivers:**
```
Devices supported: 7 (TTY, keyboard, display, tape, disk, clock, card reader)
Lines per driver: ~50
Total driver code: ~350 lines

Compare to Linux:
  - Single device driver: Often 1,000-10,000 lines
  - PDP-7 Unix: All drivers fit in 350 lines
```

### Comparison with Modern Systems

| Metric | PDP-7 Unix (1969) | Linux 6.x (2024) | Ratio |
|--------|-------------------|------------------|-------|
| Total kernel lines | 2,489 | ~30,000,000 | 12,000× |
| System calls | 26 | ~450 | 17× |
| Loadable modules | 0 | ~6,000 | ∞ |
| Supported CPUs | 1 (PDP-7) | ~30 architectures | 30× |
| File systems | 1 (Unix FS) | ~70 | 70× |
| Device drivers | 7 | ~4,000 | 570× |
| Developers | 2 (Thompson, Ritchie) | ~20,000 | 10,000× |
| Development time | ~4 weeks | 30+ years | ∞ |
| Binary size | ~8 KB | ~10 MB | 1,250× |

**Why the difference?**

PDP-7 Unix could be small because:
1. **One CPU architecture** - No portability abstractions
2. **No backward compatibility** - No legacy code
3. **Minimal hardware** - Only 7 devices to support
4. **Simple features** - No networking, no graphics, no security
5. **Expert programmers** - Thompson and Ritchie were masters
6. **Assembly language** - Direct hardware access, no overhead

Modern Linux must handle:
1. **30+ CPU architectures** - x86, ARM, RISC-V, etc.
2. **40+ years of compatibility** - Support ancient software
3. **Thousands of devices** - USB, PCI, network cards, GPUs
4. **Complex features** - Networking, security, virtualization
5. **Many contributors** - Code from thousands of developers
6. **Portability** - Written in C, works on many platforms

### Code Reuse Analysis

How much code is shared vs. specialized?

```
Shared utilities (s4.s, s5.s):      ~600 lines (24%)
  - Used by all other modules
  - High reuse factor (called from 50+ places)

File system code (s2.s, s6.s):      ~900 lines (36%)
  - Called by file-related syscalls
  - Moderate reuse (10-20 call sites per function)

Process code (s1.s, s3.s):          ~540 lines (22%)
  - Called by process syscalls and scheduler
  - Moderate reuse

Device drivers (s3.s, s7.s):        ~400 lines (16%)
  - Device-specific, low reuse
  - Each driver used by 1-2 system calls

Data structures (s8.s):             ~200 lines (8%)
  - Included by all modules
  - Maximum reuse

Boot code (s9.s):                   ~112 lines (4%)
  - Run once, never reused
  - Minimum reuse
```

**Reuse efficiency:**
- 60% of code is highly reused (utilities, data structures)
- 40% is specialized (drivers, boot, specific syscalls)

Compare to modern systems:
- Modern OS: ~70-80% specialized, 20-30% shared
- PDP-7 Unix achieved higher reuse through simplicity

### Complexity Metrics

**Cyclomatic complexity** (branches per function):

```
Function Type       | Avg Branches | Complexity
────────────────────┼──────────────┼────────────
Utilities           |      2-3     | Simple
System calls        |      4-6     | Moderate
File system ops     |      8-12    | Complex
Interrupt handler   |     20+      | Very complex
```

**Deepest call chains:**

```
User program
  → sys call (s1.s)
    → .read (s2.s)
      → finac (s6.s)
        → fget (s5.s)
      → iread (s6.s)
        → pget (s6.s)
          → alloc (s4.s)
        → dskrd (s4.s)
          → dskio (s4.s)
            → dsktrans (s4.s)

Depth: 9 levels
```

Modern kernels often reach 15-20 levels deep.

**Coupling analysis:**

```
Module    | Calls To  | Called By | Coupling Score
──────────┼───────────┼───────────┼───────────────
s1.s      | s2,s3,s4  |  (entry)  | Medium
s2.s      | s4,s5,s6  |   s1      | High
s3.s      | s4,s5,s7  |   s1      | High
s4.s      | (hardware)|  ALL      | High (utility)
s5.s      | s4,s6     | s2,s3,s6  | Medium
s6.s      | s4,s5     | s2,s5     | Medium
s7.s      | s4,s5     |(hardware) | Low (isolated)
s8.s      | -         |  ALL      | High (data)
s9.s      | s4,s6,s8  | (boot)    | Low (runs once)
```

Most modules are moderately coupled. s4.s (utilities) and s8.s (data) are highly coupled by design.

## 12. Reading Map

A guide to navigating the source code effectively.

### What to Read First

**For understanding the big picture:**
1. **s8.s** - Data structures (30 minutes)
   - See all the key structures
   - Understand memory layout
   - Learn naming conventions

2. **s1.s** - System call dispatcher (1 hour)
   - Entry/exit flow
   - System call table
   - Swapping logic

3. **This chapter** - Architecture overview (2 hours)
   - Mental model of entire system

**For file system understanding:**
1. **s6.s** - File system core (3 hours)
   - Start with `iget`, `iput` (simple)
   - Then `namei` (directory lookup)
   - Then `iread`, `iwrite` (complex)
   - Finally `pget` (block mapping)

2. **s2.s** - File operations (2 hours)
   - See how syscalls use s6.s functions
   - Understand permission checking
   - Learn file descriptor management

**For process understanding:**
1. **s3.s** - Process management (2 hours)
   - Start with `.fork` (process creation)
   - Then `.exit` (termination)
   - Then `sleep`/`wakeup` (synchronization)

2. **s1.s** - Process switching (1 hour)
   - `swap` routine
   - Context save/restore

**For device I/O understanding:**
1. **s7.s** - Interrupt handler (3 hours)
   - Start with `pibreak` structure
   - Trace one device (e.g., TTY)
   - Understand `wakeup` mechanism

2. **s3.s** - Device syscalls (1 hour)
   - `rttyi`, `wttyo` (TTY)
   - See how they use character queues

3. **s4.s** - Character queues (1 hour)
   - `putchar`, `getchar`
   - `putq`, `takeq`

### Dependencies Between Modules

**Dependency graph:**

```
        s8.s (data)
          ↑
          │ (used by all)
          │
    ┌─────┴─────────────────────────┐
    │                               │
   s4.s (utilities)                s1.s (entry)
    ↑                               ↑
    │                               │
    ├───────┬───────┬───────┬───────┤
    │       │       │       │       │
   s2.s   s3.s    s5.s    s6.s    s7.s
   file   proc   support  fs     interrupt

   s9.s (boot) - standalone, calls s4, s6, s8
```

**Required reading order:**
1. s8.s (no dependencies)
2. s4.s (depends on s8.s)
3. s1.s, s2.s, s3.s, s5.s, s6.s, s7.s (depend on s4.s, s8.s)
4. s9.s (uses s4.s, s6.s, s8.s)

### Cross-Reference Table

**Function → File mapping:**

| Function | File | Called By | Purpose |
|----------|------|-----------|---------|
| `alloc` | s4.s | s5.s, s6.s | Allocate disk block |
| `free` | s4.s | s6.s | Free disk block |
| `copy` | s4.s | ALL | Copy memory |
| `copyz` | s4.s | s5.s, s6.s, s9.s | Zero memory |
| `betwen` | s4.s | ALL | Range check |
| `dskrd` | s4.s | s6.s | Read disk block |
| `dskwr` | s4.s | s6.s | Write disk block |
| `iget` | s6.s | s2.s, s5.s, s6.s | Read inode |
| `iput` | s6.s | s2.s, s6.s | Write inode |
| `namei` | s6.s | s2.s, s5.s | Name lookup |
| `iread` | s6.s | s2.s, s9.s | Read file data |
| `iwrite` | s6.s | s2.s, s3.s, s9.s | Write file data |
| `dget` | s6.s | s5.s, s6.s | Read directory entry |
| `dput` | s6.s | s2.s, s5.s | Write directory entry |
| `fget` | s5.s | s2.s, s5.s, s6.s | Get file descriptor |
| `fput` | s5.s | s2.s | Put file descriptor |
| `sleep` | s5.s | s3.s | Block on event |
| `wakeup` | s7.s | s7.s | Unblock processes |
| `swap` | s1.s | s1.s, s3.s | Process switch |
| `fork` | s3.s | user | Create process |
| `exit` | s3.s | user | Terminate process |

**Data structure → Access pattern:**

| Structure | Defined | Read By | Written By | Frequency |
|-----------|---------|---------|------------|-----------|
| `ulist` | s8.s | s1.s, s3.s, s7.s | s3.s | Every syscall |
| `userdata` | s8.s | s1.s, s2.s, s3.s | s1.s, s2.s, s3.s | Every syscall |
| `sysdata` | s8.s | s4.s | s4.s | Every alloc/free |
| `inode` | s8.s | s6.s, s2.s | s6.s | Every file operation |
| `dnode` | s8.s | s6.s | s6.s | Directory operations |
| `fnode` | s8.s | s5.s | s5.s | File descriptor ops |
| `dskbuf` | s8.s | s4.s, s6.s | s4.s | Every disk I/O |

### Reading Strategies

**Strategy 1: Top-Down (Conceptual)**
1. Read this chapter thoroughly
2. Read s1.s (system call flow)
3. Pick one system call (e.g., `read`)
4. Trace it through all layers:
   - s2.s: `.read` entry point
   - s6.s: `iread` implementation
   - s4.s: `dskrd` disk access
5. Repeat for other system calls

**Strategy 2: Bottom-Up (Implementation)**
1. Read s8.s (data structures)
2. Read s4.s (utilities)
3. Read s6.s (file system core)
4. Read s2.s (file system calls)
5. Read s5.s (support functions)
6. Read s3.s (process management)
7. Read s7.s (interrupt handling)
8. Read s1.s (system dispatcher)
9. Read s9.s (boot loader)

**Strategy 3: Feature-Focused**

For **file system**:
- s8.s: Data structures
- s4.s: Disk I/O
- s6.s: Inode operations
- s2.s: System calls

For **process management**:
- s8.s: Process table
- s1.s: Context switching
- s3.s: Fork/exit/IPC

For **device I/O**:
- s4.s: Character queues
- s7.s: Interrupt handler
- s3.s: Device system calls

**Strategy 4: Historical Recreation**
1. Imagine you're Ken Thompson in 1969
2. Start with s1.s (first thing needed)
3. Add s2.s (basic file operations)
4. Add s3.s (processes)
5. Add s4.s (utilities as needed)
6. Continue in order s5, s6, s7, s8, s9

### Common Confusion Points

**1. The `9f+t` temporary variables**
```assembly
t = 0              " Reset at start of file
...
dac 9f+t           " Store in temporary slot
t = t+1            " Allocate next slot
```
Think of `9` as an array, `t` as the allocation pointer.

**2. Skip returns**
```assembly
jms function
   jmp error       " Taken if function fails (no skip)
" Success path
```
If function succeeds, it executes `isz function`, skipping the error jump.

**3. Indirect addressing**
```assembly
lac u.ulistp i     " Load from address stored in u.ulistp
dac 9f+t i         " Store to address stored in 9f+t
```
The `i` suffix means "indirect" (pointer dereference).

**4. Forward/backward labels**
```assembly
1: ...             " Label '1'
   jmp 1b          " Jump backward to previous '1'
   ...
   jmp 1f          " Jump forward to next '1'
1: ...             " Another label '1'
```

**5. Self-modifying code**
```assembly
dac .+1            " Store into next instruction
lac ..             " Load from address just modified
```
Common in PDP-7 due to lack of general-purpose registers.

### Recommended Reading Order

**Day 1** (4 hours): Foundation
- This chapter: Sections 1-4 (architecture, syscalls, file system)
- s8.s: Complete file
- s1.s: Entry/exit code

**Day 2** (4 hours): File System
- This chapter: Sections 4-5 (file system, processes)
- s4.s: Disk I/O functions
- s6.s: Functions `iget`, `iput`, `namei`

**Day 3** (4 hours): File System Continued
- s6.s: Functions `iread`, `iwrite`, `pget`
- s2.s: System calls `.read`, `.write`, `.open`, `.creat`

**Day 4** (4 hours): Process Management
- This chapter: Section 5 (process model)
- s3.s: Functions `.fork`, `.exit`
- s1.s: Function `swap`

**Day 5** (4 hours): Device I/O
- This chapter: Section 7 (device I/O)
- s7.s: `pibreak` interrupt handler
- s4.s: Character queue functions
- s3.s: Device handlers `rttyi`, `wttyo`

**Day 6** (4 hours): Advanced Topics
- This chapter: Sections 8-9 (boot, data structures)
- s5.s: Support functions
- s9.s: Boot loader

**Day 7** (4 hours): Mastery
- Re-read s1.s with full understanding
- Trace a complete system call from user to kernel and back
- Understand how interrupts, swapping, and I/O interact

**Total**: ~28 hours to master PDP-7 Unix source code

For comparison:
- Understanding Linux kernel basics: ~200 hours
- PDP-7 Unix is 7× faster to learn

## Conclusion

You now have a complete architectural overview of PDP-7 Unix:

1. **The Big Picture**: Nine modules totaling 2,489 lines
2. **Kernel Organization**: Each file has a specific purpose
3. **System Calls**: 26 calls organized by category
4. **File System**: Inodes, directories, free blocks
5. **Process Model**: Simple swapping-based multitasking
6. **Memory Map**: 8K words, carefully allocated
7. **Device I/O**: Seven devices, character queues
8. **Boot Sequence**: From power-on to /init
9. **Data Structures**: Process table, inodes, directories
10. **Naming Conventions**: Terse but consistent
11. **Complexity Analysis**: Remarkably efficient design
12. **Reading Map**: How to navigate the source

In the following chapters, we'll dive deep into each area:

- **Chapter 5**: Complete kernel internals walkthrough
- **Chapter 6**: Boot process and initialization details
- **Chapter 7**: File system implementation deep-dive
- **Chapter 8**: Process management internals
- **Chapter 9**: Device drivers and I/O subsystem

Armed with this architectural understanding, you're ready to explore the details. Remember Thompson's philosophy: **simplicity is key**. Every line of code serves a purpose. There is no cruft, no legacy compatibility, no unnecessary abstraction. Just pure, elegant systems programming.

Welcome to the heart of Unix.
