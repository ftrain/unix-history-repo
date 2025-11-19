# Chapter 11 - User Utilities: The Unix Philosophy Emerges

## 11.1 The Unix Philosophy in Code

The Unix philosophy—"Write programs that do one thing and do it well"—is often cited as a design principle deliberately chosen by the system's creators. But examining the PDP-7 Unix utilities reveals a different story: this philosophy emerged organically from the severe hardware constraints of 1969, not from abstract design goals.

### The Constraints That Shaped Philosophy

The PDP-7 provided only 8K words (16KB) of core memory. Each utility had to:
- Fit in minimal memory alongside the kernel
- Execute quickly on a slow processor (1.75 μs cycle time)
- Minimize disk I/O (DECtape operated at 350 bytes/second)
- Be simple enough to debug with primitive tools

These constraints made it impossible to write monolithic, feature-rich programs. The result was a collection of small, focused tools—not because Thompson and Ritchie read about modularity in a textbook, but because there was literally no room for anything else.

### Contrast with 1969 Computing Culture

To appreciate how revolutionary these utilities were, consider the dominant computing paradigms of 1969:

**Batch Processing Systems:**
- Jobs submitted via punched cards
- Hours between submission and results
- Programs were large, monolithic routines
- No interactive utilities at all

**Mainframe Time-Sharing (CTSS, Multics):**
- Complex command interpreters with built-in functionality
- Commands were part of the supervisor, not separate programs
- Heavy, feature-laden interfaces
- Commands had dozens of options and modes

**Minicomputer Monitors:**
- Paper-tape based systems
- Simple file operations in the monitor itself
- No concept of composable tools
- Everything was a built-in command

### The Unix Difference

PDP-7 Unix introduced something genuinely new:

1. **External Commands:** Utilities weren't built into the shell—they were separate executable files
2. **Uniform Interface:** All commands read from standard input and wrote to standard output
3. **Composability:** The simple I/O model meant tools could be chained (though pipes didn't exist yet on PDP-7)
4. **Minimal Feature Sets:** Each tool did exactly one thing

This wasn't planned. It was discovered.

### The Cultural Impact

What began as necessity became doctrine. When Unix moved to the PDP-11 with more memory, the small-tool philosophy persisted—not because of hardware limits, but because developers had learned its benefits:

- **Debuggability:** Small programs had fewer bugs
- **Reusability:** Simple tools combined in unexpected ways
- **Maintainability:** Each program was easy to understand
- **Testability:** Limited functionality meant complete testing was possible

The PDP-7 constraints had accidentally invented a better way to build systems.

## 11.2 File Viewing and Manipulation

### cat.s - Concatenate Files

**Purpose:** Display or concatenate file contents to standard output

**Lines of Code:** 146 (including I/O library)

**Why cat Matters:** This is arguably the simplest useful program in Unix. It demonstrates the complete pattern of Unix file I/O: open, read, process, write, close. Every Unix programmer learns by studying cat.

#### Complete Source Code with Analysis

```asm
" cat

   lac 017777 i          " Load argument count
   sad d4                " Skip if argument count differs from 4
   jmp nofiles           " No files specified
   lac 017777            " Get argument vector base
   tad d1                " Add 1
   tad d4                " Add 4 (skip past argv[0])
   dac name              " Store as current filename pointer

loop:
   sys open; name: 0; 0  " Open file for reading
   spa                   " Skip on positive AC (success)
   jmp badfile           " Handle open failure
   dac fi                " Save file descriptor

1:
   jms getc              " Get a character from input
   sad o4                " Skip if different from EOF (4)
   jmp 1f                " End of file reached
   jms putc              " Write character to output
   jmp 1b                " Continue reading

1:
   lac fi                " Load file descriptor
   sys close             " Close the input file

loop1:
   -4                    " Decrement argument count by 4
   tad 017777 i
   dac 017777 i
   sad d4                " Skip if more arguments remain
   jmp done              " All files processed
   lac name              " Advance to next filename
   tad d4
   dac name
   jmp loop              " Process next file

badfile:
   lac name              " Load filename pointer
   dac 1f
   lac d8                " File descriptor 8 (stderr? no, stdout=1)
   sys write; 1:0; 4     " Write "? " error prefix
   lac d8
   sys write; 1f; 2      " Write error message
   jmp loop1             " Continue with next file

1: 040;077012            " "? \n" error message
```

#### The Character Buffering System

The genius of cat is in its buffering. Rather than making a system call for every character, it uses 64-word buffers:

```asm
getc: 0
   lac ipt               " Load input pointer
   sad eipt              " Skip if different from end pointer
   jmp 1f                " Buffer empty, refill it
   dac 2f                " Save current pointer
   add o400000           " Increment pointer
   dac ipt
   ral                   " Rotate to check odd/even
   lac 2f i              " Load word from buffer
   szl                   " Skip if link was zero (even char)
   lrss 9                " Right shift 9 bits (get high char)
   and o177              " Mask to 7 bits
   sna                   " Skip if non-zero
   jmp getc+1            " Zero character, get next
   jmp getc i            " Return with character

1:
   lac fi                " Buffer empty - refill
   sys read; iipt+1; 64  " Read 64 words from file
   sna                   " Skip if non-zero (got data)
   jmp 1f                " EOF reached
   tad iipt              " Calculate new end pointer
   dac eipt
   lac iipt              " Reset input pointer to buffer start
   dac ipt
   jmp getc+1            " Try again

1:
   lac o4                " Return EOF (4)
   jmp getc i

putc: 0
   and o177              " Mask character to 7 bits
   dac 2f+1              " Save character
   lac opt               " Load output pointer
   dac 2f
   add o400000           " Increment pointer
   dac opt
   spa                   " Skip on positive (even character)
   jmp 1f                " Odd character
   lac 2f i              " Even: load existing word
   xor 2f+1              " OR in new character
   jmp 3f
1:
   lac 2f+1              " Odd: shift left 9 bits
   alss 9
3:
   dac 2f i              " Store back to buffer
   isz noc               " Increment character count
   lac noc
   sad d128              " Skip if different from 128
   skp
   jmp putc i            " Not full yet, return
   lac fo                " Buffer full - flush it
   sys write; iopt+1; 64 " Write 64 words
   lac iopt              " Reset output pointer
   dac opt
   dzm noc               " Clear character count
   jmp putc i
2: 0;0

ipt: 0                   " Input pointer
eipt: 0                  " End of input buffer pointer
iipt: .+1; .=.+64        " Input buffer (64 words)
fi: 0                    " File descriptor
opt: .+2                 " Output pointer
iopt: .+1; .=.+64        " Output buffer (64 words)
noc: 0                   " Number of output characters
fo: 1                    " File descriptor for stdout

d1: 1
o4:d4: 4
d8: 8
o400000: 0400000
o177: 0177
d128: 128
```

#### Character Packing Deep Dive

The PDP-7 stored two 9-bit characters per 18-bit word. This code brilliantly handles the packing:

**Getting a character (even position):**
1. Load word: `01234567 001234567` (two 9-bit chars)
2. Mask low 9 bits: `000000000 001234567`
3. Result: right character

**Getting a character (odd position):**
1. Load word: `01234567 001234567`
2. Right shift 9: `000000000 001234567` (discard low bits)
3. Result: left character

**Putting a character (even position):**
1. Character to write: `001234567`
2. Shift left 9: `01234567 000000000`
3. OR with existing: combines both characters

**Putting a character (odd position):**
1. Character already in low 9 bits
2. XOR with existing word (sets high bits)

This is optimal PDP-7 assembly code—no wasted instructions.

#### Historical Note: cat as the Example Program

In Dennis Ritchie's Unix papers, cat is always the first program shown. It's the "Hello World" of systems programming:

- Simple enough to understand in minutes
- Complex enough to show real I/O patterns
- Actually useful in daily work
- Demonstrates Unix design principles

The PDP-7 cat is 146 lines. Modern GNU cat is over 800 lines with features like showing tabs, line numbers, and non-printing characters. The PDP-7 version does one thing: copy files to output. Nothing more.

### cp.s - Copy Files

**Purpose:** Copy one file to another

**Lines of Code:** 97

**Why Copying Was Non-Trivial in 1969:**

Modern programmers take file copying for granted. In 1969, it was challenging:

- No standard library functions
- Must handle partial reads
- Must create destination file with correct permissions
- Limited memory means careful buffering
- Errors must be reported but shouldn't crash the system

#### Complete Source Code with Analysis

```asm
" cp

   lac 017777            " Get argument vector base
   tad d1
   dac name2             " Point to second filename
loop:
   lac 017777 i          " Get argument count
   sad d4                " Skip if exactly 4 (no args left)
   sys exit              " Done - exit cleanly
   sad d8                " Skip if different from 8
   jmp unbal             " Unbalanced arguments
   tad dm8               " Subtract 8 (two filenames)
   dac 017777 i
   lac name2             " Get filename pointer
   tad d4                " Advance past first name
   dac name1             " Source filename
   tad d4                " Advance to next pair
   dac name2             " Destination filename
   sys open; name1: 0; 0 " Open source file
   spa                   " Skip on positive (success)
   jmp error             " Can't open source
   lac o17               " Mode 017 (rw-rw-rw-)
   sys creat; name2: 0   " Create destination file
   spa                   " Skip on positive (success)
   jmp error             " Can't create destination
   dzm nin               " Clear bytes-read counter

1:
   lac bufp              " Get buffer address
   tad nin               " Add current position
   dac 0f                " Store as read address
   -1
   tad nin
   cma
   tad d1024             " Calculate remaining space
   dac 0f+1              " Store as read count
   lac d2                " File descriptor 2 (source)
   sys read; 0:..;..     " Read up to 1024 words
   sna                   " Skip if non-zero (got data)
   jmp 2f                " EOF or error
   tad nin               " Add to total bytes read
   dac nin
   sad d1024             " Skip if didn't read full buffer
   jmp 2f                " Got less, must be EOF
   jmp 1b                " Continue reading

2:
   lac nin               " Get total bytes read
   dac 2f                " Store as write count
   lac d3                " File descriptor 3 (destination)
   sys write; buf; 2: 0  " Write entire buffer
   dzm nin               " Reset counter
   lac 2b                " Check if last read was partial
   sad d1024
   jmp 1b                " Full read, get more data
   lac d2                " Partial read, done
   sys close             " Close source
   lac d3
   sys close             " Close destination
   jmp loop              " Process next file pair

error:
   lac name1             " Get source filename
   dac 1f
   lac d1                " FD 1 (stdout)
   sys write; 1: 0; 4    " Write filename
   lac d1
   sys write; mes; 1     " Write error message "? \n"
   lac name2             " Get destination filename
   dac 1f
   lac d1
   sys write; 1: 0; 4    " Write filename
   lac d1
   sys write; mes; 2     " Write error message
   jmp loop              " Continue with next pair

mes:
   040000;077012         " "? \n"

unbal:
   lac name2             " Unbalanced arguments error
   tad d4
   dac 1f
   lac d1
   sys write; 1: 0; 4
   lac d1
   sys write; mes; 2
   sys exit

d1: 1
d4: 4
d8: 8
o17: 017
dm8: -8
d3: 3
d1024: 1024
nin: 0                   " Number of words read
bufp: buf
d2: 2

buf:                     " Buffer allocated at end
```

#### The Buffering Strategy

cp uses a 1024-word buffer (2048 bytes). This is massive by PDP-7 standards—roughly 25% of available memory! Why so large?

**Performance Calculation:**
- DECtape: 350 bytes/second transfer rate
- System call overhead: ~50 instructions
- Small buffers: system call overhead dominates
- Large buffer: one call copies 2KB in 6 seconds

The math is brutal. With a 64-byte buffer, you'd make 32 system calls per 2KB, wasting most of your time in kernel mode. The 2KB buffer reduces this to one call, making copying 32× more efficient in syscall overhead alone.

**Memory Usage:**
- Code: ~97 words
- Buffer: 1024 words
- Total: ~1121 words (~2.2 KB)

This left ~6KB for the kernel and stack—tight but workable.

#### Error Handling Philosophy

Notice the error handling:
1. Report the error (write filename and "?")
2. Continue processing remaining files
3. Never crash

This is quintessentially Unix: be robust, report problems, keep going. A single bad file shouldn't kill the entire copy operation.

#### What's Missing vs. Modern cp

Modern GNU cp has:
- Recursive directory copying (-r)
- Preserve permissions/timestamps (-p)
- Interactive prompting (-i)
- Symbolic link handling (-s)
- Progress reporting
- Sparse file optimization
- Reflink support (COW filesystems)

PDP-7 cp has none of this. It copies one file to another. That's all. And that was enough.

### chmod.s - Change File Mode

**Purpose:** Change file permissions

**Lines of Code:** 77

**The Birth of Unix File Permissions:**

The chmod utility embodies one of Unix's most influential innovations: the permission mode bits. In 1969, most systems had crude access control—files were public or private. Unix introduced a three-level permission model (owner, group, other) with three permission types (read, write, execute) that would become universal.

#### Complete Source Code with Analysis

```asm
" chmode

   lac 017777 i          " Get argument count
   sad d4                " Skip if exactly 4 (no args)
   jmp error             " Need at least mode and one file

   lac 017777            " Get argv base
   tad d4                " Point to argv[1] (mode string)
   dac 8
   tad d1                " Point to argv[2] (first filename)
   dac name
   dzm octal             " Clear octal accumulator
   dzm nchar             " Clear character buffer
   -8                    " Process up to 8 octal digits
   dac c1

1:
   lac nchar             " Load character buffer
   dzm nchar             " Clear it
   sza                   " Skip if was zero
   jmp 2f                " Use buffered character
   lac 8 i               " Load word from mode string
   lmq                   " Save to MQ
   and o177              " Get low 9 bits (one character)
   dac nchar             " Save character
   lacq                  " Restore word
   lrss 9                " Shift right to get high character

2:
   sad o40               " Skip if different from space (040)
   jmp 3f                " Space - ignore it
   tad om60              " Subtract '0' (060 octal)
   lmq                   " Save digit in MQ
   lac octal             " Get current value
   cll; als 3            " Shift left 3 bits (multiply by 8)
   omq                   " OR in new digit
   dac octal             " Save result

3:
   isz c1                " Count characters processed
   jmp 1b                " Continue parsing

loop:
   lac 017777 i          " Get argument count
   sad d8                " Skip if exactly 8 (no more files)
   sys exit              " Done
   tad dm4               " Subtract 4 (one filename)
   dac 017777 i
   lac name              " Advance to next filename
   tad d4
   dac name
   lac octal             " Get parsed mode
   sys chmode; name:0    " Change file mode
   sma                   " Skip if minus (error)
   jmp loop              " Success, continue
   lac name              " Error - print filename
   dac 1f
   lac d1
   sys write; 1:0; 4
   lac d1
   sys write; 1f; 2      " Print "? \n"
   jmp loop

1:
   040;077012            " "? \n"

error:
   lac d1
   sys write; 1b+1; 1    " Print error and exit
   sys exit

om60: -060               " -'0'
o40: 040                 " Space
d1: 1
d8: 8
dm4: -4
d4: 4
o177: 0177

nchar: .=.+1             " Character buffer
c1: .=.+1                " Counter
octal: .=.+1             " Octal accumulator
```

#### Octal Parsing Algorithm

The octal parsing is elegant in its simplicity:

```
Input: "755"
Step 1: Parse '7'
  - Subtract '0': 7
  - Shift accumulator left 3 bits: 0 → 0
  - OR in 7: 0 | 7 = 7 (binary: 111)

Step 2: Parse '5'
  - Subtract '0': 5
  - Shift accumulator left 3 bits: 7 → 56 (binary: 111000)
  - OR in 5: 56 | 5 = 61 (binary: 111101)

Step 3: Parse '5'
  - Subtract '0': 5
  - Shift accumulator left 3 bits: 61 → 488 (binary: 111101000)
  - OR in 5: 488 | 5 = 493 (binary: 111101101)

Result: 0755 octal = 493 decimal = 111101101 binary
         rwxr-xr-x
```

Each octal digit represents exactly 3 permission bits:
- 7 (111): read + write + execute
- 5 (101): read + execute
- 4 (100): read only

#### Permission Bit Layout

On PDP-7 Unix, the mode bits were:

```
Bit 0-2: Other permissions (---rwx)
Bit 3-5: Group permissions (rwx---)
Bit 6-8: Owner permissions (rwx---)
Bit 9:   Set-UID bit
Bit 10:  Large file bit
Bit 11:  Directory bit
```

So mode 0755:
```
Binary: 111 101 101
        rwx r-x r-x
        Owner can read, write, execute
        Group can read and execute
        Other can read and execute
```

#### Historical Context: Revolutionary Access Control

Before Unix, access control was typically:
- **CTSS:** Owner vs. non-owner
- **Multics:** Complex ACLs (Access Control Lists)
- **Batch systems:** No file protection at all

Unix struck a balance:
- Simple enough to understand instantly
- Powerful enough for real security needs
- Fast to check (just bit masking)
- Compact (fits in a few bits)

This model was so successful that it spread to:
- Every Unix variant
- Linux
- macOS
- Android
- Embedded systems

Billions of devices now use the permission model that was born in these 77 lines of PDP-7 assembly.

### chown.s - Change Owner

**Purpose:** Change file ownership

**Lines of Code:** 78

**Multi-User System Concepts:**

chown is nearly identical to chmod in implementation, but conceptually it represents something profound: Unix was designed from day one as a multi-user system. On a machine that was basically a personal workstation for two people (Thompson and Ritchie), they built infrastructure for user IDs, ownership, and access control.

#### Complete Source Code

```asm
" chowner

   lac 017777 i          " Get argument count
   sad d4                " Skip if exactly 4
   jmp error             " Need at least UID and one file

   lac 017777            " Get argv base
   tad d4                " Point to argv[1] (UID string)
   dac 8
   tad d1                " Point to argv[2] (first filename)
   dac name
   dzm octal             " Clear octal accumulator
   dzm nchar             " Clear character buffer
   -8                    " Process up to 8 octal digits
   dac c1

1:
   lac nchar             " Same parsing logic as chmod
   dzm nchar
   sza
   jmp 2f
   lac 8 i
   lmq
   and o177
   dac nchar
   lacq
   lrss 9

2:
   sad o40               " Skip spaces
   jmp 3f
   tad om60              " Convert ASCII to octal
   lmq
   lac octal
   cll; als 3            " Shift left 3 (multiply by 8)
   omq                   " OR in digit
   dac octal

3:
   isz c1
   jmp 1b

loop:
   lac 017777 i          " Get argument count
   sad d8                " Skip if no more files
   sys exit
   tad dm4               " Subtract 4
   dac 017777 i
   lac name              " Advance to next filename
   tad d4
   dac name
   lac octal             " Get parsed UID
   sys chowner; name:0   " Change file owner
   sma                   " Skip on minus (error)
   jmp loop
   lac name              " Error handling
   dac 1f
   lac d1
   sys write; 1:0; 4
   lac d1
   sys write; 1f; 2
   jmp loop

1:
   040;077012

error:
   lac d1
   sys write; 1b+1; 1
   sys exit

om60: -060
o40: 040
d1: 1
d8: 8
dm4: -4
d4: 4
o177: 0177

nchar: .=.+1
c1: .=.+1
octal: .=.+1
```

#### Code Reuse Through Copying

Notice that chmod.s and chown.s are nearly identical—only the system call differs (chmode vs. chowner). Modern programmers might write a shared library or template. In 1969:

- No linker sophisticated enough for shared libraries
- No macro system for code reuse
- No C language yet (this is assembly)
- Solution: Copy and modify

This was pragmatic. The duplication cost:
- 77 lines for chmod
- 78 lines for chown
- Total: 155 lines

A shared parsing library might have been:
- 50 lines of parsing code
- 30 lines for chmod
- 30 lines for chown
- 20 lines of calling convention
- Total: 130 lines

The "savings" of 25 lines wasn't worth the complexity of linking and calling conventions. Just copy it.

#### User ID System

The user ID (UID) was stored in the inode:

```
Inode structure (12 words):
Word 0:  Flags and type
Word 1:  Number of links
Word 2:  User ID (8 bits used)
Word 3:  Size (high byte)
Word 4:  Size (low word)
Word 5-11: Block addresses
```

User IDs were 8-bit values (0-255), though only a handful were used:
- 0: Root (super-user)
- 1: dmr (Dennis M. Ritchie)
- 2: ken (Ken Thompson)
- 3-255: Available for future users

The super-user (UID 0) could change any file's owner. Regular users could not. This root/user distinction has persisted in Unix for 55+ years.

### chrm.s - Change/Remove Utility

**Purpose:** Change directory and remove files

**Lines of Code:** 41

**The Simplest Utility:**

chrm is the shortest utility in PDP-7 Unix. It demonstrates the Unix philosophy in its purest form: do one thing, do it simply.

#### Complete Source Code with Analysis

```asm
" chrm

   lac 017777            " Get argv base
   tad d5                " Skip past argv[0] and argv[1]
   dac 1f                " Save as directory name pointer
   dac 2f                " Save as filename pointer
   lac 017777 i          " Get argument count
   sad d4                " Skip if exactly 4 (no args)
   sys exit              " Need at least directory
   tad dm4               " Subtract 4 (directory name)
   dac 017777 i
   sys chdir; dd         " Change to root directory first
   sys chdir; 1;0        " Then change to specified directory

1:
   lac 017777 i          " Get remaining argument count
   sad d4                " Skip if no more files
   sys exit
   tad dm4               " Subtract 4 (one filename)
   dac 017777 i
   lac 2f                " Get filename pointer
   tad d4                " Advance it
   dac 2f
   sys unlink; 2:0       " Unlink (delete) the file
   sma                   " Skip if minus (error)
   jmp 1b                " Success, continue
   lac 2b                " Error - print filename
   dac 2f
   lac d1
   sys write; 2:0; 4
   lac d1
   sys write; 1f; 2      " Print error message
   jmp 1b                " Continue

1:
   040077;012000         " Error message "? \n"

dd:
   <dd>;040040;040040;040040  " Root directory name

d1: 1
d4: 4
d5: 5
dm4: -4
```

#### Why Change Directory First?

The chdir before unlink is crucial. It allows removing files with simple names:

```
Without chdir:
  chrm /dd/dir1 /dd/dir1/file1 /dd/dir1/file2
  Must specify full paths for each file

With chdir:
  chrm dir1 file1 file2
  Much simpler
```

The "dd" directory is the root. The code does:
1. chdir to /dd (root)
2. chdir to user-specified directory
3. unlink each file in that directory

#### Design Question: Why Not Just rm?

Modern Unix has separate commands:
- cd - change directory
- rm - remove files

PDP-7 Unix combined them into chrm. Why?

**Memory Economics:**
- cd alone: ~20 lines
- rm alone: ~30 lines
- Both separate: 50 lines
- Combined: 41 lines
- Savings: 9 lines

But more importantly:
- Two separate commands: two executable files
- Each file needs inode, directory entry, disk blocks
- Minimum overhead: 1 block (64 words) per command
- Combined: save 64 words of disk

With a 64KB filesystem, every block mattered.

#### The "dd" Convention

Notice the hardcoded "dd" directory name. This was the root directory on PDP-7 Unix. Later Unix systems used "/" as root, but PDP-7 used a two-character directory name.

The dd directory was special:
- Always inode 41 (fixed location)
- Contained all top-level directories
- User directories were inside dd

So a full path looked like:
```
/dd/dmr/file.txt
    ^^^ root
        ^^^ user directory
            ^^^^^^^^ file
```

This is why the code does two chdir calls: first to dd (root), then to the user-specified subdirectory.

## 11.3 System Utilities

### check.s - File System Checker

**Purpose:** Verify filesystem integrity and detect corruption

**Lines of Code:** 324

**Why Filesystem Checking Was Critical:**

DECtape was notoriously unreliable. Power failures, mechanical issues, and software bugs could corrupt the filesystem. The check utility was essential:

- Run at boot to verify filesystem integrity
- Detect duplicate block allocation (fatal error)
- Find lost blocks (allocated but not in any file)
- Count inodes and blocks
- Repair some types of corruption

This is the ancestor of fsck, one of Unix's most important system utilities.

#### Complete Implementation with Extensive Commentary

```asm
" check

" ============================================
" PHASE 1: INITIALIZATION
" Get kernel data structure addresses via sysloc
" ============================================

lac d1
sys sysloc                " Get address of iget() function
dac iget

lac d2
sys sysloc                " Get address of current inode structure
dac inode

lac d4
sys sysloc                " Get address of free block list
dac nxfblk                " Next free block pointer
tad d1
dac nfblks                " Number of free blocks
tad d1
dac fblks                 " Free blocks array

lac d5
sys sysloc                " Get address of memory copy function
dac copy

lac d6
sys sysloc                " Get address of zero-fill function
dac copyz

lac d7
sys sysloc                " Get address of range checking function
dac betwen

lac d8
sys sysloc                " Get address of disk read function
dac dskrd

lac d10
sys sysloc                " Get address of disk buffer
dac dskbuf
dac dskbuf1

   dzm indircnt           " Clear indirect block counter
   dzm icnt               " Clear inode counter
   dzm licnt              " Clear large file counter
   dzm blcnt              " Clear block counter
   dzm curi               " Clear current inode number
   jms copyz i; usetab; 500  " Zero out the usage table (500 words)

" ============================================
" PHASE 2: INODE SCANNING LOOP
" Scan all 3400 inodes and check their blocks
" ============================================

iloop:
   isz curi               " Increment current inode number
   -3400                  " Check if we've scanned all inodes
   tad curi
   sma                    " Skip if minus (more inodes to check)
   jmp part2              " Done with inodes, move to part 2
   lac curi
   jms iget i             " Read inode from disk
   jms copy i; inode: 0; linode; 12  " Copy inode to local buffer
   lac iflags             " Get inode flags
   sma                    " Skip if minus (allocated)
   jmp iloop              " Free inode, skip it
   isz icnt               " Count allocated inodes
   lac iflags
   and o40                " Check special file bit
   sza                    " Skip if zero (regular file)
   jmp iloop              " Special file, skip block checking

" ============================================
" Check direct blocks (7 blocks per inode)
" ============================================

   law idskps             " Load address of disk block pointers
   dac t1
   -7                     " 7 direct blocks
   dac t2
1:
   lac i t1               " Load block number
   sza                    " Skip if zero (unused block)
   jms dupcheck           " Check if block is already used
   isz t1                 " Next block pointer
   isz t2                 " Decrement counter
   jmp 1b                 " Continue

" ============================================
" Check if this is a large file (has indirect blocks)
" ============================================

   lac iflags
   and o200000            " Check large file bit
   sna                    " Skip if non-zero (large file)
   jmp iloop              " Not large, continue to next inode

" ============================================
" Process indirect blocks for large files
" ============================================

   isz licnt              " Count large files
   law idskps             " Reload block pointers
   dac t1
   -7                     " 7 indirect block pointers
   dac t2
1:
   lac i t1               " Load indirect block number
   sna                    " Skip if non-zero
   jmp 3f                 " Zero, skip to next
   jms dskrd i            " Read the indirect block
   jms copy i; dskbuf: 0; ldskbuf; 64  " Copy to local buffer
   isz indircnt           " Count indirect blocks
   law ldskbuf            " Point to indirect block data
   dac t3
   -64                    " 64 block pointers per indirect block
   dac t4
2:
   lac i t3               " Load block number from indirect block
   sza                    " Skip if zero
   jms dupcheck           " Check for duplicates
   isz t3
   isz t4
   jmp 2b                 " Continue through indirect block
3:
   isz t1                 " Next indirect block pointer
   isz t2
   jmp 1b                 " Continue through all 7 indirect pointers
   jmp iloop              " Done with this inode

" ============================================
" DUPCHECK SUBROUTINE
" Checks if a block is already marked as used
" If already used: DUPLICATE (serious error)
" If not used: Mark it as used
" ============================================

dupcheck: 0
   isz blcnt              " Count total blocks used
   jms betwen i; d709; d6400  " Check if block in valid range
   jmp badadr             " Out of range - bad address
   dac t5                 " Save block number
   lrss 4                 " Divide by 16 (word index in table)
   tad usetabp            " Add to usage table base
   dac t6                 " t6 = address of word in usage table
   cla
   llss 4                 " Get bit position within word
   tad alsscom            " Build shift instruction
   dac 2f                 " Self-modifying code!
   lac d1
2: alss 0                 " Shift 1 by bit position
   dac bit                " This is the bit mask
   lac i t6               " Load usage table word
   and bit                " Check if bit already set
   sza                    " Skip if zero (not used)
   jmp dup                " DUPLICATE BLOCK ERROR!
   lac i t6               " Not used - mark it
   xor bit                " Set the bit (XOR same as OR for setting)
   dac i t6               " Store back
   jmp i dupcheck         " Return

badadr:
   jms print              " Print error message
   lac d1
   sys write; badmes; 3   " "bad\n"
   jmp i dupcheck

badmes:
   < b>;<ad>;<r 012

dup:
   lac t5                 " Print block number
   jms print
   lac d1
   sys write; dupmes; 3   " "dup "
   lac curi               " Print inode number
   jms print
   lac d1
   sys write; dupmes+3; 1 " "\n"
   jmp i dupcheck

dupmes:
   < d>;<up>; 040; 012

" ============================================
" PRINT SUBROUTINE
" Print a number in octal
" ============================================

print: 0
   lmq                    " Save number in MQ
   law prbuf-1            " Point to print buffer
   dac 8
   -6                     " 6 octal digits
   dac t6
1:
   cla
   llss 3                 " Get low 3 bits (one octal digit)
   tad o60                " Convert to ASCII ('0' = 060)
   dac i 8                " Store in buffer
   isz t6
   jmp 1b                 " Continue
   lac d1
   sys write; prbuf; 6    " Write the 6-digit number
   jmp i print

" ============================================
" PHASE 2: CHECK FREE BLOCK LIST
" Verify that all blocks in the free list are valid
" and not already marked as used
" ============================================

part2:
   lac icnt               " Print statistics
   jmp print              " (jmp instead of jms - print doesn't return)
   lac d1
   sys write; m3; m3s     " " files\n"
   lac licnt
   jms print
   lac d1
   sys write; m4; m4s     " large\n"
   lac indircnt
   jms print
   lac d1
   sys write; m5; m5s     " indir\n"
   lac blcnt
   jms print
   lac d1
   sys write; m6; m6s     " used\n"
   dzm blcnt              " Reset block counter for free list

" Check blocks in the in-core free list
   -1
   tad nfblks i           " Get number of free blocks
   cma
   sma                    " Skip if there are blocks
   jmp 2f                 " No blocks in free list
   dac t1                 " Counter
   lac fblks              " Free blocks array
   dac t2                 " Pointer
1:
   lac i t2               " Load free block number
   jms dupcheck           " Check it
   isz t2
   isz t1
   jmp 1b                 " Continue

" Walk the linked list of free block buffers on disk
2:
   lac nxfblk i           " Get next free block buffer address
1:
   sna                    " Skip if non-zero (more buffers)
   jmp part3              " Done with free list
   dac t1
   jms dupcheck           " Check the buffer block itself
   lac t1
   jms dskrd i            " Read the buffer
   jms copy i; dskbuf1: 0; ldskbuf; 64
   law ldskbuf
   dac t1
   -9                     " 9 free blocks per buffer (word 0 is link)
   dac t2
2:
   isz t1                 " Skip link word
   lac i t1               " Load free block number
   jms dupcheck           " Check it
   isz t2
   jmp 2b
   lac ldskbuf            " Get link to next buffer
   jmp 1b                 " Continue

" ============================================
" PHASE 3: FIND MISSING BLOCKS
" Any blocks not marked in usage table are lost
" ============================================

part3:
   lac blcnt              " Print free blocks count
   jms print
   lac d1
   sys write; m7; m7s     " " free\n"
   lac d709               " Start at block 709 (first data block)
   dac t1
1:
   isz t1                 " Next block
   lac t1
   sad d6400              " Skip if reached end (block 6400)
   sys exit               " Done - exit successfully
   lrss 4                 " Divide by 16 (word index)
   tad usetabp
   dac t2                 " t2 = usage table word address
   cla
   llss 4                 " Get bit position
   tad alsscom
   dac 2f
   lac d1
2: alss 0                 " Build bit mask
   dac bit
   lac i t2               " Load usage table word
   and bit                " Check if bit is set
   sza                    " Skip if zero (not used)
   jmp 1b                 " Used, continue
   lac t1                 " Not used - this block is missing!
   jms print
   lac d1
   sys write; m8; m8s     " " missing\n"
   jmp 1b

" ============================================
" DATA AND CONSTANTS
" ============================================

d1: 1
d2: 2
d4: 4
d5: 5
d6: 6
d7: 7
d8: 8
d10: 10
o60: 060
o400000: 0400000
o400001: 0400001
o40: 040
o200000: 0200000
alsscom: alss 0
d709: 709                 " First data block
d6400: 6400               " Last block + 1

m3:
   040;<fi>;<le>;<s 012
m3s = .-m3
m4:
   040;<la>;<rg>;<e 012
m4s = .-m4
m5:
   040;<in>;<di>;<r 012
m5s = .-m5
m6:
   040;<us>;<ed>;012
m6s = .-m6
m7:
   040;<fr>;<ee>;012
m7s = .-m7
m8:
   040;<mi>;<ss>;<in>;<g 012
m8s = .-m8

" ============================================
" VARIABLES AND BUFFERS
" ============================================

usetabp: usetab
curi: 0                   " Current inode number
bit: 0                    " Bit mask for usage table
blcnt: 0                  " Block count
indircnt: 0               " Indirect block count
icnt: 0                   " Inode count
licnt: 0                  " Large file count
t1: 0                     " Temporary variables
t2: 0
t3: 0
t4: 0
t5: 0
t6: 0

iget: 0                   " Kernel function pointers
nxfblk: 0
nfblks: 0
fblks: 0
copy: 0
copyz: 0
betwen: 0
dskrd: 0

ldskbuf: .=.+64           " Local disk buffer (64 words)
linode: .=.+12            " Local inode buffer (12 words)
iflags = linode           " Inode flags (word 0)
idskps = iflags+1         " Inode disk block pointers (words 1-7)
usetab: .=.+500           " Block usage table (500 words = 8000 bits)
prbuf: .=.+6              " Print buffer (6 characters)
```

#### The Bitmap Algorithm

The heart of check is the usage table—a bitmap tracking which blocks are allocated:

```
Block numbers: 709 - 6399 (5691 blocks total)
Bitmap size: 5691 bits = 356 words (rounded to 500)

For block number N:
  Word index = (N - 709) / 16
  Bit index = (N - 709) % 16

Example: Block 1000
  Word index = (1000 - 709) / 16 = 18
  Bit index = (1000 - 709) % 16 = 3

  Word usetab[18], bit 3
```

The code uses clever self-modifying code:

```asm
   llss 4                 " Shift left by bit position
   tad alsscom            " Add to "alss 0" instruction
   dac 2f                 " Store as next instruction
   lac d1
2: alss 0                 " This instruction is modified!
```

If bit index is 3, this generates:
```asm
   lac d1                 " AC = 1
   alss 3                 " AC = 1 << 3 = 8
```

Result: a bit mask with bit 3 set.

#### The Three-Phase Algorithm

**Phase 1: Scan all inodes**
- For each allocated inode
- Check all direct blocks (7 per inode)
- If large file, check indirect blocks (7 × 64 = 448 blocks max)
- Mark each block in usage table
- If already marked: DUPLICATE (fatal error)

**Phase 2: Check free block list**
- Walk in-core free list
- Follow linked list on disk
- Mark each free block
- If already marked: DUPLICATE (shouldn't be free!)

**Phase 3: Find missing blocks**
- Scan entire block range (709-6399)
- Any block not marked is "missing"
- Missing blocks are allocated but not in any file or free list
- These are lost blocks (can be added back to free list)

#### Duplicate Block Detection

Duplicate blocks are the worst filesystem corruption:

```
Example:
  Inode 100: contains blocks [1000, 1001, 1002]
  Inode 200: contains blocks [1001, 1003, 1004]

  Block 1001 appears in both inodes!
```

What happens:
1. Reading is unpredictable (which inode's data?)
2. Writing corrupts both files
3. Deleting one file frees the block, corrupting the other

check detects this and reports:

```
1001 dup 100
1001 dup 200
```

The operator must then manually fix the filesystem (usually by deleting one or both files).

#### Modern fsck Descended From This

This 324-line program is the ancestor of:
- Unix fsck (file system check)
- Linux e2fsck
- macOS fsck_hfs
- Windows chkdsk (conceptually)

The basic algorithm hasn't changed in 55 years:
1. Build bitmap of allocated blocks
2. Check for duplicates
3. Find missing blocks
4. Verify directory structure
5. Fix what you can

Modern fsck is thousands of lines and handles:
- Multiple filesystem types
- Journaling
- Extents instead of blocks
- Symbolic links
- Extended attributes
- Quotas

But the core logic—scan inodes, mark blocks, find duplicates—is identical to the PDP-7 version.

### init.s - System Initialization and Login

**Purpose:** First user-space process; handles login and starts shells

**Lines of Code:** 292

**Revolutionary Concepts:**

init embodies several revolutionary ideas:

1. **First User Process:** Process ID 1, parent of all user processes
2. **Multi-User Login:** Separate login sessions on different terminals
3. **Password Authentication:** The birth of Unix security
4. **Shell Execution:** Loads and runs the command interpreter

In 1969, most systems had at most a single operator console. Unix supported multiple simultaneous users—even on a machine with only two terminals!

#### Complete Implementation with Analysis

```asm
" init

   -1
   sys intrp              " Ignore interrupts initially
   jms init1              " Start terminal 1 login
   jms init2              " Start terminal 2 login
1:
   sys rmes               " Wait for child to exit (receive message)
   sad pid1               " Skip if different from terminal 1 PID
   jmp 1f
   sad pid2               " Skip if different from terminal 2 PID
   jms init2              " Terminal 2 exited, restart it
   jmp 1                  " Wait for next exit

1:
   jms init1              " Terminal 1 exited, restart it
   jmp 1                  " Continue waiting

" ============================================
" INIT1: Initialize terminal 1 (TTY)
" ============================================

init1: 0
   sys fork               " Create child process
   jmp 1f                 " Parent continues here
   sys open; ttyin; 0     " Child: open TTY input (FD 0 = stdin)
   sys open; ttyout; 1    " Open TTY output (FD 1 = stdout)
   jmp login              " Go to login process
1:
   dac pid1               " Parent: save child PID
   jmp init1 i            " Return

" ============================================
" INIT2: Initialize terminal 2 (Display)
" ============================================

init2: 0
   sys fork               " Create child process
   jmp 1f                 " Parent continues here
   sys open; keybd; 0     " Child: open keyboard (FD 0)
   sys open; displ; 1     " Open display (FD 1)
   jmp login              " Go to login process
1:
   dac pid2               " Parent: save child PID
   jmp init2 i            " Return

" ============================================
" LOGIN: Handle user authentication
" ============================================

login:
   -1
   sys intrp              " Ignore interrupts during login
   sys open; password; 0  " Open password file (FD 2)
   lac d1
   sys write; m1; m1s     " Write "login: "
   jms rline              " Read username from terminal
   lac ebufp
   dac tal                " Save end of buffer pointer
1:
   jms gline              " Get line from password file
   law ibuf-1             " Point to input buffer (username)
   dac 8
   law obuf-1             " Point to password file line
   dac 9

" Compare username with password file entry
2:
   lac 8 i                " Load character from input
   sac o12                " Skip if different from '\n'
   lac o72                " Load ':'
   sad 9 i                " Skip if different from password file
   skp
   jmp 1b                 " No match, try next line
   sad o72                " Skip if it was ':'
   skp
   jmp 2b                 " Continue comparing username
   lac 9 i                " Get next character from password file
   sad o72                " Skip if different from ':'
   jmp 1f                 " Username matches, check password

" Username matched but wrong terminator
   -1
   tad 9
   dac 9
   lac d1
   sys write; m3; m3s     " Write "password: "
   jms rline              " Read password
   law ibuf-1
   dac 8

" Compare password
2:
   lac 8 i                " Load character from input
   sad o12                " Skip if different from '\n'
   lac o72                " Load ':'
   sad 9 i                " Skip if different from password file
   skp
   jmp error              " Password mismatch - error
   sad o72                " Skip if it was ':'
   skp
   jmp 2b                 " Continue comparing password

" ============================================
" PASSWORD ENTRY PARSING
" Extract home directory and UID from password entry
" Format: username:password:uid:directory
" ============================================

1:
   dzm nchar              " Clear character buffer
   law dir-1              " Point to directory name buffer
   dac 8
1:
   lac 9 i                " Get character from password file
   sad o72                " Skip if different from ':'
   jmp 1f                 " Found ':', done with directory
   dac char               " Save character
   lac nchar
   sza                    " Skip if zero (need new word)
   jmp 2f                 " Already have character in word

" Pack first character of a word (high 9 bits)
   lac char
   alss 9                 " Shift left 9 bits
   xor o40                " XOR with space (padding)
   dac 8 i                " Store in directory buffer
   dac nchar              " Save as current character
   jmp 1b

" Pack second character of a word (low 9 bits)
2:
   lac 8                  " Get current buffer pointer
   dac nchar              " Save as character position
   lac nchar i            " Load existing word
   and o777000            " Mask low 9 bits
   xor char               " OR in new character
   dac nchar i            " Store back
   dzm nchar              " Clear character buffer
   jmp 1b

" ============================================
" UID PARSING
" Extract user ID in octal
" ============================================

1:
   dzm nchar              " Clear octal accumulator
1:
   lac 9 i                " Get character
   sad o12                " Skip if different from '\n'
   jmp 2f                 " End of line, done
   tad om60               " Subtract '0'
   lmq                    " Save digit in MQ
   lac nchar              " Get current value
   cll; als 3             " Shift left 3 bits (multiply by 8)
   omq                    " OR in new digit
   dac nchar              " Save result
   jmp 1b

" ============================================
" SET USER CONTEXT AND EXECUTE SHELL
" ============================================

2:
   lac nchar
   sys setuid             " Set user ID
   sys chdir; dd          " Change to root
   sys chdir; dir         " Change to user's home directory

" Open shell executable
   lac d2
   sys close              " Close password file (FD 2)
   sys open; sh; 0        " Try to open "sh" (shell)
   sma                    " Skip if minus (failed)
   jmp 1f                 " Shell exists, use it

" Shell doesn't exist in user dir, link from system
   sys link; system; sh; sh  " Link /dd/system/sh to ./sh
   spa                    " Skip on positive (success)
   jmp error              " Link failed
   sys open; sh; 0        " Open the linked shell
   spa                    " Skip on positive (success)
   jmp error              " Open failed
   sys unlink; sh         " Unlink ./sh (already open)

" ============================================
" BOOTSTRAP SHELL EXECUTION
" The shell code is read into memory starting at 017700
" Then jumped to, effectively exec'ing it
" ============================================

1:
   law 017700             " Destination address for shell
   dac 9
   law boot-1             " Source: bootstrap code
   dac 8
1:
   lac 8 i                " Copy bootstrap code
   dac 9 i
   sza                    " Skip if zero (end marker)
   jmp 1b
   jmp 017701             " Jump to bootstrap code

" Bootstrap code (copied to high memory and executed)
boot:
   lac d2                 " FD 2 (shell file)
   lmq
   sys read; 4096; 07700  " Read shell into memory at 4096
   lacq
   sys close              " Close shell file
   jmp 4096               " Jump to shell entry point
   0                      " End marker

" ============================================
" RLINE: Read line from terminal
" Handles backspace (043) and line kill (0100)
" ============================================

rline: 0
   law ibuf-1             " Point to input buffer
   dac 8
1:
   cla
   sys read; char; 1      " Read one character
   lac char
   lrss 9                 " Get high byte (first character)
   sad o100               " Skip if different from line kill (@)
   jmp rline+1            " Line kill - start over
   sad o43                " Skip if different from backspace (#)
   jmp 2f                 " Backspace
   dac 8 i                " Store character in buffer
   sad o12                " Skip if different from '\n'
   jmp rline i            " End of line, return
   jmp 1b                 " Continue

2:
   law ibuf-1             " Backspace handling
   sad 8                  " Skip if different (not at start)
   jmp 1b                 " At start, ignore backspace
   -1                     " Back up one character
   tad 8
   dac 8
   jmp 1b

" ============================================
" GLINE: Get line from password file (FD 2)
" ============================================

gline: 0
   law obuf-1             " Point to output buffer
   dac 8
1:
   jms gchar              " Get character from file
   dac 8 i                " Store in buffer
   sad o12                " Skip if different from '\n'
   jmp gline i            " End of line, return
   jmp 1b

" ============================================
" GCHAR: Get character with buffering
" ============================================

gchar: 0
   lac tal                " Get current pointer
   sad ebufp              " Skip if different from end
   jmp 1f                 " Buffer empty, refill
   ral                    " Rotate to check odd/even
   lac tal i              " Load word
   snl                    " Skip if link was not set
   lrss 9                 " Shift right 9 (get high char)
   and o777               " Mask to 9 bits
   lmq                    " Save character
   lac tal                " Advance pointer
   add o400000
   dac tal
   lacq                   " Restore character
   sna                    " Skip if non-zero
   jmp gchar+1            " Zero, get next
   jmp gchar i            " Return character

" Refill buffer
1:
   lac bufp               " Reset to buffer start
   dac tal
1:
   dzm tal i              " Zero out buffer
   isz tal
   lac tal
   sad ebufp              " Skip if different from end
   skp
   jmp 1b                 " Continue zeroing
   lac bufp               " Reset pointer
   dac tal
   lac d2                 " FD 2 (password file)
   sys tead; buf; 64      " Read from tape (DECtape)
   sna                    " Skip if non-zero (got data)
   jmp error              " EOF or error
   jmp gchar+1            " Try again

" ============================================
" ERROR HANDLING
" ============================================

error:
   lac d1
   sys write; m2; m2s     " Write "?\n"
   lac d1
   sys smes               " Send message to init (tell parent we died)
   sys exit               " Exit

" ============================================
" MESSAGES
" ============================================

m1:
   012; <lo>;<gi>;<n;<:;<
m1s = .-m1
m2:
   <?; 012
m2s = .-m2
m3:
   <pa>;<ss>;<wo>;<rd>;<: 040
m3s = .-m3
dd:
   <dd>;040040;040040;040040
dir:
   040040;040040;040040;040040

" ============================================
" FILE NAMES
" ============================================

ttyin:
   <tt>;<yi>;<n 040;040040
ttyout:
   <tt>;<yo>;<ut>; 040040
keybd:
   <ke>;<yb>;<oa>;<rd>
displ:
   <di>;<sp>;<la>;<y 040
sh:
   <sh>; 040040;040040;040040
system:
   <sy>;<st>;<em>; 040040
password:
   <pa>;<ss>;<wo>;<rd>

" ============================================
" CONSTANTS AND BUFFERS
" ============================================

d1: 1
o43: 043                  " '#' (backspace)
o100: 0100                " '@' (line kill)
o400000; 0400000
d2: 2
o12: 012                  " '\n' (newline)
om60: -060                " -'0'
d3: 3
ebufp: buf+64             " End of buffer
bufp: buf
o777: 0777
o777000: 0777000
o40: 040                  " Space
o72: 072                  " ':' (field separator)

ibuf: .=.+100             " Input buffer
obuf: .=.+100             " Output buffer (password file line)
tal: .=.+1                " Tape/file pointer
buf: .=.+64               " File I/O buffer
char: .=.+1               " Character buffer
nchar: .=.+1              " Numeric character accumulator
pid1: .=.+1               " Process ID for terminal 1
pid2: .=.+1               " Process ID for terminal 2
```

#### The Password File Format

The password file had a simple format:

```
username:password:uid:directory\n
```

Example:
```
dmr:zyx123:1:dmr
ken:abc456:2:ken
```

Fields:
- **username:** User's login name
- **password:** Plain text password (no encryption!)
- **uid:** User ID in octal
- **directory:** Home directory name

The code parses this by looking for ':' delimiters.

#### Security in 1969

Notice: **passwords in plain text**. No encryption, no hashing. Why?

1. **Physical Security:** The PDP-7 was in a locked room
2. **Trusted Users:** Only Thompson, Ritchie, and maybe a few others
3. **No Network:** No remote access, no need to protect against remote attackers
4. **Cultural Norms:** Security wasn't a major concern in 1969 computing

Within a few years, Unix added crypt() and hashed passwords. But the PDP-7 version was truly naive.

#### The Multi-User Concept

init manages two login sessions:

**Terminal 1 (TTY):**
- Input: /dd/ttyin (teletype input)
- Output: /dd/ttyout (teletype output)
- Process ID saved in pid1

**Terminal 2 (Display):**
- Input: /dd/keyboar (keyboard)
- Output: /dd/display (vector display)
- Process ID saved in pid2

When a session exits (user logs out or shell crashes), init detects it via the rmes system call and automatically restarts that session.

This is the origin of the Unix login: daemon pattern that persists today:
- Modern Linux: systemd manages getty instances
- Modern Unix: init or launchd manages login sessions
- Same concept: monitor sessions, restart on exit

#### The Shell Bootstrap

The shell execution is fascinating. There's no exec() system call yet! Instead:

1. Read password file to find user's directory
2. chdir to user's home directory
3. Open "sh" file (the shell executable)
4. Copy bootstrap code to high memory (017700)
5. Jump to bootstrap
6. Bootstrap reads shell from file into memory at location 4096
7. Bootstrap closes file and jumps to 4096

This is a primitive form of exec() done entirely in user space!

Modern Unix has the exec() system call, which does all this in the kernel. But the PDP-7 version shows that it's just loading and jumping—no magic.

#### Cultural Impact: Multi-User Login in 1969

In 1969, most minicomputers supported one user at a time. Mainframes supported many users, but through complex job control systems.

Unix introduced:
- Simple login mechanism
- Per-user home directories
- User IDs and permissions
- Independent shell sessions
- Automatic session restart

This made multi-user computing accessible to small systems. Within a decade:
- VAX systems supported hundreds of users
- University computing labs used Unix terminals
- Time-sharing became commonplace

All of it started with this 292-line init program on a PDP-7.

### maksys.s - System Installation

**Purpose:** Copy a.out executable to disk track 18x

**Lines of Code:** 52

**System Installation Process:**

maksys is a tool for installing the system to a specific disk track. It writes an executable to a fixed location where the boot loader can find it.

#### Complete Source Code

```asm
" copy a.out to disk track 18x
" where x is the argument

   lac 017777 i; sad d8; skp; jmp error   " Need exactly 1 argument
   lac 017777; tad d5; dac track          " Get track number pointer
   lac i track; lrss 9; tad om60          " Parse track digit
   spa; jmp error; dac track              " Check valid
   tad dm10; sma; jmp error               " Must be 0-9

   sysopen; a.out; 0                      " Open a.out
   spa; jmp error
   sys read; bufp; buf; 3072              " Read 3072 words
   sad .-1                                " Skip if read exactly 3072
   jmp error                              " Wrong size

   dscs                                   " Disk control: clear and select
   -3072; dslw                            " Set word count: 3072
   lac bufp; dslm                         " Set memory address
   lac track; alss 8; xor o300000; dsld   " Set disk address
   lac o30000; dsls                       " Start disk write
   dssf; jmp .-1                          " Wait for done
   dsrs; spa; jmp error                   " Check status

   -1024; dslw                            " Write second part
   lac d3072; dslm
   lac track; alss 8; xor o300110; dsld
   lac o3000; dsls
   dssf; jmp .-1
   dsrs; spa; jmp error
   sys exit

error:
   lac d1; sys write; 1f; 2
   sys exit
1: 077077;012

dm10: -10
dm5: 5
om60: -060
o300000: 0300000
o300100: 0300110
d8: 8
d3072: 3072
o3000: 03000
d1: 1
a.out:
   <a.>;<ou>;<t 040;040040

track: .=.+1

buf:
```

#### Direct Disk I/O

This code uses direct disk I/O via the disk controller:

**Disk Commands:**
- `dscs` - Clear and select disk
- `dslw` - Load word count
- `dslm` - Load memory address
- `dsld` - Load disk address
- `dsls` - Start operation
- `dssf` - Skip if done
- `dsrs` - Read status

The disk address calculation:
```asm
lac track; alss 8; xor o300000; dsld
```

This builds a disk address from:
- Track number (0-9)
- Fixed sector (18)
- Read/write command bits

The system image is written to track 18x where x is the argument (0-9), allowing up to 10 different system images.

#### Why Fixed Locations?

The boot ROM knew to load from track 180-189. By writing system images to these tracks, you could boot different versions:

```
Track 180: Stable system
Track 181: Development system
Track 182: Experimental kernel
Track 183: Backup
...
```

At boot time, you'd select which track to load from.

### trysys.s - System Loader

**Purpose:** Load and execute a.out from disk

**Lines of Code:** 40

**Testing New Systems:**

trysys loads a system image into memory and jumps to it. This was used for testing new kernels without installing them to the boot track.

#### Complete Source Code

```asm
" trysys

   sys open; a.out; 0     " Open a.out
   spa
   jmp error              " Can't open
   sys read; buf; 3072    " Read entire file
   sad .-1                " Skip if read exactly 3072 words
   jmp error              " Wrong size
   iof                    " Interrupts off
   caf                    " Clear all flags
   cdf                    " Clear data field
   clof                   " Clear overflow
   law buf                " Source address
   dac t1
   dzm t2                 " Destination: address 0
   -3072
   dac c1                 " Counter

1:
   lac t1 i               " Copy loop
   dac t2 i               " Copy word from buffer to low memory
   isz t1                 " Increment source
   isz t2                 " Increment destination
   isz c1                 " Decrement counter
   jmp 1b                 " Continue
   jmp 0100               " Jump to system entry point (location 0100)

error:
   lac d1
   sys write; 1f; 1
   sys exit
1: 077012

a.out:
   <a.>;<ou>;<t 040; 040040
t1: 0
t2: 0
c1: 0
d1: 1
buf:
```

#### The Bootstrap Process

1. Open a.out
2. Read 3072 words into high memory buffer
3. Disable interrupts (about to overwrite kernel!)
4. Copy from buffer to address 0
5. Jump to location 0100 (system entry point)

This overwrites the current kernel with the new one and jumps to it. There's no way to recover if the new kernel is bad—you'd have to reboot from DECtape.

#### Why Location 0100?

The PDP-7 used locations 0-077 for special purposes:
- 0-7: Trap vectors
- 8-77: Reserved

Location 0100 (octal) = 64 (decimal) was the first safe location for code. All PDP-7 Unix programs started at 0100.

## 11.4 Disk Utilities

### dsksav.s / dskres.s - Disk Backup/Restore

**Purpose:** Backup and restore disk tracks

**Lines of Code:** 27 each

**Why Backup Was Critical:**

DECtape was unreliable. A backup strategy was essential:

1. **Regular Backups:** Save disk to tape weekly
2. **Before Experiments:** Backup before trying new code
3. **After Corruption:** Restore from last good backup

#### dsksav.s - Save Disk to Tape

```asm
" dsksav

   iof                    " Interrupts off
   hlt                    " Halt - operator starts with continue
   dzm track              " Start at track 0
   -640                   " 640 tracks total
   dac c1
1:
   lac track
   jms dskrd1             " Read from disk 1
   lac track
   jms dskwr0             " Write to disk 0 (tape)
   lac track
   tad d10                " Next track (10 sectors per track)
   dac track
   isz c1                 " Count down
   jmp 1b                 " Continue
   hlt                    " Done - halt
   sys exit

track: 0
c1: 0
d10: 10
```

#### dskres.s - Restore Disk from Tape

```asm
" dskres

   iof                    " Interrupts off
   hlt                    " Halt - operator starts
   dzm track              " Start at track 0
   -640                   " 640 tracks
   dac c1
1:
   lac track
   jms dskrd0             " Read from disk 0 (tape)
   lac track
   jms dskwr1             " Write to disk 1
   lac track
   tad d10
   dac track
   isz c1
   jmp 1b
   hlt
   sys exit

track: 0
c1: 0
d10: 10
```

#### The Disk Copy Strategy

Both programs use the same pattern:
1. Halt for operator to mount tapes
2. Loop through all tracks (0-6399 in steps of 10)
3. Read from source
4. Write to destination
5. Halt when done

The `hlt` instruction was crucial—it gave the operator time to:
- Mount the backup tape
- Verify everything was ready
- Press CONTINUE on the front panel to start

#### Disk Numbering

- **Disk 0:** DECtape drive (tape backup)
- **Disk 1:** Fixed disk or second DECtape

The utilities read from one and write to the other, creating a complete disk image.

#### No Error Checking

Notice: no error checking! If a read or write failed, the program continued anyway. Why?

1. **Simplicity:** Error handling would double the code size
2. **Operator Present:** Someone was physically watching the process
3. **Retry Manually:** If errors occurred, operator would halt and retry
4. **Trust Hardware:** DECtape was reliable enough most of the time

This reflects the 1969 philosophy: build simple tools, rely on humans for error recovery.

## 11.5 Common Patterns

Examining all these utilities reveals common patterns that emerged organically from PDP-7 programming:

### Pattern 1: Argument Parsing

**Standard argument vector:**
```
Location 017777:   Argument count (4 × number of args)
Location 017777+1: Pointer to argv[0]
Location 017777+2: Pointer to argv[1]
...
```

**Standard parsing loop:**
```asm
loop:
   lac 017777 i          " Get argument count
   sad d4                " Skip if exactly 4 (no args left)
   sys exit              " Done
   tad dm4               " Subtract 4
   dac 017777 i          " Update count
   lac nameptr           " Get current filename pointer
   tad d4                " Advance to next
   dac nameptr           " Store
   " ... process file ...
   jmp loop
```

This pattern appears in: cat, cp, chmod, chown, chrm

### Pattern 2: Character Packing/Unpacking

**Pack two 9-bit characters into 18-bit word:**
```asm
" Even character (high 9 bits)
lac char
alss 9                   " Shift left 9
dac word                 " Store

" Odd character (low 9 bits)
lac word
and o777000              " Keep high bits
xor char                 " OR in low bits
dac word
```

**Unpack:**
```asm
" Get even character (high 9 bits)
lac word
lrss 9                   " Shift right 9
and o777                 " Mask to 9 bits

" Get odd character (low 9 bits)
lac word
and o777                 " Mask to 9 bits
```

This pattern appears in: cat, init, and throughout the system

### Pattern 3: Buffered I/O

**Standard buffer structure:**
```asm
buf: .=.+64              " 64-word buffer
bufptr: buf              " Current position
endptr: buf+64           " End of buffer
```

**Read with buffering:**
```asm
getc:
   lac bufptr            " Get current position
   sad endptr            " Skip if not at end
   jmp fillbuf           " Refill buffer
   dac temp              " Save pointer
   add o400000           " Increment
   dac bufptr            " Update pointer
   " ... extract character ...
   jmp getc i            " Return

fillbuf:
   lac fd
   sys read; buf; 64     " Read 64 words
   lac buf
   dac bufptr            " Reset pointer
   jmp getc              " Retry
```

This pattern appears in: cat, cp, init

### Pattern 4: Error Reporting

**Standard error message:**
```asm
error:
   lac filename          " Get filename
   dac 1f
   lac d1                " FD 1 (stdout)
   sys write; 1: 0; 4    " Write filename (4 chars)
   lac d1
   sys write; errmsg; 2  " Write "? \n"
   jmp continue          " Keep going

errmsg:
   040;077012            " "? \n"
```

This pattern appears in: cat, cp, chmod, chown, chrm

### Pattern 5: Octal Parsing

**Convert ASCII octal string to number:**
```asm
   dzm result            " Clear result
   -8                    " Up to 8 digits
   dac count
1:
   " ... get next character ...
   tad om60              " Subtract '0' (060 octal)
   lmq                   " Save digit
   lac result
   cll; als 3            " Shift left 3 (× 8)
   omq                   " OR in digit
   dac result
   isz count
   jmp 1b
```

This pattern appears in: chmod, chown, init

### Pattern 6: Self-Modifying Code

**Build instructions at runtime:**
```asm
   lac bitpos            " Get bit position
   tad shiftinst         " Add to instruction template
   dac 1f                " Store as next instruction
   lac d1
1: alss 0                " This instruction is modified!
```

This pattern appears in: check (for bitmap operations)

### Pattern 7: Word-Aligned String Storage

**Store strings as packed characters:**
```asm
filename:
   <ab>;<cd>;<ef>; 040040    " "abcdef  "

" First word: 'a' in high 9 bits, 'b' in low 9 bits
" Second word: 'c' and 'd'
" Third word: 'e' and 'f'
" Fourth word: two spaces (padding)
```

This pattern appears in: all utilities for filenames and messages

## 11.6 The Minimalist Aesthetic

### Lines of Code Comparison

| Utility | PDP-7 Lines | Modern Lines | Ratio |
|---------|-------------|--------------|-------|
| cat | 146 | ~800 (GNU cat) | 5.5× |
| cp | 97 | ~1200 (GNU cp) | 12.4× |
| chmod | 77 | ~600 (GNU chmod) | 7.8× |
| chown | 78 | ~500 (GNU chown) | 6.4× |
| init | 292 | ~2500 (systemd) | 8.6× |
| fsck (check) | 324 | ~15000 (e2fsck) | 46.3× |
| **Total** | **1014** | **~20600** | **20.3×** |

Modern versions are 20× larger on average. Why?

**Features Added:**
- Internationalization (i18n)
- Long options (--help, --version)
- Security hardening
- Extended attributes
- Unicode support
- Error recovery
- Progress reporting
- Accessibility

**What's Missing From PDP-7 Versions:**

cat:
- No line numbering (-n)
- No tab display (-T)
- No non-printing characters (-v)
- No squeeze blank lines (-s)

cp:
- No recursive copy (-r)
- No preserve permissions (-p)
- No interactive prompting (-i)
- No verbose mode (-v)
- No symlink handling

chmod:
- No symbolic modes (u+rwx)
- No recursive (-R)
- No verbose (-v)
- No reference file

check:
- No automatic repair
- No journaling support
- No progress reporting
- No bad block handling
- No snapshot support

### Why Less Was More

The minimal feature set was actually beneficial:

**Advantages:**
1. **Understandable:** Anyone could read the entire source
2. **Debuggable:** Fewer bugs due to simpler code
3. **Maintainable:** Easy to modify or fix
4. **Portable:** Simple code ported to new systems easily
5. **Fast:** No overhead from unused features

**Memory Savings:**

```
PDP-7 utilities total: 1014 lines × ~10 bytes/line = ~10KB
Modern utilities total: 20600 lines × ~40 bytes/line = ~800KB

Ratio: Modern versions are 80× larger in binary size
```

The entire set of PDP-7 utilities fit in 10KB. Modern cat alone is often 50KB+.

### The Constraint-Driven Design Process

How did minimalism emerge?

1. **Write Initial Version:** Implement basic functionality
2. **Hit Memory Limit:** Program too large for available memory
3. **Cut Features:** Remove everything non-essential
4. **Optimize Code:** Make it smaller and faster
5. **Ship It:** No time for more features anyway

The result: only essential features remained. This wasn't planned—it was forced by constraints.

### Cultural Impact on Modern Software

The minimalist aesthetic became a design principle:

**Unix Philosophy Commandments:**
1. Make each program do one thing well
2. Expect the output of every program to become the input to another
3. Design and build software to be tried early
4. Use tools rather than unskilled help to lighten a programming task

These weren't philosophical insights—they were survival strategies for programming on minimal hardware. But they worked so well that they became principles.

Modern examples of this philosophy:
- Microservices (vs. monoliths)
- Single Responsibility Principle (OOP)
- Unix command pipelines
- Functional programming (small functions)
- API design (minimal surface area)

All trace back to the PDP-7 constraint: **you literally couldn't build large programs, so you learned to build small ones well**.

## 11.7 Historical Context

### What Utilities Existed on Other 1969 Systems?

To appreciate Unix's innovation, consider what else existed in 1969:

#### IBM OS/360 (Mainframe Batch Processing)

**Job Control Language (JCL):**
```
//MYJOB JOB (ACCT),'PROGRAMMER NAME',CLASS=A,MSGCLASS=X
//STEP1 EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN DD DUMMY
//SYSUT1 DD DSN=INPUT.FILE,DISP=SHR
//SYSUT2 DD DSN=OUTPUT.FILE,DISP=(NEW,CATLG,DELETE),
// UNIT=SYSDA,SPACE=(CYL,(5,1)),DCB=(RECFM=FB,LRECL=80)
```

This is roughly equivalent to `cp input.file output.file` in Unix.

**Characteristics:**
- Verbose, complex syntax
- Jobs submitted via cards
- Hours between submission and results
- No interactive utilities
- Everything through batch system

#### CTSS (Compatible Time-Sharing System)

**Commands:**
- `LOGIN` - Log in
- `LOGOUT` - Log out
- `LISTF` - List files
- `DUMP` - Display file contents
- `TYPIST` - Text editor
- `MAD` - Compile MAD program
- `LOAD` - Load program
- `START` - Run program

**Characteristics:**
- Interactive (revolutionary for 1961!)
- Commands built into supervisor
- No concept of external programs
- No pipelines or composition
- Each command was special-purpose

#### Multics (Multiplexed Information and Computing Service)

**Commands:**
- `print` - Print file
- `copy` - Copy file
- `list` - List directory
- `edit` - Interactive editor (very sophisticated)
- `mail` - Send mail
- `who` - List users

**Characteristics:**
- Sophisticated command language
- Heavy, feature-rich commands
- Integrated into complex OS
- Required mainframe-class hardware
- Commands were built-in, not separate programs

#### DEC OS/8 (PDP-8 Operating System)

**Commands:**
- `DIR` - Directory
- `PIP` - Peripheral Interchange Program (copy files)
- `EDIT` - Text editor
- `FOTP` - File-Oriented Transfer Program
- `PAL8` - Assembler

**Characteristics:**
- Simple monitor
- Few commands (memory constraints)
- Most functionality in PIP (like MS-DOS later)
- Commands loaded from storage on demand
- No multi-user support

### The Batch Processing Era

In 1969, most computing was batch processing:

**Typical Workflow:**
1. Write program on coding sheets
2. Keypunch cards from sheets
3. Submit card deck to operator
4. Wait hours or days
5. Receive printout
6. Debug from printout
7. Re-punch cards
8. Goto 3

**No Interactive Utilities:**
- Couldn't cat a file (no terminal)
- Couldn't cp interactively (submit JCL job)
- Couldn't chmod (no file permissions)
- Couldn't check filesystem (operator's job)

Unix was revolutionary because you could type a command and see results instantly.

### Time-Sharing System Commands

CTSS and Multics pioneered time-sharing, but their commands differed from Unix:

**CTSS LISTF (equivalent to ls):**
```
LISTF
FILE1    12/01/68 15:30
FILE2    12/02/68 09:15
FILE3    12/02/68 14:22
```

**Unix ls:**
```
$ ls
file1
file2
file3
```

**Key Difference:** CTSS LISTF was built into the supervisor. Unix ls was a separate program that anyone could replace or modify.

**Multics print (equivalent to cat):**
```
print file1
[contents of file1]
```

**Unix cat:**
```
$ cat file1
[contents of file1]
```

**Key Difference:** Multics print had dozens of options and features. Unix cat did one thing: concatenate files.

### How Unix Utilities Differed

**1. External Programs:**
- Other systems: commands built into OS
- Unix: commands are executable files
- Impact: users could write new commands

**2. Uniform Interface:**
- Other systems: each command had unique syntax
- Unix: all commands read stdin, write stdout
- Impact: commands could be composed (later: pipes)

**3. Minimal Feature Sets:**
- Other systems: feature-rich integrated commands
- Unix: simple tools that do one thing
- Impact: smaller, faster, more maintainable

**4. File-Based:**
- Other systems: special syntax for devices and files
- Unix: everything is a file
- Impact: uniform handling of files, devices, pipes

**5. Accessible Source:**
- Other systems: proprietary, closed source
- Unix: source code available and readable
- Impact: users could study and modify utilities

### The Lasting Influence on Command-Line Culture

The PDP-7 utilities established patterns that persist today:

**Short Command Names:**
- PDP-7: cat, cp, chmod, chown
- Modern: ls, mv, rm, grep, sed, awk
- Impact: fast to type, easy to remember

**Simple Syntax:**
- PDP-7: `cat file1 file2`
- Modern: `cat file1 file2`
- Impact: consistent, learnable

**Composability:**
- PDP-7: uniform I/O (no pipes yet)
- Later Unix: `cat file | grep pattern`
- Impact: small tools combine powerfully

**Manual Pages:**
- PDP-7: no docs (too small)
- Later Unix: man pages for every command
- Impact: self-documenting system

**Everything is a File:**
- PDP-7: devices as files
- Modern: sockets, processes, devices all as files
- Impact: uniform interface to everything

### From Necessity to Philosophy

The evolution:

**1969 (PDP-7):**
- Constraint: 8K words of memory
- Response: Small utilities
- Reason: No choice

**1971 (PDP-11):**
- Resource: More memory available
- Decision: Keep utilities small
- Reason: It works well

**1973 (Unix Time-Sharing):**
- Resource: Multiple users
- Decision: Small tools, pipes
- Reason: Efficiency and composability

**1974 (Unix Paper Published):**
- Document: "The Unix Time-Sharing System"
- Message: Simple tools are a design philosophy
- Impact: Other systems adopt the model

**1980s (Unix Wars):**
- Fragmentation: Many Unix variants
- Constant: Small tool philosophy
- Result: Philosophy transcends implementations

**1990s (Linux):**
- Revolution: Free Unix clone
- Preservation: GNU utilities follow Unix model
- Scale: Millions of users adopt the philosophy

**2000s (Open Source):**
- Expansion: Philosophy spreads beyond Unix
- Examples: Git, Node.js, Go tools
- Culture: "Do one thing well" becomes universal

### The Irony of Success

The PDP-7 utilities were minimal because they had to be. Now they're celebrated as brilliant design.

Ken Thompson later said:
> "I didn't design Unix to be portable, or to have small tools, or any of that. I designed it to get work done on the hardware I had. Everything else emerged from constraints."

The "Unix Philosophy" was discovered, not invented.

### Modern Lessons

What can modern developers learn from PDP-7 utilities?

**1. Constraints Drive Innovation:**
- Limited memory forced simplicity
- Simplicity proved superior
- Lesson: Embrace constraints

**2. Small is Beautiful:**
- PDP-7 cat: 146 lines, does one thing
- Modern cat: 800 lines, does many things
- Lesson: Feature bloat is optional

**3. Composition Over Integration:**
- Small tools that combine
- Better than large integrated systems
- Lesson: Build composable components

**4. Source Code as Documentation:**
- PDP-7 code is readable
- Modern code is often opaque
- Lesson: Clarity matters

**5. Optimization Later:**
- PDP-7 utilities were simple first
- Optimization came when needed
- Lesson: Premature optimization is evil

### Conclusion: Philosophy from Pragmatism

The Unix philosophy emerged from the pragmatic constraints of PDP-7 development:

- **8K words of memory** → Small programs
- **Slow DECtape** → Efficient I/O
- **Limited development time** → Simple designs
- **Two developers** → Minimal features
- **No formal requirements** → Organic evolution

These constraints accidentally created the most influential computing philosophy of the past 50 years.

The PDP-7 utilities weren't designed to be minimal—they had to be minimal. That they were also elegant, maintainable, and composable was a happy accident.

Or as Dennis Ritchie put it:
> "Unix is simple. It just takes a genius to understand its simplicity."

The genius wasn't in planning simplicity—it was in recognizing that the constraints had forced them to build something better than they'd originally intended.

---

**End of Chapter 11**

**Next Chapter:** Chapter 12 - The Shell: Command Interpretation and Execution
