# Chapter 7 - File System Implementation

The PDP-7 Unix file system represents one of the most significant innovations in computing history. While constrained by hardware limitations—just 8K words of memory and a 300KB DECtape—Thompson and Ritchie created a file system design so elegant and powerful that it forms the foundation of virtually every modern operating system.

This chapter examines the complete implementation: from low-level disk layout to high-level operations like opening files and traversing directories. We'll trace actual code paths, analyze data structures, and understand why decisions made in 1969 continue to influence operating system design today.

## 7.1 Revolutionary Design

### The Fundamental Innovation

In 1969, most file systems tightly coupled filenames with file storage. The PDP-7 Unix file system introduced a radical separation:

**Traditional approach (1960s):**
```
Directory: "MYFILE.DAT" → Track 142, Sector 5, Length 200 blocks
```

**Unix approach (1969):**
```
Directory: "myfile" → Inode 42
Inode 42: → Owner, permissions, size, blocks [5123, 5124, 5125, ...]
```

### Why This Was Revolutionary

**1. Hard Links Become Trivial**

Multiple directory entries can reference the same inode:
```
/dd/ken/prog.s    → Inode 137
/dd/dmr/test.s    → Inode 137  (same file!)
```

**2. Renaming Requires No Data Movement**

Traditional systems: Copy entire file to new location, delete old.
Unix: Change directory entry, done. Even for gigabyte files (if they existed).

**3. Permissions and Metadata in One Place**

No need to update multiple directory entries when changing permissions or ownership.

**4. Efficient Directory Operations**

Directories are just files. No special code paths. Reading a directory is reading a file.

### Comparison with Contemporary Systems

**IBM OS/360 (1964)**
- **Organization:** Partitioned datasets (PDS) with members
- **Naming:** Hierarchical but rigid (dataset.member)
- **Metadata:** Stored in directory entry
- **Rename:** Copy entire dataset
- **Links:** Not supported

**DEC TOPS-10 (1967)**
- **Organization:** Flat directory per user [PROJECT,PROGRAMMER]
- **Naming:** FILENAME.EXT
- **Metadata:** In directory (UFD - User File Directory)
- **Rename:** Copy file
- **Links:** Not supported

**Multics (1969)**
- **Organization:** Hierarchical segments
- **Naming:** Path-based (>user>project>file)
- **Metadata:** Separate "branch" structure (similar concept to inode!)
- **Rename:** Complex pointer updates
- **Links:** Supported but heavyweight

**PDP-7 Unix (1969)**
- **Organization:** Hierarchical directories
- **Naming:** Flexible paths (/dd/ken/file)
- **Metadata:** Inode separate from name
- **Rename:** Update directory entry only
- **Links:** Natural and efficient

**Historical note:** Multics influenced Unix, but Unix simplified the concept dramatically. Where Multics took 10,000 lines to implement segments, Unix used 300 lines for inodes.

## 7.2 Disk Layout

The DECtape in PDP-7 Unix provides 6,400 tracks, each holding 64 words (18 bits each). This gives approximately 300KB of total storage. The disk is organized into carefully designed regions:

### Complete Disk Organization

```
Track Range    | Contents              | Size        | Purpose
---------------|-----------------------|-------------|---------------------------
0-1            | Bootstrap Code        | 2 tracks    | Cold/warm boot loaders
2-711          | Inode Area            | 710 tracks  | File metadata storage
712-6399       | Data Area             | 5,688 tracks| File content blocks
Track 6000     | System Data           | 1 track     | Free list, unique ID, time
```

**Calculations:**

- **Total capacity:** 6,400 tracks × 64 words/track × 18 bits/word = 7,372,800 bits ≈ 922KB
- **Usable data:** 5,688 tracks × 64 words = 364,032 words ≈ 819KB
- **Inode capacity:** 710 tracks ÷ (12 words/inode × 64 words/track) = 3,796 inodes maximum

### Detailed Memory Map Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PDP-7 UNIX DISK LAYOUT                      │
│                     (DECtape - 6400 tracks total)                   │
└─────────────────────────────────────────────────────────────────────┘

Track 0-1: BOOTSTRAP AREA (2 tracks = 128 words)
┌─────────────────────────────────────────────────────────────┐
│ Track 0:  Cold boot loader (s9.s) - Initialize empty FS     │
│ Track 1:  Warm boot loader (s8.s coldentry) - Normal boot   │
└─────────────────────────────────────────────────────────────┘

Track 2-711: INODE AREA (710 tracks = 45,440 words)
┌─────────────────────────────────────────────────────────────┐
│ 5.33 inodes per track (12 words each, 64 words per track)   │
│ Track 2:   Inodes 0-4   (inode 0 unused, 1 = root dir)      │
│ Track 3:   Inodes 5-9                                        │
│ Track 4:   Inodes 10-14                                      │
│ ...                                                          │
│ Track 711: Inodes 3790-3794                                  │
│                                                              │
│ Total: ~3,795 inodes maximum                                │
│                                                              │
│ Special inodes:                                              │
│   Inode 0:  Reserved (unused/invalid marker)                │
│   Inode 1:  Root directory "/"                              │
│   Inode 2:  /dd directory                                   │
│   Inode 3:  /dd/sys directory or init                       │
│   Inode 4+: User files                                      │
└─────────────────────────────────────────────────────────────┘

Track 712-6399: DATA AREA (5,688 tracks = 364,032 words)
┌─────────────────────────────────────────────────────────────┐
│ File content blocks (64 words per block)                    │
│ Track 712:  Block 0 (first data block)                      │
│ Track 713:  Block 1                                         │
│ ...                                                          │
│ Track 6399: Block 5687 (last data block)                    │
│                                                              │
│ Maximum data storage: 5,688 × 64 = 364,032 words           │
│                     = 656,457 bytes                         │
│                     ≈ 641 KB                                │
└─────────────────────────────────────────────────────────────┘

Track 6000: SYSTEM DATA TRACK (1 track = 64 words) [SPECIAL LOCATION]
┌─────────────────────────────────────────────────────────────┐
│ sysdata structure (saved/restored on every boot):           │
│   Word 0:     s.nxfblk  - Next free block overflow pointer  │
│   Word 1:     s.nfblks  - Number of free blocks in memory   │
│   Words 2-11: s.fblks   - Free block cache (10 blocks)      │
│   Word 12:    s.uniq    - Unique ID counter                 │
│   Word 13-14: s.tim     - System time (36-bit)              │
│   Words 15+:  Reserved for future use                       │
└─────────────────────────────────────────────────────────────┘
```

### Why This Layout?

**1. Bootstrap at Track 0**
- Tape can be loaded from beginning
- Minimal seeking during boot
- Standard location known to hardware

**2. Inodes Near Beginning**
- Frequently accessed (every file operation)
- Shorter seek times from track 0
- Grouped together for locality

**3. Data Area is Contiguous**
- Simple block allocation
- No fragmentation issues
- Easy to calculate block → track mapping

**4. System Data at Fixed Location**
- Known address for quick access
- Written on clean shutdown
- Read on warm boot

### Physical Block Addressing

Converting inode number to track:

```assembly
" Given inode number in AC, find its track
inode_to_track:
    lac inode_num          " Load inode number (e.g., 42)
    div d5                 " Divide by 5 (5.33 inodes per track)
    add d2                 " Add 2 (inode area starts at track 2)
    dac track              " Result: track number

    " Offset within track
    lac inode_num
    div d5                 " Divide by 5
    lac mqr                " Get remainder
    mul d12                " Multiply by 12 (words per inode)
    dac offset             " Offset in words from track start
```

**Example:** Inode 42
- Track = 42 ÷ 5 + 2 = 8 + 2 = Track 10
- Offset = (42 mod 5) × 12 = 2 × 12 = 24 words into track

## 7.3 Inodes - The Heart of Unix

The inode (index node) is the central data structure. Every file and directory has exactly one inode containing all metadata.

### Inode Structure (12 Words)

```assembly
" inode - File metadata structure (12 words = 216 bits)
" Location: Disk tracks 2-711, in-memory copy during operations

inode:
   i.flags: .=.+1    " [Word 0] File type and permissions (18 bits)
   i.dskps: .=.+7    " [Words 1-7] Disk block pointers (7 words)
   i.uid:   .=.+1    " [Word 8] Owner user ID
   i.nlks:  .=.+1    " [Word 9] Number of directory links (negative)
   i.size:  .=.+1    " [Word 10] File size in words
   i.uniq:  .=.+1    " [Word 11] Unique ID (validation)
   .=inode+12
```

### Field-by-Field Analysis

#### i.flags - Type and Permissions (Word 0)

The 18-bit i.flags word packs file type and permissions:

```
Bit Layout (18 bits):
┌─────┬─────┬─────┬─────┬──────────────────────────────┐
│ 17  │ 16  │ 15  │ 14  │  13  12  11 ... 3  2  1  0  │
├─────┼─────┼─────┼─────┼──────────────────────────────┤
│Large│Char │ Dir │ Res │    Permission Bits (14)      │
│File │ Dev │     │     │                              │
└─────┴─────┴─────┴─────┴──────────────────────────────┘

Bit 17: Large file (uses indirect blocks)
Bit 16: Character device
Bit 15: Directory
Bit 14: Reserved
Bits 13-0: Permissions and flags
```

**Permission bit layout:**
```
Owner permissions:
  Bit 2: Read    (040000 octal = 100 000 000 000 000 000 binary)
  Bit 1: Write   (020000 octal = 010 000 000 000 000 000 binary)
  Bit 0: Execute (010000 octal = 001 000 000 000 000 000 binary)

Group permissions (not fully implemented in PDP-7):
  Bits 5-3: (Reserved for future use)

Other permissions:
  Bits 8-6: (Reserved for future use)

Setuid bit:
  Bit 9: Setuid (004000 octal)
```

**Common i.flags values:**

```
0100644  Regular file, rw-r--r--
0040755  Directory, rwxr-xr-x
0104755  Executable with setuid, rwsr-xr-x
0120000  Character device
```

**Code to check permissions:**

```assembly
" Check if user can read file
" Input: AC = inode flags, user ID in u.uid
" Output: AC = 0 if allowed, -1 if denied

check_read:
    dac temp_flags        " Save flags
    lac u.uid            " Get user ID
    sad i.uid            " Same as file owner?
    jmp owner_check

    " Not owner - check world permissions (simplified)
    lac temp_flags
    and o4               " Mask world-read bit
    sza                  " Zero = no permission
    jmp allowed
    lac d-1              " Denied
    jmp ret

owner_check:
    lac temp_flags
    and o40000           " Owner read bit
    sza
    jmp allowed
    lac d-1
    jmp ret

allowed:
    cla                  " AC = 0 = allowed
ret:
    " Return
```

#### i.dskps - Disk Block Pointers (Words 1-7)

Seven words provide block addresses:

**For small files (≤ 7 blocks = 448 words):**
```
i.dskps[0] = Direct block 0 (track number 712-6399)
i.dskps[1] = Direct block 1
i.dskps[2] = Direct block 2
i.dskps[3] = Direct block 3
i.dskps[4] = Direct block 4
i.dskps[5] = Direct block 5
i.dskps[6] = Direct block 6
```

**For large files (> 7 blocks):**
```
i.dskps[0] = Indirect block (points to array of 64 block numbers)
i.dskps[1-6] = Unused (0)
```

**Maximum file size calculation:**

Small file max: 7 blocks × 64 words = 448 words = 1,008 bytes

Large file max: 1 indirect block → 64 pointers × 64 words/block = 4,096 words = 9,216 bytes

#### i.uid - Owner User ID (Word 8)

Simple 18-bit user ID. Special values:
- 0 or -1: Superuser (root)
- 1-32767: Regular users

#### i.nlks - Link Count (Word 9)

**Important:** Stored as negative number!

```
i.nlks = -1  →  1 link (normal file)
i.nlks = -2  →  2 links (hard-linked file)
i.nlks = -3  →  3 links
```

**Why negative?** Efficient check for "no links":
```assembly
    lac i.nlks
    sma              " Skip if minus (has links)
    jmp free_inode   " Zero or positive = no links, free it
```

#### i.size - File Size (Word 10)

Size in **words**, not bytes. Maximum value: 4096 (for large files).

#### i.uniq - Unique ID (Word 11)

Global counter incremented on every file creation. Prevents stale directory entries from accessing wrong files:

```assembly
" Creating new file
    lac s.uniq           " Get global counter
    add d1              " Increment
    dac s.uniq          " Store back
    dac new_inode+i.uniq " Set in new inode
    dac dir_entry+d.uniq " Set in directory entry
```

Later, when accessing file:
```assembly
" Validate directory entry still points to correct file
    lac dir_entry+d.uniq
    sad inode+i.uniq
    jmp ok              " Match - safe to use
    " Mismatch - file was deleted and inode reused!
    jms error
```

### Complete inode Code Analysis

#### iget - Load Inode from Disk

```assembly
" iget - Get inode from disk
" Input: AC = inode number
" Output: Inode loaded into core at 'inodebuf'
" Destroys: All registers

iget:
    0                    " Return address
    dac iget_inum       " Save inode number

    " Calculate track number
    div d5              " Divide by 5 inodes per track
    add d2              " Add 2 (inode area starts at track 2)
    dac track_num       " Save track number

    " Calculate offset within track
    lac iget_inum
    div d5
    lac mqr             " Remainder in MQ
    mul d12             " × 12 words per inode
    dac inode_offset

    " Read track into buffer
    lac track_num
    jms dskrd; inodeblock  " Read track

    " Copy inode to inodebuf
    law inodeblock-1
    add inode_offset    " Start address
    dac 8               " Auto-increment pointer
    law inodebuf-1
    dac 9
    law d12             " 12 words to copy
    dac count

1:  lac 8 i             " Copy word
    dac 9 i
    isz count
    jmp 1b

    " Return inode number in AC
    lac iget_inum
    jmp iget i          " Return

iget_inum: 0
track_num: 0
inode_offset: 0
inodeblock: .=.+64      " Buffer for track
inodebuf: .=.+12        " Active inode
```

#### iput - Write Inode to Disk

```assembly
" iput - Put inode back to disk
" Input: AC = inode number, inodebuf contains modified inode
" Output: Inode written to disk

iput:
    0
    dac iput_inum

    " Calculate track and offset (same as iget)
    div d5
    add d2
    dac track_num

    lac iput_inum
    div d5
    lac mqr
    mul d12
    dac inode_offset

    " Read track (need to preserve other inodes)
    lac track_num
    jms dskrd; inodeblock

    " Copy inodebuf into correct position
    law inodebuf-1
    dac 8
    law inodeblock-1
    add inode_offset
    dac 9
    law d12
    dac count

1:  lac 8 i
    dac 9 i
    isz count
    jmp 1b

    " Write track back
    lac track_num
    jms dskwr; inodeblock

    jmp iput i

iput_inum: 0
```

### Example Inode: A Text File

Let's examine a real inode for `/dd/ken/prog.s`:

```
Offset  Field      Value (Octal)  Meaning
------  -----      -------------  -------
0       i.flags    040644         Regular file, rw-r--r--
1       i.dskps[0] 005231        Block 5231 (track 5943)
2       i.dskps[1] 005232        Block 5232
3       i.dskps[2] 005233        Block 5233
4       i.dskps[3] 000000        (unused)
5       i.dskps[4] 000000        (unused)
6       i.dskps[5] 000000        (unused)
7       i.dskps[6] 000000        (unused)
8       i.uid      000001         Owner: ken (UID 1)
9       i.nlks     177777         -1 in 18-bit = 1 link
10      i.size     000173         123 words = 276 bytes
11      i.uniq     001437         Unique ID 799
```

**Interpretation:**
- Regular file (bit 15 clear, bit 16 clear, bit 17 clear)
- Owner can read/write (bits 0-1 set for owner)
- Others can read (bit 2 set for world)
- Occupies 3 blocks (123 words ÷ 64 words/block = 2.9 → 3 blocks)
- Single directory link
- Created as the 799th file since system initialization

## 7.4 Directories

A directory is simply a file with the directory bit set (i.flags bit 15). Its content is an array of directory entries.

### Directory Entry Structure (8 Words)

```assembly
" Directory entry (8 words)
dnode:
   d.i:    .=.+1    " [Word 0] Inode number
   d.name: .=.+4    " [Words 1-4] Filename (4 words = 6-8 chars)
   d.uniq: .=.+1    " [Word 5] Unique ID (must match inode)
   .=.+2             " [Words 6-7] Padding/reserved
   .=dnode+8
```

### Filename Encoding

PDP-7 stores two 9-bit characters per word:

```
Word layout (18 bits):
┌─────────┬─────────┐
│ Char 0  │ Char 1  │
│ (9 bits)│ (9 bits)│
└─────────┴─────────┘

4 words = 8 characters maximum, but only 6 used in practice
```

**Example: "prog.s" filename**

```
ASCII values (9-bit):
  'p' = 160 (octal) = 001 110 000
  'r' = 162 (octal) = 001 110 010
  'o' = 157 (octal) = 001 101 111
  'g' = 147 (octal) = 001 100 111
  '.' = 056 (octal) = 000 101 110
  's' = 163 (octal) = 001 110 011

Packing:
  d.name[0] = 'p' 'r' = 160162 (octal)
  d.name[1] = 'o' 'g' = 157147 (octal)
  d.name[2] = '.' 's' = 056163 (octal)
  d.name[3] = '\0''\0' = 000000 (padding)
```

**Code to pack filename:**

```assembly
" Pack ASCII string into directory name format
" Input: String at 'filename', output at 'dname'

pack_name:
    0
    law filename-1
    dac 8               " Source pointer
    law dname-1
    dac 9               " Dest pointer
    law d4              " 4 words max
    dac word_count

pack_word:
    lac 8 i             " Get first char
    sza                 " Check for null
    jmp 1f
    " Null terminator - fill rest with zeros
    cla
    jmp pack_store

1:  alss 9             " Shift to high 9 bits
    dac temp
    lac 8 i            " Get second char
    sza
    jmp 2f
    " Second char is null
    lac temp
    jmp pack_store

2:  add temp           " Combine both chars

pack_store:
    dac 9 i            " Store packed word
    isz word_count
    jmp pack_word

    jmp pack_name i

temp: 0
word_count: 0
```

### Example Directory: Root Directory "/"

Inode 1 contents (the root directory):

```
Directory entry 0: (current directory)
  d.i    = 1          " Points to self
  d.name = ". "       " 056000, 000000, 000000, 000000
  d.uniq = 1

Directory entry 1: (parent directory)
  d.i    = 1          " Root's parent is root
  d.name = ".."       " 056056, 000000, 000000, 000000
  d.uniq = 1

Directory entry 2:
  d.i    = 2          " /dd directory
  d.name = "dd"       " 144144, 000000, 000000, 000000
  d.uniq = 2

Directory entry 3:
  d.i    = 15         " /sys directory
  d.name = "sys"      " 163171, 163000, 000000, 000000
  d.uniq = 15
```

**Total directory size:** 4 entries × 8 words = 32 words

### Directory Operations Code

#### dget - Read Directory Entry

```assembly
" dget - Get directory entry
" Input: AC = entry number, u.cdir = directory inode
" Output: dirbuf contains entry

dget:
    0
    dac entry_num       " Save entry number
    mul d8              " × 8 words per entry
    dac byte_offset     " Offset in words

    " Get directory inode
    lac u.cdir
    jms iget            " Load into inodebuf

    " Calculate which block contains entry
    lac byte_offset
    div d64             " 64 words per block
    dac block_num
    lac mqr
    dac block_offset

    " Get block number from inode
    lac block_num
    sad d0
    lac inodebuf+i.dskps+0   " Block 0
    sad d1
    lac inodebuf+i.dskps+1   " Block 1
    " ... (more blocks)

    " Read block
    jms dskrd; dirbuf_block

    " Copy entry to dirbuf
    law dirbuf_block-1
    add block_offset
    dac 8
    law dirbuf-1
    dac 9
    law d8
    dac count

1:  lac 8 i
    dac 9 i
    isz count
    jmp 1b

    jmp dget i

entry_num: 0
byte_offset: 0
block_num: 0
block_offset: 0
dirbuf_block: .=.+64
dirbuf: .=.+8
```

#### dput - Write Directory Entry

```assembly
" dput - Write directory entry
" Input: AC = entry number, dirbuf = entry to write

dput:
    0
    " Similar to dget but copies from dirbuf to disk
    " (Code mirrors dget with reversed copy direction)
    jmp dput i
```

#### search_dir - Find File in Directory

```assembly
" search_dir - Search directory for filename
" Input: AC = directory inode, 'searchname' = name to find
" Output: AC = inode number if found, -1 if not found

search_dir:
    0
    dac dir_inode

    " Load directory inode
    lac dir_inode
    jms iget

    " Get directory size in entries
    lac inodebuf+i.size
    div d8              " Size in words ÷ 8 words per entry
    dac num_entries

    " Search each entry
    cla
    dac entry_index

search_loop:
    lac entry_index
    jms dget            " Get entry

    " Check if entry is used (d.i ≠ 0)
    lac dirbuf+d.i
    sza
    jmp check_name
    jmp next_entry      " Empty entry, skip

check_name:
    " Compare names (4 words)
    law searchname-1
    dac 8
    law dirbuf+d.name-1
    dac 9
    law d4
    dac count

compare_loop:
    lac 8 i
    sad 9 i
    jmp name_match
    " Mismatch
    jmp next_entry

name_match:
    isz count
    jmp compare_loop

    " All 4 words matched!
    " Verify unique ID
    lac dirbuf+d.i
    jms iget            " Load file's inode
    lac inodebuf+i.uniq
    sad dirbuf+d.uniq
    jmp found_it
    " Unique ID mismatch - stale entry
    jmp next_entry

found_it:
    lac dirbuf+d.i      " Return inode number
    jmp search_dir i

next_entry:
    isz entry_index
    lac entry_index
    sad num_entries
    jmp not_found
    jmp search_loop

not_found:
    lac d-1
    jmp search_dir i

dir_inode: 0
num_entries: 0
entry_index: 0
searchname: .=.+4       " Caller fills this
```

## 7.5 Free Block Management

The free block list uses an elegant two-level cache structure that minimizes disk I/O.

### Free Block List Structure

**In-memory cache (in sysdata structure):**

```assembly
" sysdata - System-wide data (64 words total)
sysdata:
    s.nxfblk: .=.+1    " Next overflow block pointer
    s.nfblks: .=.+1    " Number of blocks in cache (0-10)
    s.fblks:  .=.+10   " Cached free block numbers
    s.uniq:   .=.+1    " Unique ID counter
    s.tim:    .=.+2    " System time (36-bit)
    .=.+49             " Reserved
    .=sysdata+64
```

**On-disk overflow blocks:**

When the in-memory cache overflows, blocks are stored on disk. Each overflow block contains:

```
Word 0:     Pointer to next overflow block (or 0)
Words 1-63: Free block numbers (up to 63 blocks)
```

### Visual Representation

```
In-Memory (sysdata):                     On-Disk Overflow:
┌──────────────────────┐
│ s.nxfblk: 5234  ─────┼────┐            ┌─────────────────┐
│ s.nfblks: 10         │    │            │ Block 5234:     │
│ s.fblks[0]: 1234     │    └──────────> │  [0]: 5500      │ → Block 5500...
│ s.fblks[1]: 1235     │                 │  [1]: 3456      │
│ s.fblks[2]: 1236     │                 │  [2]: 3457      │
│ s.fblks[3]: 1237     │                 │  ...            │
│ s.fblks[4]: 1238     │                 │  [63]: 3519     │
│ s.fblks[5]: 1239     │                 └─────────────────┘
│ s.fblks[6]: 1240     │
│ s.fblks[7]: 1241     │
│ s.fblks[8]: 1242     │
│ s.fblks[9]: 1243     │
└──────────────────────┘

When s.nfblks = 10 (full), allocating a block:
1. Return s.fblks[9] (block 1243)
2. Decrement s.nfblks to 9

When s.nfblks = 0 (empty), allocating a block:
1. Read block s.nxfblk (5234)
2. s.nxfblk = block[0] (5500)
3. Copy block[1..63] → s.fblks[0..62]
4. s.nfblks = 63
5. Return s.fblks[62]
```

### Allocation Algorithm (alloc)

```assembly
" alloc - Allocate a free block
" Input: None
" Output: AC = block number, or halts if no blocks available

alloc:
    0

    " Check if we have blocks in cache
    lac s.nfblks
    sza                 " Zero blocks?
    jmp alloc_from_cache

    " Cache empty - need to refill from overflow
    lac s.nxfblk
    sza                 " Zero = no more blocks!
    jmp refill_cache

    " Out of disk space!
    jms halt_msg; "OUT OF DISK SPACE\0"

refill_cache:
    " Read overflow block
    lac s.nxfblk
    dac temp_block
    jms dskrd; overflow_buf

    " Get next overflow pointer
    lac overflow_buf+0
    dac s.nxfblk

    " Copy blocks to cache
    law overflow_buf
    dac 8
    law s.fblks-1
    dac 9
    law d63             " 63 blocks (word 0 is pointer)
    dac count

1:  lac 8 i
    dac 9 i
    isz count
    jmp 1b

    law d63
    dac s.nfblks

    " Mark overflow block as allocated
    " (Use it as the allocated block to avoid waste)
    lac temp_block
    jmp alloc i

alloc_from_cache:
    " Decrement count
    lac s.nfblks
    add d-1
    dac s.nfblks

    " Get block from cache
    tad s.fblks         " Add to base address
    dac 8
    lac 8 i             " Get block number

    " Clear the block before returning
    dac return_block
    jms dskwr; zero_block

    lac return_block
    jmp alloc i

temp_block: 0
return_block: 0
overflow_buf: .=.+64
zero_block: .=.+64      " Pre-zeroed block
```

### Free Algorithm (free)

```assembly
" free - Return block to free list
" Input: AC = block number to free

free:
    0
    dac block_to_free

    " Check if cache has room
    lac s.nfblks
    sad d10             " Cache full (10 blocks)?
    jmp overflow_cache

    " Add to cache
    tad s.fblks         " Calculate address
    dac 8
    lac block_to_free
    dac 8 i             " Store in cache

    " Increment count
    lac s.nfblks
    add d1
    dac s.nfblks

    jmp free i

overflow_cache:
    " Cache full - flush to disk
    " Use the block being freed as new overflow block
    lac block_to_free
    dac new_overflow

    " Write current cache to this block
    law overflow_buf
    dac 9

    " Word 0: pointer to previous overflow
    lac s.nxfblk
    dac 9 i

    " Words 1-63: copy cache (but only 10 valid)
    law s.fblks-1
    dac 8
    law d10
    dac count

1:  lac 8 i
    dac 9 i
    isz count
    jmp 1b

    " Write overflow block
    lac new_overflow
    jms dskwr; overflow_buf

    " Update in-memory pointers
    lac new_overflow
    dac s.nxfblk
    lac d1              " One block in cache (the one we just freed)
    dac s.nfblks

    jmp free i

block_to_free: 0
new_overflow: 0
```

### Why This Design?

**Advantages:**

1. **Fast common case:** Allocate/free usually requires no disk I/O
2. **Memory efficient:** Only 12 words for entire free list management
3. **Handles overflow gracefully:** Scales to any disk size
4. **Simple:** ~50 lines of code total

**Disadvantages:**

1. **Fragmentation:** Blocks allocated in order used, no locality
2. **No wear leveling:** Same blocks reused repeatedly
3. **Crash vulnerability:** Cache not synced to disk continuously

**Historical note:** This exact algorithm (with minor enhancements) was used through Unix V6 (1975). Modern file systems use bitmaps or B-trees, but the basic concept of caching free blocks persists.

## 7.6 File Operations

### 7.6.1 open - Opening a File

The `open` system call converts a filename to a file descriptor.

**System call interface:**
```assembly
sys open; filename; mode   " mode: 0=read, 1=write, 2=read+write
```

**Complete implementation:**

```assembly
" .open - Open file system call
" User provides: filename address, access mode
" Returns: File descriptor (0-9) in AC, or -1 on error

.open:
    " Get filename address from user space
    lac u.base          " System call arg 1
    dac filename_ptr

    " Get access mode
    lac u.base+1        " System call arg 2
    dac access_mode

    " Resolve filename to inode
    lac filename_ptr
    jms namei           " Returns inode number in AC
    spa                 " Positive = found
    jmp open_error      " Negative = not found

    dac file_inode

    " Get inode metadata
    lac file_inode
    jms iget            " Load into inodebuf

    " Check permissions
    lac inodebuf+i.flags
    jms check_access; access_mode
    spa
    jmp open_perm_error

    " Find free file descriptor slot
    jms find_free_fd    " Returns FD number in AC
    spa
    jmp open_too_many   " All 10 FDs in use

    dac fd_num

    " Calculate FD address in u.ofiles
    mul d3              " × 3 words per FD
    tad u.ofiles
    dac fd_addr

    " Initialize file descriptor
    law fd_addr
    dac 9

    lac access_mode
    add o100000         " Set "in use" bit
    dac 9 i             " f.flags

    cla                 " Position = 0
    dac 9 i             " f.badd (byte address)

    lac file_inode
    dac 9 i             " f.i (inode number)

    " Return file descriptor number
    lac fd_num
    jmp .open i

open_error:
    lac d-1
    jmp .open i

open_perm_error:
    lac d-1
    jmp .open i

open_too_many:
    lac d-1
    jmp .open i

filename_ptr: 0
access_mode: 0
file_inode: 0
fd_num: 0
fd_addr: 0
```

**Supporting function: find_free_fd**

```assembly
" find_free_fd - Find unused file descriptor
" Output: AC = FD number (0-9), or -1 if all used

find_free_fd:
    0
    law d10
    dac fd_count
    cla
    dac fd_index

check_fd:
    " Calculate address of FD
    lac fd_index
    mul d3
    tad u.ofiles
    dac fd_ptr

    " Check if in use (high bit of f.flags)
    lac fd_ptr
    dac 8
    lac 8 i             " Get f.flags
    and o100000         " Check "in use" bit
    sza                 " Zero = not in use
    jmp try_next

    " Found free FD
    lac fd_index
    jmp find_free_fd i

try_next:
    isz fd_index
    isz fd_count
    jmp check_fd

    " All FDs in use
    lac d-1
    jmp find_free_fd i

fd_count: 0
fd_index: 0
fd_ptr: 0
```

### 7.6.2 read - Reading from a File

**System call interface:**
```assembly
sys read; fd; buffer; count   " Read 'count' words into 'buffer'
```

**Implementation:**

```assembly
" .read - Read from file
" Input: FD number, buffer address, word count
" Output: AC = words read, or -1 on error

.read:
    " Get file descriptor
    lac u.base          " FD number
    jms get_fd_addr     " Returns FD address in AC
    spa
    jmp read_bad_fd

    dac fd_addr
    law fd_addr
    dac 8

    " Extract FD fields
    lac 8 i
    dac f.flags
    lac 8 i
    dac f.badd          " Current position
    lac 8 i
    dac f.i             " Inode number

    " Get buffer and count
    lac u.base+1
    dac buffer_addr
    lac u.base+2
    dac read_count

    " Load inode
    lac f.i
    jms iget

    " Check if position beyond EOF
    lac f.badd
    sad inodebuf+i.size
    jmp read_eof        " At end of file

    " Read character by character (simple but slow!)
    cla
    dac words_read
    law buffer_addr-1
    dac 9               " Output pointer

read_loop:
    " Calculate which block contains current position
    lac f.badd
    div d64             " Block number
    dac block_num
    lac mqr
    dac block_offset    " Offset within block

    " Get block address from inode
    lac block_num
    jms get_block_addr  " Returns track number
    spa
    jmp read_error

    " Read block
    jms dskrd; block_buf

    " Get word from block
    law block_buf-1
    add block_offset
    dac 8
    lac 8 i
    dac 9 i             " Store in user buffer

    " Update position
    lac f.badd
    add d1
    dac f.badd

    " Check for EOF
    sad inodebuf+i.size
    jmp read_done

    " Update count
    isz words_read
    lac words_read
    sad read_count
    jmp read_done
    jmp read_loop

read_done:
    " Update FD position
    lac fd_addr
    law fd_addr
    dac 8
    lac 8 i             " Skip f.flags
    lac f.badd
    dac 8 i             " Update f.badd

    " Return words read
    lac words_read
    jmp .read i

read_eof:
    cla                 " 0 words read
    jmp .read i

read_bad_fd:
read_error:
    lac d-1
    jmp .read i

fd_addr: 0
f.flags: 0
f.badd: 0
f.i: 0
buffer_addr: 0
read_count: 0
words_read: 0
block_num: 0
block_offset: 0
block_buf: .=.+64
```

**Note:** This simple implementation reads one word at a time. Real implementation would buffer entire blocks for efficiency.

### 7.6.3 write - Writing to a File

```assembly
" .write - Write to file
" Input: FD number, buffer address, word count
" Output: AC = words written, or -1 on error

.write:
    " Similar to .read but:
    " 1. Check write permission
    " 2. Allocate new blocks if needed
    " 3. Update i.size if file grows
    " 4. Write blocks back to disk

    " (Implementation mirrors .read with modifications)
    jmp .write i
```

### 7.6.4 creat - Creating a File

**System call interface:**
```assembly
sys creat; filename; mode   " Create file with permissions 'mode'
```

**Implementation:**

```assembly
" .creat - Create new file
" Input: filename, permission mode
" Output: FD number, or -1 on error

.creat:
    lac u.base
    dac filename_ptr
    lac u.base+1
    dac perm_mode

    " Check if file already exists
    lac filename_ptr
    jms namei
    spa                 " Exists?
    jmp create_new

    " File exists - truncate it
    dac existing_inode
    jms iget

    " Free all blocks
    jms free_all_blocks; inodebuf

    " Reset size
    dzm inodebuf+i.size

    lac existing_inode
    jms iput

    " Open the truncated file
    lac filename_ptr
    law d1              " Write mode
    jms .open
    jmp .creat i

create_new:
    " Allocate new inode
    jms icreat          " Returns inode number
    spa
    jmp creat_no_inodes

    dac new_inode
    jms iget

    " Initialize inode
    lac perm_mode
    dac inodebuf+i.flags

    " Clear block pointers
    law inodebuf+i.dskps-1
    dac 8
    law d7
    dac count
1:  dzm 8 i
    isz count
    jmp 1b

    lac u.uid
    dac inodebuf+i.uid

    lac d-1             " -1 = 1 link
    dac inodebuf+i.nlks

    dzm inodebuf+i.size

    lac s.uniq
    add d1
    dac s.uniq
    dac inodebuf+i.uniq

    " Write inode
    lac new_inode
    jms iput

    " Add to directory
    lac u.cdir          " Current directory
    jms add_dir_entry; filename_ptr; new_inode
    spa
    jmp creat_dir_full

    " Open the new file
    lac filename_ptr
    law d1              " Write mode
    jms .open
    jmp .creat i

creat_no_inodes:
creat_dir_full:
    lac d-1
    jmp .creat i

filename_ptr: 0
perm_mode: 0
existing_inode: 0
new_inode: 0
```

### 7.6.5 link - Creating Hard Links

**System call interface:**
```assembly
sys link; oldname; newname   " Create newname → same inode as oldname
```

**Implementation:**

```assembly
" .link - Create hard link
" Input: existing filename, new filename
" Output: 0 on success, -1 on error

.link:
    " Get existing file's inode
    lac u.base
    jms namei
    spa
    jmp link_not_found

    dac link_inode
    jms iget

    " Increment link count
    lac inodebuf+i.nlks
    add d-1             " Remember: stored negative
    dac inodebuf+i.nlks

    lac link_inode
    jms iput

    " Add new directory entry
    lac u.cdir
    lac u.base+1        " New filename
    jms add_dir_entry; link_inode
    spa
    jmp link_dir_full

    cla                 " Success
    jmp .link i

link_not_found:
link_dir_full:
    lac d-1
    jmp .link i

link_inode: 0
```

### 7.6.6 unlink - Removing Directory Entries

```assembly
" .unlink - Remove directory entry
" Input: filename
" Output: 0 on success, -1 on error

.unlink:
    " Find file
    lac u.base
    jms namei
    spa
    jmp unlink_not_found

    dac unlink_inode
    jms iget

    " Increment link count (toward zero)
    lac inodebuf+i.nlks
    add d1              " -2 → -1, -1 → 0
    dac inodebuf+i.nlks

    " If links = 0, free inode and blocks
    sma                 " Skip if still negative (has links)
    jms free_inode; unlink_inode

    " Remove directory entry
    lac u.cdir
    lac u.base
    jms remove_dir_entry

    lac unlink_inode
    jms iput

    cla
    jmp .unlink i

unlink_not_found:
    lac d-1
    jmp .unlink i

unlink_inode: 0
```

## 7.7 Path Name Lookup

The `namei` function is the core of Unix pathname resolution.

### namei Algorithm

**Input:** Pathname string (e.g., "/dd/ken/prog.s" or "subdir/file")
**Output:** Inode number, or -1 if not found

**Algorithm:**

1. Start with root inode (1) for absolute paths, current directory (u.cdir) for relative
2. Extract first component ("dd")
3. Search directory for component
4. If found and not last component, load that inode as directory
5. Repeat for next component
6. Return final inode number

```assembly
" namei - Name to inode lookup
" Input: AC = pointer to pathname string
" Output: AC = inode number, or -1 if not found

namei:
    0
    dac path_ptr

    " Check if absolute or relative path
    law path_ptr
    dac 8
    lac 8 i             " Get first character
    and o777            " Mask to char (9 bits)
    sad o57             " '/' = 057 octal
    jmp absolute_path

    " Relative path - start with current directory
    lac u.cdir
    jmp start_lookup

absolute_path:
    " Absolute path - start with root
    law d1              " Root inode = 1

    " Skip leading '/'
    lac path_ptr
    add d1
    dac path_ptr

start_lookup:
    dac current_inode

component_loop:
    " Extract next component
    lac path_ptr
    jms extract_component  " Returns component in 'component', advances path_ptr
    sza                    " Zero length = end of path
    jmp lookup_component

    " End of path - return current inode
    lac current_inode
    jmp namei i

lookup_component:
    " Load current directory
    lac current_inode
    jms iget

    " Check if it's a directory
    lac inodebuf+i.flags
    and o100000         " Directory bit
    sza
    jmp is_directory

    " Not a directory - error
    lac d-1
    jmp namei i

is_directory:
    " Search directory for component
    lac current_inode
    jms search_dir      " Uses 'component' as search name
    spa
    jmp not_found

    " Found - this becomes current inode
    dac current_inode

    " Check if more components
    lac path_ptr
    dac 8
    lac 8 i
    sza                 " Null terminator?
    jmp component_loop

    " End of path
    lac current_inode
    jmp namei i

not_found:
    lac d-1
    jmp namei i

path_ptr: 0
current_inode: 0
component: .=.+4        " Buffer for component name
```

**Supporting function: extract_component**

```assembly
" extract_component - Extract one path component
" Input: AC = pointer to path (updated on return)
" Output: 'component' filled with name, AC = length

extract_component:
    0
    dac comp_ptr

    " Clear component buffer
    law component-1
    dac 9
    law d4
    dac count
1:  dzm 9 i
    isz count
    jmp 1b

    " Copy characters until '/' or null
    law comp_ptr
    dac 8
    law component-1
    dac 9
    cla
    dac char_count

extract_loop:
    lac 8 i             " Get character
    sza                 " Null?
    jmp check_slash

    " End of string
    lac comp_ptr
    dac path_ptr        " Update global
    lac char_count
    jmp extract_component i

check_slash:
    sad o57             " '/' ?
    jmp found_slash

    " Regular character - pack it
    dac current_char
    lac char_count
    and o1              " Odd or even?
    sza
    jmp pack_second

    " First char of word
    lac current_char
    alss 9
    dac temp_word
    jmp next_char

pack_second:
    " Second char of word
    lac temp_word
    add current_char
    dac 9 i             " Store packed word

next_char:
    isz char_count
    jmp extract_loop

found_slash:
    " Skip the slash
    lac comp_ptr
    add d1
    dac path_ptr
    lac char_count
    jmp extract_component i

comp_ptr: 0
char_count: 0
current_char: 0
temp_word: 0
```

### Execution Trace: Opening "/dd/ken/prog.s"

Let's trace complete execution:

```
User program:
    sys open; filename; 0

filename: "dd/ken/prog.s\0"

Step 1: System call entry (s1.s)
    - Save user registers to u.ac, u.mq, etc.
    - AC now contains first arg address
    - Jump to .open

Step 2: .open extracts arguments
    - filename_ptr = address of "dd/ken/prog.s"
    - access_mode = 0 (read)

Step 3: namei called with "dd/ken/prog.s"
    - Not absolute path (no leading /)
    - current_inode = u.cdir = 1 (root)

Step 4: Extract "dd"
    - component = "dd\0\0\0\0\0\0"
    - path_ptr now points to "ken/prog.s"

Step 5: Search root directory for "dd"
    - Load inode 1 (root directory)
    - Read directory blocks
    - Entry 2: d.i = 2, d.name = "dd"
    - Match! current_inode = 2

Step 6: Extract "ken"
    - component = "ken\0\0\0\0\0"
    - path_ptr now points to "prog.s"

Step 7: Search /dd for "ken"
    - Load inode 2 (/dd directory)
    - Scan entries
    - Entry 5: d.i = 25, d.name = "ken"
    - Match! current_inode = 25

Step 8: Extract "prog.s"
    - component = "prog.s\0\0"
    - path_ptr now points to "\0"

Step 9: Search /dd/ken for "prog.s"
    - Load inode 25
    - Scan entries
    - Entry 8: d.i = 137, d.name = "prog.s"
    - Match! current_inode = 137

Step 10: End of path
    - Return inode 137

Step 11: .open continues
    - Load inode 137
    - Check permissions (read allowed)
    - Find free FD: slot 3
    - u.ofiles[3].flags = 0100000 (in use, read)
    - u.ofiles[3].badd = 0
    - u.ofiles[3].i = 137

Step 12: Return to user
    - AC = 3 (file descriptor)
    - Restore user registers
    - Continue at instruction after system call

Total operations:
- 3 inode reads (inodes 1, 2, 25)
- 3 directory searches
- 1 FD allocation
- ~200 instructions executed
- ~15 milliseconds on PDP-7
```

## 7.8 Buffer Cache

To improve performance, Unix caches disk blocks in memory.

### Buffer Cache Structure

```assembly
" Disk buffer cache (4 buffers)
" Each buffer is 64 words + metadata

buf1: .=.+64
buf1_track: 0           " Track number (0 = invalid)
buf1_dirty: 0           " 1 = modified, needs writeback

buf2: .=.+64
buf2_track: 0
buf2_dirty: 0

buf3: .=.+64
buf3_track: 0
buf3_dirty: 0

buf4: .=.+64
buf4_track: 0
buf4_dirty: 0

" LRU tracking
buf_lru: 0;1;2;3        " Least recently used order
```

### dskrd with Caching

```assembly
" dskrd - Read disk block with caching
" Input: AC = track number, arg = buffer address
" Output: Data in buffer

dskrd:
    0
    dac track_num
    lac dskrd i
    dac buffer_addr
    isz dskrd

    " Check each buffer
    lac track_num
    sad buf1_track
    jmp hit_buf1
    sad buf2_track
    jmp hit_buf2
    sad buf3_track
    jmp hit_buf3
    sad buf4_track
    jmp hit_buf4

    " Cache miss - need to read
    jms find_lru_buffer    " Returns buffer number
    jms evict_buffer       " Write if dirty

    " Read into buffer
    lac track_num
    jms physical_read; buf1  " Read to buffer

    " Update metadata
    lac track_num
    dac buf1_track
    dzm buf1_dirty

    " Copy to user buffer
    jms copy; buf1; buffer_addr; 64

    jms update_lru; 0
    jmp dskrd i

hit_buf1:
    jms copy; buf1; buffer_addr; 64
    jms update_lru; 0
    jmp dskrd i

    " (Similar for buf2, buf3, buf4)

track_num: 0
buffer_addr: 0
```

### Performance Impact

**Without cache:**
- Every file operation requires disk I/O
- Latency: 50ms per block (DECtape seek + read)
- Reading 10-block file: 500ms

**With cache (4 blocks):**
- Hot blocks served from memory
- Latency: 10μs (memory access)
- Reading 10-block file: ~100ms (cache hits on frequently accessed blocks)

**Limitation:** Only 4 buffers (256 words = 576 bytes). Modern systems cache megabytes or gigabytes.

## 7.9 Large Files

Files larger than 7 blocks (448 words) use indirect blocks.

### Direct vs. Indirect Blocks

**Small file (≤ 448 words):**

```
inode:
  i.dskps[0] = 1234  ──→  Block 1234: [data words 0-63]
  i.dskps[1] = 1235  ──→  Block 1235: [data words 64-127]
  i.dskps[2] = 1236  ──→  Block 1236: [data words 128-191]
  i.dskps[3] = 1237  ──→  Block 1237: [data words 192-255]
  i.dskps[4] = 1238  ──→  Block 1238: [data words 256-319]
  i.dskps[5] = 1239  ──→  Block 1239: [data words 320-383]
  i.dskps[6] = 1240  ──→  Block 1240: [data words 384-447]
```

**Large file (> 448 words):**

```
inode:
  i.flags = 0140644  (bit 17 set = large file)
  i.dskps[0] = 2000  ──→  Indirect block 2000:
                            [0]: 3000 ──→ Block 3000: [data 0-63]
                            [1]: 3001 ──→ Block 3001: [data 64-127]
                            [2]: 3002 ──→ Block 3002: [data 128-191]
                            ...
                            [63]: 3063 ──→ Block 3063: [data 4032-4095]
  i.dskps[1-6] = 0   (unused)
```

### Maximum File Size

- **Indirect block:** 64 pointers
- **Each pointer:** Points to 64-word data block
- **Maximum:** 64 × 64 = 4,096 words = 9,216 bytes ≈ 9KB

**Why so small?**
1. Total disk is only 640KB
2. 9KB is 1.4% of disk - reasonable for largest file
3. Most files were tiny (< 1KB)

### Implementation: get_block_addr

```assembly
" get_block_addr - Get track number for logical block
" Input: AC = logical block number, inodebuf = file inode
" Output: AC = track number, or -1 if beyond EOF

get_block_addr:
    0
    dac logical_block

    " Check if large file
    lac inodebuf+i.flags
    and o200000         " Bit 17 = large file
    sza
    jmp large_file

    " Small file - direct blocks
    lac logical_block
    sad d7              " Block 7 or higher?
    jmp beyond_eof
    sma cla
    jmp beyond_eof

    " Get direct block pointer
    lac logical_block
    tad inodebuf+i.dskps
    dac 8
    lac 8 i
    jmp get_block_addr i

large_file:
    " Read indirect block
    lac inodebuf+i.dskps
    jms dskrd; indirect_buf

    " Get pointer from indirect block
    lac logical_block
    sad d64             " Block 64 or higher?
    jmp beyond_eof
    sma cla
    jmp beyond_eof

    tad indirect_buf-1
    dac 8
    lac 8 i
    jmp get_block_addr i

beyond_eof:
    lac d-1
    jmp get_block_addr i

logical_block: 0
indirect_buf: .=.+64
```

## 7.10 File Permissions

### Permission Bit Layout

From i.flags (18 bits):

```
┌─────────────────────────────────────────┐
│ Bit  │ Octal  │ Meaning                 │
├──────┼────────┼─────────────────────────┤
│  0   │ 000001 │ Owner execute           │
│  1   │ 000002 │ Owner write             │
│  2   │ 000004 │ Owner read              │
│  3   │ 000010 │ Group execute (unused)  │
│  4   │ 000020 │ Group write (unused)    │
│  5   │ 000040 │ Group read (unused)     │
│  6   │ 000100 │ Other execute (unused)  │
│  7   │ 000200 │ Other write (unused)    │
│  8   │ 000400 │ Other read (unused)     │
│  9   │ 001000 │ Setuid                  │
│ 10-14│ 036000 │ Reserved                │
│  15  │ 040000 │ Directory               │
│  16  │ 100000 │ Character device        │
│  17  │ 200000 │ Large file              │
└──────┴────────┴─────────────────────────┘
```

**Note:** Only owner permissions fully implemented in PDP-7. Group/other bits reserved.

### Permission Check Algorithm

```assembly
" check_access - Check if user can access file
" Input: inodebuf = file inode, access_mode (0=read, 1=write, 2=execute)
" Output: AC = 0 if allowed, -1 if denied

check_access:
    0
    dac req_mode

    " Superuser can do anything
    lac u.uid
    sza                 " UID 0 or -1 = superuser
    add d1
    sza
    jmp check_owner

    cla                 " Superuser: allow
    jmp check_access i

check_owner:
    " Check if user owns file
    lac u.uid
    sad inodebuf+i.uid
    jmp owner_check_perm

    " Not owner - deny (group/other not implemented)
    lac d-1
    jmp check_access i

owner_check_perm:
    " Check requested permission
    lac req_mode
    sza                 " Read (mode 0)?
    jmp check_write

    " Check read permission
    lac inodebuf+i.flags
    and o4              " Owner read bit
    sza
    jmp access_ok
    jmp access_denied

check_write:
    lac req_mode
    sad d1              " Write (mode 1)?
    jmp 1f
    jmp check_exec

1:  lac inodebuf+i.flags
    and o2              " Owner write bit
    sza
    jmp access_ok
    jmp access_denied

check_exec:
    lac inodebuf+i.flags
    and o1              " Owner execute bit
    sza
    jmp access_ok
    jmp access_denied

access_ok:
    cla
    jmp check_access i

access_denied:
    lac d-1
    jmp check_access i

req_mode: 0
```

### Setuid Implementation

The setuid bit (bit 9) allows a program to run with the permissions of the file owner, not the user running it.

```assembly
" exec - Execute program (simplified)
exec:
    " Load executable into memory
    lac filename
    jms namei
    jms iget

    " Check if setuid
    lac inodebuf+i.flags
    and o1000           " Setuid bit
    sza
    jmp do_setuid
    jmp normal_exec

do_setuid:
    " Change effective UID to file owner
    lac inodebuf+i.uid
    dac u.uid

normal_exec:
    " Load and execute program
    " ...
```

**Security model:** Very simple. No saved UID, no groups, no capabilities. But effective for basic multi-user system.

## 7.11 Historical Context

### 1969 File Systems

**Flat file systems (most common):**
- CDC 6600, IBM 1401, DEC PDP-8
- All files in one directory
- Naming: simple identifiers or numbers

**Hierarchical file systems (rare):**
- Multics: Full hierarchy with segments
- CTSS: Two-level (user + file)
- Atlas Supervisor: Limited hierarchy

**Unix innovation:**
- Simple hierarchical structure
- Inode separation
- Unified I/O model (files, devices, directories all "files")
- Permissions integrated into file system

### Comparison Table

| Feature              | PDP-7 Unix | Multics | OS/360 | TOPS-10 |
|----------------------|------------|---------|--------|---------|
| Hierarchy depth      | Unlimited  | Unlimited| 2      | 1       |
| Hard links           | Yes        | Yes     | No     | No      |
| Rename cost          | O(1)       | O(n)    | O(n)   | O(n)    |
| Permissions          | Per-file   | Per-segment| Dataset| File   |
| Max file size        | 9KB        | Unlimited| Unlimited| Large|
| Directory as file    | Yes        | No      | No     | No      |
| Implementation lines | ~500       | ~15,000 | ~50,000| ~10,000|

### Influence on Modern File Systems

**Unix V6 (1975):**
- Same basic structure
- Improved: 3 indirect levels, larger blocks
- Max file size: 1GB (theoretically)

**Unix V7 (1979):**
- Long filenames (14 chars → 255 chars in later versions)
- Improved performance
- Better locking

**BSD FFS (1983):**
- Cylinder groups
- Fragment support
- Performance optimizations
- **Still** uses inodes and directories as files

**ext2/ext3/ext4 (1993-2008):**
- Linux standard file system
- Inode-based (exactly like PDP-7!)
- Extent-based allocation (ext4)
- Journaling (ext3/ext4)

**Modern file systems that use inode concept:**
- XFS, JFS, ReiserFS, Btrfs (Linux)
- HFS+, APFS (macOS)
- UFS (BSD)
- ZFS (Solaris/FreeBSD)

**File systems WITHOUT inodes:**
- FAT12/16/32 (MS-DOS, Windows)
- NTFS (Windows) - uses MFT, similar concept but different implementation

### What Changed, What Didn't

**What changed:**
- ✓ File size limits (9KB → terabytes)
- ✓ Filename length (6 chars → 255+ chars)
- ✓ Block size (64 words → 4KB or larger)
- ✓ Caching (4 blocks → gigabytes)
- ✓ Performance optimizations (thousands of tweaks)

**What didn't change:**
- ✗ Inode structure (still ~12 pointers + metadata)
- ✗ Directory as file
- ✗ Separation of name and metadata
- ✗ Hard link implementation
- ✗ Permission model (extended, but same base)

**The PDP-7 file system got the fundamentals right. 55 years later, we're still using the same architecture.**

## 7.12 Complete Example: Creating and Reading a File

Let's trace a complete workflow from system initialization through file creation and reading.

### Scenario

User ken creates file `/dd/ken/memo` containing "hello world", then reads it back.

### Step-by-Step Execution

```
─────────────────────────────────────────────────────────────
STEP 1: System Boot
─────────────────────────────────────────────────────────────

[Track 0 loaded and executed - coldentry]

1. Load sysdata from track 6000:
   s.nxfblk = 0       (no overflow blocks yet)
   s.nfblks = 10      (10 free blocks in cache)
   s.fblks = [5000, 5001, 5002, 5003, 5004, 5005, 5006, 5007, 5008, 5009]
   s.uniq = 100       (100 files created since installation)
   s.tim = 12345,67000 (system time)

2. Load and execute init (inode 3)

3. Init forks login process

4. User ken logs in, UID becomes 1

─────────────────────────────────────────────────────────────
STEP 2: Create File
─────────────────────────────────────────────────────────────

User types to shell: create memo

Shell executes:
   sys creat; "memo\0"; 0644

Kernel (.creat):

5. Call namei("memo")
   - Relative path, start with u.cdir = 25 (ken's directory)
   - Search directory inode 25 for "memo"
   - Not found → return -1

6. Allocate new inode
   - Call icreat
   - Scan from inode 20 upward
   - Find inode 137 is free (i.flags = 0)
   - Return 137

7. Initialize inode 137:
   i.flags  = 040644  (regular file, rw-r--r--)
   i.dskps  = 0,0,0,0,0,0,0 (no blocks yet)
   i.uid    = 1       (ken)
   i.nlks   = -1      (one link)
   i.size   = 0       (empty)
   i.uniq   = 101     (s.uniq incremented: 100→101)

8. Write inode 137 to disk
   - Track = 137÷5 + 2 = 27 + 2 = 29
   - Offset = (137 mod 5) × 12 = 2 × 12 = 24
   - Read track 29, modify words 24-35, write back

9. Add directory entry to /dd/ken (inode 25):
   - Load inode 25
   - Read directory blocks
   - Find empty slot (entry 8)
   - entry[8].d.i = 137
   - entry[8].d.name = "memo\0\0\0\0"
   - entry[8].d.uniq = 101
   - Write directory block back

10. Open file for writing
    - Find FD slot 3
    - u.ofiles[3].flags = 0100001 (in use, write)
    - u.ofiles[3].badd = 0
    - u.ofiles[3].i = 137

11. Return FD 3 to user

─────────────────────────────────────────────────────────────
STEP 3: Write Data
─────────────────────────────────────────────────────────────

User program:
   sys write; 3; buffer; 2   " Write 2 words

buffer: "he"; "ll"   (packed: 'h'<<9|'e', 'l'<<9|'l')

Kernel (.write):

12. Get file descriptor 3
    - f.flags = 0100001 (write mode)
    - f.badd = 0 (position)
    - f.i = 137 (inode)

13. Load inode 137
    - Currently: i.size = 0, no blocks

14. Need to allocate first block
    - Call alloc
    - s.nfblks = 10
    - Return s.fblks[9] = 5009
    - s.nfblks = 9
    - Clear block 5009

15. Store in inode:
    - i.dskps[0] = 5009

16. Write data:
    - block_buf[0] = "he"
    - block_buf[1] = "ll"

17. Write block 5009 to disk

18. Update inode 137:
    - i.size = 2
    - Write to disk

19. Update FD:
    - u.ofiles[3].badd = 2

20. Return 2 (words written)

─────────────────────────────────────────────────────────────
STEP 4: Close File
─────────────────────────────────────────────────────────────

User program:
   sys close; 3

Kernel (.close):

21. Clear FD 3:
    - u.ofiles[3].flags = 0 (not in use)

─────────────────────────────────────────────────────────────
STEP 5: Re-open and Read
─────────────────────────────────────────────────────────────

User program:
   sys open; "memo\0"; 0   " Read mode

Kernel (.open):

22. Call namei("memo")
    - Search directory inode 25
    - Find entry 8: d.i = 137, d.name = "memo"
    - Verify d.uniq (101) matches inode 137 i.uniq (101) ✓
    - Return 137

23. Load inode 137:
    - i.flags = 040644 (readable)
    - i.size = 2
    - i.dskps[0] = 5009

24. Allocate FD 4:
    - u.ofiles[4].flags = 0100000 (in use, read)
    - u.ofiles[4].badd = 0
    - u.ofiles[4].i = 137

25. Return FD 4

─────────────────────────────────────────────────────────────
STEP 6: Read Data
─────────────────────────────────────────────────────────────

User program:
   sys read; 4; buffer; 2

Kernel (.read):

26. Get FD 4:
    - f.badd = 0
    - f.i = 137

27. Load inode 137

28. Calculate block:
    - Block = 0 ÷ 64 = 0
    - Block address = i.dskps[0] = 5009

29. Read block 5009 (from cache if available!)
    - block_buf[0] = "he"
    - block_buf[1] = "ll"

30. Copy to user buffer:
    - buffer[0] = "he"
    - buffer[1] = "ll"

31. Update FD:
    - u.ofiles[4].badd = 2

32. Return 2 (words read)

─────────────────────────────────────────────────────────────
FINAL STATE
─────────────────────────────────────────────────────────────

Disk:
  Track 29: Inode 137 (memo)
  Track 5721: Block 5009 (data: "hell")
  Track ?: Directory block with entry pointing to 137

Memory:
  sysdata:
    s.nfblks = 9 (one block allocated)
    s.uniq = 101

Process:
  u.cdir = 25 (/dd/ken)
  u.uid = 1 (ken)
  u.ofiles[4] is open to inode 137, position 2

Total operations:
  - Disk writes: 5 (inode, directory, data, inode update, sysdata)
  - Disk reads: 8 (inode loads, directory searches, data read)
  - System calls: 5 (creat, write, close, open, read)
  - Time: ~250ms on PDP-7
```

## Summary

The PDP-7 Unix file system achieved extraordinary sophistication within severe constraints:

- **8K words** of memory
- **640KB** disk
- **No MMU** or memory protection
- **18-bit** word size

Yet it introduced concepts that persist today:

1. **Separation of name and metadata** (inodes)
2. **Hierarchical directories** (as files)
3. **Hard links** (multiple names → one file)
4. **Unified permissions model**
5. **Simple, elegant algorithms**

Every time you `ls -l`, create a hard link, or rename a gigabyte file instantly, you're using ideas that Ken Thompson and Dennis Ritchie perfected in 1969 on a computer with less power than a digital watch.

The PDP-7 Unix file system wasn't just ahead of its time—it defined the future.

---

**Next Chapter:** [Chapter 8 - Process Management](08-process-management.md)

**Previous Chapter:** [Chapter 6 - Boot and Initialization](06-boot-initialization.md)
