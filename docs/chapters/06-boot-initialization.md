# Boot and Initialization

## The Cold Start: Bringing Unix to Life

One of the most fascinating aspects of any operating system is how it bootstraps itself from nothing. The PDP-7 Unix boot process is remarkable for its simplicity—just 20 lines of assembly code in `s9.s` prepare an empty disk, and another 20 lines in `s8.s` (coldentry) bring the system to life.

### Historical Context: Bootstrapping in 1969

In 1969, "booting" a computer was a far more involved process than today:

- **Physical switches**: Operators manually entered bootstrap code via front panel switches
- **Paper tape**: Bootstrap loaders were read from punched paper tape
- **Magnetic tape**: Larger systems loaded from tape in multiple stages
- **No firmware**: Most computers had no ROM; every bit of code came from external media

The PDP-7 Unix boot process was revolutionary for being:
- **Self-contained**: Everything needed was on DECtape
- **Automated**: Minimal operator intervention required
- **Fast**: Complete boot in under 30 seconds
- **Recoverable**: Could rebuild filesystem from scratch

## 6.1 The Cold Boot Process (s9.s)

The file `s9.s` contains the **cold boot loader**, used only during initial installation. Let's examine the complete process:

### Stage 1: Disk Initialization

```assembly
" S9 - Cold boot loader
" Initialize empty filesystem on disk

" Step 1: Zero out the inode list (tracks 2-711)
    lac d2              " Start at track 2
1:
    jms dskwr; 07700    " Write zeros to track
    tad d5              " Add 5 (skip to next inode track)
    dac lac 1b          " Update track number
    sad d712            " Reached track 712?
    jmp 1b              " No, continue loop

" Step 2: Initialize free block list
    jms copy; initfblk; sysdata; 14    " Copy initial free list
    law track712        " Start of data area
    dac s.nxfblk        " Set as first free block
```

**What this does:**
1. Writes zeros to tracks 2-711 (the inode storage area)
2. Initializes the free block list starting at track 712
3. Sets up the system data structure (sysdata)

**Why this matters:**
- Creates a blank filesystem ready for files
- Establishes the free block chain
- Prepares system metadata

### Stage 2: Reading Files from Paper Tape

The cold boot loader then reads files from paper tape and writes them to disk:

```assembly
" Read files from paper tape reader
1:
    jms getc            " Get character count
    sna                 " Zero = end of tape
    jmp bootdone
    dac count           " Store file size

    jms getc            " Get flags
    dac i.flags

    jms getc            " Get link count
    dac i.nlks

    " Read file data into memory buffer
    law buffer
    dac 8              " Auto-increment pointer
2:
    jms getc
    dac 8 i            " Store in buffer
    isz count
    jmp 2b

    " Compute checksum
    jms checksum
    sad expected
    jmp checksumok
    jms halt           " Checksum failed!

checksumok:
    " Write file to disk
    jms allocblocks    " Allocate disk blocks
    jms writefile      " Write data to blocks
    jms createinode    " Create inode entry
    jmp 1b             " Next file
```

**The Paper Tape Format:**

Each file on the tape contains:
```
+------------------+
| File size (words)|  1 word
+------------------+
| Flags            |  1 word (permissions, type)
+------------------+
| Link count       |  1 word
+------------------+
| File data        |  N words
+------------------+
| Checksum         |  1 word (sum of all previous words)
+------------------+
```

**The Installation Tape Contents:**

1. **System kernel** (tracks 18-100) - The combined s1-s9 code
2. **init** - First user process (inode 3)
3. **sh** - Shell program
4. **ed** - Text editor
5. **as** - Assembler
6. **Basic utilities** - cat, cp, chmod, etc.

### Stage 3: Jump to System

After loading all files:

```assembly
bootdone:
    " Read inode #3 (init program)
    lac d3
    jms iget            " Get inode for file 3

    " Load init into memory at location 4096
    cla
    jms iread; 4096; 4096

    " Jump to init
    jmp 4096
```

## 6.2 The Warm Boot Process (s8.s coldentry)

Once Unix is installed, subsequent boots use **coldentry** in s8.s. This is much faster:

```assembly
coldentry:
    dzm 0100            " Clear location 100 (re-entrance guard)
    caf                 " Clear all flags
    ion                 " Interrupts on
    clon                " Clock on

    " Initialize display
    law 3072            " Display buffer size
    wcga                " Write to display
    jms dspinit         " Initialize display system
    law dspbuf
    jms movdsp          " Move display buffer

    " Load system data from disk track 0
    cla
    jms dskio; 06000    " Read track 6000 (system data)
    jms copy; dskbuf; sysdata; ulist-sysdata

    " Load and execute init (inode 3)
    lac d3
    jms namei; initf    " Look up "init"
       jms halt         " Failed - halt system
    jms iget            " Get inode
    cla
    jms iread; 4096; 4096   " Read into memory
    jmp 4096                " Execute init
```

**Boot Sequence Timeline:**

```
T+0ms     : Power on, operator loads bootstrap via front panel
T+100ms   : Bootstrap reads coldentry from DECtape track 0
T+500ms   : coldentry executed, display initialized
T+1000ms  : System data loaded from disk
T+2000ms  : init file read from filesystem (inode 3)
T+2500ms  : Jump to init (first user process starts)
T+3000ms  : init forks login processes
T+5000ms  : Login prompt appears on TTY and display
```

**Total boot time: ~5 seconds** (vs. minutes for contemporary systems!)

## 6.3 The Init Process: Unix's First Program

The file `init.s` is special—it's the first user-space program that runs. Let's examine it in detail:

### Forking Login Processes

```assembly
" init - first user process

    -1
    sys intrp           " Set interrupt flag
    jms init1           " Fork TTY login
    jms init2           " Fork display/keyboard login

" Main loop - wait for processes to die, respawn them
1:
    sys rmes            " Receive message (blocking wait)
    sad pid1            " Was it TTY process?
    jmp 1f
    sad pid2            " Was it display process?
    jms init2           " Yes, restart display login
    jmp 1               " Wait for next message
1:
    jms init1           " Restart TTY login
    jmp 1               " Continue forever
```

**What this does:**
- Forks two login processes (one for TTY, one for display/keyboard)
- Waits for either to terminate (when user logs out)
- Immediately spawns a replacement
- Runs forever, providing perpetual login capability

**Revolutionary concept**: The system never stops accepting logins!

### The Login Sequence

```assembly
login:
    -1
    sys intrp           " Set interrupt flag
    sys open; password; 0   " Open password file

    " Display "login:" prompt
    lac d1
    sys write; m1; m1s  " Write "login: "

    " Read username
    jms rline           " Read line from terminal
    lac ebufp
    dac tal             " Save end of buffer pointer
```

The login process then:

1. **Reads the password file** (`/etc/password` - though path not yet implemented)
2. **Compares username** line by line
3. **Prompts for password** if username matches
4. **Compares password** (plaintext - no encryption in 1970!)
5. **Extracts user info** (UID and home directory)
6. **Changes to home directory**
7. **Executes shell**

### Password File Format

The password file has one line per user:

```
username:password:uid:homedir
```

Example:
```
ken:.,12345:1:ken
dmr:secret:2:dmr
```

**Parsing the password file:**

```assembly
" Search password file for username
1:
    jms gline           " Get next line from password file
    law ibuf-1          " Input buffer
    dac 8
    law obuf-1          " Username we're searching for
    dac 9

" Compare characters until mismatch or delimiter
2:
    lac 8 i             " Get char from file
    sac o12             " Skip if not ':'
    lac o72             " Load ':'
    sad 9 i             " Compare with user input
    skp                 " Match - continue
    jmp 1b              " No match - try next line
    sad o72             " End of username?
    skp                 " No, keep comparing
    jmp 2b              " Yes, found user!
```

**Extracting the home directory name:**

After finding the matching username, init parses the line to extract:
1. **Password** (between first and second ':')
2. **UID** (between second and third ':')
3. **Directory name** (after third ':')

```assembly
" Extract directory name (after third colon)
    dzm nchar           " Character counter
    law dir-1           " Directory name buffer
    dac 8
1:
    lac 9 i             " Get next character
    sad o72             " Is it ':'?
    jmp 1f              " Yes, end of field
    dac char            " No, save character

    " Pack 2 characters per word (9 bits each)
    lac nchar
    sza                 " Is nchar zero?
    jmp 2f              " No, pack with previous char

    " First character - shift left 9 bits
    lac char
    alss 9              " Arithmetic left shift 9
    xor o40             " Toggle case bit (?)
    dac 8 i             " Store first character
    dac nchar           " Mark as having one char
    jmp 1b

2:  " Second character - combine with first
    dzm nchar           " Reset character count
    lac 8               " Get word with first char
    add char            " Add second character
    dac 8               " Store complete word
    jmp 1b

1:  " Directory name extracted
```

### Setting User Context

Once authenticated, init sets up the user environment:

```assembly
" Extract UID
    jms getuid          " Parse UID from file

" Set user ID
    sys setuid          " Become that user

" Change to user's home directory
    sys chdir; dirname  " Change to /dd/<dirname>

" Look for user's shell
    sys open; sh; 0     " Try to open "sh" in user's dir
    spa                 " Skip if successful
    jmp 1f              " Failed - try default
    jmp havesh

1:  " Link default shell
    sys link; systemsh; sh

havesh:
    " Load shell into memory at high address
    lac d1
    sys read; 017700; 256   " Read shell code

    " Execute shell
    jmp 017700
```

**What's happening here:**

1. **setuid**: Kernel changes process's UID to the user's ID
2. **chdir**: Changes current directory to user's home (e.g., `/dd/ken`)
3. **Shell loading**: Tries to find shell in user's directory
4. **Fallback**: If no user shell, links from `/system/sh`
5. **Execution**: Loads shell into high memory and jumps to it

**Why load at 017700?**
- High memory address (near end of 8K address space)
- Avoids overwriting init's code
- Shell can use lower memory for its own data

## 6.4 Memory Layout During Boot

The boot process transforms memory from empty to fully operational:

### T+0: Power On
```
0000-0100:  [Undefined - random bits]
0100-7777:  [Undefined - random bits]
```

### T+100ms: Bootstrap Loaded
```
0000-0040:  [Bootstrap code - entered via front panel]
0040-7777:  [Undefined]
```

### T+500ms: Coldentry Running
```
0000-0020:  Interrupt vectors
0020:       System call vector
0100:       coldentry start
0100-2000:  Kernel code (s1-s9)
2000-3000:  Kernel data structures
3000-4000:  Disk buffers
4000-7777:  [Free for user process]
```

### T+5000ms: Init Running
```
0000-0020:  Interrupt vectors
0020:       System call vector → kernel entry
0100-2000:  Kernel code (resident)
2000-3000:  Kernel data
3000-4000:  Disk buffers
4000-5000:  Init code and data
5000-7777:  [Free]
```

### T+10000ms: User Logged In, Shell Running
```
0000-0020:  Interrupt vectors
0020:       System call vector
0100-2000:  Kernel code
2000-3000:  Kernel data
3000-4000:  Disk buffers
4000-6000:  Shell code and data
6000-7700:  [Free for shell's use]
7700-7777:  [Shell stack area]
```

## 6.5 Historical Context: Boot Processes in 1969

### Other Systems' Boot Processes

**IBM System/360 (1964)**
- **IPL** (Initial Program Load) via card deck or tape
- Multi-stage bootstrap
- Operator intervention at each stage
- Boot time: 5-10 minutes

**DEC PDP-10 / TOPS-10 (1967)**
- Paper tape bootstrap (50-100 ft of tape)
- Manual switch entry of initial loader
- Multiple program loads from tape
- Boot time: 10-15 minutes

**Multics on GE 645 (1969)**
- Complex multi-volume tape bootstrap
- Operator commands at multiple stages
- System generation could take hours
- Reboot time: 20-30 minutes

**DEC PDP-11 / Unix V1 (1971)**
- Single-stage bootstrap from disk
- Much faster than PDP-7 (better hardware)
- Boot time: 3-5 seconds

### What Made PDP-7 Unix Different

1. **Speed**: 5 seconds vs. 10-30 minutes for competitors
2. **Simplicity**: 40 lines of code vs. thousands
3. **Automation**: Minimal operator intervention
4. **Recovery**: Could rebuild filesystem from tape in minutes
5. **Self-contained**: Everything on one DECtape

## 6.6 The Evolution of Unix Booting

### PDP-7 Unix (1970)
- Paper tape cold boot
- DECtape warm boot
- No bootloader separation

### Unix V1 (1971) - PDP-11
- Disk bootstrap
- Separate boot block
- Faster hardware

### Unix V6 (1975) - PDP-11
- Two-stage boot
- `/boot` program loads `/unix`
- More sophisticated filesystem

### Unix V7 (1979) - PDP-11
- `/boot` loads `/unix`
- Multi-user init with `/etc/inittab`
- Run levels introduced

### Modern Linux (2020s)
- Multi-stage boot (BIOS/UEFI → bootloader → kernel → init)
- GRUB/systemd complexity
- But core concepts unchanged:
  - Kernel loads into memory
  - init starts as PID 1
  - init spawns login processes

**The PDP-7 pattern persists 50+ years later!**

## 6.7 Clever Optimizations

### Re-entrance Guard

```assembly
coldentry:
    dzm 0100            " Clear location 100
```

**Why?** If cold start code runs twice (operator error), location 0100 will already be zero on second entry. Code could check this and halt instead of destroying the running system.

### Single-Track System Data

All system metadata fits in one DECtape track (64 words):
- Free block list (10 blocks cached)
- Unique ID counter
- System time (2 words)

**Benefit**: Single disk I/O operation to save/restore entire system state.

### Shared Buffer Space

The disk buffer at 07700 is reused:
- During boot: holds system data being loaded
- After boot: serves as disk I/O buffer
- Saves precious memory

### Init as Inode 3

**Why number 3?**
- Inode 0: Invalid/unused
- Inode 1: Root directory (`/`)
- Inode 2: `/dd` directory
- Inode 3: `init` executable

Hard-coding inode 3 means cold boot can find init without a pathname parser!

## 6.8 Lessons from PDP-7 Boot Process

### Design Principles

1. **Simplicity**: Minimal code, minimal steps
2. **Speed**: Every operation essential
3. **Reliability**: Checksum verification, minimal operator intervention
4. **Recoverability**: Can rebuild from scratch
5. **Self-contained**: No external dependencies beyond paper tape

### Modern Relevance

These principles influenced:
- **Embedded systems**: Many still use similar simple boot processes
- **Linux kernel**: "Keep boot fast and simple"
- **Container systems**: Fast initialization inspired by Unix
- **Cloud instances**: Rapid boot times essential

### What We Lost

Modern systems sacrifice boot simplicity for:
- Security (secure boot, verified boot)
- Flexibility (multiple init systems, configuration)
- Hardware support (thousands of drivers)
- Features (graphical boot, recovery modes)

**Trade-off**: Boot code grew from 40 lines to millions.

## 6.9 Hands-On: Tracing a Complete Boot

Let's trace every instruction during a cold boot:

```
[Operator enters bootstrap via front panel switches]

1. Load word 052000 into location 0000
2. Load word 064000 into location 0001
   ...
20. Toggle RUN switch

[Bootstrap code executes]
0000: 052000    " Enable paper tape reader
0001: 064000    " Wait for ready
0002: 030100    " Read word into location 0100
...
0020: 600100    " Jump to location 0100

[Coldentry code now executing from location 0100]
0100: 140100    " DZM 0100 (clear re-entrance guard)
0101: 740000    " CAF (clear all flags)
0102: 760002    " ION (interrupts on)
0103: 760020    " CLON (clock on)
0104: 603000    " LAW 3072 (display buffer size)
0105: 764014    " WCGA (write to graphics)
0106: 100500    " JMS dspinit (initialize display)
...

[Hours later, after filesystem is created, init forks shell]
4096: 140100    " Init code at location 4096
...
4200: 100300    " JMS init1 (fork TTY login)
...

[User types username and password]
...

[Shell loads and executes]
7700: 200377    " Shell code at high memory
...
7720: 740013    " OPR RAL (shell processing command)
```

**Complete boot: 5,000+ instructions executed in 5 seconds.**

## 6.10 Conclusion

The PDP-7 Unix boot process exemplifies the Unix philosophy:

> **"Do one thing and do it well"**

Boot code has one job: Get the system running as fast as possible with maximum reliability. At 40 lines of assembly code achieving a 5-second boot time, it succeeded brilliantly.

Every modern Unix-like system still follows this pattern:
1. Hardware/firmware loads small bootstrap
2. Bootstrap loads kernel into memory
3. Kernel initializes hardware and data structures
4. Kernel starts init as first process
5. Init spawns user environment

**Thompson and Ritchie got it right the first time. The design hasn't needed fundamental changes in 55 years.**

---

*"Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away."*
— Antoine de Saint-Exupéry

The PDP-7 Unix boot process achieved perfection.
