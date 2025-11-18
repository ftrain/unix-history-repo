# Introduction and Historical Context

## The Birth of Unix

On a summer day in 1969, Ken Thompson sat down at a PDP-7 minicomputer at Bell Laboratories in Murray Hill, New Jersey. What he created over the following months would fundamentally reshape computing for the next half-century and beyond. This was the birth of Unix.

### The Multics Withdrawal

The story begins not with success, but with abandonment. Bell Labs, along with MIT and General Electric, had been developing **Multics** (Multiplexed Information and Computing Service), an ambitious time-sharing operating system. Multics aimed to provide a computing utility—like telephone service or electricity—where many users could simultaneously access a powerful central computer.

By 1969, the project had grown enormously complex. Bell Labs management, concerned about cost and complexity, decided to withdraw from the project. This left several researchers, including Ken Thompson and Dennis Ritchie, without access to the comfortable interactive computing environment they had grown accustomed to.

### Space Travel and the Search for a Computer

Ken Thompson had written a game called **Space Travel** that simulated the motion of planets and spacecraft in the solar system. The game required significant computational power and, more importantly, a graphics display. Thompson initially ran it on the GE mainframe using Multics, but the cost—approximately $75 per session in 1960s dollars—was prohibitive for a game.

Thompson and Ritchie went searching for an available computer. They found a **Digital Equipment Corporation PDP-7** sitting in a corner of Bell Labs. The PDP-7 was already obsolete by 1969 standards (it had been introduced in 1964), but it had several appealing characteristics:

1. **Graphics capability** - A **DEC Type 340 display** for vector graphics
2. **Availability** - Nobody else was using it
3. **Accessibility** - No gatekeepers controlling access
4. **Interactivity** - Direct connection without batch processing delays

### From Game to Operating System

Thompson ported Space Travel to the PDP-7, but quickly realized that what the machine really needed was a proper operating system. Drawing on his experience with Multics, but striving for simplicity rather than comprehensiveness, Thompson began designing a minimal but complete operating system.

The design philosophy was revolutionary for its time:

> **"Make each program do one thing well. To do a new job, build afresh rather than complicate old programs by adding new features."**

This became known as the **Unix philosophy**.

### The Four-Week Creation

According to Thompson's later recollections, Unix was created during a four-week period when his family was on vacation:

- **Week 1**: Written the kernel (process management, system calls)
- **Week 2**: Implemented the file system
- **Week 3**: Created the editor (ed)
- **Week 4**: Built the assembler (as)

While this timeline is somewhat mythologized—actual development took longer—it captures the remarkable speed and simplicity of the original Unix implementation.

### Why "Unix"?

The original name was **"Unics"**—Uniplexed Information and Computing Service—a pun on "Multics." Where Multics aimed to multiplex resources for many users simultaneously, Unics simplified everything by handling one thing at a time well. The name eventually became "Unix."

## The PDP-7 Environment

### Why This Machine Mattered

The PDP-7 was a significant constraint that shaped Unix's development:

#### **Hardware Limitations**

| Specification | Value | Impact on Unix |
|---------------|-------|----------------|
| Word size | 18 bits | Files measured in words, not bytes |
| Memory | 8K words (16 KB) | Extreme minimalism required |
| Mass storage | DECtape | Limited filesystem space |
| CPU speed | ~1.75 μs cycle | Performance-conscious code |
| Price | ~$72,000 (1965) | Accessible for research lab |

#### **The 18-Bit Architecture**

Unlike modern 8-bit byte-oriented architectures, the PDP-7 used **18-bit words**. This affected everything:

- **Character storage**: 2 characters per word (9 bits each, supporting 512 possible characters)
- **File sizes**: Measured in words, not bytes
- **Addressing**: Octal (base-8) notation natural for 18-bit words
- **Pointers**: Word addresses, not byte addresses

This is why early Unix source code uses octal notation pervasively:

```assembly
" Octal notation in PDP-7 assembly
lac 0177        " Load accumulator with octal 177 (decimal 127)
dac 017777      " Store at location 17777 octal (decimal 8191)
```

### The Development Environment

Creating Unix on the PDP-7 presented unique challenges:

#### **Cross-Development**

Initially, Thompson wrote the assembler on the **GE 635 mainframe** running GECOS (the successor to Multics at Bell Labs):

1. Write PDP-7 assembly code on the GE 635
2. Cross-assemble to PDP-7 machine code
3. Punch output to paper tape
4. Physically carry paper tape to PDP-7
5. Load paper tape into PDP-7 memory
6. Debug by examining core dumps

This tedious process continued until the PDP-7 could self-host—that is, until Unix itself could run the assembler and tools needed to develop Unix.

#### **Self-Hosting Achievement**

A crucial milestone came when Unix became **self-hosting**:

- The **assembler (as.s)** could assemble itself
- The **editor (ed1.s, ed2.s)** could edit its own source code
- The **debugger (db.s)** could debug programs that crashed
- System utilities could be developed entirely on Unix

This self-hosting capability proved Unix's viability as a complete operating system.

## The Source Code We Have Today

### A Miraculous Preservation

The PDP-7 Unix source code could easily have been lost to history. What we have today exists thanks to remarkable preservation efforts:

#### **1970-1971: The Original Printouts**

Dennis Ritchie kept **printed listings** of the PDP-7 Unix source code—nearly 190 pages of line-printer output. These printouts sat in his office at Bell Labs for decades.

#### **2019: The Discovery**

After Ritchie's death in 2011, his papers were donated to the **Computer History Museum**. In 2019, to commemorate Unix's 50th anniversary, the museum made these printouts publicly accessible. The source code listings included:

- Complete system source (s1.s through s9.s)
- User utilities (cat, cp, ed, as, etc.)
- Development tools (assembler, editor, debugger)
- B language interpreter (bi.s)
- Documentation (sysmap symbol table)

#### **The Resurrection Project**

Warren Toomey and the **Unix Heritage Society (TUHS)** undertook a remarkable project:

1. **Scan** the 190 pages of printouts
2. **OCR** (Optical Character Recognition) the assembly code
3. **Manually correct** OCR errors
4. **Reconstruct** the exact file structure
5. **Cross-assemble** the code to verify correctness
6. **Run** the resulting system in a PDP-7 simulator

The **pdp7-unix project** successfully booted PDP-7 Unix from these scanned printouts. The operating system that Thompson wrote in 1969 runs again today—more than 50 years later.

### What This Repository Represents

The `unix-history-repo` repository you're reading about contains:

**Git Commit Structure**:
```
185f8e8 - Empty repository at start of Unix Epoch (1970-01-01)
68ed7b9 - Add licenses and README (2021-01-01)
c7f751f - Start development on Research PDP7 (1970-06-30) [merge]
16fdb21 - Research PDP7 development (1970-06-30) [40 FILES]
```

The dates are symbolic:
- **January 1, 1970** = Unix Epoch (time_t = 0, the beginning of Unix time)
- **June 30, 1970** = Approximate date of PDP-7 Unix completion

The files represent Unix as it existed in mid-1970, before Unix was rewritten in C, before it ran on the PDP-11, before it became the foundation of the modern computing world.

## Why This Code Matters

### Historical Significance

This code represents:

1. **First Unix**: The original implementation by Thompson and Ritchie
2. **Last assembly Unix**: All later versions were rewritten in C
3. **Design principles**: Core Unix concepts in their purest form
4. **Proof of concept**: Demonstrated that a small team could build a complete OS
5. **Foundation**: Direct ancestor of Linux, BSD, macOS, iOS, Android

### Technical Significance

The PDP-7 Unix demonstrated several revolutionary concepts:

#### **1. Hierarchical File System**

Before Unix, most systems had flat file structures. Unix introduced:

- **Directories** as special files containing name-to-inode mappings
- **Hierarchical organization** with `/` root directory
- **Path-based navigation** (added in later PDP-7 versions)
- **Unified namespace** treating devices as files

```assembly
" Directory entry structure (from s8.s)
" d.i    - inode number (1 word)
" d.name - filename (4 words, 3 chars/word)
" d.uniq - unique ID (1 word)
" Total: 6 words per directory entry
```

#### **2. Process Abstraction**

Unix provided clean process primitives:

- **fork()** - Create child process (copy of parent)
- **exit()** - Terminate process
- **Interprocess communication** via message passing (smes/rmes)

This process model persists in Unix and Linux today:

```assembly
" Process creation (from s3.s)
.fork:
   lac procmax         " Get maximum process number
   dac i u.namep       " Store as new process ID
   " ... create new process table entry
   " ... copy parent's memory to disk
   " ... set up child's state
```

#### **3. Simple but Complete I/O Model**

Unix unified file and device I/O:

- Same system calls (read/write) for files and devices
- Character devices handled through queue abstraction
- Block devices (disk) accessed through buffer cache

```assembly
" Reading from file or device uses same interface
sys read; buffer; count
```

#### **4. Minimalist Design Philosophy**

The entire PDP-7 Unix consists of:

| Component | Lines of Code |
|-----------|---------------|
| Kernel (s1-s9) | ~2,500 |
| Utilities | ~2,500 |
| Development tools | ~3,000 |
| **Total** | **~8,000** |

Compare this to modern systems:
- Linux kernel: ~30 million lines
- Windows: ~50 million lines

Yet PDP-7 Unix was a complete, self-hosting operating system.

### Cultural Impact

Unix introduced cultural practices that shaped software development:

#### **Open Development**

While not "open source" in the modern sense, Unix spread through:
- Academic licenses (universities could get source code)
- Source code included with distributions
- Collaborative development culture

#### **Documentation Philosophy**

The concept of **manual pages** (man pages) started with Unix:
- One page per command
- Standard format (NAME, SYNOPSIS, DESCRIPTION)
- Comprehensive reference always available

#### **Tool Composition**

The Unix philosophy of **small tools composed via pipes** emerged from this era:
```bash
# Modern example of Unix philosophy
cat file.txt | grep "error" | sort | uniq | wc -l
```

Though pipes came in later PDP-11 versions, the principle of small, focused tools originated with PDP-7 Unix.

## The Evolution Path

### From PDP-7 to PDP-11

By 1971, Bell Labs acquired a **PDP-11/20**, a more capable machine:

- **16-bit words** (more conventional than 18-bit)
- **Byte addressing** (8-bit bytes)
- **More memory** (up to 256 KB)
- **Better performance**

Thompson and Ritchie rewrote Unix in PDP-11 assembly, improving and extending it. This became **Unix Version 1** (V1), released in 1971.

### The Invention of C

In 1972, Dennis Ritchie created the **C programming language**, evolving it from:

- **B language** (Ken Thompson, 1969) - untyped, interpreted
- **BCPL** (Martin Richards, 1966) - systems programming language

By 1973, Unix was **rewritten in C**—an unprecedented achievement. Operating systems were written in assembly; using a high-level language was considered impractical. But C was designed specifically to be efficient enough for systems programming.

This decision made Unix **portable**. Instead of rewriting the entire system for each new computer, only the small machine-dependent parts needed to change. Unix could—and did—run on dozens of different architectures.

### The Explosive Growth

From PDP-7 Unix's humble beginning, Unix spread rapidly:

- **1970s**: Research Unix (V1-V7), BSD Unix at UC Berkeley
- **1980s**: System V (AT&T), SunOS, HP-UX, AIX
- **1990s**: Linux (Linus Torvalds), FreeBSD, NetBSD, OpenBSD
- **2000s**: Mac OS X (based on BSD), Android (Linux kernel)
- **2020s**: Unix and Unix-like systems power the vast majority of servers, smartphones, and embedded devices

## Reading This Book in Context

### What You'll Learn

This comprehensive reference will teach you:

1. **How an operating system actually works** - Not abstract theory, but concrete implementation
2. **Assembly language programming** - PDP-7 assembly in detail
3. **Historical computing** - How programmers worked with severe constraints
4. **System design principles** - Lessons that remain relevant today
5. **Software archaeology** - How to read and understand legacy code

### What Makes This Code Special

Unlike learning from modern systems:

- **Small enough to understand completely** - 8,000 lines vs. millions
- **No abstractions hiding complexity** - Direct hardware access throughout
- **Every line serves a purpose** - No cruft, no legacy compatibility layers
- **Elegant simplicity** - Core concepts without decades of additions

### The Challenge and the Reward

Reading 1960s assembly code is challenging:

- **Octal arithmetic** instead of decimal or hexadecimal
- **18-bit words** instead of bytes
- **Minimal comments** (Ken Thompson was famously terse)
- **Archaic syntax** and conventions

But the reward is profound understanding. By the time you finish this book, you will understand:

- How a computer boots from nothing
- How files are stored and retrieved
- How processes are created and scheduled
- How programs are assembled and executed
- How a complete operating system fits in 8,000 lines of code

## Document Structure

This reference is organized as follows:

### Part I: Foundations (Chapters 1-4)

**Chapter 1** (this chapter) - Historical context and introduction
**Chapter 2** - PDP-7 hardware architecture in detail
**Chapter 3** - Assembly language programming guide
**Chapter 4** - System architecture overview

### Part II: The Kernel (Chapters 5-9)

**Chapter 5** - Kernel internals (s1.s through s9.s)
**Chapter 6** - Boot process and initialization
**Chapter 7** - File system implementation
**Chapter 8** - Process management
**Chapter 9** - Device drivers and I/O

### Part III: User Space (Chapters 10-12)

**Chapter 10** - Development tools (assembler, editor, debugger)
**Chapter 11** - User utilities (cat, cp, chmod, etc.)
**Chapter 12** - The B language system

### Part IV: Analysis and Legacy (Chapters 13-14)

**Chapter 13** - Code evolution and development patterns
**Chapter 14** - Legacy and impact on modern systems

### Appendices

**Appendix A** - Complete instruction set reference
**Appendix B** - System call reference
**Appendix C** - Symbol table (sysmap)
**Appendix D** - Glossary of terms
**Appendix E** - Index
**Appendix F** - Bibliography and references
**Appendix G** - Complete source code listings

## Begin Your Journey

You are about to explore one of computing's greatest treasures—the source code that started the Unix revolution. Whether you're a student, professional programmer, computer historian, or simply curious, this journey will deepen your understanding of how computers really work.

In the following chapters, we'll examine every line of code, every system call, every clever optimization. We'll see how Thompson and Ritchie achieved the seemingly impossible: a complete, self-hosting operating system in just 8,000 lines of assembly code.

Welcome to the genesis of Unix.

---

*"Unix is simple and coherent, but it takes a genius (or at any rate a programmer) to understand and appreciate the simplicity."*
— Dennis Ritchie, 1984
