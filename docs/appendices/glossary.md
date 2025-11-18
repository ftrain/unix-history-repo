# Appendix D - Glossary of Terms and Concepts

## About This Glossary

This comprehensive glossary covers all terminology needed to understand PDP-7 Unix documentation, source code, and historical context. Terms are organized alphabetically and tagged by category:

- **[HW]** - Hardware terms
- **[ASM]** - Assembly language terms
- **[OS]** - Operating system concepts
- **[UNIX]** - Unix-specific terms
- **[HIST]** - Historical terms and figures

Each entry provides:
1. **Definition** - Clear, precise explanation
2. **In PDP-7 Unix** - Specific usage context
3. **Location** - Source file references where applicable
4. **Etymology** - Origin of the name/term (where interesting)
5. **See also** - Related terms and cross-references

---

## A

**a.out**
*Category: [UNIX]*

The default output filename for assembled programs. Stands for "assembler output."

**In PDP-7 Unix:** The PDP-7 assembler (`as.s`) creates executable machine code in this file. Programs are loaded and executed directly from a.out.

**Location:** Referenced in assembler operation, though the actual filename may vary in PDP-7 implementation.

**Etymology:** The name "a.out" (assembler output) became a Unix tradition. Later C compilers also used this as the default output name. The a.out format persisted through many Unix generations until replaced by ELF (Executable and Linkable Format) in the 1990s.

**Modern equivalent:** Modern systems use names like `a.out` (still), `a.exe` (Windows), or custom names specified by `-o` flag.

**See also:** Assembler, as.s

---

**AC (Accumulator)**
*Category: [HW]*

The primary 18-bit working register in the PDP-7 CPU. All arithmetic and logical operations use the accumulator.

**In PDP-7 Unix:** The accumulator is central to all computation. System calls pass arguments and return values through AC. Nearly every instruction in PDP-7 assembly involves the accumulator.

**Location:** Used throughout all source files. Examples in `s1.s:16`, `s1.s:20`, `s1.s:77`.

**Etymology:** "Accumulator" was traditional terminology in early computers, referring to a register that "accumulates" results of arithmetic operations.

**Modern equivalent:** Modern CPUs have multiple general-purpose registers (e.g., RAX, RBX in x86-64) rather than a single accumulator.

**See also:** MQ, Link, Register Set, lac, dac

---

**Address Field**
*Category: [ASM]*

The 13-bit portion of a memory reference instruction specifying which memory location to access.

**In PDP-7 Unix:** Memory reference instructions use bits 0-12 for the address field. Combined with indirect and index bits, this determines the effective address.

**Location:** Every memory reference instruction uses an address field. See instruction encoding throughout all assembly files.

**Etymology:** From general computer architecture terminology for the portion of an instruction encoding an operand location.

**See also:** Indirect Addressing, Direct Addressing, Effective Address, Memory Reference Instructions

---

**ADM (Automatic Data Management)**
*Category: [UNIX]*

A DECtape-based backup and storage utility for PDP-7 Unix.

**In PDP-7 Unix:** ADM manages data on DECtape, providing file backup and restoration capabilities.

**Location:** `/home/user/unix-history-repo/adm.s`

**Etymology:** "Automatic Data Management" suggests automated tape handling.

**See also:** DECtape, dskio.s

---

**ALD (Assembler Loader and Debugger)**
*Category: [UNIX]*

A utility combining loading and debugging functions for assembled programs.

**In PDP-7 Unix:** ALD loads machine code into memory and provides basic debugging capabilities.

**Location:** `/home/user/unix-history-repo/ald.s`

**See also:** Debugger, db.s, Assembler

---

**Alloc**
*Category: [OS]*

The kernel routine that allocates free blocks from the file system.

**In PDP-7 Unix:** Allocates disk blocks when files grow or new files are created. Maintains the free block list in the superblock.

**Location:** `sysmap:39` defines `alloc` at address `001556`.

**Etymology:** Short for "allocate," standard computing terminology.

**Modern equivalent:** Modern file systems use bitmap allocators, extent trees, or B-trees rather than simple free lists.

**See also:** Free, Superblock, Free Block List, File System

---

**ALS (Arithmetic Left Shift)**
*Category: [ASM]*

An OPR instruction that shifts the accumulator left by a specified number of bit positions, filling with zeros on the right. Arithmetic operation (preserves sign in some contexts).

**In PDP-7 Unix:** Used for multiplication by powers of two, bit manipulation, and character packing operations.

**Location:** Used in `init.s:112` for character encoding: `cll; als 3` (shift left 3 bits).

**Etymology:** "Arithmetic" distinguishes it from logical shifts in that it may preserve sign bits in some CPU architectures (though PDP-7 treats both similarly).

**Modern equivalent:** `<<` operator in C, or `SHL` in x86 assembly.

**See also:** ARS, OPR, Shift Instructions

---

**ALSS (Arithmetic Left Shift and Store)**
*Category: [ASM]*

An OPR microcoded instruction that shifts AC left by 9 bits (one character position) and stores result.

**In PDP-7 Unix:** Specifically used for character manipulation, shifting 9-bit characters.

**Location:** `init.s:97` - `alss 9` shifts left character into high position.

**See also:** ALS, Character Packing

---

**APR (Asynchronous Paper Tape Reader)**
*Category: [UNIX]*

User utility for reading data from paper tape asynchronously.

**In PDP-7 Unix:** Allows programs to read input from paper tape reader device.

**Location:** `/home/user/unix-history-repo/apr.s`

**See also:** Paper Tape, I/O Devices

---

**ARS (Arithmetic Right Shift)**
*Category: [ASM]*

An OPR instruction that shifts the accumulator right, preserving the sign bit.

**In PDP-7 Unix:** Used for division by powers of two while maintaining sign.

**Modern equivalent:** `>>` operator in C (with signed integers), or `SAR` in x86 assembly.

**See also:** ALS, LRSS, OPR

---

**AS (Assembler)**
*Category: [UNIX]*

The PDP-7 Unix assembler that translates assembly language source code into executable machine code.

**In PDP-7 Unix:** The assembler is a two-pass program that reads assembly source, builds symbol tables, resolves references, and generates machine code. Critical for system development since all PDP-7 Unix is written in assembly.

**Location:** `/home/user/unix-history-repo/as.s` (10,999 lines)

**Etymology:** "AS" = "assembler," a standard Unix command name that persists today (GNU `as`, `nasm`, etc.).

**Modern equivalent:** Modern assemblers include GNU `as` (GAS), NASM, MASM, or integrated assemblers in compilers.

**See also:** Two-Pass Assembler, Symbol Table, a.out

---

**ASCII (American Standard Code for Information Interchange)**
*Category: [HW]*

7-bit character encoding standard used for text representation.

**In PDP-7 Unix:** Characters are stored as 7-bit ASCII values (0-127), though the PDP-7 uses 9-bit character cells. The upper 2 bits could extend the character set but typically held zeros for ASCII compatibility.

**Location:** Character operations throughout the codebase mask with `o177` (octal 177 = decimal 127) to extract 7-bit ASCII.

**Etymology:** Standardized in 1963 by ASA (American Standards Association), later ANSI.

**Modern equivalent:** UTF-8 supersedes ASCII but remains backward-compatible with the 7-bit ASCII subset.

**See also:** Character Packing, 9-bit Characters, o177

---

**Auto-Increment Register**
*Category: [HW]*

Memory locations 010-017 (octal) that automatically increment their value when used as indirect addresses.

**In PDP-7 Unix:** Provides efficient pointer operations without explicit increment instructions. When accessing memory indirectly through locations 010-017, the PDP-7 hardware first increments the value, then uses it as an address.

**Location:** Used extensively for buffers and iterators. Location 8-9 (010-011 octal) common for temporary pointers throughout kernel code.

**Etymology:** Hardware feature unique to PDP series machines.

**Modern equivalent:** Modern CPUs offer auto-increment addressing modes in instructions (e.g., ARM `LDR r0, [r1], #4`).

**See also:** Indirect Addressing, Register 8, Register 9

---

## B

**B Language**
*Category: [HIST]*

A typeless programming language created by Ken Thompson in 1969, predecessor to C.

**In PDP-7 Unix:** PDP-7 Unix included a B interpreter (`bi.s`), allowing programs to be written in a higher-level language than assembly. B was Thompson's simplification of BCPL.

**Location:** `/home/user/unix-history-repo/bi.s` (4,160 lines), `/home/user/unix-history-repo/bc.s` (B compiler), `/home/user/unix-history-repo/bl.s` (B loader)

**Etymology:** The letter "B" - origin debated. Either "B" for BCPL, or simply the next letter after "A" (no "A" language existed).

**Modern equivalent:** C language, created by Dennis Ritchie (1972) as B's typed successor.

**See also:** BCPL, C Language, bi.s, Ken Thompson

---

**BCPL (Basic Combined Programming Language)**
*Category: [HIST]*

A systems programming language created by Martin Richards in 1966 at Cambridge University.

**In PDP-7 Unix:** BCPL influenced Ken Thompson's design of B. BCPL's word-oriented, typeless approach suited PDP-7's architecture.

**Etymology:** "Basic" + "Combined Programming Language" - simplified CPL (Combined Programming Language).

**Modern equivalent:** Influenced C and thus all C-family languages (C++, Java, C#, JavaScript).

**See also:** B Language, C Language, Ken Thompson

---

**Bell Labs (Bell Telephone Laboratories)**
*Category: [HIST]*

Research and development subsidiary of AT&T where Unix was created.

**In PDP-7 Unix:** Unix was born at Bell Labs in Murray Hill, New Jersey. Ken Thompson and Dennis Ritchie worked in the Computing Science Research Center.

**Etymology:** Founded in 1925, named after Alexander Graham Bell.

**Historical significance:** Bell Labs produced numerous computing innovations: Unix, C, C++, transistor, laser, information theory, cellular telephony.

**See also:** Ken Thompson, Dennis Ritchie, Murray Hill, AT&T

---

**Betwen (Between)**
*Category: [OS]*

Kernel utility function that tests if a value falls within a specified range.

**In PDP-7 Unix:** Used for bounds checking, validating array indices, and parameter validation throughout the kernel.

**Location:** `sysmap:44` defines `betwen` at address `001654`. Used in `s1.s:39`, `s1.s:45`, `s1.s:148`.

**Etymology:** Misspelling of "between" - likely a typo that became canonical in the code.

**Modern equivalent:** Range checking logic or assertions.

**See also:** Error Checking, Parameter Validation

---

**Block**
*Category: [OS]*

A fixed-size unit of disk storage, typically 64 words (128 bytes) in PDP-7 Unix.

**In PDP-7 Unix:** All file system operations work in block-sized units. Disk I/O transfers entire blocks between disk and buffer cache.

**Location:** Block size evident in buffer operations like `s1.s:62` - `jms copy; sysdata; dskbuf; 64`

**Etymology:** "Block" as a contiguous chunk of storage is standard file system terminology.

**Modern equivalent:** Modern file systems use larger blocks (4KB, 8KB typical). Called "blocks," "clusters," or "allocation units."

**See also:** Buffer Cache, dskbuf, File System

---

**Boot (Bootstrap)**
*Category: [OS]*

The process of loading and starting the operating system.

**In PDP-7 Unix:** Bootstrap code loads Unix kernel from DECtape or disk into memory and transfers control to it. The `init.s` program contains bootstrap logic.

**Location:** `init.s:154-161` contains boot code that loads and jumps to system code.

**Etymology:** "Pulling oneself up by one's bootstraps" - the system loads itself from a simple starting state.

**Modern equivalent:** BIOS/UEFI → bootloader (GRUB, etc.) → kernel initialization.

**See also:** init, coldentry

---

**Buffer Cache**
*Category: [OS]*

Kernel memory area holding recently accessed disk blocks to improve I/O performance.

**In PDP-7 Unix:** Buffers reduce disk I/O by caching frequently accessed blocks. The kernel maintains buffers for both data blocks and directory blocks.

**Location:** `dskbuf` and related buffer areas referenced throughout kernel. Defined at `sysmap:90` and elsewhere.

**Etymology:** "Buffer" (temporary storage) + "cache" (hidden storage).

**Modern equivalent:** Page cache, buffer cache (Linux separates them; modern systems often unify them).

**See also:** dskbuf, dskio, Block

---

## C

**C Language**
*Category: [HIST]*

Programming language created by Dennis Ritchie at Bell Labs (1972), used to rewrite Unix.

**In PDP-7 Unix:** Not present in PDP-7 Unix (which predates C), but B language (C's predecessor) is included.

**Etymology:** Named "C" as successor to "B" language.

**Historical significance:** Unix rewritten in C (1973) made it portable across architectures, enabling Unix's explosive growth. C became the dominant systems programming language.

**Modern equivalent:** C remains widely used. C++ extends it with object-orientation.

**See also:** B Language, Dennis Ritchie, Unix V7

---

**CAT (Concatenate)**
*Category: [UNIX]*

User utility that concatenates files and prints them to standard output.

**In PDP-7 Unix:** One of the simplest Unix utilities, demonstrating core I/O concepts. Reads files specified as arguments and writes their contents sequentially to output.

**Location:** `/home/user/unix-history-repo/cat.s` (146 lines)

**Etymology:** "Concatenate" - to link together in a series. The name emphasizes combining multiple inputs.

**Modern equivalent:** `cat` command exists essentially unchanged in all Unix/Linux systems.

**See also:** File I/O, read, write, getc, putc

---

**Character Packing**
*Category: [HW]*

Storing two 9-bit characters in each 18-bit word.

**In PDP-7 Unix:** Characters occupy bits 17-9 (left character) and 8-0 (right character) of a word. Code must extract and pack characters carefully.

**Location:** `cat.s:53-59` shows character extraction; `init.s:96-109` shows character packing.

**Etymology:** "Packing" multiple items into a single storage unit is standard terminology.

**Modern equivalent:** Modern systems use 8-bit bytes as the fundamental unit, avoiding packing complexity.

**See also:** 9-bit Characters, ALSS, LRSS, ASCII

---

**CHDIR (Change Directory)**
*Category: [UNIX]*

System call that changes the current working directory for a process.

**In PDP-7 Unix:** Sets the process's current directory, affecting subsequent file operations that use relative paths.

**Location:** System call defined at `.chdir` in `s2.s:175`. Used in `init.s:127-128` to navigate to user directory.

**Etymology:** "Change directory" - descriptive name.

**Modern equivalent:** `chdir()` system call and `cd` command exist in all Unix systems.

**See also:** Directory, pwd, Current Directory, u.cdir

---

**CHMOD (Change Mode)**
*Category: [UNIX]*

System call and utility that changes file permission bits.

**In PDP-7 Unix:** Modifies file access permissions (read, write, execute). Only file owner or superuser can change mode.

**Location:** System call at `.chmod` in `s2.s:36`. Utility at `/home/user/unix-history-repo/chmod.s`.

**Etymology:** "Change mode" where "mode" refers to access permissions.

**Modern equivalent:** `chmod()` system call and `chmod` command standard in all Unix systems, now with more complex permission models (user/group/other, ACLs).

**See also:** CHOWN, File Permissions, inode

---

**CHOWN (Change Owner)**
*Category: [UNIX]*

System call and utility that changes file ownership.

**In PDP-7 Unix:** Changes the user ID associated with a file. Typically restricted to superuser.

**Location:** System call at `.chown` in `s2.s:48`. Utility at `/home/user/unix-history-repo/chown.s`.

**Etymology:** "Change owner."

**Modern equivalent:** `chown()` system call and `chown` command in all Unix systems, now also handling group ownership.

**See also:** CHMOD, UID, User ID, Ownership

---

**CLA (Clear Accumulator)**
*Category: [ASM]*

OPR instruction that sets the accumulator to zero.

**In PDP-7 Unix:** Commonly used to initialize AC before operations or to return zero values.

**Location:** Used extensively, e.g., `s2.s:63` - `cla` before read operation.

**Etymology:** "Clear" + "Accumulator."

**Modern equivalent:** `XOR RAX, RAX` in x86 (XOR register with itself to zero).

**See also:** AC, OPR, DZM

---

**CLL (Clear Link)**
*Category: [ASM]*

OPR instruction that sets the Link bit to zero.

**In PDP-7 Unix:** Used before arithmetic operations to prevent carry-in, or before shifts to control rotation behavior.

**Location:** `init.s:112` - `cll; als 3` clears Link before shifting.

**Etymology:** "Clear" + "Link."

**See also:** Link, CLA, OPR

---

**CLOSE**
*Category: [UNIX]*

System call that closes an open file descriptor.

**In PDP-7 Unix:** Releases the file descriptor, decrements inode reference count, and frees kernel resources associated with the open file.

**Location:** System call at `.close` in `s2.s:245`. Used in `cat.s:26` after reading file.

**Etymology:** Opposite of "open" - standard I/O terminology.

**Modern equivalent:** `close()` system call in all Unix systems.

**See also:** OPEN, File Descriptor, File Table

---

**Coldentry (Cold Entry Point)**
*Category: [OS]*

The kernel entry point for system initialization on boot (cold start).

**In PDP-7 Unix:** When the system boots, execution begins at coldentry, which initializes all kernel data structures, devices, and spawns the first process.

**Location:** `sysmap:50` defines `coldentr` at address `004520`. Referenced in `s1.s:52`.

**Etymology:** "Cold start" vs. "warm start" (restart without power cycle). "Cold" means starting from powered-off state.

**Modern equivalent:** Kernel initialization code, often in `init/main.c` or similar.

**See also:** Boot, Init, System Initialization

---

**Context Switch**
*Category: [OS]*

Saving one process's state and restoring another's state when the CPU switches between processes.

**In PDP-7 Unix:** The scheduler performs context switches during process swapping. Saves all registers (AC, MQ, PC, etc.) to the process's user structure.

**Location:** Process switching logic in `s1.s:80-127` (swap routine). Save/restore in `.save` at `s3.s:77`.

**Etymology:** "Context" (process state) + "switch" (change between).

**Modern equivalent:** All multitasking OS perform context switches, now with more complex state (FPU, SIMD, memory mappings).

**See also:** Process, Swap, u structure, User Data Area

---

**Copy**
*Category: [OS]*

Kernel utility that copies memory from one location to another.

**In PDP-7 Unix:** Fundamental routine for moving data between buffers, user space, and kernel space.

**Location:** `sysmap:53` defines `copy` at `001700`. Used throughout, e.g., `s1.s:32`, `s1.s:62`, `s1.s:70`.

**Etymology:** Standard verb for data duplication.

**Modern equivalent:** `memcpy()` in C, or REP MOVSB in x86 assembly.

**See also:** Copyz, Buffer Cache

---

**Copyz**
*Category: [OS]*

Kernel utility that copies memory and fills remaining space with zeros.

**In PDP-7 Unix:** Like copy, but zero-fills the destination beyond the source length. Useful for clearing buffer areas.

**Location:** `sysmap:52` defines `copyz` at `001723`.

**See also:** Copy, DZM

---

**CP (Copy File)**
*Category: [UNIX]*

User utility that copies files.

**In PDP-7 Unix:** Reads source file and writes contents to destination file.

**Location:** `/home/user/unix-history-repo/cp.s`

**Etymology:** "Copy."

**Modern equivalent:** `cp` command in all Unix systems, with many more options.

**See also:** CAT, File I/O

---

**CREAT (Create File)**
*Category: [UNIX]*

System call that creates a new file or truncates an existing file.

**In PDP-7 Unix:** Allocates a new inode, creates a directory entry, and opens the file for writing.

**Location:** System call at `.creat` in `s2.s:213`. Used in `ed1.s:6` to create temporary file.

**Etymology:** "Create" - famously misspelled without the trailing 'e', which became standard in Unix.

**Historical note:** The misspelling "creat" (vs. "create") persisted through all Unix versions and into POSIX, becoming one of Unix's endearing quirks.

**Modern equivalent:** `creat()` system call (still with the misspelling) or `open()` with O_CREAT flag.

**See also:** OPEN, Inode, Directory

---

**Current Directory**
*Category: [OS]*

The directory relative to which relative pathnames are interpreted for a process.

**In PDP-7 Unix:** Each process has a current directory stored in its u structure (`u.cdir`). Changed via chdir system call.

**Location:** `u.cdir` at `sysmap:247`.

**See also:** CHDIR, Directory, u structure

---

## D

**DAC (Deposit Accumulator)**
*Category: [ASM]*

Memory reference instruction that stores the accumulator's value to memory.

**In PDP-7 Unix:** Fundamental operation for storing computation results, writing variables, and updating memory.

**Location:** Used ubiquitously. Examples: `s1.s:16`, `s1.s:17`, `s1.s:20`, etc.

**Etymology:** "Deposit" + "Accumulator."

**Modern equivalent:** `MOV [mem], RAX` in x86, `STR` in ARM.

**See also:** AC, LAC, Memory Reference Instructions

---

**DB (Debugger)**
*Category: [UNIX]*

Interactive debugger for examining and modifying programs and memory.

**In PDP-7 Unix:** Allows setting breakpoints, examining registers and memory, single-stepping through code.

**Location:** `/home/user/unix-history-repo/db.s` (13,532 lines - one of the largest utilities)

**Etymology:** "Debugger."

**Modern equivalent:** `gdb`, `lldb`, or modern IDE debuggers with far more features.

**See also:** ALD, Development Tools

---

**/dd Directory**
*Category: [UNIX]*

Special root-level directory in PDP-7 Unix file system.

**In PDP-7 Unix:** Used as part of the directory hierarchy for user login directories. `init.s:127` changes to `/dd` before user-specific directory.

**Location:** Referenced in `init.s:249-250` as `dd: <dd>;040040;040040;040040`.

**Etymology:** Possibly "device directory" or simply a two-letter abbreviation. Historical documentation unclear.

**See also:** Directory, Root Directory, File System

---

**DEC (Digital Equipment Corporation)**
*Category: [HIST]*

Computer manufacturer that produced the PDP series, including the PDP-7.

**In PDP-7 Unix:** DEC's PDP-7 was the hardware platform for the first Unix. DEC later produced the PDP-11 (Unix's second platform) and VAX (Unix's third).

**Etymology:** Founded 1957 by Ken Olsen and Harlan Anderson.

**Historical significance:** DEC revolutionized computing with affordable minicomputers, making interactive computing accessible to universities and research labs. DEC was acquired by Compaq (1998), which was acquired by HP (2002).

**See also:** PDP-7, PDP-11, Minicomputer

---

**DECtape**
*Category: [HW]*

Magnetic tape storage system manufactured by DEC for PDP computers.

**In PDP-7 Unix:** Primary mass storage device for PDP-7 Unix. Stored file system, provided backup, and enabled program loading.

**Characteristics:**
- Capacity: ~144 KB per tape
- Block addressable (unlike sequential streaming tape)
- Random access within limits
- Reliable for the era

**Location:** DECtape I/O routines in disk I/O subsystem.

**Etymology:** "DEC" + "tape."

**Modern equivalent:** Hard drives, SSDs. DECtape's random access made it more like slow disk than traditional tape.

**See also:** Disk I/O, Mass Storage, dskio

---

**Dennis Ritchie (dmr)**
*Category: [HIST]*

Co-creator of Unix (with Ken Thompson) and creator of the C programming language.

**In PDP-7 Unix:** Ritchie collaborated with Thompson on PDP-7 Unix design and implementation. He later created C and led the Unix rewrite in C.

**Historical significance:**
- Co-created Unix (1969-1970)
- Created C language (1972)
- Co-authored "The C Programming Language" (1978)
- Turing Award (1983, with Thompson)

**Life:** 1941-2011

**See also:** Ken Thompson, C Language, Bell Labs

---

**Direct Addressing**
*Category: [ASM]*

Addressing mode where the instruction's address field directly specifies the memory location.

**In PDP-7 Unix:** Most common addressing mode. Instruction bits 0-12 contain the memory address of the operand.

**Example:**
```assembly
lac d1        " Direct: load AC from location 'd1'
dac temp      " Direct: store AC to location 'temp'
```

**Modern equivalent:** Direct addressing exists in most architectures, though often called "absolute" or "direct" mode.

**See also:** Indirect Addressing, Address Field, Memory Reference Instructions

---

**Directory**
*Category: [OS]*

A special file containing mappings from filenames to inode numbers.

**In PDP-7 Unix:** Directories are files with a special format: each entry has 6 words (inode number, 4-word filename, unique ID).

**Location:** Directory entry structure defined by labels `d.i`, `d.name`, `d.uniq` in `sysmap:58-60`.

**Structure (6 words per entry):**
- d.i (1 word): inode number
- d.name (4 words): filename (up to 12 characters, 3 per word)
- d.uniq (1 word): unique identifier

**Etymology:** From "directory" as an index or catalog.

**Modern equivalent:** Directory concepts fundamentally unchanged, though entry formats and sizes differ.

**See also:** Inode, File System, d.i, d.name, d.uniq

---

**Disk I/O**
*Category: [OS]*

Kernel subsystem managing reading and writing of disk/tape blocks.

**In PDP-7 Unix:** Handles DECtape operations, buffer management, and block allocation.

**Location:** `dskio` defined at `sysmap:90`, implementation in kernel source. `dskrd`, `dskwr` for read/write.

**See also:** DECtape, Buffer Cache, dskbuf

---

**dskbuf (Disk Buffer)**
*Category: [OS]*

Kernel buffer area for disk I/O operations.

**In PDP-7 Unix:** 64-word buffer holding one disk block during transfers.

**Location:** `sysmap:91` defines `dskbufp` at `004114`. Used in `s1.s:62`.

**See also:** Buffer Cache, Block, dskio

---

**dskio (Disk I/O)**
*Category: [OS]*

Kernel routine performing disk read/write operations.

**In PDP-7 Unix:** Transfers blocks between memory and DECtape.

**Location:** `sysmap:90` at address `002173`. Called from `s1.s:64`.

**See also:** dskrd, dskwr, DECtape

---

**dskrd (Disk Read)**
*Category: [OS]*

Kernel routine to read a block from disk.

**In PDP-7 Unix:** Loads specified block into buffer.

**Location:** `sysmap:92` at `002127`.

**See also:** dskwr, dskio, Buffer Cache

---

**dskwr (Disk Write)**
*Category: [OS]*

Kernel routine to write a block to disk.

**In PDP-7 Unix:** Writes buffer contents to specified disk block.

**Location:** `sysmap:102` at `002157`.

**See also:** dskrd, dskio, Buffer Cache

---

**DZM (Deposit Zero in Memory)**
*Category: [ASM]*

Memory reference instruction that stores zero to a memory location.

**In PDP-7 Unix:** Efficient way to initialize variables or clear flags without loading AC.

**Location:** Used extensively, e.g., `s1.s:24` - `dzm nchar`.

**Etymology:** "Deposit" + "Zero" + "Memory."

**Modern equivalent:** `MOV DWORD PTR [mem], 0` in x86.

**See also:** DAC, CLA, Memory Initialization

---

## E

**ED (Editor)**
*Category: [UNIX]*

Line-oriented text editor, one of Unix's foundational utilities.

**In PDP-7 Unix:** The primary tool for editing text files and source code. Ed uses a command-based interface where users specify line ranges and operations.

**Location:** `/home/user/unix-history-repo/ed1.s` and `/home/user/unix-history-repo/ed2.s` (16,787 lines total)

**Commands:** a (append), c (change), d (delete), p (print), r (read), w (write), s (substitute), q (quit)

**Etymology:** "Editor."

**Historical significance:** Ed's influence is profound:
- Template for all Unix editors (vi, sed, awk)
- Regular expressions first popularized in ed
- Command syntax influenced countless tools
- Still shipped with Unix systems today

**Modern equivalent:** `ed` still exists. Modern editors (vim, emacs, nano) provide screen-oriented editing, but ed's line-oriented approach suits non-interactive use.

**See also:** Regular Expressions, sed, vi

---

**Effective Address**
*Category: [ASM]*

The final memory address computed from an instruction's address field after applying indirect and index modes.

**In PDP-7 Unix:** Effective address calculation:
1. Start with 13-bit address field
2. If index bit set: add auto-increment register value
3. If indirect bit set: fetch memory[address] as new address

**Etymology:** "Effective" meaning "actual" or "resulting."

**Modern equivalent:** All architectures compute effective addresses, often with more complex modes (base+index+displacement).

**See also:** Indirect Addressing, Auto-Increment Register, Address Field

---

**EOF (End of File)**
*Category: [OS]*

Condition indicating no more data available from a file.

**In PDP-7 Unix:** Read system calls return zero to indicate EOF. Programs test for this to know when to stop reading.

**Location:** `cat.s:19-20` tests for EOF: `sad o4` (skip if AC differs from 4) then `jmp 1f`.

**Etymology:** "End Of File."

**Modern equivalent:** Universal concept; read() returns 0 at EOF in all Unix systems.

**See also:** READ, File I/O

---

**EXIT**
*Category: [UNIX]*

System call that terminates a process.

**In PDP-7 Unix:** Closes all open files, releases process resources, and notifies parent process.

**Location:** System call at `.exit` in `s3.s:85`. Used in `init.s:238` to terminate on error.

**Etymology:** Standard programming term for termination.

**Modern equivalent:** `exit()` system call (or `_exit()`) in all Unix systems.

**See also:** FORK, Process, Process Termination

---

## F

**File Descriptor**
*Category: [OS]*

Small integer identifying an open file within a process.

**In PDP-7 Unix:** Each process has an array of file descriptors (in u.ofiles). System calls like read/write take file descriptor as argument.

**Location:** `u.ofiles` at `sysmap:241`.

**Standard descriptors:**
- 0: standard input
- 1: standard output
- 2: standard error (later Unix addition; PDP-7 had limited support)

**Etymology:** "Descriptor" meaning "identifier."

**Modern equivalent:** Same concept in all Unix systems, now typically 0-1023 per process.

**See also:** OPEN, CLOSE, File Table, u.ofiles

---

**File System**
*Category: [OS]*

Hierarchical organization of files and directories on storage media.

**In PDP-7 Unix:** Tree-structured file system with:
- Root directory (/)
- Inodes storing file metadata
- Directory files mapping names to inodes
- Free block list in superblock

**Innovations:**
- Hierarchical (not flat like earlier systems)
- Uniform interface (files and devices)
- Separation of name from metadata (inode)

**Etymology:** "File" + "system" (organization).

**Modern equivalent:** Unix file system model (UFS, ext4, XFS, etc.) derives from PDP-7/PDP-11 design.

**See also:** Inode, Directory, Superblock, Hierarchical File System

---

**FORK**
*Category: [UNIX]*

System call that creates a new process by duplicating the calling process.

**In PDP-7 Unix:** Fork creates a child process with copy of parent's memory, open files, and state. Returns 0 in child, child's PID in parent.

**Location:** System call at `.fork` in `s3.s:43`. Used in `init.s:19` and `init.s:29`.

**Etymology:** "Fork" as in "fork in a road" - process splits into two paths.

**Historical significance:** Fork model became fundamental to Unix process creation, still used today (though often optimized with copy-on-write).

**Modern equivalent:** `fork()` still standard in Unix/Linux, though sometimes supplemented with `vfork()` or `clone()`.

**See also:** EXIT, Process, Process Creation, exec

---

**Free**
*Category: [OS]*

Kernel routine that returns a block to the free block list.

**In PDP-7 Unix:** Releases disk blocks when files are deleted or truncated.

**Location:** `sysmap:118` at `001615`.

**See also:** Alloc, Free Block List, Superblock

---

**Free Block List**
*Category: [OS]*

Linked list of available disk blocks in the file system.

**In PDP-7 Unix:** Superblock contains head of free list. Each free block contains pointer to next free block.

**Location:** Superblock structure includes `s.fblks` (free block list) and `s.nfblks` (number of free blocks).

**Modern equivalent:** Modern file systems use bitmaps or B-trees for free space tracking.

**See also:** Alloc, Free, Superblock, Block

---

## G

**GECOS (General Electric Comprehensive Operating System)**
*Category: [HIST]*

Operating system for GE mainframes used at Bell Labs after Multics withdrawal.

**In PDP-7 Unix:** Thompson initially cross-assembled PDP-7 programs on the GE 635 running GECOS before Unix became self-hosting.

**Etymology:** Originally "GCOS" (General Comprehensive Operating System), later "GECOS" adding "Electric."

**Historical note:** The GECOS field in Unix password files (real name, office, phone) derives from batch job headers in GECOS.

**See also:** Multics, Cross-Development, Bell Labs

---

**getc (Get Character)**
*Category: [UNIX]*

Buffered character input routine.

**In PDP-7 Unix:** Reads characters from input buffer, refilling from file when buffer exhausted.

**Location:** `cat.s:73-100` implements getc.

**See also:** putc, Character I/O, READ

---

**GETUID (Get User ID)**
*Category: [UNIX]*

System call that returns the current process's user ID.

**In PDP-7 Unix:** Returns value of u.uid.

**Location:** System call at `.getuid` in `s2.s:55`.

**See also:** SETUID, UID, u.uid

---

## H

**HALT (Halt Processor)**
*Category: [ASM]*

Instruction that stops CPU execution.

**In PDP-7 Unix:** Used in error conditions or system shutdown. CPU halts until manually restarted.

**Location:** `s1.s:6` - `hlt` instruction at start of kernel.

**Etymology:** Standard computer instruction name.

**See also:** System Calls, Error Handling

---

**Hierarchical File System**
*Category: [OS]*

File system organized as a tree of directories rather than flat list.

**In PDP-7 Unix:** Revolutionary for the era. Root directory (/) contains subdirectories, which can contain files and more subdirectories.

**Historical significance:** Most systems before Unix had flat file spaces or simple two-level hierarchies. Unix's fully hierarchical design became the standard.

**See also:** Directory, File System, Root Directory

---

## I

**i (Indirect Bit)**
*Category: [ASM]*

Bit in instruction encoding (bit 13) that specifies indirect addressing.

**In PDP-7 Unix:** When set, the address field points to a location containing the actual address to use.

**Example:**
```assembly
lac name      " Direct: load from 'name'
lac name i    " Indirect: load from address stored in 'name'
```

**See also:** Indirect Addressing, Address Field, Memory Reference Instructions

---

**Iget (Inode Get)**
*Category: [OS]*

Kernel routine that retrieves an inode from disk into memory.

**In PDP-7 Unix:** Looks up inode by number, loads from disk if not cached, increments reference count.

**Location:** `sysmap:131` at `003030`.

**See also:** Iput, Inode, Inode Cache

---

**Indirect Addressing**
*Category: [ASM]*

Addressing mode where memory location contains address of actual operand.

**In PDP-7 Unix:** Denoted by `i` suffix. Enables pointers, arrays, and dynamic addressing.

**Example:**
```assembly
   lac ptr i     " Load from address stored in 'ptr'
   dac ptr i     " Store to address stored in 'ptr'
```

**Location:** Used extensively, e.g., `s1.s:44` - `jms laci` (load AC indirect).

**Modern equivalent:** All modern architectures support indirect/pointer addressing.

**See also:** Direct Addressing, Auto-Increment Register, i bit

---

**INIT (Initialize)**
*Category: [UNIX]*

First user-space process, parent of all processes, responsible for system initialization and login.

**In PDP-7 Unix:** Init spawns login sessions on terminals, manages session lifecycle, and respawns login prompts when sessions end.

**Location:** `/home/user/unix-history-repo/init.s` (292 lines)

**Process ID:** Always PID 1.

**Etymology:** "Initialize" or "initialization."

**Historical significance:** Init process (PID 1) became Unix tradition. Modern Linux systems often use systemd or other init replacements, but the concept persists.

**Modern equivalent:** systemd, upstart, SysVinit, or other init systems.

**See also:** Boot, Process, Login, PID

---

**Inode (Index Node)**
*Category: [OS]*

Data structure storing file metadata (size, ownership, permissions, disk block locations).

**In PDP-7 Unix:** Each file has one inode containing:
- i.flags: file type and permissions
- i.uid: owner user ID
- i.size: file size in words
- i.dskps: disk block pointers
- i.nlks: number of hard links
- i.uniq: unique identifier

**Location:** Structure defined by labels `ii`, `i.flags`, `i.dskps`, etc. in `sysmap:132-133`.

**Etymology:** "Index node" - indexes into the node/file.

**Historical significance:** Separation of filename (in directory) from metadata (in inode) was revolutionary. Enabled hard links, efficient renaming, and flexible directory structures.

**Modern equivalent:** All Unix file systems use inodes (or equivalent structures with different names).

**See also:** Directory, File System, d.i, Iget, Iput

---

**IOF (I/O Off - Interrupts Off)**
*Category: [ASM]*

IOT instruction that disables interrupts.

**In PDP-7 Unix:** Critical sections use iof to prevent interrupt handlers from corrupting data structures.

**Location:** Used in `s1.s:14`, `s1.s:24`, `s1.s:100` before critical operations.

**Etymology:** "I/O Off" (misleading name - actually disables interrupts).

**Modern equivalent:** `CLI` (clear interrupts) in x86, or kernel spinlocks with interrupt disabling.

**See also:** ION, Interrupts, Critical Section

---

**ION (I/O On - Interrupts On)**
*Category: [ASM]*

IOT instruction that enables interrupts.

**In PDP-7 Unix:** Re-enables interrupts after critical sections.

**Location:** Used in `s1.s:41`, `s1.s:58`, `s1.s:81` after critical sections.

**Etymology:** "I/O On" (actually enables interrupts).

**See also:** IOF, Interrupts

---

**IOT (Input/Output Transfer)**
*Category: [ASM]*

Class of instructions for device I/O operations.

**In PDP-7 Unix:** IOT instructions control peripherals (teletype, DECtape, display, paper tape reader). Each device has specific IOT codes.

**Etymology:** "Input/Output Transfer."

**Examples:**
- iof: disable interrupts
- ion: enable interrupts
- Device-specific IOTs for reading/writing

**Modern equivalent:** IN/OUT instructions (x86), or memory-mapped I/O (ARM, modern systems).

**See also:** IOF, ION, I/O Devices

---

**Iput (Inode Put)**
*Category: [OS]*

Kernel routine that releases reference to an inode, writing to disk if last reference.

**In PDP-7 Unix:** Decrements inode reference count. If zero and no links remain, frees inode and its blocks.

**Location:** `sysmap:137` at `003057`.

**See also:** Iget, Inode, Reference Counting

---

**ISZ (Increment and Skip if Zero)**
*Category: [ASM]*

Memory reference instruction that increments a memory location and skips next instruction if result is zero.

**In PDP-7 Unix:** Used for loop counters and testing conditions.

**Location:** Common in loops, e.g., `s1.s:191` - `isz chkint`.

**Etymology:** "Increment and Skip if Zero."

**Modern equivalent:** No direct equivalent; requires separate INC and conditional jump.

**See also:** Memory Reference Instructions, Loop Control

---

## J

**JMP (Jump)**
*Category: [ASM]*

Instruction that unconditionally transfers control to specified address.

**In PDP-7 Unix:** Primary control flow instruction for loops, conditionals, and function returns.

**Location:** Ubiquitous, e.g., `s1.s:7`, `s1.s:21`, `s1.s:46`, etc.

**Etymology:** "Jump."

**Modern equivalent:** JMP in x86, B (branch) in ARM.

**See also:** JMS, Control Flow

---

**JMS (Jump to Subroutine)**
*Category: [ASM]*

Instruction that calls a subroutine, storing return address.

**In PDP-7 Unix:** Stores PC+1 in first word of subroutine, then jumps to subroutine+1. Subroutine returns via `jmp <name> i`.

**Location:** Used for all function calls, e.g., `s1.s:32`, `s1.s:39`, `s1.s:45`.

**Etymology:** "Jump to Subroutine."

**Mechanism:**
```assembly
   jms copy         " Store PC+1 at 'copy', jump to copy+1

copy: 0             " Return address stored here
   " ... subroutine code ...
   jmp copy i       " Return via indirect jump
```

**Modern equivalent:** CALL instruction (x86), BL (branch and link) in ARM.

**See also:** Subroutine, Function Call, Return Address

---

## K

**Ken Thompson (ken)**
*Category: [HIST]*

Creator of Unix, co-creator of the C language (with Ritchie).

**In PDP-7 Unix:** Thompson designed and implemented most of PDP-7 Unix in 1969, including kernel, file system, assembler, and shell.

**Historical significance:**
- Created Unix (1969)
- Created B language (1969)
- Co-created C (with Ritchie)
- Invented grep (1973)
- Designed UTF-8 (with Rob Pike, 1992)
- Turing Award (1983, with Ritchie)

**Life:** Born 1943

**See also:** Dennis Ritchie, Bell Labs, Unix History

---

**Kernel**
*Category: [OS]*

Core of the operating system, running with full hardware privileges.

**In PDP-7 Unix:** Kernel provides system calls, manages processes, implements file system, and handles I/O. Resides in memory at all times.

**Location:** Kernel source in `s1.s` through `s9.s` (~2,500 lines total).

**Etymology:** "Kernel" as central or essential part, like a seed kernel.

**Modern equivalent:** All OS have kernels. Monolithic kernels (Linux) vs. microkernels (Minix, QNX) debate began later.

**See also:** System Call, Process Management, File System

---

## L

**LAC (Load Accumulator)**
*Category: [ASM]*

Memory reference instruction that loads a value from memory into the accumulator.

**In PDP-7 Unix:** Most common instruction, used to fetch data, load constants, and access variables.

**Location:** Ubiquitous throughout all source files, e.g., `s1.s:16`, `s1.s:18`, `s1.s:20`.

**Etymology:** "Load" + "Accumulator."

**Modern equivalent:** `MOV RAX, [mem]` in x86, `LDR` in ARM.

**See also:** AC, DAC, Memory Reference Instructions

---

**LACQ (Load Accumulator from MQ)**
*Category: [ASM]*

OPR instruction that copies MQ register to AC.

**In PDP-7 Unix:** Retrieves value previously stored in MQ.

**Location:** Used in `s1.s:26`, `init.s:158`, `init.s:211`.

**Etymology:** "Load AC from Q" (Q = MQ register).

**See also:** LMQ, MQ, AC

---

**LAW (Load Accumulator With)**
*Category: [ASM]*

Instruction that loads an immediate value (from next word) into AC.

**In PDP-7 Unix:** Loads constants directly without separate memory location.

**Location:** Used in `init.s:49`, `init.s:51`, `init.s:143`.

**Etymology:** "Load Accumulator With."

**Example:**
```assembly
   law 1234       " AC ← 1234 (immediate value)
```

**Modern equivalent:** `MOV RAX, immediate` in x86.

**See also:** LAC, Immediate Addressing

---

**Link (Link Bit/Register)**
*Category: [HW]*

Single-bit register used for carry, overflow, and rotation operations.

**In PDP-7 Unix:** Link extends AC to 19 bits for rotations, holds carry for arithmetic, and serves as condition flag.

**Location:** Referenced throughout in shift/rotate operations and arithmetic.

**Etymology:** "Link" between AC and external operations, or linking rotations.

**Modern equivalent:** Carry flag (CF) in x86 EFLAGS, or carry bit in ARM.

**See also:** AC, CLL, RAL, RAR

---

**LINK (Create Hard Link)**
*Category: [UNIX]*

System call that creates a new directory entry (hard link) for an existing file.

**In PDP-7 Unix:** Adds new name for file in directory, increments inode link count.

**Location:** System call at `.link` in `s2.s:92`. Used in `init.s:135`.

**Etymology:** "Link" as connection between names and files.

**Modern equivalent:** `link()` system call in all Unix systems.

**See also:** UNLINK, Inode, Hard Link, i.nlks

---

**LMQ (Load MQ)**
*Category: [ASM]*

OPR instruction that copies AC to MQ register.

**In PDP-7 Unix:** Saves AC value in MQ for later use or multi-register operations.

**Location:** Used in `s1.s:76`, `init.s:106`, `init.s:156`.

**Etymology:** "Load MQ."

**See also:** LACQ, MQ, AC

---

**Login**
*Category: [UNIX]*

Process of authenticating a user and starting their shell session.

**In PDP-7 Unix:** Init displays login prompt, reads username and password, verifies against password file, sets UID, changes to home directory, and executes shell.

**Location:** Login logic in `init.s:38-152`.

**Etymology:** "Log in" to the system.

**Modern equivalent:** getty/login/PAM in modern Unix systems.

**See also:** Init, Password, Shell, SETUID

---

**LRSS (Link Right Shift and Store)**
*Category: [ASM]*

OPR microcoded instruction that right-shifts AC by 9 bits (one character), including Link.

**In PDP-7 Unix:** Used for character extraction from packed words.

**Location:** `cat.s:83` - `lrss 9` extracts character.

**Etymology:** "Link Right Shift and Store."

**See also:** ALSS, Character Packing, Link

---

## M

**MA (Memory Address Register)**
*Category: [HW]*

Internal 13-bit register holding address for memory operations.

**In PDP-7 Unix:** Not directly accessible but crucial to understanding addressing modes.

**See also:** Address Field, Effective Address, PC

---

**Mass Storage**
*Category: [HW]*

Non-volatile storage devices (DECtape, disk) for persistent data.

**In PDP-7 Unix:** DECtape provided mass storage, holding file system and programs.

**See also:** DECtape, File System, dskio

---

**Memory Reference Instructions**
*Category: [ASM]*

Instructions that access memory (LAC, DAC, ADD, TAD, ISZ, DZM, JMP, JMS).

**In PDP-7 Unix:** Most PDP-7 instructions reference memory with 13-bit address field, plus indirect and index bits.

**Encoding:**
```
Bits 17-14: Opcode (4 bits)
Bit 13: Indirect flag
Bit 12: Index flag
Bits 11-0: Address (12 bits) or 0-12 (13 bits for some)
```

**See also:** LAC, DAC, TAD, ISZ, DZM, JMP, JMS

---

**Minicomputer**
*Category: [HIST]*

Class of smaller, cheaper computers than mainframes (1960s-1980s).

**In PDP-7 Unix:** The PDP-7 was a minicomputer, making interactive computing accessible to research groups without requiring mainframe budgets.

**Etymology:** "Mini" relative to room-sized mainframes.

**Historical significance:** Minicomputers democratized computing, enabling Unix's creation. DEC, Data General, Prime, HP made minicomputers.

**Modern equivalent:** Modern workstations/servers are descendants; "mini" distinction lost as all computers shrank.

**See also:** PDP-7, DEC, Mainframe

---

**MQ (Multiplier-Quotient Register)**
*Category: [HW]*

Secondary 18-bit register for extended operations.

**In PDP-7 Unix:** Used in multiplication, division, double-precision shifts, and as temporary storage.

**Location:** Saved/restored in context switches (`u.mq` in user structure).

**Etymology:** "Multiplier-Quotient" from its use in multiply/divide operations.

**Modern equivalent:** Modern CPUs have many general-purpose registers (16+ in x86-64) rather than special-purpose MQ.

**See also:** AC, LMQ, LACQ, Register Set

---

**Multics (Multiplexed Information and Computing Service)**
*Category: [HIST]*

Ambitious time-sharing operating system project (1964-1969) by MIT, GE, Bell Labs.

**In PDP-7 Unix:** Unix was created after Bell Labs withdrew from Multics. Thompson and Ritchie wanted Multics-like environment but simpler. Unix's original name "Unics" punned on "Multics."

**Etymology:** "Multiplexed" (serving multiple users simultaneously) + "Information and Computing Service."

**Historical significance:** Though Multics itself was complex and commercial failure, it pioneered concepts Unix inherited:
- Hierarchical file system
- Dynamic linking
- Ring-based security
- Shell and command language

**See also:** Unics, Ken Thompson, Dennis Ritchie, Bell Labs

---

## N

**namei (Name to Inode)**
*Category: [OS]*

Kernel routine that converts a pathname to an inode.

**In PDP-7 Unix:** Parses path, traverses directories, and returns inode corresponding to the name.

**Location:** `sysmap:153` at `002750`.

**See also:** Pathname, Directory, Inode

---

**9-bit Characters**
*Category: [HW]*

Character size in PDP-7, allowing 512 possible characters (though typically 7-bit ASCII used).

**In PDP-7 Unix:** Each 18-bit word holds two 9-bit characters. 9 bits allowed 7-bit ASCII plus parity or extensions.

**Etymology:** Chosen to fit two characters per word (2 × 9 = 18 bits).

**Modern equivalent:** 8-bit bytes (octets) are universal standard now.

**See also:** Character Packing, ASCII, 18-bit Word

---

## O

**Octal (Base-8) Notation**
*Category: [ASM]*

Number system using digits 0-7, natural for 18-bit words (6 octal digits).

**In PDP-7 Unix:** All constants, addresses, and numbers in assembly use octal. 18 bits = exactly 6 octal digits (000000 to 777777).

**Examples:**
- `o177` = octal 177 = decimal 127 = binary 001111111
- `0400000` = octal 400000 = half-word flag for character packing
- `017777` = octal 17777 = decimal 8191 = max 13-bit address

**Location:** Octal constants denoted with leading `o` or `0`, e.g., `o12`, `o777`, `0100`.

**Etymology:** "Octal" from Latin "octo" (eight).

**Historical note:** Octal was common in 12-bit, 18-bit, 36-bit machines. Hexadecimal replaced it when 8-bit bytes and powers-of-2 word sizes dominated.

**Modern equivalent:** Hexadecimal (base-16) now standard for most architectures.

**See also:** 18-bit Word, Constants, Assembly Language

---

**OPEN**
*Category: [UNIX]*

System call that opens a file for reading or writing.

**In PDP-7 Unix:** Takes filename and mode, allocates file descriptor, returns descriptor number.

**Location:** System call at `.open` in `s2.s:186`. Used throughout utilities, e.g., `cat.s:12`, `init.s:21-22`.

**Modes:**
- 0: read only
- 1: write only
- 2: read-write (later Unix addition)

**Etymology:** Standard I/O terminology.

**Modern equivalent:** `open()` system call in all Unix systems, with many more flags (O_CREAT, O_APPEND, O_TRUNC, etc.).

**See also:** CLOSE, CREAT, File Descriptor

---

**OPR (Operate Instructions)**
*Category: [ASM]*

Class of instructions performing operations on AC, MQ, and Link without memory access.

**In PDP-7 Unix:** OPR instructions are microcoded, combining multiple operations in one instruction.

**Examples:**
- `cla` - Clear AC
- `cll` - Clear Link
- `lmq` - Load MQ from AC
- `lacq` - Load AC from MQ
- `als` - Arithmetic Left Shift
- `ral` - Rotate AC Left

**Etymology:** "Operate" - operate on registers.

**Modern equivalent:** Register-to-register instructions in all architectures.

**See also:** CLA, CLL, LMQ, LACQ, ALS, RAL

---

## P

**Paper Tape**
*Category: [HW]*

Punched paper tape for program/data storage and input.

**In PDP-7 Unix:** Used for loading programs before file system available, and for long-term archival.

**Characteristics:**
- 8 channels (holes) across tape
- Sequential access only
- Slow but reliable
- Readable by human (holes visible)

**Etymology:** Literally paper with punched holes.

**Modern equivalent:** Obsolete; replaced by magnetic media, then flash storage.

**See also:** APR, I/O Devices, Boot

---

**Password**
*Category: [UNIX]*

Secret authentication credential for user login.

**In PDP-7 Unix:** Stored in password file (`/password`). Init reads and verifies against user input during login.

**Location:** Referenced in `init.s:41`, `init.s:266`.

**Etymology:** "Pass" + "word" - word allowing passage.

**Historical note:** Early Unix passwords stored in plaintext. Encryption came later (Version 3 introduced crypt()).

**Modern equivalent:** Hashed and salted passwords, multi-factor authentication.

**See also:** Login, Init, User ID

---

**Pathname**
*Category: [UNIX]*

String specifying location of file in directory hierarchy.

**In PDP-7 Unix:** Pathnames navigate directory tree. Absolute paths start from root (/), relative paths from current directory.

**Etymology:** "Path" + "name."

**See also:** Directory, File System, namei

---

**PC (Program Counter)**
*Category: [HW]*

Register holding address of next instruction to execute.

**In PDP-7 Unix:** 13-bit register, automatically incremented after instruction fetch. Modified by JMP and JMS.

**Etymology:** "Program Counter."

**Modern equivalent:** RIP (x86-64), PC (ARM) - all architectures have instruction pointer.

**See also:** JMP, JMS, Address Field

---

**PDP-7 (Programmed Data Processor 7)**
*Category: [HW]*

18-bit minicomputer manufactured by DEC (1964-1969), platform for first Unix.

**Specifications:**
- Word size: 18 bits
- Memory: Up to 8K words (16 KB)
- Speed: ~1.75 μs cycle time
- Price: ~$72,000 (1965)
- Peripherals: Teletype, DECtape, paper tape, display

**In PDP-7 Unix:** The entire environment that shaped Unix's minimal design.

**Historical significance:** Though obsolete when Thompson used it (1969), the PDP-7's availability and simplicity enabled Unix's creation.

**See also:** DEC, 18-bit Word, Minicomputer, Hardware Architecture

---

**PDP-11**
*Category: [HIST]*

16-bit minicomputer by DEC, Unix's second platform (1971+).

**Historical significance:** Unix rewritten for PDP-11 in 1971, becoming Version 1. PDP-11's byte addressing and larger memory enabled Unix's growth. Most Unix development through the 1970s occurred on PDP-11.

**See also:** PDP-7, Unix V1, Unix V7

---

**PID (Process ID)**
*Category: [OS]*

Unique integer identifying a process.

**In PDP-7 Unix:** Each process has a PID. Init is always PID 1. Fork returns child's PID to parent.

**Location:** Stored in `u.pid` (user structure).

**Etymology:** "Process ID."

**Modern equivalent:** PIDs in all Unix systems, typically 16-bit or 32-bit integers.

**See also:** Process, Fork, Init, u.pid

---

**Pipe**
*Category: [UNIX]*

Mechanism for passing data between processes (not in PDP-7 Unix).

**In PDP-7 Unix:** Pipes not implemented in PDP-7 Unix. Added in later PDP-11 versions.

**Historical note:** Pipes ("|") became iconic Unix feature, but weren't in the original PDP-7 version. Inter-process communication used message passing (smes/rmes).

**See also:** rmes, smes, Inter-Process Communication

---

**Process**
*Category: [OS]*

Running instance of a program with its own memory space and execution state.

**In PDP-7 Unix:** Each process has:
- Unique PID
- User structure (u) with state
- Memory space (swappable to disk)
- Open file table
- Current directory

**Location:** Process management in `s3.s` (fork, exit, save).

**Etymology:** "Process" as ongoing activity or task.

**Modern equivalent:** Process concept fundamentally unchanged, though modern systems add threads, namespaces, control groups.

**See also:** Fork, Exit, PID, Context Switch, User Structure

---

**Process Swapping**
*Category: [OS]*

Moving process memory between RAM and disk to allow more processes than fit in RAM.

**In PDP-7 Unix:** Inactive processes swapped to disk, freeing memory for active processes. Swapper routine manages swap operations.

**Location:** Swap logic in `s1.s:80-129`.

**Etymology:** "Swap" meaning exchange places.

**Modern equivalent:** Modern systems use demand paging rather than whole-process swapping.

**See also:** Context Switch, swap, Virtual Memory

---

**putc (Put Character)**
*Category: [UNIX]*

Buffered character output routine.

**In PDP-7 Unix:** Writes characters to output buffer, flushing to file when buffer fills.

**Location:** `cat.s:102-129` implements putc.

**See also:** getc, Character I/O, WRITE

---

## Q

**Quantum (Time Quantum)**
*Category: [OS]*

Time slice allocated to a process before scheduler switches to another process.

**In PDP-7 Unix:** Each process runs for `uquant` time units before being swapped. `maxquant` defines maximum quantum.

**Location:** `uquant` at `sysmap:253`, `maxquant` at `sysmap:149`.

**Etymology:** "Quantum" from physics - discrete unit.

**Modern equivalent:** Time slices in all multitasking systems, typically milliseconds.

**See also:** Scheduler, Process Swapping, Time-Sharing

---

## R

**RAL (Rotate Accumulator Left)**
*Category: [ASM]*

OPR instruction rotating AC and Link left by one bit.

**In PDP-7 Unix:** Used for bit manipulation, especially in character packing/unpacking.

**Operation:** `Link || AC` rotated left: `Link ← AC[17], AC ← AC[16:0] || Link`

**Location:** Used in `init.s:202`, `cat.s:80`.

**Etymology:** "Rotate AC Left."

**Modern equivalent:** ROL (Rotate Left) in x86.

**See also:** RAR, RCR, Link, Rotate Instructions

---

**RAR (Rotate Accumulator Right)**
*Category: [ASM]*

OPR instruction rotating AC and Link right by one bit.

**Operation:** `Link || AC` rotated right: `AC[0] → Link, Link → AC[17], AC ← AC[17:1]`

**Etymology:** "Rotate AC Right."

**See also:** RAL, RCR, Link

---

**RCR (Rotate Combined Right)**
*Category: [ASM]*

OPR instruction rotating Link and AC right together.

**In PDP-7 Unix:** Similar to RAR but may have slightly different behavior in microcoded implementation.

**Location:** Used in `cat.s:67`.

**See also:** RAL, RAR, Rotate Instructions

---

**READ**
*Category: [UNIX]*

System call that reads data from file descriptor into buffer.

**In PDP-7 Unix:** Takes file descriptor, buffer address, and byte count. Returns number of bytes read (0 at EOF).

**Location:** System call at `.read` in `s2.s:251`. Used in `cat.s:90`, `init.s:168`.

**Etymology:** Standard I/O term.

**Modern equivalent:** `read()` system call in all Unix systems.

**See also:** WRITE, OPEN, File Descriptor, File I/O

---

**Register**
*Category: [HW]*

Small, fast storage location in CPU.

**In PDP-7 Unix:** Four main registers: AC, MQ, Link, PC.

**See also:** AC, MQ, Link, PC, Register Set

---

**RENAME**
*Category: [UNIX]*

System call that changes a file's name in the directory.

**In PDP-7 Unix:** Removes old directory entry and creates new one, without copying file data.

**Location:** System call at `.rename` in `s2.s:154`.

**Etymology:** "Re-name."

**Modern equivalent:** `rename()` system call in Unix systems.

**See also:** LINK, UNLINK, Directory

---

**Research Unix**
*Category: [HIST]*

Original Unix lineage developed at Bell Labs, as distinct from commercial versions.

**Versions:**
- PDP-7 Unix (1969-1970)
- V1-V7 (1971-1979)
- V8-V10 (1980s)

**Etymology:** "Research" because developed in research organization (Bell Labs Computing Science Research Center), not as commercial product.

**See also:** Unix V7, BSD Unix, Bell Labs

---

**rmes (Receive Message)**
*Category: [UNIX]*

System call for inter-process message passing.

**In PDP-7 Unix:** Receives message from another process. Blocks if no message available.

**Location:** System call at `.rmes` in `s3.s:99`. Used in `init.s:8`.

**Etymology:** "Receive message."

**See also:** smes, Inter-Process Communication, Pipe

---

**Root Directory**
*Category: [OS]*

Top-level directory (/) in hierarchical file system.

**In PDP-7 Unix:** All pathnames ultimately descend from root. Absolute paths start with /.

**Etymology:** "Root" of the directory tree.

**Modern equivalent:** Universal in all Unix/Linux systems.

**See also:** Directory, File System, Pathname

---

## S

**SAD (Skip if Accumulator Different)**
*Category: [ASM]*

Memory reference instruction that compares AC with memory and skips next instruction if different.

**In PDP-7 Unix:** Primary comparison instruction for conditionals.

**Location:** Used extensively, e.g., `s1.s:171-172`, `cat.s:19`.

**Etymology:** "Skip if AC Different."

**Example:**
```assembly
   lac value
   sad limit
   jmp equal       " Not skipped if AC ≠ limit
   " Skipped if AC = limit
equal:
```

**Modern equivalent:** CMP + conditional jump (x86), CMP + conditional branch (ARM).

**See also:** SNA, SZA, Skip Instructions

---

**SAVE (Save Process State)**
*Category: [UNIX]*

System call that saves current process state and potentially swaps to disk.

**In PDP-7 Unix:** Saves registers and memory state, used in process scheduling and swapping.

**Location:** System call at `.save` in `s3.s:77`. Referenced in `s1.s:69`.

**See also:** Context Switch, Process Swapping

---

**Scheduler**
*Category: [OS]*

Kernel component deciding which process runs next.

**In PDP-7 Unix:** Simple round-robin scheduling with time quanta. Swaps processes in/out as needed.

**Location:** Scheduling logic in swap routine (`s1.s:80-129`).

**Etymology:** "Schedule" - plan of activities.

**Modern equivalent:** Modern schedulers are far more complex (CFS in Linux, with priority classes, real-time support, multi-core balancing).

**See also:** Process, Quantum, Time-Sharing, Process Swapping

---

**SEEK**
*Category: [UNIX]*

System call that changes file pointer position.

**In PDP-7 Unix:** Moves read/write position within file.

**Location:** System call at `.seek` in `s2.s:60`.

**Etymology:** "Seek" as in searching for position.

**Modern equivalent:** `lseek()` system call (with whence parameter: SEEK_SET, SEEK_CUR, SEEK_END).

**See also:** TELL, File Pointer, File I/O

---

**Self-Hosting**
*Category: [HIST]*

Ability of a system to develop itself (assembler can assemble itself, editor can edit its own source).

**In PDP-7 Unix:** Major milestone when PDP-7 Unix could assemble and edit its own code without requiring the GE mainframe.

**Historical significance:** Self-hosting proved Unix was a complete, viable operating system.

**See also:** Cross-Development, Assembler, Editor

---

**SETUID (Set User ID)**
*Category: [UNIX]*

System call that changes process's user ID.

**In PDP-7 Unix:** Sets `u.uid`. After login authentication, init uses setuid to run shell with user's identity.

**Location:** System call at `.setuid` in `s2.s:146`. Used in `init.s:126`.

**Etymology:** "Set User ID."

**Security note:** Later Unix versions restricted setuid to superuser or added setuid bit on executables for privilege elevation.

**Modern equivalent:** `setuid()` system call, plus setuid file permission bit.

**See also:** GETUID, UID, Login, u.uid

---

**SH (Shell)**
*Category: [UNIX]*

Command interpreter providing user interface to Unix.

**In PDP-7 Unix:** Shell reads commands from user, interprets them, and executes programs. Located in user's directory (or /system).

**Location:** Referenced in `init.s:132-138`, `init.s:262`.

**Etymology:** "Shell" wrapping the kernel.

**Historical significance:** Thompson shell (sh) was first Unix shell. Later versions: Bourne shell (1977), C shell (1978), Bash (1989).

**Modern equivalent:** Bash, zsh, fish, PowerShell.

**See also:** Command Interpreter, Init, Login

---

**Shift Instructions**
*Category: [ASM]*

OPR instructions that shift AC bits left or right.

**In PDP-7 Unix:** Used for multiplication/division by powers of 2, bit manipulation, character packing.

**Types:**
- ALS: Arithmetic Left Shift
- ARS: Arithmetic Right Shift
- LRSS: Link Right Shift and Store

**See also:** ALS, ARS, LRSS, OPR

---

**Skip Instructions**
*Category: [ASM]*

Instructions that conditionally skip the next instruction based on a test.

**In PDP-7 Unix:** Primary mechanism for conditionals before structured control flow.

**Types:**
- SAD: Skip if AC Different
- SNA: Skip if AC Non-zero
- SZA: Skip if AC Zero
- ISZ: Increment and Skip if Zero
- SZL: Skip if Link Zero
- SNL: Skip if Link Non-zero
- SPA: Skip if AC Positive
- SMA: Skip if AC Minus (negative)
- SNS: Skip if AC Non-zero and Skip

**Location:** Used throughout for all conditional logic.

**Etymology:** "Skip" next instruction.

**Pattern:**
```assembly
   lac value
   sad limit     " Skip next if AC ≠ limit
   jmp equal     " Jump if equal (not skipped)
   " Fall through if not equal (skipped)
equal:
```

**See also:** SAD, SNA, SZA, ISZ, Conditional Execution

---

**SMA (Skip if Minus - AC negative)**
*Category: [ASM]*

Skip instruction that skips next instruction if AC is negative (bit 17 set).

**Location:** Used in `cat.s:133`, `init.s:133`.

**Etymology:** "Skip if Minus (negative) Accumulator."

**See also:** SPA, SAD, Skip Instructions

---

**smes (Send Message)**
*Category: [UNIX]*

System call for inter-process message passing.

**In PDP-7 Unix:** Sends message to another process. Blocks if recipient not ready.

**Location:** System call at `.smes` in `s3.s:124`. Used in `init.s:237`.

**Etymology:** "Send message."

**See also:** rmes, Inter-Process Communication

---

**SNA (Skip if AC Non-zero)**
*Category: [ASM]*

Skip instruction that skips next instruction if AC ≠ 0.

**In PDP-7 Unix:** Common test for null pointers, zero values, or success/failure.

**Location:** Used extensively, e.g., `s1.s:59`, `s1.s:107`, `s1.s:123`.

**Etymology:** "Skip if (AC is) Not zero" or "Skip if Non-zero Accumulator."

**Modern equivalent:** TEST + JNZ (jump if not zero) in x86.

**See also:** SZA, SAD, Skip Instructions

---

**SNL (Skip if Link Non-zero)**
*Category: [ASM]*

Skip instruction that skips next instruction if Link bit is set.

**Location:** Used in `init.s:204`.

**See also:** SZL, Link, Skip Instructions

---

**SNS (Skip if AC Non-zero and Skip)**
*Category: [ASM]*

Complex skip instruction with dual function.

**In PDP-7 Unix:** Tests AC and performs conditional skip with side effect.

**Location:** Used in `cat.s:59`.

**See also:** SNA, Skip Instructions

---

**SPA (Skip if AC Positive)**
*Category: [ASM]*

Skip instruction that skips next instruction if AC ≥ 0 (bit 17 clear).

**In PDP-7 Unix:** Tests for non-negative values, often after system calls that return -1 on error.

**Location:** Used in `cat.s:13`, `init.s:136`, `init.s:139`.

**Etymology:** "Skip if Positive Accumulator."

**See also:** SMA, Skip Instructions, Error Checking

---

**Space Travel**
*Category: [HIST]*

Space simulation game written by Ken Thompson, catalyst for Unix creation.

**In PDP-7 Unix:** Thompson wanted to run Space Travel more economically than on the GE mainframe ($75/session). Porting it to the idle PDP-7 led to creating an operating system for the PDP-7, which became Unix.

**Historical significance:** Often cited as the "reason" Unix was created, though Thompson's interest in operating systems was deeper.

**See also:** Ken Thompson, PDP-7, Unix History

---

**Superblock**
*Category: [OS]*

File system data structure containing metadata about the entire file system.

**In PDP-7 Unix:** Contains:
- s.fblks: free block list
- s.nfblks: number of free blocks
- s.nxfblk: next free block pointer
- s.uniq: unique ID counter
- s.tim: time stamp

**Location:** Structure defined by labels starting with `s.` in sysmap (lines 215-220).

**Etymology:** "Super" (above/over) + "block" (unit of storage).

**Modern equivalent:** All file systems have superblocks or equivalent metadata structures.

**See also:** File System, Free Block List, Inode

---

**Symbol Table**
*Category: [ASM]*

Assembler data structure mapping symbolic names to addresses.

**In PDP-7 Unix:** Assembler builds symbol table in first pass, uses it to resolve references in second pass.

**Location:** Symbol table functionality in `as.s`. Output format in `sysmap` file.

**See also:** Assembler, Two-Pass Assembler, sysmap

---

**SZA (Skip if AC Zero)**
*Category: [ASM]*

Skip instruction that skips next instruction if AC = 0.

**In PDP-7 Unix:** Common test for null, empty, or false values.

**Location:** Used extensively, e.g., `s1.s:61`, `s1.s:166`, `s1.s:185`.

**Etymology:** "Skip if Zero Accumulator."

**Modern equivalent:** TEST + JZ (jump if zero) in x86.

**See also:** SNA, SAD, Skip Instructions

---

**SZL (Skip if Link Zero)**
*Category: [ASM]*

Skip instruction that skips next instruction if Link bit is clear.

**Location:** Used in `cat.s:82`.

**See also:** SNL, Link, Skip Instructions

---

**sys (System Call Prefix)**
*Category: [ASM]*

Assembly language prefix indicating a system call invocation.

**In PDP-7 Unix:** Programs invoke system calls with `sys <name>` syntax.

**Example:**
```assembly
   sys fork      " Invoke fork system call
   sys open; name; mode  " Open file
   sys read; buf; count  " Read data
```

**Location:** Used throughout all user programs.

**See also:** System Call, Kernel

---

**sysdata (System Data Area)**
*Category: [OS]*

Kernel data area for system-wide variables and tables.

**In PDP-7 Unix:** Contains global kernel data structures.

**Location:** `sysmap:231` at address `005553`.

**See also:** userdata, Kernel, u structure

---

**sysmap (System Map)**
*Category: [UNIX]*

Symbol table file listing all kernel symbols and their addresses.

**In PDP-7 Unix:** Documents kernel layout, essential for understanding code structure.

**Location:** `/home/user/unix-history-repo/sysmap` (260 lines)

**See also:** Symbol Table, Kernel, Assembler

---

**System Call**
*Category: [OS]*

Interface for user programs to request kernel services.

**In PDP-7 Unix:** Programs trap into kernel via `sys` directive. Kernel validates parameters, performs operation, returns result.

**System calls in PDP-7 Unix:**
- fork, exit, save
- open, creat, close, read, write
- seek, tell, link, unlink
- chdir, chmod, chown
- getuid, setuid
- smes, rmes (message passing)
- intrp, capt, rele, status

**Location:** System call dispatch in `s1.s:133-138`. Individual implementations in `s2.s` and `s3.s`.

**Etymology:** "System call" - call into the system (kernel).

**Modern equivalent:** System call interface fundamental to all operating systems. Linux has ~300+ system calls.

**See also:** Kernel, User Mode, Kernel Mode

---

## T

**TAD (Two's Complement Add)**
*Category: [ASM]*

Memory reference instruction that adds memory value to AC.

**In PDP-7 Unix:** Primary arithmetic instruction. Sets Link on overflow.

**Location:** Used extensively for arithmetic, e.g., `s1.s:43`, `s1.s:47`.

**Etymology:** "Two's Complement Add" (signed addition).

**Example:**
```assembly
   lac count
   tad d1        " AC ← AC + 1 (increment count)
   dac count
```

**Modern equivalent:** ADD instruction in all architectures.

**See also:** AC, Arithmetic, Link

---

**TELL**
*Category: [UNIX]*

System call that returns current file pointer position.

**In PDP-7 Unix:** Returns offset within file where next read/write will occur.

**Location:** System call at `.tell` in `s2.s:84`.

**Etymology:** "Tell" the current position.

**Modern equivalent:** Integrated into `lseek()` with SEEK_CUR and 0 offset.

**See also:** SEEK, File Pointer

---

**Teletype (TTY)**
*Category: [HW]*

Electromechanical typewriter terminal for input/output.

**In PDP-7 Unix:** Primary user interface device. Keyboard for input, printer for output. Typically ASR-33 Teletype (10 characters/second).

**Characteristics:**
- Speed: 110 baud (10 cps)
- Paper-based output
- Mechanical keyboard
- Integral paper tape punch/reader

**Location:** TTY I/O routines in kernel.

**Etymology:** "Tele-" (distance) + "type" (typewriter). Originally for telegraph communications.

**Historical note:** "TTY" still used in Unix/Linux to refer to terminals (pts, tty0, etc.), though teletype machines are obsolete.

**Modern equivalent:** Terminal emulators, SSH clients, console screens.

**See also:** Terminal, I/O Devices

---

**TIME**
*Category: [UNIX]*

System call that returns current system time.

**In PDP-7 Unix:** Returns time value maintained by kernel.

**Location:** System call at `.time` in `s2.s:168`.

**Etymology:** Standard term.

**Modern equivalent:** `time()` system call, now returning seconds since Unix Epoch (Jan 1, 1970).

**See also:** System Time, Unix Epoch

---

**Time-Sharing**
*Category: [OS]*

Operating system technique allowing multiple users/processes to share CPU by rapid switching.

**In PDP-7 Unix:** Unix implemented time-sharing with process swapping and scheduling. Each process gets time quantum before being swapped.

**Etymology:** "Sharing" time among users/processes.

**Historical significance:** Time-sharing was revolutionary in the 1960s, replacing batch processing. Multics pioneered it; Unix made it practical and efficient.

**Modern equivalent:** All modern OS are time-sharing (though often called "multitasking" now).

**See also:** Process Swapping, Scheduler, Quantum, Multitasking

---

**TUHS (The Unix Heritage Society)**
*Category: [HIST]*

Organization preserving Unix history and source code.

**Founded:** 1994 by Warren Toomey

**Significance:** Maintains archive of historical Unix versions, documentation, and artifacts. Instrumental in preserving and resurrecting PDP-7 Unix.

**Website:** http://www.tuhs.org/

**See also:** Warren Toomey, pdp7-unix Project, Unix History

---

**Two-Pass Assembler**
*Category: [ASM]*

Assembler that processes source code twice to resolve forward references.

**In PDP-7 Unix:** The `as.s` assembler makes two passes:
1. **Pass 1:** Build symbol table, assign addresses
2. **Pass 2:** Generate machine code using symbol table

**Location:** Two-pass logic in `as.s`, controlled by `passno` flag.

**Etymology:** "Two passes" through the source code.

**Reason:** Forward references (using symbols before they're defined) require knowing all symbol values before generating code.

**Modern equivalent:** Most assemblers still use two passes, though some use more sophisticated algorithms.

**See also:** Assembler, Symbol Table, as.s

---

## U

**u structure (User Structure)**
*Category: [OS]*

Per-process data structure containing process state.

**In PDP-7 Unix:** Each process has a u structure with:
- u.ac, u.mq: saved registers
- u.pid: process ID
- u.uid: user ID
- u.ofiles: open file descriptors
- u.cdir: current directory
- u.base, u.count: I/O parameters
- u.intflg: interrupt flag

**Location:** Labels starting with `u.` in sysmap (lines 237-248, 254).

**Etymology:** "u" for "user" structure.

**Modern equivalent:** task_struct (Linux), proc structure (BSD) - much larger and more complex now.

**See also:** Process, Context Switch, userdata

---

**UID (User ID)**
*Category: [OS]*

Integer identifying a user for permissions and accounting.

**In PDP-7 Unix:** Each process has a UID (u.uid). Files have owner UID (i.uid). System checks UID for access control.

**Location:** `u.uid` at `sysmap:244`, `i.uid` at `sysmap:128`.

**Etymology:** "User ID."

**Historical note:** PDP-7 Unix had simple UID scheme. Later versions added group IDs (GID), supplementary groups, etc.

**Modern equivalent:** UIDs standard in all Unix systems. UID 0 = root (superuser).

**See also:** GETUID, SETUID, Permissions, Ownership

---

**UNICS (Uniplexed Information and Computing Service)**
*Category: [HIST]*

Original name for Unix, punning on Multics.

**Etymology:** "Uniplexed" (simplified, one thing at a time) vs. "Multiplexed" (Multics' complex multi-user approach). Later shortened to "Unix."

**Historical note:** The pun reflected Thompson's philosophy: simplicity over complexity, doing one thing well.

**See also:** Unix, Multics, Ken Thompson

---

**Unix**
*Category: [HIST]*

Operating system created by Ken Thompson and Dennis Ritchie at Bell Labs (1969-1970).

**In PDP-7 Unix:** The first version, written entirely in PDP-7 assembly language.

**Etymology:** From "Unics" (Uniplexed Information and Computing Service), spelling later changed to "Unix."

**Historical significance:**
- Pioneered hierarchical file system
- Introduced clean process model (fork/exec)
- Established "Unix philosophy" (small tools, composition)
- Became most influential operating system in history
- Led to BSD, Linux, macOS, iOS, Android

**Modern equivalent:** Linux, BSD variants, macOS - all Unix-like or Unix-derived.

**See also:** Ken Thompson, Dennis Ritchie, Unics, Research Unix

---

**Unix Epoch**
*Category: [HIST]*

Starting point of Unix time: January 1, 1970, 00:00:00 UTC.

**In PDP-7 Unix:** Not strictly implemented in PDP-7 Unix, but the repository uses this date symbolically.

**Etymology:** "Epoch" as starting point of an era.

**Modern equivalent:** Unix time (seconds since Epoch) used in all Unix systems. Will overflow 32-bit signed integers on January 19, 2038 (Y2038 problem).

**See also:** TIME, Unix History

---

**Unix Philosophy**
*Category: [HIST]*

Design principles guiding Unix development:

1. Make each program do one thing well
2. Expect output of one program to be input of another
3. Design and build software to be tried early
4. Use tools to lighten programming tasks

**In PDP-7 Unix:** Embodied in simple, focused utilities (cat, cp, ed) and composition via shell.

**Historical significance:** Influenced software design far beyond Unix. Principles of modularity, simplicity, and composition spread to all computing.

**See also:** Ken Thompson, Dennis Ritchie, Unix

---

**Unix V1, V2, ..., V7**
*Category: [HIST]*

Research Unix versions released from Bell Labs (1971-1979).

**Timeline:**
- V1 (1971): First PDP-11 Unix
- V3 (1973): Rewritten in C (except some assembly)
- V6 (1975): Widely distributed to universities
- V7 (1979): Last widely distributed Research Unix

**Significance:** Each version added features and polish. V7 became basis for BSD and commercial Unix variants.

**See also:** Research Unix, PDP-11, C Language

---

**UNLINK**
*Category: [UNIX]*

System call that removes a directory entry (filename) for a file.

**In PDP-7 Unix:** Decrements inode link count. If count reaches zero and no process has file open, deletes file and frees its blocks.

**Location:** System call at `.unlink` in `s2.s:128`. Used in `init.s:141`.

**Etymology:** "Unlink" - break the link between name and file.

**Modern equivalent:** `unlink()` system call in all Unix systems.

**See also:** LINK, RENAME, Inode, Hard Link

---

**userdata (User Data Area)**
*Category: [OS]*

Memory area containing current process's u structure.

**In PDP-7 Unix:** Points to active process's saved state and context.

**Location:** `sysmap:254` at `005642`.

**See also:** u structure, sysdata, Process

---

## V

**Virtual Memory**
*Category: [OS]*

Technique allowing processes to use more memory than physically available via paging/swapping.

**In PDP-7 Unix:** Primitive form via process swapping. Entire processes swapped to/from disk, not individual pages.

**Modern equivalent:** Modern systems use demand paging with virtual address spaces, page tables, and MMUs.

**See also:** Process Swapping, swap, Memory Management

---

## W

**Warren Toomey**
*Category: [HIST]*

Computer scientist who founded TUHS and led PDP-7 Unix resurrection project.

**Significance:** Toomey's work preserving Unix history, scanning Dennis Ritchie's printouts, and coordinating the PDP-7 Unix restoration made this documentation possible.

**See also:** TUHS, pdp7-unix Project, Unix Heritage

---

**Word (18-bit)**
*Category: [HW]*

Fundamental unit of storage in PDP-7.

**In PDP-7 Unix:** All memory addresses reference words, not bytes. File sizes measured in words. Instructions are one word (18 bits).

**Implications:**
- Memory: 8K words = 16 KB
- Characters: 2 per word (9 bits each)
- Addresses: 13 bits = 8192 word addresses

**See also:** 18-bit Word, 9-bit Characters, Memory

---

**WRITE**
*Category: [UNIX]*

System call that writes data from buffer to file descriptor.

**In PDP-7 Unix:** Takes file descriptor, buffer address, and word count. Returns number of words written.

**Location:** System call at `.write` in `s2.s:289`. Used in `init.s:43`, `init.s:70`, `cat.s:125`.

**Etymology:** Standard I/O term.

**Modern equivalent:** `write()` system call in all Unix systems (now byte-oriented, not word-oriented).

**See also:** READ, File I/O, File Descriptor

---

## X

**XOR (Exclusive OR)**
*Category: [ASM]*

Logical operation available as OPR microcoded instruction.

**In PDP-7 Unix:** Used for bit manipulation, toggling flags, and quick comparisons.

**Location:** Used in `init.s:98`, `init.s:107`.

**Etymology:** "Exclusive OR" - true if operands differ.

**Modern equivalent:** XOR in all architectures.

**See also:** OPR, Logical Operations

---

## Y

**Y2038 Problem**
*Category: [HIST]*

Future overflow of 32-bit Unix time on January 19, 2038.

**Relevance:** Unix time (seconds since Epoch) will overflow signed 32-bit integer at 03:14:07 UTC on January 19, 2038.

**Solution:** Modern systems transitioning to 64-bit time_t.

**See also:** Unix Epoch, TIME

---

## Z

**Zero Page**
*Category: [HW]*

First page of memory (addresses 0-0177 octal) in PDP-7.

**In PDP-7 Unix:** Contains interrupt vectors, kernel entry points, and frequently accessed variables. Direct addressing within zero page is most efficient.

**Location:** `s1.s` starts with `orig:` at address 0.

**Etymology:** "Page zero" or "zero page."

**Modern equivalent:** Modern CPUs don't privilege address 0; often kept unmapped to catch null pointer dereferences.

**See also:** Memory Organization, Interrupts

---

## Appendix: Symbol Naming Conventions

**Octal Constants:**
- `o12`, `o177`, `o777`: Octal values (leading 'o')
- `d1`, `d2`, `d10`: Decimal constants (leading 'd')
- `dm1`: Decimal minus 1 (-1)

**System Data Structures:**
- `d.`: Directory entry fields (d.i, d.name, d.uniq)
- `i.`: Inode fields (i.flags, i.uid, i.size, i.dskps)
- `u.`: User structure fields (u.ac, u.pid, u.uid, u.ofiles)
- `s.`: Superblock fields (s.fblks, s.nfblks, s.tim)
- `f.`: File table fields (f.flags, f.badd)

**System Calls:**
- `.`: Prefix for system call entry points (.fork, .read, .write)

**Kernel Routines:**
- Lowercase: Kernel functions (alloc, free, copy, betwen)
- Mixed: Device or subsystem routines (dskio, dskrd, dskwr)

---

## Cross-Reference by Chapter

Readers should consult these chapters for more details:

- **Chapter 2**: Hardware terms (AC, MQ, Link, PDP-7, 18-bit word, DECtape)
- **Chapter 3**: Assembly terms (LAC, DAC, TAD, JMS, OPR, addressing modes)
- **Chapter 4**: System architecture (kernel, process, file system overview)
- **Chapter 5-9**: Kernel internals (system calls, inode, directory, swap)
- **Chapter 10**: Development tools (assembler, editor, debugger)
- **Chapter 11**: User utilities (cat, cp, ed, sh)
- **Chapter 12**: B language system

---

## Bibliography

For more information, consult:

1. PDP-7 User's Manual (DEC, 1965)
2. "UNIX Implementation" - Ken Thompson (CACM, 1974)
3. "The Evolution of the Unix Time-sharing System" - Dennis Ritchie (1979)
4. Unix Programmer's Manual, Research Edition
5. TUHS Archives: http://www.tuhs.org/
6. pdp7-unix project: https://github.com/DoctorWkt/pdp7-unix

---

*This glossary is part of the comprehensive PDP-7 Unix Documentation Project.*

*Last updated: November 2025*
