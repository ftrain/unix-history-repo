# Chapter 14: Legacy and Impact — How 8,000 Lines Changed the World

*"Unix is simple and coherent, but it takes a genius (or at any rate a programmer) to understand and appreciate the simplicity."*
— Dennis Ritchie, 1984

In the summer of 1969, Ken Thompson sat down at an obsolete PDP-7 minicomputer and wrote approximately 8,000 lines of assembly code. That code became Unix. What happened next is one of the most remarkable stories in the history of technology—a tale of how elegant design, simple principles, and the right ideas at the right time can reshape the entire world.

Today, more than 55 years later, the descendants of that PDP-7 code run on billions of devices. They power the servers behind every major website, the smartphones in our pockets, the supercomputers advancing science, and the embedded systems controlling everything from cars to spacecraft. Unix didn't just succeed—it became the invisible foundation of modern computing.

This chapter traces that extraordinary journey.

## 14.1 From PDP-7 to World Domination

### The PDP-11 Port (1970-1971)

#### Why Move to PDP-11?

By late 1970, PDP-7 Unix had proven its worth. The system was self-hosting, complete, and remarkably productive to use. But the PDP-7's limitations were becoming painful:

**PDP-7 Constraints:**
- **8K words** (16 KB) of memory—barely enough for kernel + one user
- **18-bit architecture**—incompatible with emerging industry standards
- **DECtape storage**—slow and limited capacity
- **Obsolete hardware**—introduced in 1964, already ancient by 1970
- **No memory protection**—dangerous for multi-user systems

The solution arrived in early 1971: Bell Labs acquired a **PDP-11/20**, a much more capable machine:

```
PDP-7 vs. PDP-11 Comparison:

Specification       PDP-7 (1964)      PDP-11/20 (1970)    Improvement
─────────────────────────────────────────────────────────────────────
Word size           18-bit            16-bit              Industry std.
Addressable memory  8K words (16KB)   256KB               16x larger
Memory protection   None              MMU available       Multi-user safe
Mass storage        DECtape (144KB)   RK05 disk (2.4MB)   17x capacity
Character encoding  9-bit/char        8-bit ASCII         Standards-based
Price               $72,000 (1965)    $10,800 (1970)      Much cheaper
Performance         ~1.75μs cycle     ~1.2μs cycle        Faster
```

The PDP-11 represented a new generation of minicomputers. With its orthogonal instruction set, general-purpose registers, and byte-addressable memory, it was far more programmer-friendly than the PDP-7.

#### The Assembly Rewrite

In 1971, Thompson and Ritchie rewrote Unix entirely for the PDP-11. This was not a simple port—it was a ground-up redesign that preserved the concepts while improving the implementation.

**What Changed:**

1. **Byte-oriented architecture**: Files measured in bytes, not 18-bit words
2. **Larger address space**: Full file system, multiple simultaneous users
3. **Memory protection**: Kernel/user separation via PDP-11 MMU
4. **Improved I/O**: Better device support, including RK05 disk
5. **Performance**: Faster execution, more responsive interaction

**What Stayed the Same:**

1. **Hierarchical file system**: Still based on inodes and directory entries
2. **Process model**: Fork/exec paradigm unchanged
3. **System call interface**: Similar API, adapted to new architecture
4. **Design philosophy**: Simplicity, orthogonality, tool composition
5. **Development tools**: Editor, assembler, shell preserved and enhanced

The PDP-11 version became **Unix Version 1 (V1)**, released internally at Bell Labs in November 1971. The famous **Unix Programmer's Manual** accompanied it—the first formal documentation of the system.

#### Industry Context: The Minicomputer Revolution

The timing was perfect. The early 1970s saw the **minicomputer revolution**:

**The Market Shift:**
- **1960s**: Computing dominated by mainframes (IBM, UNIVAC)
- **1970s**: Minicomputers democratize computing (DEC, Data General, HP)
- **Cost reduction**: From millions to tens of thousands of dollars
- **Direct access**: Interactive use replacing batch processing
- **Departmental computing**: Each research group could own a computer

DEC's PDP series led this revolution. Unix rode that wave, becoming the operating system of choice for research and development. Where mainframes ran proprietary operating systems tailored to commercial data processing, minicomputers needed flexible systems for technical computing—exactly Unix's strength.

### The Invention of C (1972)

#### Why a New Language?

By 1972, Unix was running successfully on the PDP-11, but it had a problem: it was written entirely in PDP-11 assembly language. Thompson recognized that:

1. **Assembly was non-portable**: Every new architecture required complete rewrite
2. **Assembly was error-prone**: No type checking, easy to create bugs
3. **Assembly was hard to maintain**: Difficult to understand and modify
4. **Assembly was limiting**: High-level abstractions needed

Thompson had already experimented with higher-level languages. In 1969, he had created **B**, an interpreted language based on Martin Richards' **BCPL** (Basic Combined Programming Language). B was elegant but had limitations:

**B Language Characteristics:**
- **Typeless**: Everything was a word, no distinction between pointers and integers
- **Interpreted**: Slow execution via bytecode interpreter
- **Word-oriented**: Assumed word addressing, not byte addressing
- **Compact**: Could run in small memory spaces

B worked on the word-addressed PDP-7 but struggled with the byte-addressed PDP-11. The PDP-11 could address individual bytes, but B treated everything as words.

#### How PDP-7 Unix Influenced C's Design

Dennis Ritchie took over B's evolution, creating **NB** (New B) and eventually **C**. The language was designed specifically to write Unix:

**C's Design Principles (Derived from Unix Experience):**

1. **Close to the machine**: Direct hardware access when needed
2. **Efficient**: Performance comparable to assembly
3. **Portable**: Abstract enough to move between architectures
4. **Systems-oriented**: Support for low-level operations
5. **Simple**: Small language, easy to implement compiler

**Key C Features Driven by Unix Needs:**

```c
/* Pointers - direct memory access like assembly */
char *ptr = &buffer[0];
*ptr = 'A';

/* Structures - organize kernel data structures */
struct inode {
    int i_mode;      /* file type and permissions */
    char i_nlink;    /* number of links */
    char i_uid;      /* user ID */
    char i_gid;      /* group ID */
    int i_size0;     /* size (high byte) */
    int i_size1;     /* size (low bytes) */
    int i_addr[8];   /* block addresses */
    int i_atime[2];  /* access time */
    int i_mtime[2];  /* modification time */
};

/* Bit manipulation - device register access */
#define DONE 0200    /* device done bit */
if (status & DONE) {
    /* device ready */
}

/* Low-level I/O - system call interface */
int fd = open("/tmp/file", 0);
read(fd, buffer, 512);
close(fd);
```

C gave programmers the **power of assembly** with the **abstraction of high-level languages**. It was revolutionary.

#### The Portable Unix Rewrite (1973)

In 1973, Ritchie and Thompson made a bold decision: **rewrite Unix in C**. This was unprecedented. Operating systems were always written in assembly language. High-level languages were for applications, not kernels.

**The Skeptics Said:**
- "Too slow—systems need assembly for performance"
- "Too large—compiled code will bloat the kernel"
- "Too risky—unproven for systems programming"
- "Too abstract—can't access hardware from high-level language"

**Thompson and Ritchie Proved Them Wrong:**

The C rewrite succeeded brilliantly. By late 1973, **Unix Version 4** was running in C. About 90% of the kernel was C, with only the most hardware-dependent parts in assembly.

**The Results:**
- **Performance**: Nearly as fast as assembly (clever compiler, efficient design)
- **Size**: Slightly larger but still compact
- **Portability**: Unix could move to new machines in months, not years
- **Maintainability**: Much easier to understand and modify
- **Influence**: Proved high-level languages viable for systems programming

**Code Comparison - Same Function in Assembly vs. C:**

PDP-7 Assembly (from s8.s):
```assembly
" namei - convert pathname to inode
namei: 0
   lac u.namep
   dac t
   law dbuf
   dac t+1
1:
   lac t i
   sna
   jmp 2f
   lmq
   lac t i
   dac t+1 i
   isz t+1
   lac t i
   dac t+1 i
   isz t+1
   -3
   tad t+1
   dac t+1
   jmp 1b
2:
   " ... continued for many more lines
```

Unix V6 C (1975):
```c
/* namei - convert pathname to inode */
struct inode *namei(path)
char *path;
{
    struct inode *dp;
    char *cp;
    int c;

    dp = rootdir;
    while (c = *path++) {
        /* search directory for component */
        if ((c = dirlook(dp, path)) == 0)
            return NULL;
        dp = iget(c);
    }
    return dp;
}
```

The difference is striking. The C version is **readable, maintainable, and portable**. This single decision—writing an OS in a high-level language—changed the industry forever.

#### Revolutionary: OS in High-Level Language

The C rewrite made Unix **portable**. Instead of supporting only PDP-11, Unix could run on:

**Early Ports:**
- **Interdata 8/32** (1977) - First port to non-DEC hardware
- **IBM 360** (1977) - Mainframe Unix
- **VAX-11/780** (1978) - 32-bit Unix (Unix/32V)

Each port took months instead of years. The pattern was:
1. Port the C compiler to new architecture
2. Recompile Unix kernel with new compiler
3. Port small amount of assembly-language code
4. Debug and optimize

This portability made Unix **inevitable**. Any computer manufacturer wanting a modern OS could license Unix and have it running quickly. The alternative—writing an OS from scratch—took years and cost millions.

### Research Unix Evolution (1971-1979)

The 1970s saw rapid Unix evolution at Bell Labs. Each **Research Unix** version added features while maintaining the core simplicity:

```
Unix Version Timeline (Research Editions):

Version   Date      Key Features
──────────────────────────────────────────────────────────────────────────
V1        1971-11   First PDP-11 Unix
                    - Hierarchical file system
                    - fork() and exec()
                    - Basic shell
                    - ~4,500 lines of assembly

V2        1972-06   Multiple processes
                    - Improved file system
                    - Pipes (!!)
                    - More utilities

V3        1973-02   Mostly C rewrite begins
                    - C compiler included
                    - Improved shell (glob patterns)

V4        1973-11   First C-based Unix
                    - ~90% written in C
                    - Performance equal to assembly
                    - Pipes fully integrated

V5        1974-06   Widespread distribution begins
                    - Improved reliability
                    - More utilities
                    - Documentation improved

V6        1975-05   First widely distributed version
                    - ~9,000 lines of C kernel code
                    - "Lions' Commentary" based on V6
                    - Academic licenses available
                    - Source code to universities: $200

V7        1979-01   The classic Unix
                    - Bourne shell (sh)
                    - Awk, sed, make
                    - Improved file system
                    - Port to VAX (32-bit)
                    - "The Unix Programming Environment"
                    - Influenced POSIX standard
```

#### The Pipe: Unix's Killer Feature

**Unix Version 2 (1972)** introduced **pipes**, one of the most influential features in computing history:

```bash
# List all .txt files, sort by name, show first 10
ls *.txt | sort | head -10

# Count unique error messages in log
grep ERROR logfile | sort | uniq -c

# Find largest files in directory tree
du -a | sort -n | tail -20
```

**Before pipes:**
```bash
# Without pipes, you needed temporary files:
ls > tempfile1
sort tempfile1 > tempfile2
head -10 tempfile2
rm tempfile1 tempfile2
```

**After pipes:**
```bash
ls | sort | head -10
```

Pipes embodied the Unix philosophy: **small tools, composed together, each doing one thing well**. This simple idea transformed how programmers think about building software.

**Pipe Implementation (Unix V6 C code):**
```c
/* Create a pipe - returns two file descriptors */
pipe()
{
    struct inode *ip;
    int r[2];     /* reader and writer file descriptors */

    ip = ialloc();           /* allocate inode for pipe */
    ip->i_mode = IPIPE;      /* mark as pipe */
    r[0] = ufalloc();        /* allocate reader fd */
    u.u_ofile[r[0]] = ip;    /* connect to inode */
    r[1] = ufalloc();        /* allocate writer fd */
    u.u_ofile[r[1]] = ip;    /* connect to inode */

    u.u_ar0[R0] = r[0];      /* return reader */
    u.u_ar0[R1] = r[1];      /* return writer */
}
```

Compare to PDP-7 Unix, which had **message passing** (smes/rmes) but not pipes. Pipes were the evolution of that idea into something more general and powerful.

#### The Programmer's Workbench

Unix became the preferred environment for software development. By the mid-1970s, Bell Labs researchers were using Unix for all their work. The **Programmer's Workbench (PWB)** variant of Unix added:

- **Source Code Control System (SCCS)**: Version control
- **Make**: Automated builds
- **Lex and Yacc**: Parser generators
- **Lint**: C code checker
- **Prof**: Performance profiler

These tools set the standard for software development environments that persists today.

#### Spreading Through Academia

**Unix Version 6 (1975)** became widely available to universities through **academic licenses**. For $200, a university could get:
- Complete source code
- Documentation
- Right to modify and share among universities

This openness was revolutionary. Students and researchers could:
- **Study the code**: Learn OS internals from real implementation
- **Modify the system**: Experiment with new ideas
- **Share improvements**: Collaborate across universities

**John Lions' Commentary on Unix V6** (1977) became the most photocopied computer science text in history. It presented the entire Unix kernel with line-by-line commentary—a complete education in operating systems.

**Impact on Computer Science Education:**

Universities using Unix by 1979:
- University of California, Berkeley
- MIT
- Carnegie Mellon
- Stanford
- Harvard
- University of Toronto
- University of New South Wales (Australia)
- And hundreds more...

An entire generation of computer scientists learned operating systems by reading and modifying Unix code. When they graduated, they brought Unix philosophy to industry.

## 14.2 The Unix Family Tree

Unix didn't evolve linearly—it branched into a rich family tree. Two main branches dominated: **BSD Unix** (academic, open) and **System V** (commercial, standardized).

```
                        The Unix Family Tree

                    PDP-7 Unix (1969)
                           |
                    PDP-11 Unix (1971)
                           |
                    Research Unix V1-V7
                    /                  \
                   /                    \
          BSD Unix (1977)          System V (1983)
         /    |     \                    |
        /     |      \                   |
   FreeBSD OpenBSD NetBSD           SVR4 (1988)
      |       |       |              /   |   \
   Darwin  Security  Embedded    Solaris AIX HP-UX
      |
   macOS/iOS
      |
   2+ billion                         Linux (1991)
   devices                               |
                                    Everywhere
                                    (servers, Android,
                                     embedded, cloud)
```

### BSD Unix (1977-1995)

#### UC Berkeley's Contributions

The **Berkeley Software Distribution** began in 1977 when graduate student **Bill Joy** started distributing Unix enhancements from UC Berkeley. BSD became the most influential Unix variant, introducing:

**Major BSD Innovations:**

**1. Networking (1983)** - TCP/IP Implementation
```c
/* BSD socket API - became the standard for network programming */
int sockfd = socket(AF_INET, SOCK_STREAM, 0);
struct sockaddr_in addr;
addr.sin_family = AF_INET;
addr.sin_port = htons(80);
addr.sin_addr.s_addr = inet_addr("192.168.1.1");
connect(sockfd, (struct sockaddr*)&addr, sizeof(addr));
```

The BSD socket API became the universal interface for network programming, used in every modern OS.

**2. Virtual Memory (1980)** - 4.1BSD
- Demand paging: Load code only when needed
- Memory-mapped files: Access files as memory
- Copy-on-write fork(): Efficient process creation

**3. Job Control (1978)** - Background/foreground processes
```bash
# Run command in background
$ long_process &
[1] 1234

# Suspend current job
$ ^Z
[1]+  Stopped    long_process

# Resume in foreground
$ fg
long_process
```

**4. C Shell (csh)** - Bill Joy, 1978
- History mechanism: `!command`
- Aliases: `alias ll='ls -l'`
- Job control built-in
- C-like syntax

**5. Vi Editor** - Bill Joy, 1976
```
Still used today (vim, neovim)
Influenced: Emacs keybindings, modern editors
```

**6. Fast File System** - McKusick, 1983
- Cylinder groups: Cluster related data
- Larger block sizes: Better performance
- Symbolic links: Flexible file references

#### The Berkeley Software Distribution Legacy

BSD releases transformed Unix from research project to production system:

```
BSD Release History:

Version   Date      Significance
────────────────────────────────────────────────────────────────────
1BSD      1977      Pascal system, ex editor
2BSD      1978      C shell, vi editor, job control
3BSD      1979      Virtual memory support
4.0BSD    1980      Rewritten virtual memory system
4.1BSD    1981      Performance improvements
4.2BSD    1983      TCP/IP networking, Fast File System
4.3BSD    1986      Improved performance, stability
4.4BSD    1993      Final release, fully free code
```

**BSD's Commercial Impact:**

Companies built on BSD:
- **Sun Microsystems** (SunOS): Workstation revolution
- **DEC** (Ultrix): VAX Unix
- **Microsoft** (Xenix): Yes, Microsoft sold Unix!
- **NeXT** (NeXTSTEP): Steve Jobs' company
- **Apple** (Darwin/macOS): BSD-based OS

### System V (1983-1992)

#### AT&T's Commercial Unix

While BSD flourished in academia, AT&T developed **Unix System V** as a commercial product:

**System V Release History:**

```
SVR1    1983    First commercial release
SVR2    1984    Improved utilities, security
SVR3    1987    STREAMS, TLI networking
SVR4    1988    Unified BSD + System V features
                (Solaris, AIX, HP-UX based on SVR4)
```

**System V Contributions:**

1. **STREAMS**: Modular I/O system
2. **Shared libraries**: Reduce memory usage
3. **TLI (Transport Layer Interface)**: Alternative to sockets
4. **Vi improvements**: Enhanced vi editor
5. **System administration**: sysadm, admin tools

#### The "Unix Wars" (1988-1993)

The late 1980s saw the **Unix Wars**—competing standards, incompatible versions, fragmentation:

**The Conflict:**
- **AT&T**: System V, commercial licensing
- **Berkeley**: BSD, academic/free
- **Vendors**: Each with proprietary extensions
- **Result**: Incompatible Unix versions, customer confusion

**Standard Battles:**
- **POSIX** (IEEE): Attempted portable OS interface
- **X/Open**: Vendor consortium for standards
- **OSF/1** (Open Software Foundation): Anti-AT&T consortium
- **UI** (Unix International): Pro-AT&T consortium

The wars hurt Unix commercially. Customers didn't know which Unix to choose. Microsoft capitalized on this confusion, promoting Windows NT as a stable alternative.

#### SVR4: The Unification (1988)

**System V Release 4** attempted to end the wars by unifying BSD and System V:

**SVR4 Merged:**
- System V base
- BSD networking (TCP/IP, sockets)
- BSD file system features
- SunOS features
- Xenix features

**Major SVR4 Descendants:**
- **Solaris** (Sun Microsystems): Dominant commercial Unix
- **AIX** (IBM): Mainframe and server Unix
- **HP-UX** (Hewlett-Packard): Enterprise Unix
- **IRIX** (Silicon Graphics): Graphics workstation OS

These commercial Unix systems powered the internet boom of the 1990s and still run critical enterprise systems today.

### The Open Source Revolution

While commercial Unix fragmented, a new movement emerged: **free, open-source Unix**.

#### Linux (1991-present)

In 1991, a Finnish computer science student named **Linus Torvalds** posted to comp.os.minix newsgroup:

> *"I'm doing a (free) operating system (just a hobby, won't be big and professional like gnu) for 386(486) AT clones."*

That "hobby" became **Linux**, the most successful software project in history.

**Linux Timeline:**

```
1991-08   Linus announces Linux 0.01
          - 10,000 lines of C code
          - Runs on i386
          - Basic process management, file system

1991-10   Linux 0.02 released
          - Can run bash and gcc
          - GPL licensed

1992      First Linux distributions
          - MCC Interim
          - Softlanding Linux System (SLS)

1993      Slackware, Debian founded
          - Package management
          - Easier installation

1994      Linux 1.0 released
          - 176,250 lines of code
          - Stable, production-ready

1996      Linux 2.0
          - SMP (multiple CPUs)
          - 64-bit architectures

1998      Enterprise adoption begins
          - Oracle, IBM support Linux
          - Major companies migrate

2001      Linux 2.4
          - Enterprise features
          - Improved scalability

2011      Linux 3.0
          - ~15 million lines of code

2025      Linux 6.x
          - ~30+ million lines of code
          - Powers most of the internet
```

**Why Linux Succeeded:**

1. **Free**: $0 cost, no licensing restrictions
2. **Open source**: Complete source code available
3. **Unix-compatible**: Familiar to Unix users
4. **PC-based**: Ran on inexpensive x86 hardware
5. **Internet-ready**: Perfect timing for web era
6. **Community-driven**: Thousands of contributors
7. **Vendor-neutral**: Not controlled by one company

#### How PDP-7 Concepts Survive in Linux

Despite 30+ million lines of modern code, Linux preserves PDP-7 Unix's core concepts:

**1. File System Structure**

PDP-7 Unix (1969):
```assembly
" inode structure (from s8.s)
" i.flgs:  flags (directory, special file, etc.)
" i.nlks:  number of links
" i.uid:   user id
" i.size:  size in words
" i.addr:  block addresses (8 words)
" i.actime: access time
" i.modtime: modification time
```

Linux (2025):
```c
/* include/linux/fs.h */
struct inode {
    umode_t         i_mode;      /* file type and permissions */
    unsigned short  i_opflags;   /* flags */
    kuid_t          i_uid;       /* user id */
    kgid_t          i_gid;       /* group id */
    unsigned int    i_flags;     /* filesystem flags */
    loff_t          i_size;      /* file size in bytes */
    struct timespec i_atime;     /* access time */
    struct timespec i_mtime;     /* modification time */
    struct timespec i_ctime;     /* change time */
    union {
        struct block_device *i_bdev;  /* block device */
        struct cdev *i_cdev;          /* character device */
    };
    /* ... many more fields for modern features */
};
```

**The continuity is remarkable**: 55+ years later, Linux still uses inodes with user IDs, sizes, timestamps, and block addresses. The structure grew larger, but the core concept is Thompson's PDP-7 design.

**2. Process Fork Model**

PDP-7 Unix (1969):
```assembly
.fork:
   jms lookfor; 0      " find empty process slot
      skp
      jms error         " error if no slot
   dac 9f+t
   isz uniqpid          " increment unique process ID
   lac uniqpid
   dac u.ac             " store as child's PID
   " ... copy parent's memory
   " ... set up child's state
```

Linux (2025):
```c
/* kernel/fork.c - simplified */
long do_fork(unsigned long clone_flags,
             unsigned long stack_start,
             unsigned long stack_size,
             int __user *parent_tidptr,
             int __user *child_tidptr)
{
    struct task_struct *p;
    int pid;

    /* Allocate new process descriptor */
    p = copy_process(clone_flags, stack_start, stack_size,
                     parent_tidptr, child_tidptr);

    /* Assign PID */
    pid = get_task_pid(p, PIDTYPE_PID);

    /* Wake up new process */
    wake_up_new_task(p);

    return pid;
}
```

Same fundamental idea: allocate process structure, assign PID, copy parent state, return to both parent and child. Linux's version handles threads, namespaces, and modern features, but the core fork() model is unchanged from 1969.

**3. System Calls**

PDP-7 Unix had 26 system calls:
```
0 = rele (release held core)
1 = fork (create process)
2 = read (read file)
3 = write (write file)
4 = open (open file)
5 = close (close file)
6 = wait (wait for child)
7 = creat (create file)
... (18 more)
```

Linux (2025) has 300+ system calls, but the original 26 are still there:

```c
/* arch/x86/entry/syscalls/syscall_64.tbl */
0   read    sys_read           /* PDP-7: sys read */
1   write   sys_write          /* PDP-7: sys write */
2   open    sys_open           /* PDP-7: sys open */
3   close   sys_close          /* PDP-7: sys close */
...
57  fork    sys_fork           /* PDP-7: sys fork */
```

**Same names, same numbers (mostly), same behavior**. Code written for Unix V6 (1975) can still compile and run on Linux (2025) with minimal changes.

**4. "Everything is a File"**

PDP-7 Unix treated devices as files:
```assembly
" Read from file or device - same interface
lac u.fofp      " get file descriptor
" ... read from file or device based on inode flags
```

Linux (2025):
```bash
# Still true 55+ years later:
$ cat /dev/urandom | head -c 16 | xxd
00000000: 8f3a 2e91 c872 b54a 9c0d e8f3 2a11 5ac7  .:...r.J....*.Z.

$ echo "test" > /dev/null   # Null device, like PDP-7

$ cat /proc/cpuinfo          # Even /proc is a file!
```

#### BSD Descendants: The BSD License Legacy

While Linux used GPL, the BSD family used the **BSD license** (later ISC, MIT-style licenses):

**BSD License:**
```
Permission is granted to use, copy, modify, and distribute this software
for any purpose with or without fee, provided that the above copyright
notice and this permission notice appear in all copies.
```

This permissive license allowed **commercial use without restrictions**. Companies could take BSD code, modify it, and ship proprietary products. This strategy led to massive BSD adoption:

**FreeBSD (1993-present)**
- Focus: Performance, advanced networking
- Users: Netflix, WhatsApp, Sony PlayStation
- Impact: Powers massive CDN infrastructure

**OpenBSD (1996-present)**
- Focus: Security, code correctness
- Contributions: OpenSSH (universal), LibreSSL, httpd
- Philosophy: "Only two remote holes in the default install, in a heck of a long time!"

**NetBSD (1993-present)**
- Focus: Portability
- Platforms: 57+ different architectures
- Motto: "Of course it runs NetBSD"

**Darwin/macOS (2000-present)**
- Apple's BSD-based OS
- XNU kernel: Mach + BSD
- Unified iOS, macOS, tvOS, watchOS
- **2+ billion active devices**

### The Mobile Era: Unix in Your Pocket

The 2000s brought Unix to mobile devices:

**iOS (2007)**
```
Based on: Darwin (BSD-derived)
Kernel: XNU (Mach microkernel + BSD)
Devices: iPhone, iPad, Apple Watch, Apple TV
Market: 2+ billion active devices
Unix concepts: Processes, file system, security model
```

**Android (2008)**
```
Based on: Linux kernel
Userland: Modified GNU/Linux tools + Dalvik/ART
Devices: Smartphones, tablets, TVs, cars
Market: 3+ billion active devices
Unix concepts: Full Linux kernel with mobile optimizations
```

**The Numbers:**
- **5+ billion smartphones** run Unix-derived operating systems
- Every iPhone traces ancestry to PDP-7 Unix via BSD
- Every Android traces ancestry to PDP-7 Unix via Linux
- **Every smartphone user is a Unix user**

## 14.3 Unix Concepts in Modern Systems

### Ubiquitous Ideas from PDP-7 Unix

Some PDP-7 concepts are so fundamental they appear in every modern OS:

#### 1. Hierarchical File System

**PDP-7 Unix (1969):**
```
/
├── bin/      (binaries)
├── dev/      (devices)
├── etc/      (configuration)
├── tmp/      (temporary)
└── usr/      (user files)
```

**Linux/macOS (2025):**
```
/
├── bin/      (binaries)
├── dev/      (devices)
├── etc/      (configuration)
├── home/     (user directories)
├── proc/     (process info)
├── sys/      (system info)
├── tmp/      (temporary)
├── usr/      (user programs)
└── var/      (variable data)
```

**Windows** even adopted this (sort of):
```
C:\
├── Program Files\
├── Users\
├── Windows\
└── ...
```

#### 2. Process Fork/Exec Model

Every modern OS uses fork/exec or equivalent:

**PDP-7 Pattern:**
```assembly
" Fork child, exec new program
sys fork
   br parentcode   " parent continues here
   " child continues here
   sys exec; program; args
```

**Linux C (2025):**
```c
/* Same pattern, 55 years later */
pid_t pid = fork();
if (pid == 0) {
    /* child */
    execve("/bin/program", argv, envp);
} else {
    /* parent */
    wait(&status);
}
```

**Windows** uses different API but same concept:
```c
CreateProcess("program.exe", args, ...);  /* fork + exec combined */
WaitForSingleObject(hProcess, INFINITE);  /* wait */
```

#### 3. Shell as Separate Program

**PDP-7 Philosophy:**
- Shell is just a user program
- Not part of kernel
- Can be replaced with custom shell

**Modern Reality:**
- bash, zsh, fish, PowerShell—all user programs
- Kernel doesn't care which shell you use
- Multiple shells can coexist

#### 4. Text-Based Tools

**PDP-7 Unix Tools:**
```
cat, cp, mv, rm, ls, ed, as, chmod, chown
```

**Modern Unix Tools (virtually identical):**
```bash
$ cat file.txt           # Same command, 55 years later
$ cp source dest         # Same command
$ ls -l                  # Same command
$ chmod 755 script.sh    # Same command
```

**Tool Composition:**

PDP-7 concept (realized in V2 with pipes):
```
Small tools → compose via pipes → complex operations
```

Modern reality:
```bash
# Process web server logs
cat access.log |
    grep "404" |
    awk '{print $7}' |
    sort |
    uniq -c |
    sort -nr |
    head -10
```

### Modern Implementations: What's the Same, What Evolved

#### How Linux Implements fork() Today

**PDP-7 fork() (simplified):**
```assembly
.fork:
   " 1. Find empty process slot
   jms lookfor; 0

   " 2. Assign new PID
   isz uniqpid
   lac uniqpid
   dac u.ac

   " 3. Copy parent memory to disk
   jms save

   " 4. Set up child state
   " (child starts after fork instruction)

   " 5. Return to parent (child PID in AC)
   "    and to child (0 in AC)
```

**Linux fork() (simplified):**
```c
long do_fork(unsigned long clone_flags, ...)
{
    struct task_struct *p;
    int pid;

    /* 1. Allocate child process descriptor */
    p = alloc_task_struct();

    /* 2. Copy parent's task_struct to child */
    copy_process(current, p);

    /* 3. Allocate new PID */
    pid = alloc_pidmap();

    /* 4. Copy-on-write memory setup */
    /*    DON'T actually copy - share pages,
          mark read-only, copy on first write */
    copy_mm(clone_flags, p);

    /* 5. Set child's return value to 0 */
    /*    Parent's return value is child PID */
    p->thread.ax = 0;  /* child returns 0 */

    /* 6. Add to scheduler */
    wake_up_new_task(p);

    return pid;  /* parent returns child PID */
}
```

**Key Evolution:**
- **Copy-on-write**: Don't copy memory until needed (PDP-7 copied everything)
- **Threads**: clone() supports threads (shared memory)
- **Namespaces**: Isolated process trees (containers)
- **cgroups**: Resource limits per process group

But the **fundamental model is identical**: fork creates child as copy of parent, returns twice (parent gets child PID, child gets 0).

#### Modern File Systems vs. PDP-7

**PDP-7 File System:**
```
- 16-bit inode numbers (65,536 max files)
- 8 direct block pointers per inode
- No indirect blocks
- No symbolic links
- Simple directory structure (name → inode)
- 512-word blocks (1,152 bytes)
```

**ext4 (Linux) File System:**
```
- 32-bit inode numbers (4 billion+ files)
- 12 direct blocks + indirect + double indirect + triple indirect
- Extents (ranges of blocks) for large files
- Symbolic links, hard links
- Directory indexing (htree) for fast lookup
- Variable block sizes (1KB to 64KB)
- Journaling for crash recovery
- Extended attributes (metadata)
```

**APFS (Apple) File System:**
```
- 64-bit inode numbers
- Copy-on-write (never modify in place)
- Snapshots (instant backups)
- Encryption built-in
- Space sharing between volumes
- Atomic operations
```

**What Stayed the Same:**
- **Inode concept**: Metadata separate from data
- **Directory structure**: Name → inode mapping
- **Hierarchical organization**: Tree of directories
- **Permissions model**: User/group/other (evolved)

#### System Calls: Evolution from 26 to 300+

**PDP-7 Unix: 26 System Calls**
```
Core I/O:     open, close, read, write, seek, creat
Process:      fork, exec, exit, wait
File system:  link, unlink, chdir, mkdir, mknod
Permissions:  chmod, chown
Special:      rele, smdate, wait, smes, rmes
```

**Linux: 300+ System Calls**
```
Original 26:  Still present (mostly compatible)

Networking:   socket, bind, listen, accept, connect, send, recv
              (50+ network-related calls)

Memory:       mmap, munmap, mprotect, madvise
              brk, sbrk (memory allocation)

Threads:      clone, futex, set_tid_address
              (20+ thread-related calls)

Timers:       nanosleep, timer_create, timer_settime
              (15+ time-related calls)

Security:     setuid, setgid, capabilities, seccomp
              (30+ security calls)

Modern I/O:   epoll, select, poll, io_uring
              sendfile, splice (zero-copy I/O)

Containers:   unshare, setns (namespace management)

And 150+ more...
```

**Backward Compatibility:**

PDP-7-era code concepts still work:
```c
/* This 1970s-style code still compiles and runs */
int fd = open("file.txt", 0);
char buf[512];
int n = read(fd, buf, 512);
write(1, buf, n);  /* fd 1 = stdout */
close(fd);
```

## 14.4 Cultural Impact

Unix didn't just change technology—it changed how we think about software.

### The Unix Philosophy

**Articulated by Doug McIlroy (Bell Labs, 1978):**

> 1. **Make each program do one thing well.** To do a new job, build afresh rather than complicate old programs by adding new features.
>
> 2. **Expect the output of every program to become the input to another**, as yet unknown, program. Don't clutter output with extraneous information. Avoid stringently columnar or binary input formats. Don't insist on interactive input.
>
> 3. **Design and build software, even operating systems, to be tried early**, ideally within weeks. Don't hesitate to throw away the clumsy parts and rebuild them.
>
> 4. **Use tools in preference to unskilled help** to lighten a programming task, even if you have to detour to build the tools and expect to throw some of them out after you've finished using them.

**In Practice:**
```bash
# Each tool does one thing well
$ ls          # List files (that's all)
$ grep        # Search text (that's all)
$ sort        # Sort lines (that's all)
$ uniq        # Remove duplicates (that's all)
$ wc          # Count lines/words/bytes (that's all)

# Compose together for complex operations
$ ls -l | grep "\.txt$" | wc -l
# How many .txt files?

$ cat logfile | grep ERROR | sort | uniq -c | sort -nr
# Count and rank error messages
```

Compare to **monolithic approach**:
```bash
# Hypothetical monolithic tool
$ super-log-analyzer --file=logfile --filter=ERROR --unique --count --sort=descending
```

The Unix approach is more flexible: you can combine tools in infinite ways.

### "Worse is Better" vs. "The Right Thing"

**Richard Gabriel (1991)** contrasted Unix's design philosophy with MIT's:

**MIT/Lisp "The Right Thing":**
- Completeness: System must be complete and correct
- Consistency: Design must be consistent above all
- Correctness: Never sacrifice correctness for simplicity
- Perfection: Get it right, even if it takes years

**Unix "Worse is Better":**
- Simplicity: Implementation should be simple
- Get it working: Ship something that works, even if incomplete
- Iterate: Improve based on real-world use
- Pragmatism: Practical solutions over theoretical perfection

**Example:**

MIT approach (Multics):
```
- Comprehensive security model (rings of protection)
- Full virtual memory (segments)
- Dynamic linking
- Built-in database (file system as database)
- Took years to develop
- Very complex
```

Unix approach:
```
- Simple security (user/group/other)
- Basic file system (inodes + data)
- Static linking initially
- Plain files, not database
- Working system in months
- Very simple
```

**Result**: Unix shipped and iterated. Multics never achieved widespread adoption. "Worse is better" **won**.

But Unix **evolved** toward "the right thing" over time:
- Added virtual memory (BSD)
- Added networking (BSD)
- Added dynamic linking (System V)
- Added sophisticated security (SELinux)

The key: **ship early, iterate, improve based on real use**.

### How This Shaped Software Engineering

**Unix Philosophy Influenced:**

**Python (1991):**
```python
# "There should be one-- and preferably only one --obvious way to do it"
# Simple, readable, composable
import sys
for line in sys.stdin:
    if "ERROR" in line:
        print(line)
```

**Go (2009):**
```go
// Simple, orthogonal features
// Composition over inheritance
// Tools for specific jobs (gofmt, govet)
```

**Rust (2010):**
```rust
// Composable traits
// Cargo build tool (like make)
// Small, focused standard library
```

**Modern DevOps:**
```bash
# Unix philosophy in containerized world
$ docker run alpine ls    # Container does one thing
$ kubectl apply -f config.yaml | grep Running
# Compose tools via pipes, even in cloud era
```

### The Open Source Movement

Unix's openness—even partial, academic openness—set crucial precedent.

#### Academic Unix Licenses (1970s)

**AT&T Academic License:**
- Source code provided
- Can modify for research
- Can't redistribute commercially
- Tiny fee ($200 for universities)

This created:
- **Educated programmers**: Generation learned OS internals
- **Collaborative culture**: Universities shared improvements
- **Innovation**: Research fed back into Unix

#### BSD License (1980s)

**Berkeley's Free Software:**
- Use for any purpose
- Modify freely
- Redistribute freely
- Commercial use allowed
- No copyleft restrictions

**Impact:**
- TCP/IP stack: Universal
- Utilities: Spread everywhere
- Commercial adoption: Companies built businesses on BSD

#### GNU Project (1983)

**Richard Stallman's Vision:**
- Unix-like system, completely free
- GNU's Not Unix (GNU)
- GPL license (copyleft)
- Free software philosophy

**GNU Tools:**
```
gcc - C compiler
bash - Bourne Again Shell
emacs - Editor
gdb - Debugger
make, tar, gzip, etc.
```

Combined with Linux kernel (1991) → **GNU/Linux**, the most successful free software platform.

#### Linux and the GPL (1991)

**Linus Torvalds' Choice:**
- GPL license (not BSD)
- Must share improvements
- Prevented proprietary forks
- Created collaborative ecosystem

**Result:**
- **Thousands of contributors**
- **Hundreds of companies** (Red Hat, IBM, Google, etc.)
- **Millions of lines** of free software
- **Powers most of the internet**

#### How PDP-7 Unix's Openness Set Precedent

Without PDP-7 Unix's "semi-openness":
- No student access to source code
- No university modifications
- No collaborative culture
- No BSD
- No GNU
- No Linux
- **Completely different computing landscape**

Thompson and Ritchie's decision to share Unix with universities—even under restrictive licenses—planted seeds that grew into the open source movement.

### Software Engineering Practices

Unix introduced practices now universal:

#### Man Pages: Documentation Culture

**Unix Manual (1971):**
```
NAME
     cat - concatenate and print files

SYNOPSIS
     cat file ...

DESCRIPTION
     Cat reads each file in sequence and writes it on the standard output.
```

**Still standard today:**
```bash
$ man cat      # Same format, 50+ years later
$ man fork
$ man anything
```

**Influence:**
- Every Unix command documented
- Standard format (NAME, SYNOPSIS, DESCRIPTION, EXAMPLES)
- Always available
- Searchable (man -k keyword)

Modern equivalents: `--help`, online docs, but **man pages still dominant in Unix/Linux world**.

#### Version Control Evolution

**SCCS (Source Code Control System, 1972):**
```bash
$ sccs create file.c     # Start tracking
$ sccs edit file.c       # Check out for editing
$ sccs delget file.c     # Check in changes
$ sccs prs file.c        # Show history
```

**RCS (Revision Control System, 1982):**
```bash
$ ci -l file.c           # Check in, keep lock
$ co -l file.c           # Check out with lock
$ rlog file.c            # Show log
```

**CVS (Concurrent Versions System, 1986):**
```bash
$ cvs checkout project   # Get project
$ cvs update            # Get latest
$ cvs commit            # Send changes
```

**Git (2005):**
```bash
$ git clone repo        # Get project
$ git pull              # Get latest
$ git commit            # Record changes
$ git push              # Send changes
```

**Progression:**
- SCCS: Single file, locked editing
- RCS: Better branching, still locked
- CVS: Concurrent editing, merging
- Git: Distributed, branching cheap, offline work

But **core concept from Unix era**: track changes, review history, collaborate.

#### Collaborative Development

**Unix Development Model (1970s Bell Labs):**
- Small team (Thompson, Ritchie, McIlroy, Ossanna, ~10 core people)
- Shared code
- Peer review (informal)
- Rapid iteration
- Meritocracy (best ideas win)

**Modern Open Source:**
- Large teams (Linux: 10,000+ contributors)
- Shared code (GitHub, GitLab)
- Peer review (pull requests, code review)
- Continuous integration
- Meritocracy (maintainer trust)

**Same principles, larger scale**.

#### The Hacker Culture

Unix created **hacker culture** (positive sense):

**Values:**
- Technical excellence
- Cleverness and elegance
- Sharing knowledge
- Meritocracy
- Hands-on learning
- Question authority
- Build cool stuff

**Artifacts:**
- Jargon File / Hacker Dictionary
- .signature files
- Easter eggs in software
- Hackers (Steven Levy, 1984)
- The Cathedral and the Bazaar (Eric Raymond, 1997)

Unix was **the hacker's operating system**—powerful, flexible, rewarding expertise.

## 14.5 Market Impact

Unix transformed entire industries.

### The Minicomputer Era (1970s)

**Market Transformation:**

**Before Unix (1960s):**
- Mainframes: $1-10 million
- Proprietary OSes: Tied to hardware
- Batch processing: Submit jobs, wait hours/days
- Specialists: Operators, programmers separate
- Vendor lock-in: Can't switch vendors

**With Unix (1970s):**
- Minicomputers: $10,000-100,000
- Portable OS: Runs on multiple vendors' hardware
- Interactive: Real-time response
- Programmers: Direct access to machine
- Some portability: Move between Unix systems

**DEC's Dominance:**
- PDP-11 series: Best-selling minicomputer
- Unix: Killer app for PDP-11
- VAX series: Scaled Unix to 32-bit
- Market share: DEC #2 computer company (after IBM) by 1980

### The Workstation Era (1980s)

Unix enabled the **engineering workstation** market:

#### Sun Microsystems (1982-2010)

**"The network is the computer"**

Founded by Bill Joy (BSD), Andreas Bechtolsheim, Vinod Khosla, Scott McNealy.

**Sun's Innovation:**
- **SunOS (BSD-based)**: Networked Unix
- **NFS (Network File System)**: Transparent remote files
- **SPARC**: High-performance RISC CPU
- **Workstations**: Graphics, networking, Unix

**Market Impact:**
- Dominated CAD/CAM: Engineers designing cars, chips, buildings
- Dominated scientific computing
- Web servers: Sun dominated .com era
- Peak: $5 billion revenue, 40,000 employees
- Acquired by Oracle (2010) for $7.4 billion

#### Silicon Graphics (SGI) (1982-2009)

**IRIX Unix** + powerful graphics hardware

**Markets:**
- 3D graphics: Movies (Industrial Light & Magic used SGI)
- Scientific visualization
- Virtual reality

**Cultural Impact:**
- Jurassic Park: "It's a Unix system! I know this!"
- Every 1990s sci-fi movie: Unix workstations everywhere
- Netscape Navigator: Developed on SGI workstations

#### NeXT (1985-1996)

**Steve Jobs' Unix Workstation Company**

**NeXTSTEP OS:**
- Mach microkernel + BSD Unix
- Objective-C
- Display PostScript
- Object-oriented frameworks

**Legacy:**
- World Wide Web: Tim Berners-Lee created the web on NeXT
- macOS: NeXTSTEP became OS X (2001)
- iOS: Based on OS X
- **Billions of devices run NeXT's Unix descendant**

### The Server Era (1990s-present)

#### Unix Dominating Servers

**1990s Server Market:**
```
Operating System    Market Share (1998)
───────────────────────────────────────
Unix (various)      ~40%
Windows NT          ~35%
NetWare             ~15%
Other               ~10%
```

**Unix Variants:**
- Solaris (Sun): Web servers, databases
- AIX (IBM): Enterprise, mainframe integration
- HP-UX (HP): Business-critical applications
- IRIX (SGI): Scientific computing

**"No one ever got fired for buying Unix"** (paraphrasing IBM saying)

#### The Dot-Com Boom (1995-2000)

**Unix powered the internet boom:**

**Web Servers:**
- Apache: Unix/Linux only (initially)
- Netscape servers: Solaris, IRIX
- Yahoo: FreeBSD
- Google: Linux (from start)

**Databases:**
- Oracle: Solaris, AIX, HP-UX
- Informix: Unix only
- Sybase: Unix only

**E-commerce:**
- eBay: Sun Solaris
- Amazon: Unix initially, then Linux

#### Linux Takeover (2000-present)

**Linux vs. Commercial Unix:**

```
Year    Commercial Unix    Linux        Windows
────────────────────────────────────────────────
2000    40%               10%          50%
2005    25%               25%          50%
2010    15%               35%          50%
2015     5%               60%          35%
2020     2%               70%          28%
2025    <1%               75%+         <25%
```

**Why Linux Won:**
- **Free**: No licensing costs
- **Open source**: Fix bugs yourself
- **Vendor neutral**: Not tied to one company
- **Commodity hardware**: Run on cheap x86 servers
- **Community**: Thousands of developers

**Commercial Unix Survivors:**
- AIX: IBM mainframe integration
- Solaris: Oracle database optimization
- HP-UX: Legacy enterprise systems

**But Linux dominates**: AWS, Google Cloud, Azure all run mostly Linux.

#### Cloud Computing Built on Linux

**Modern Cloud (2025):**

**Amazon Web Services (AWS):**
- EC2 instances: ~90% Linux
- Amazon Linux: Custom distribution
- Lambda: Linux containers

**Google Cloud:**
- Compute Engine: Mostly Linux
- GKE (Kubernetes): Linux containers
- Google's internal servers: Custom Linux

**Microsoft Azure:**
- ~60% of VMs run Linux
- Windows Server: ~40%
- Even Microsoft runs more Linux than Windows in cloud!

**Infrastructure:**
- Docker containers: Linux
- Kubernetes orchestration: Linux
- CI/CD pipelines: Linux
- Most web servers: Linux (Apache, nginx)

**The irony**: Microsoft, which fought Unix for decades, now:
- Runs more Linux than Windows in Azure
- Contributes to Linux kernel
- Created WSL (Windows Subsystem for Linux)
- Owns GitHub (where Linux is developed)

### The Mobile Era (2000s-present)

#### The Numbers

**Unix-derived mobile OS market:**

```
Operating System  Market Share (2025)  Unix Ancestry
────────────────────────────────────────────────────
Android           ~70%                 Linux kernel
iOS               ~27%                 BSD via Darwin
Other             ~3%                  Various
```

**Total devices:**
- Android: ~3 billion active devices (Linux)
- iOS: ~2 billion active devices (BSD)
- **5+ billion Unix-derived devices**

Every modern smartphone runs an operating system descended from PDP-7 Unix.

#### iOS: BSD in Your Pocket

**Darwin → iOS:**
```
PDP-7 Unix (1969)
  → BSD Unix (1977)
    → NeXTSTEP (1989)
      → Mac OS X (2001)
        → iOS (2007)
```

**iOS Kernel (XNU):**
```c
/* XNU = "X is Not Unix" (but actually, it is) */
- Mach microkernel (CMU, 1985)
- BSD subsystem (FreeBSD code)
- I/O Kit (drivers)
```

**Unix Features in iOS:**
- File system: HFS+ → APFS (hierarchical)
- Processes: fork/exec model (restricted)
- Permissions: User/group (sandboxed)
- Networking: BSD sockets
- Shell: bash/zsh (accessible via jailbreak)

#### Android: Linux in Your Pocket

**Android Architecture:**
```
Applications (Java/Kotlin)
  ↓
Android Framework
  ↓
Native Libraries (C/C++)
  ↓
Linux Kernel (modified)
```

**Linux Kernel Modifications:**
- Binder: IPC mechanism
- Ashmem: Shared memory
- Wakelocks: Power management
- Low Memory Killer: OOM handling

**But fundamentally Linux:**
```bash
# Android Debug Bridge shell
$ adb shell
android:/ $ uname -a
Linux localhost 5.10.107-android13 #1 SMP PREEMPT ...

android:/ $ ps
USER       PID  PPID VSIZE  RSS  WCHAN    PC  NAME
root         1     0  14104 2156 SyS_epoll_wait S /init
root       123     1  15204 3248 binder_thread_read S /system/bin/servicemanager
...
```

**Unix DNA everywhere**: processes, file system, permissions, sockets, pipes—all there, just packaged differently.

## 14.6 Educational Impact

### Unix in Computer Science Education

Unix became **the teaching OS**:

**Why Unix for Education:**
1. **Source code available**: Study real implementation
2. **Small enough to understand**: Not millions of lines
3. **Complete system**: All OS concepts present
4. **Widely used**: Industry-relevant skill
5. **Free (eventually)**: No license barriers for students

#### Operating Systems Textbooks

**Classic Texts Using Unix:**

**"Operating System Concepts" (Silberschatz, Galvin, Gagne):**
- First edition: 1983
- 10+ editions through 2018
- Standard OS textbook
- Uses Unix/Linux examples throughout

**"Modern Operating Systems" (Andrew Tanenbaum):**
- First edition: 1992
- 4+ editions through 2014
- Created MINIX as teaching tool
- Linus Torvalds learned OS concepts from this book

**"The Design of the Unix Operating System" (Maurice Bach):**
- 1986
- Detailed System V internals
- Source code walkthroughs
- Classic reference

**"Lions' Commentary on UNIX 6th Edition" (John Lions):**
- 1977 (republished 1996)
- Line-by-line kernel commentary
- Most photocopied CS document ever
- Educated generation of OS developers

#### MINIX: Educational Unix

**Andrew Tanenbaum (1987):**
```
MINIX = Mini-Unix
- Microkernel design
- ~12,000 lines of C
- Included with "Operating Systems" textbook
- Students could modify and experiment
- Source code explained in book
```

**Impact:**
- Hundreds of universities used MINIX for OS courses
- Linus Torvalds learned from MINIX
- Influenced Linux design (and famous Tanenbaum-Torvalds debate)

**The Debate (1992):**

Tanenbaum:
> "Linux is obsolete... a monolithic [kernel] in 1991 is fundamentally wrong."

Torvalds:
> "Your job is being a professor and researcher... My job is to provide the best OS as possible."

**Result**: Both were right in their contexts. MINIX was better for teaching, Linux was better for production. Both descended from Unix ideas.

#### Linux as Teaching Tool

**Modern OS Education:**
- Most universities: Linux kernel projects
- Students: Build modules, modify scheduler, implement file systems
- Online courses: MIT OCW, Stanford CS140, etc.
- Open source: Students contribute to real projects

**Advantages over older Unix:**
- Free: No licensing issues
- Modern: Current technology
- Active: Real-world development
- Documented: Massive documentation available

### This PDP-7 Code as Historical Artifact

**The PDP-7 Unix source represents:**

1. **Genesis**: Where it all started
2. **Simplicity**: Before decades of feature additions
3. **Clarity**: Core concepts in pure form
4. **Historical**: How programming was done
5. **Educational**: Learn from masters

**What Students Learn from PDP-7 Unix:**
- How an OS really works (no abstractions hiding complexity)
- Assembly language and low-level programming
- Design principles (simplicity, orthogonality)
- Historical context (how we got here)
- Appreciation for modern tools (we have it easy now!)

## 14.7 Economic Impact

Unix's economic impact is staggering.

### Companies Built on Unix

**Major Unix-Based Companies:**

```
Company          Founded  Peak Value    Unix Role
──────────────────────────────────────────────────────────────
Sun Microsystems 1982     $200B (2000)  SunOS/Solaris
Silicon Graphics 1982     $7B (1995)    IRIX
NeXT             1985     $429M (1996)  NeXTSTEP → macOS
Apple            1976     $3T (2024)    macOS/iOS (BSD)
Google           1998     $2T (2024)    Linux (servers, Android)
Red Hat          1993     $34B (2019)   Enterprise Linux
Oracle           1977     $200B (2024)  Acquired Sun, Solaris
IBM              1911     $155B (2024)  AIX, bought Red Hat
```

**Hundreds More:**
- Netflix: FreeBSD for CDN
- WhatsApp: FreeBSD for messaging
- Amazon: Linux for AWS
- Facebook: Linux for infrastructure
- Twitter: Linux for services
- Every major web company: Unix/Linux

### Market Valuations

**Unix-Derived Technology Market Cap (2024 estimates):**

```
Apple (iOS/macOS)           $3.0 trillion
Google (Android/Cloud)      $2.0 trillion
Amazon (AWS/Linux)          $1.8 trillion
Microsoft (Azure/Linux)     $3.0 trillion
Meta (Linux infra)          $900 billion
Oracle (Solaris/Linux)      $200 billion
───────────────────────────────────────────
Total                       $11 trillion+
```

**Not all of this is Unix**, but Unix/Linux is fundamental infrastructure for all these companies.

### Jobs Created

**Direct Unix/Linux Jobs (2024 estimates):**

```
Category                     Jobs (approximate)
─────────────────────────────────────────────
Linux system administrators  2,000,000+
DevOps engineers (Linux)     1,500,000+
Android developers           5,000,000+
iOS developers               3,000,000+
Embedded Linux engineers     1,000,000+
Kernel developers            50,000+
───────────────────────────────────────────
Total                        12,500,000+
```

**Indirect jobs** (web developers, data scientists, etc. using Unix/Linux infrastructure): tens of millions more.

### Industries Enabled

Unix/Linux enabled entire industries:

**1. The Internet (1990s-present)**
- Web servers: Mostly Unix/Linux
- DNS servers: BIND (Unix)
- Email servers: sendmail, postfix (Unix)
- Without Unix: Internet would look very different

**2. Mobile Computing (2007-present)**
- iOS: 2 billion devices
- Android: 3 billion devices
- Without Unix: Mobile revolution delayed or different

**3. Cloud Computing (2006-present)**
- AWS, Google Cloud, Azure: Built on Linux
- Virtualization: Xen, KVM (Linux)
- Containers: Docker, Kubernetes (Linux)
- Without Unix/Linux: Cloud computing much harder/different

**4. Embedded Systems**
- Routers: Linux
- Smart TVs: Linux
- Automotive: Linux (many systems)
- IoT devices: Linux
- Without Unix: Embedded much more fragmented

**5. Scientific Computing**
- Supercomputers: 100% run Linux (Top500 list)
- Research: Most done on Unix/Linux
- Bioinformatics: Unix tools standard
- Without Unix: Scientific progress slower

**6. Entertainment**
- Movie VFX: Linux render farms
- Game servers: Linux
- Streaming: Linux (Netflix, YouTube)
- Without Unix: Entertainment tech different

### Estimated Total Economic Impact

**Impossible to quantify exactly**, but rough estimate:

**Conservative Estimate:**
- Companies built on Unix: $10+ trillion market cap
- Jobs directly enabled: 10+ million
- Industries transformed: Internet, mobile, cloud, embedded
- Time saved: Billions of person-hours (developer productivity)
- Revenue enabled: Trillions of dollars annually

**Thompson and Ritchie's 8,000 lines of code** → **one of the highest-ROI software projects in history**.

## 14.8 Technical Debt and Lessons

Not everything from 1969 aged well. What can we learn?

### What Aged Well

#### 1. Core Abstractions

**Still valid today:**
- **Files as abstraction**: Devices, processes, network connections—all files
- **Hierarchical namespace**: Directories and paths
- **Process model**: fork/exec, parent/child relationships
- **System calls**: Clean separation between user and kernel
- **Text streams**: Universal data format

**These concepts are eternal**—they'll likely still be valid in 2069.

#### 2. Design Simplicity

**PDP-7 Unix Philosophy:**
- Simple mechanisms
- General-purpose tools
- Composition over monolithic design
- Clear interfaces

**Still best practice**:
- Microservices (composition)
- Unix philosophy in distributed systems
- REST APIs (simple, stateless)
- Cloud-native (small, focused services)

#### 3. Tool Composition Model

**1969 concept:**
```
Small tools → pipes → complex operations
```

**2025 reality:**
```bash
# Same pattern, 55 years later
cat data.json | jq '.results[]' | grep "active" | wc -l
```

**Modern equivalent:**
```python
# Python: compose functions
result = (
    load_data()
    | filter_active
    | transform
    | aggregate
)
```

**Kubernetes:**
```yaml
# Compose containers
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
  - name: sidecar
    image: logging:latest
```

**Same principle, different scales**.

### What Didn't Age Well

#### 1. No Memory Protection

**PDP-7 Unix:**
- Any process could access any memory
- No protection between user/kernel
- Bugs could crash entire system
- Security nightmare

**Modern systems:**
- MMU (Memory Management Unit) required
- Kernel/user separation enforced by hardware
- Process isolation mandatory
- Virtual memory standard

**Lesson**: Security can't be bolted on; it must be designed in.

#### 2. Non-Reentrant Code

**PDP-7 Unix:**
```assembly
" Global variables everywhere
counter: 0

increment:
   lac counter
   add o1
   dac counter    " RACE CONDITION if interrupted!
```

**Modern approach:**
```c
/* Thread-safe, reentrant */
int increment(int *counter) {
    return __atomic_add_fetch(counter, 1, __ATOMIC_SEQ_CST);
}
```

**PDP-7 had no threads**, so reentrancy wasn't a concern. Modern systems must handle concurrency.

**Lesson**: Assumptions about execution environment change; design for concurrency even if not needed yet.

#### 3. Limited Security Model

**PDP-7 Unix Security:**
- User ID: Yes
- Permissions: Basic (user/other, later user/group/other)
- No encryption
- No capabilities
- No sandboxing
- Trust all logged-in users

**Modern Security Needs:**
- Mandatory Access Control (SELinux, AppArmor)
- Capabilities (fine-grained permissions)
- Namespaces (containers, isolation)
- Encryption (at rest, in transit)
- Sandboxing (app isolation)
- Zero-trust architecture

**Lesson**: 1969 security model insufficient for internet-connected, adversarial environment. Security requirements evolve.

#### 4. What Modern Systems Had to Add

**Not in PDP-7 Unix, essential now:**

**Networking:**
- TCP/IP stack (BSD, 1983)
- Sockets API
- Network protocols

**Concurrency:**
- Threads (POSIX threads, 1995)
- Thread synchronization (mutexes, semaphores)
- Lockless data structures

**Security:**
- Encrypted file systems
- Mandatory access control
- Sandboxing
- Secure boot

**Performance:**
- SMP (Symmetric MultiProcessing)
- NUMA (Non-Uniform Memory Access)
- Scalability to 1000+ CPUs

**Reliability:**
- Journaling file systems
- Redundancy (RAID)
- Hot-plug devices
- Containerization

**PDP-7 Unix didn't need these**—but they became essential as computing evolved.

### Lessons for Today

#### 1. The Value of Simplicity

**PDP-7 Unix: 8,000 lines**
- Comprehensible
- Debuggable
- Maintainable
- Portable (eventually)

**Modern Linux: 30+ million lines**
- Complex
- Hard to debug
- Difficult to maintain
- But feature-rich

**Trade-off**: Features vs. simplicity

**Lesson**: **Start simple. Add complexity only when necessary. Preserve simplicity where possible.**

**Examples of simplicity preserved:**
- Go language: Deliberately simple
- SQLite: Minimalist database
- Redis: Simple data structures
- nginx: Simple event model

#### 2. Constraints Driving Innovation

**PDP-7 Constraints:**
- 8K words of RAM
- 18-bit architecture
- Slow DECtape storage

**Innovations from Constraints:**
- Extremely efficient code
- Inode/directory separation (save space)
- Swap to disk (maximize available memory)
- Simple, orthogonal design (no room for complexity)

**Modern Example:**
- **SQLite**: Designed for embedded systems with constraints
- **Result**: Most deployed database (billions of instances)
- **Why**: Constraints forced excellent design

**Lesson**: **Don't fear constraints. They force creative solutions and excellent design.**

#### 3. Long-Term Thinking in Design

**PDP-7 Design Decisions Still Valid:**
- Hierarchical file system: 55+ years, still standard
- Process model: 55+ years, still standard
- System call interface: 55+ years, still compatible
- Text-based tools: 55+ years, still dominant

**Bad Design is Hard to Fix:**
- C strings (null-terminated): Security nightmare, but backwards compatibility prevents change
- Unix file permissions: Insufficient for modern security, but can't break compatibility
- 32-bit time_t: Y2038 problem looming

**Lesson**: **Design for the long term. APIs are forever. Bad design persists for decades.**

**Good Examples:**
- Git: Well-designed data model, scales beautifully
- Unicode: Planned for future expansion
- IPv6: Learned from IPv4 limitations

#### 4. Code That Lasts 50+ Years

**What makes code last?**

1. **Simple, clear concepts**: Easy to understand decades later
2. **Stable interfaces**: Backward compatibility maintained
3. **Good documentation**: Future maintainers can learn
4. **Minimal dependencies**: Less to break over time
5. **Solves real problems**: Continues to be useful

**PDP-7 Unix achieved all of these.**

**Lesson**: **Write code that others (including future you) can understand. Simple, well-documented, solving real problems.**

## 14.9 The Preservation Effort

Why preserve 50+-year-old code? Because **history matters**.

### The Unix Heritage Society

#### Warren Toomey and TUHS

**The Unix Heritage Society (TUHS):**
- Founded: ~1995
- Mission: Preserve Unix history
- Leader: Warren Toomey (Australia)
- Website: https://www.tuhs.org/

**Achievements:**
- Preserved ancient Unix source code (V1-V7)
- Documented Unix history
- Lobbied for open-sourcing old Unix
- Created community of Unix historians
- Rescued code from oblivion

#### Preserving Unix History

**Challenges:**
- Old printouts: Fading, fragile
- Lost media: DECtapes, disks unreadable
- Forgotten knowledge: Original authors aging/deceased
- Legal issues: Who owns ancient code?
- Technical issues: Old formats, obsolete hardware

**Solutions:**
- **Scanned printouts**: Digitize before they decay
- **OCR and manual correction**: Convert to text
- **Simulators**: SIMH, E11—run old hardware virtually
- **Interviews**: Recorded oral histories
- **Legal work**: Got Caldera/SCO to open-source ancient Unix

#### The pdp7-unix Resurrection

**The PDP-7 Unix project:**

**2019: Unix 50th Anniversary**

Dennis Ritchie's papers donated to Computer History Museum included PDP-7 Unix printouts (~190 pages).

**The Team:**
- Warren Toomey (TUHS)
- Volunteers from Unix community
- Computer historians

**The Process:**

1. **Scan printouts** (Computer History Museum)
2. **OCR the text** (extract assembly code)
3. **Manually correct errors** (OCR isn't perfect)
4. **Reconstruct file structure** (determine which code goes in which file)
5. **Build cross-assembler** (PDP-7 assembler for modern systems)
6. **Assemble code** (create binary)
7. **Debug** (fix OCR errors, missing code)
8. **Run in simulator** (SIMH PDP-7 emulator)
9. **IT BOOTED!** (June 2019)

**The Result:**

PDP-7 Unix runs again, 50 years later. You can:
```bash
# On modern Linux:
$ git clone https://github.com/DoctorWkt/pdp7-unix
$ cd pdp7-unix
$ make
$ ./simh/pdp7 unixv0.simh

# PDP-7 Unix boots!
login: root
#
```

**Historical Significance:**
- First time PDP-7 Unix ran since ~1971
- Proves preservation is possible
- Enables study of original Unix
- Inspires future preservation efforts

#### Making History Accessible

**TUHS Provides:**
- Source code: V1-V7 Unix, BSD, etc.
- Documentation: Manuals, papers, notes
- Simulators: Run ancient Unix
- Mailing list: Discuss Unix history
- Archives: Preserve for future

**Anyone can study Unix history:**
```bash
# Run Unix V6 (1975)
$ git clone https://github.com/simh/simh
$ cd simh
$ make pdp11
$ ./pdp11 unix_v6.ini
# Unix V6 boots, login as root, explore!
```

**Educational Value:**
- Students: See OS evolution
- Historians: Understand computing history
- Programmers: Learn from masters
- Everyone: Appreciate how far we've come

### Running PDP-7 Unix Today

#### SIMH Simulator

**SIMH: Computer History Simulation**
- Simulates ancient computers
- PDP-7, PDP-11, VAX, IBM 1401, etc.
- Cycle-accurate (ish)
- Runs ancient software

**Running PDP-7 Unix:**
```bash
$ ./pdp7 pdp7.ini

PDP-7 simulator V4.0-0

# Unix boots
@
```

**You can:**
- Edit files (ed)
- Compile programs (as.s)
- Run utilities (cat, cp, ls)
- Experience 1969 computing

#### Actual PDP-7 Hardware

**Living Computer Museum (Seattle)**
- Had working PDP-7 (until museum closed 2020)
- Could run PDP-7 Unix on real hardware
- Historical computing events

**Other PDP-7s:**
- Very few survive (maybe 5-10 worldwide)
- Museum pieces
- Occasionally operational

**The experience:**
- Teletype terminal (clacky!)
- Toggle switches (front panel)
- DECtape (slow!)
- Ancient but functional

#### Historical Computing Community

**Communities:**
- TUHS (Unix Heritage Society)
- SIMH users
- Vintage Computer Federation
- Computer History Museum
- Living Computer Museum (closed but archived)

**Activities:**
- Preserve old software
- Restore old hardware
- Document history
- Share knowledge
- Inspire new generations

#### Why It Matters

**"Those who don't know history are doomed to repeat it."**

**Studying historical systems teaches:**
- Design principles (what worked, what didn't)
- Evolution of ideas (how we got here)
- Context (why decisions were made)
- Fundamentals (stripped of modern cruft)
- Appreciation (how much progress we've made)

**PDP-7 Unix is:**
- Small enough to understand completely
- Foundational (all modern Unix descends from it)
- Well-documented (now)
- Runnable (via simulator)
- Educational (teaches OS fundamentals)

## 14.10 Conclusion: The Longest-Lasting Code

### Perspective

Consider these numbers:

**Written**: Summer/Fall 1969
**First boot**: Late 1969
**Still influencing systems**: 2025
**Duration of impact**: **56+ years and counting**
**No end in sight**: Will likely influence systems for decades more

**Few software projects last 5 years.**
**Unix has lasted 50+.**

**Why?**
- **Elegant design**: Simple, powerful abstractions
- **Solves real problems**: File management, process control, I/O
- **Good enough**: Not perfect, but adequate and improvable
- **Portable**: C rewrite enabled adaptation to new hardware
- **Open (eventually)**: Sharing enabled evolution and improvement
- **Right time**: Minicomputer revolution needed good OS
- **Right people**: Thompson and Ritchie were geniuses

### The Thompson and Ritchie Legacy

#### Turing Awards

**Ken Thompson: 1983 Turing Award**
> "For their development of generic operating systems theory and specifically for the implementation of the UNIX operating system."

**Dennis Ritchie: 1983 Turing Award** (shared with Thompson)
> "For their development of generic operating systems theory and specifically for the implementation of the UNIX operating system."

**Additional Honors:**
- National Medal of Technology (1998, USA)
- Japan Prize (2011)
- IEEE Richard W. Hamming Medal
- Numerous honorary doctorates

**Dennis Ritchie (1941-2011):**
> "Unix is very simple, it just needs a genius to understand its simplicity."

**Ken Thompson (1943-present):**
> "When in doubt, use brute force."
> "One of my most productive days was throwing away 1000 lines of code."

#### Lasting Influence

**Thompson and Ritchie taught the world:**

1. **Simplicity is power**: Simple systems are understandable, maintainable, adaptable
2. **Composition over complexity**: Small tools composed beat large monoliths
3. **Portability matters**: Write once, run anywhere (with C rewrite)
4. **Share knowledge**: Collaboration accelerates progress
5. **Design for humans**: Make the system pleasant to use
6. **Iterate**: Ship early, improve based on use

**Their code influenced:**
- Every Unix/Linux developer
- Every C programmer
- Every systems programmer
- Every open-source contributor
- Billions of device users (unknowingly)

#### Simplicity as Design Principle

**The PDP-7 Unix philosophy:**

> **"Do one thing well."**
> **"Keep it simple."**
> **"Make it work first, optimize later."**
> **"Write programs that write programs."**
> **"Worse is better (ship and iterate)."**

**Applied today:**
- Google: Simple search box, complex backend
- Apple: Simple user interface, complex engineering
- Unix tools: Each does one thing well
- Modern APIs: REST (simple), not SOAP (complex)

**The eternal lesson**: **Complexity is easy. Simplicity is hard. Simplicity wins.**

#### Code as Literature

**Donald Knuth: "Literate Programming"**
> "Let us change our traditional attitude to the construction of programs: Instead of imagining that our main task is to instruct a computer what to do, let us concentrate rather on explaining to human beings what we want a computer to do."

**PDP-7 Unix code is literature:**
- Read to learn
- Study to understand
- Appreciate the craft
- Learn from masters

**Like reading Shakespeare:**
- Understand the language (PDP-7 assembly)
- Appreciate the artistry (elegant solutions)
- Learn the context (1969 constraints)
- Apply the lessons (design principles)

**Thompson and Ritchie were poet-programmers:**
- Every line purposeful
- No wasted words (instructions)
- Elegant solutions to hard problems
- Art and engineering combined

### Looking Forward

#### Unix Concepts in the Next 50 Years?

**What will persist?**

**Likely to continue:**
- **Hierarchical file systems**: Too useful to abandon
- **Process model**: Fork/exec or equivalent
- **Text streams**: Universal data exchange
- **Composition**: Small pieces, loosely joined
- **System calls**: Kernel/user separation

**Likely to evolve:**
- **Security model**: Zero-trust, capability-based
- **Concurrency**: Better than threads
- **Distributed**: Assume networked systems
- **Persistence**: Persistent memory changes everything
- **Hardware**: Quantum, neuromorphic, exotic architectures

**But core Unix ideas will adapt**: They're too fundamental to abandon entirely.

#### What Will Finally Change?

**Candidates for replacement:**

**1. File systems:**
- Current: Hierarchical trees
- Future: Databases? Object stores? Content-addressed?
- Unix assumption: May not hold

**2. Processes:**
- Current: Fork/exec, isolation
- Future: Lightweight isolates? Unikernels? WebAssembly?
- Unix model: May evolve significantly

**3. Text:**
- Current: Text streams, ASCII/UTF-8
- Future: Structured data (JSON, Protocol Buffers)?
- Unix tradition: May become secondary

**4. Monolithic kernels:**
- Current: Large kernel (Linux)
- Future: Microkernels? Library OSes? Separation kernels?
- Unix architecture: Already being challenged

**But changes will be gradual**: Backward compatibility and installed base keep Unix concepts alive.

#### The Immortality of Good Ideas

**Why Unix ideas persist:**

1. **Fundamentally sound**: Based on solid computer science
2. **Practical**: Solve real problems efficiently
3. **Simple**: Easy to understand and implement
4. **Flexible**: Adapt to new contexts
5. **Proven**: 50+ years of success

**Good ideas don't die—they evolve:**
- Files → objects
- Pipes → streams
- Processes → containers
- System calls → APIs
- Terminals → web browsers

**The idea persists even as implementation changes.**

**Unix is immortal because:**
- **It works**
- **It's simple**
- **It's everywhere**
- **It solves real problems**
- **It adapts to new requirements**

### Final Reflection: 8,000 Lines That Changed the World

In 1969, Ken Thompson wrote approximately 8,000 lines of assembly code on an obsolete PDP-7 minicomputer. He created:
- A hierarchical file system
- A simple process model
- A set of elegant abstractions
- A foundation for modern computing

Today, in 2025:
- **5+ billion smartphones** run Unix-derived operating systems
- **90%+ of servers** run Unix or Linux
- **100% of Top 500 supercomputers** run Linux
- **Every major cloud platform** is built on Linux
- **The entire internet** runs primarily on Unix/Linux infrastructure

**From 8,000 lines of code** to **the foundation of modern civilization's digital infrastructure**.

**No other software has had comparable impact.**

**Thompson and Ritchie didn't set out to change the world**—they just wanted a better environment to write programs. They needed:
- A decent editor
- An assembler
- A file system
- A simple OS to host these tools

They built it with:
- Minimal resources (8K words of RAM)
- Obsolete hardware (PDP-7)
- No budget
- No formal project approval
- Just skill, taste, and determination

**The result:**
- Unix
- C language
- Modern computing
- A legacy that will outlive us all

**The lesson:**
> **Good design lasts.**
> **Simple solutions scale.**
> **Elegant code is eternal.**
> **8,000 lines can change the world.**

---

**Epilogue:**

When you use your smartphone, browse a website, stream a video, send an email, or use any digital service, you are standing on the shoulders of giants.

Somewhere in the stack—maybe buried deep, maybe abstracted away—are ideas that Ken Thompson and Dennis Ritchie created in 1969 on a PDP-7 minicomputer.

**Files. Processes. Directories. Text streams. Simple tools composed together.**

**These ideas didn't just influence computing—they became computing.**

**And it all started with 8,000 lines of assembly code.**

Thank you, Ken. Thank you, Dennis.

**Your code lives forever.**

---

*"Unix is simple and coherent, but it takes a genius (or at any rate a programmer) to understand and appreciate the simplicity."*
— Dennis Ritchie (1941-2011)

*"When in doubt, use brute force."*
— Ken Thompson (1943-)

**The End**

---

## References and Further Reading

**Historical Sources:**
- Thompson, K., & Ritchie, D. M. (1974). "The UNIX Time-Sharing System." *Communications of the ACM*, 17(7), 365-375.
- Ritchie, D. M. (1984). "The Evolution of the Unix Time-sharing System." *AT&T Bell Laboratories Technical Journal*, 63(6), 1577-1593.
- Salus, P. H. (1994). *A Quarter Century of UNIX*. Addison-Wesley.
- Raymond, E. S. (2003). *The Art of Unix Programming*. Addison-Wesley.

**Technical References:**
- Lions, J. (1977). *Lions' Commentary on UNIX 6th Edition*. (Republished 1996)
- Bach, M. J. (1986). *The Design of the UNIX Operating System*. Prentice Hall.
- McKusick, M. K., et al. (1996). *The Design and Implementation of the 4.4BSD Operating System*. Addison-Wesley.

**Online Resources:**
- Unix Heritage Society: https://www.tuhs.org/
- PDP-7 Unix resurrection: https://github.com/DoctorWkt/pdp7-unix
- Computer History Museum: https://computerhistory.org/
- The Evolution of the Unix Time-sharing System: https://www.bell-labs.com/usr/dmr/www/

**Oral Histories:**
- Thompson and Ritchie interviews (Computer History Museum)
- Unix pioneers' oral histories (TUHS)
- "The UNIX Oral History Project" (various sources)
