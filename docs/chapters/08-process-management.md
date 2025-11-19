# Chapter 8 - Process Management

The process is the fundamental abstraction in Unix—the unit of computation, resource allocation, and protection. In PDP-7 Unix, we see this revolutionary concept in its earliest and simplest form: just 4 words per process in the process table, 64 words of saved state, and a handful of system calls. Yet from this minimal foundation emerges true multiprogramming: multiple programs sharing a single processor through time-slicing and swapping.

This chapter explores how PDP-7 Unix implements processes, from the data structures that represent them to the algorithms that create, schedule, swap, and terminate them. We'll trace the complete lifecycle of a process from fork to exit, examine the swapping mechanism that enables multiprogramming in just 8K of memory, and understand the simple but effective round-robin scheduler.

## 8.1 The Process Abstraction

### What is a Process in PDP-7 Unix?

A process in PDP-7 Unix is an executing instance of a program. More precisely, it consists of:

1. **Code**: The program instructions loaded from a file
2. **Data**: Variables and working storage (in the upper 2K of memory)
3. **Context**: Saved register values (AC, MQ, program counter, link register)
4. **Resources**: Open file descriptors and current directory
5. **Identity**: Process ID (PID) and user ID (UID)
6. **State**: Whether the process is running, ready, or swapped out

Unlike modern systems with virtual memory, PDP-7 Unix processes share a single 8K memory space. Only one process can be in memory at a time—the others are swapped out to disk tracks 06000 and 07000.

### The Revolutionary Concept in 1969

In 1969, most computer systems ran **batch jobs** or **interactive sessions**:

**Batch systems** (like IBM OS/360):
- Jobs submitted on punched cards
- Queued and run sequentially
- No interaction during execution
- One job at a time per partition

**Timesharing systems** (like CTSS, Multics):
- Multiple users share CPU time
- Complex schedulers with priorities
- Heavyweight processes with separate address spaces
- Required sophisticated hardware (MMU, page tables)

**PDP-7 Unix processes** were different:
- Lightweight (minimal per-process overhead)
- Uniform (all processes treated equally, no priorities)
- Simple (no virtual memory, no protection rings)
- Fast (fork creates process in ~100ms)
- Elegant (same abstraction for interactive and batch)

The genius was **making processes so cheap** that programs could create them freely. This led directly to the Unix philosophy of small tools combined via pipes—but that came later, in PDP-11 Unix.

### Comparison with Batch Jobs

| Aspect | Batch Job (OS/360) | Process (PDP-7 Unix) |
|--------|-------------------|---------------------|
| Creation | Operator loads cards | fork() system call |
| Identity | Job name | Numeric PID |
| Scheduling | FIFO queue | Round-robin time-slicing |
| Memory | Fixed partition | Entire 8K (swapped) |
| I/O | Dedicated devices | Shared via file descriptors |
| Termination | Job complete | exit() system call |
| Parent/Child | No relationship | Parent waits for child |
| Lifetime | Minutes to hours | Seconds to minutes |

The PDP-7 Unix process model was simpler than batch jobs in some ways (no job control language, no complex scheduling) but more powerful in others (dynamic creation, parent/child relationships, uniform abstraction).

## 8.2 Process Table

The process table (`ulist`) is the central data structure for process management. It's an array of 10 entries, each representing one potential process slot.

### The ulist Structure

Located in `s8.s`, the process table is declared as:

```assembly
" Process table (ulist) - 4 words per process
" Maximum of 10 processes (mnproc = 10)

ulist: .=.+mnproc*4     " Allocate 40 words (10 processes × 4 words)
```

Each entry contains exactly **4 words**:

```
Process Table Entry (4 words):
┌─────────────────────────────────────────┐
│ Word 0: State and flags                 │
│         Bits 0-1:  State (0-3)          │
│         Bits 2-17: Flags (unused)       │
├─────────────────────────────────────────┤
│ Word 1: Process ID (PID)                │
│         Unique number 1-65535           │
├─────────────────────────────────────────┤
│ Word 2: Swap track address              │
│         06000 or 07000 (disk track)     │
├─────────────────────────────────────────┤
│ Word 3: Reserved                        │
│         (unused in PDP-7 Unix)          │
└─────────────────────────────────────────┘
```

### Maximum 10 Processes

The manifest constant `mnproc` defines the maximum number of concurrent processes:

```assembly
mnproc = 10     " Maximum number of processes
```

**Why only 10?**
- **Memory constraints**: With 8K total memory and ~2K for each process, swapping more than a few processes would be slow
- **Swap space**: Only 2 disk tracks allocated for swapping (06000, 07000)
- **Simplicity**: Small process table means fast search
- **Practical limit**: On a single-user system (usually), 10 processes was plenty

In practice, a typical PDP-7 Unix session might have:
1. `init` (PID 1) - waiting for login
2. `sh` (shell) - running user commands
3. User program - executing command
4. `ed` - editing a file

That's only 3-4 processes, well under the limit.

### The State Field (2 bits)

The low 2 bits of word 0 encode the process state:

```assembly
" Process states (bits 0-1 of ulist[proc,0])
" State 0: Unused (process slot is free)
" State 1: In memory, ready to run
" State 2: In memory, waiting (not ready)
" State 3: On disk, ready to run
```

Only 2 bits are needed because there are just 4 possible states. The implementation is elegantly minimal:

```assembly
" Get process state
    law ulist       " Address of process table
    tad proc        " Add process number × 4
    tad proc
    tad proc
    tad proc
    dac 8           " Auto-increment pointer
    lac 8 i         " Load word 0
    and d3          " Mask to get bits 0-1
    " AC now contains state (0-3)

d3: 3              " Mask for 2-bit state field
```

### PID Allocation

Process IDs are allocated sequentially using a global counter:

```assembly
" In s8.s - System data
nproc: 0           " Next process ID to allocate

" In fork (s3.s) - Allocate new PID
    isz nproc      " Increment and skip if zero
    jmp .+1        " (never zero, so always continue)
    lac nproc      " Get new PID
    dac 8 i        " Store in ulist[new_proc, 1]
```

PIDs start at 1 and increment forever. In a long-running system, they would eventually wrap around after 262,143 processes (18-bit word), but this would take weeks of continuous forking.

**PID 1 is special**: It's always `init`, the first process created during boot. When a process's parent exits, the process is reparented to PID 1.

### Complete Process Table Structure Analysis

Let's examine the full structure with an example of 3 running processes:

```
Memory Layout of ulist (10 processes × 4 words = 40 words):

Address  Process  Word  Contents          Description
-------  -------  ----  ----------------  ------------------------------------
ulist+0    0       0    0000000000000001  State=1 (in memory, ready)
ulist+1    0       1    0000000000000001  PID=1 (init)
ulist+2    0       2    0000000006000     Swap track = 06000
ulist+3    0       3    0000000000000000  (unused)

ulist+4    1       0    0000000000000001  State=1 (in memory, ready)
ulist+5    1       1    0000000000000042  PID=42 (shell)
ulist+6    1       2    0000000007000     Swap track = 07000
ulist+7    1       3    0000000000000000  (unused)

ulist+10   2       0    0000000000000011  State=3 (on disk, ready)
ulist+11   2       1    0000000000000043  PID=43 (ed)
ulist+12   2       2    0000000007000     Swap track = 07000
ulist+13   2       3    0000000000000000  (unused)

ulist+14   3       0    0000000000000000  State=0 (unused)
ulist+15   3       1    0000000000000000  PID=0
ulist+16   3       2    0000000000000000  No swap track
ulist+17   3       3    0000000000000000  (unused)

... (6 more unused slots)
```

### Finding a Free Process Slot

When `fork()` needs to create a new process, it searches for an unused slot:

```assembly
" Find free process slot
    law ulist-4     " Start before first entry
    dac 8           " Auto-increment pointer
    law mnproc      " Loop counter = 10
    dac count

1:
    lac 8 i         " Get ulist[i,0]
    and d3          " Extract state bits
    sza             " Skip if state == 0 (unused)
    jmp 2f          " Used, try next

    " Found free slot
    lac 8           " Get pointer address
    tad dm4         " Back up to start of entry
    " AC now has address of free entry
    jmp found

2:
    isz 8           " Skip words 1, 2, 3
    isz 8
    isz 8
    isz count       " Decrement counter
    jmp 1b          " Try next slot

    " No free slots
    error           " Fork fails!

found:
    " Initialize new process entry
    ...
```

## 8.3 User Data Structure

While the process table entry contains minimal metadata, the bulk of a process's state is stored in the **userdata** structure—64 words of saved context that gets swapped in and out with the process.

### The userdata Structure (64 words)

Located in `s8.s`:

```assembly
" User data structure - 64 words
" Saved with process when swapped out
" Loaded when process swapped in

userdata:
    uac:    0      " +0  Saved AC (accumulator)
    umq:    0      " +1  Saved MQ (multiplier-quotient)
    urq:    0      " +2  Saved rq (return address register)
    upc:    0      " +3  Saved PC (program counter, for debugging)

    uid:    0      " +4  User ID (for permissions)
    upid:   0      " +5  Process ID
    uppid:  0      " +6  Parent process ID

    " File descriptor table (30 slots)
    ufil:   .=.+30 " +7 to +36  File descriptor array

    ucdir:  0      " +37 Current directory inode number

    ustack: .=.+26 " +38 to +63 Kernel stack space
```

This structure occupies exactly 64 words and is loaded at a fixed memory location (typically around address 7700) when a process is active.

### Saved Registers

The first few words preserve the CPU state:

```assembly
uac:    " Saved accumulator
    " Contains the value of AC when process was interrupted
    " Restored on context switch back to this process

umq:    " Saved multiplier-quotient register
    " Used in multiply/divide operations
    " Must be preserved across context switches

urq:    " Saved return address
    " The rq register holds subroutine return addresses
    " Critical for resuming execution correctly

upc:    " Saved program counter (for debugging)
    " Not always used, but helpful for crash dumps
```

**Why save these?** When the kernel switches from one process to another, it must preserve the complete CPU state. Otherwise, when the process resumes, its registers would contain garbage from whatever else was running.

### File Descriptors (30 slots)

The `ufil` array is the process's **file descriptor table**:

```assembly
ufil:   .=.+30     " 30 file descriptor slots

" Each entry is a single word containing:
"   - File number (index into system-wide file table)
"   - Or 0 if slot is unused

" Example file descriptor table:
"   ufil+0:  0      (fd 0 unused - no stdin yet in PDP-7!)
"   ufil+1:  0      (fd 1 unused - no stdout yet)
"   ufil+2:  0      (fd 2 unused - no stderr yet)
"   ufil+3:  14     (fd 3 open, refers to file table entry 14)
"   ufil+4:  7      (fd 4 open, refers to file table entry 7)
"   ...
```

**Important historical note**: PDP-7 Unix did NOT have the stdin/stdout/stderr convention (file descriptors 0, 1, 2). That was invented later for PDP-11 Unix. In PDP-7 Unix, file descriptors started at 0 and were just indices into the file table.

**Why 30 slots?** This seems arbitrary, but it's based on:
- 64 words total for userdata
- 7 words for registers/IDs
- 1 word for current directory
- ~26 words for kernel stack
- Leaves ~30 words for file descriptors

### Current Directory

```assembly
ucdir:  0      " Current directory inode number

" Example values:
"   ucdir = 41     Process is in inode 41 (the root directory)
"   ucdir = 123    Process is in inode 123 (some subdirectory)
```

Every process has a current working directory, stored as an inode number. When the user opens a file with a relative path, the kernel searches starting from this directory.

**Example**: If a process's `ucdir` is 41 (root) and it opens "usr/ken/file", the kernel:
1. Starts at inode 41
2. Searches for "usr" in that directory
3. Searches for "ken" in the "usr" directory
4. Opens "file" in the "ken" directory

### UID and PID

```assembly
uid:    0      " User ID (who owns this process)
upid:   0      " Process ID (unique identifier)
uppid:  0      " Parent process ID
```

**UID** determines permissions:
- UID 0 = superuser (can do anything)
- UID > 0 = normal user (restricted access)

**PID** is the unique process identifier, used for:
- Wait system call (parent waits for child's PID)
- Messages (send/receive between specific PIDs)
- Process table lookups

**PPID** (parent PID) tracks the parent/child relationship:
- When a process exits, it sends a message to its parent
- If the parent has exited, the child is reparented to PID 1 (init)

### Full Code Walkthrough: Saving Context

Here's how the kernel saves a process's context during a system call entry:

```assembly
" System call entry point (location 020)
" Entered via hardware trap when user executes 'sys' instruction

020:
    dac uac         " Save AC to userdata.uac
    law 020         " Load address 020
    dac urq         " Save as return address
    lac 017         " Get MQ register
    dac umq         " Save to userdata.umq

    " At this point, all critical registers are saved
    " Kernel can freely use AC, MQ without corrupting user state

    lac s.insys     " Check if already in system call
    sna             " Skip if non-zero (recursive call)
    jmp entry       " First entry, proceed normally

    " Recursive system call - panic
    error

entry:
    lac d1
    dac s.insys     " Set "inside system call" flag

    " Dispatch to system call handler
    ...
```

### Restoring Context on Return

When returning to user mode:

```assembly
" System call exit point
sysexit:
    dza             " Clear AC
    dac s.insys     " Clear "inside system call" flag

    " Check if process should be swapped out
    jms swap        " Swap scheduling

    lac umq         " Restore MQ register
    dac 017
    lac urq         " Get return address
    dac 8           " Set up auto-increment pointer
    lac uac         " Restore AC

    " Return to user space
    jmp 8 i         " Jump indirect through rq
```

### Complete Memory Layout of userdata

Let's visualize a real example with a process that has opened 3 files:

```
Address  Offset  Field    Value   Description
-------  ------  -------  ------  ----------------------------------
7700     +0      uac      004217  Saved AC = 004217 (octal)
7701     +1      umq      000000  Saved MQ = 0
7702     +2      urq      001234  Saved return address = 001234
7703     +3      upc      001233  Saved PC = 001233

7704     +4      uid      000012  User ID = 12 (user "ken")
7705     +5      upid     000043  Process ID = 43
7706     +6      uppid    000042  Parent PID = 42 (the shell)

7707     +7      ufil[0]  000000  fd 0: unused
7710     +8      ufil[1]  000000  fd 1: unused
7711     +9      ufil[2]  000000  fd 2: unused
7712     +10     ufil[3]  000014  fd 3: file table entry 14 (open)
7713     +11     ufil[4]  000007  fd 4: file table entry 7 (open)
7714     +12     ufil[5]  000021  fd 5: file table entry 21 (open)
7715     +13     ufil[6]  000000  fd 6: unused
...      ...     ...      ...     (23 more unused fd slots)
7736     +36     ufil[29] 000000  fd 29: unused

7737     +37     ucdir    000041  Current directory = inode 41 (root)

7740     +38     ustack   ...     Kernel stack begins here
...      ...     ...      ...     (26 words of stack space)
7763     +63     ustack   ...     Top of kernel stack
```

## 8.4 Process States

PDP-7 Unix has exactly **4 process states**, encoded in 2 bits. This is far simpler than modern operating systems with 10+ states (running, ready, blocked, sleeping, zombie, traced, etc.).

### State Definitions

```assembly
" Process states (bits 0-1 of ulist entry word 0)

" State 0: NOT USED
"   Process slot is free
"   Can be allocated by fork()

" State 1: IN MEMORY, READY
"   Process is loaded in memory (addresses 0-7777)
"   Ready to run (not waiting for I/O)
"   Will be selected by scheduler

" State 2: IN MEMORY, NOT READY
"   Process is loaded in memory
"   Waiting for something (I/O completion, message, etc.)
"   Will NOT be selected by scheduler

" State 3: ON DISK, READY
"   Process is swapped out to disk (track 06000 or 07000)
"   Ready to run if swapped back in
"   Will be selected by swap scheduler
```

### State 0: Not Used (Free Slot)

```assembly
" Example: ulist[5,0] = 0
"   Process slot 5 is unused
"   Available for fork() to allocate
```

When `fork()` searches for a free process slot, it looks for entries with state 0. When a process exits, its state is set to 0, freeing the slot for reuse.

### State 1: In Memory, Ready

```assembly
" Example: ulist[2,0] = 1
"   Process 2 is in memory
"   Ready to execute
"   Eligible for CPU time slicing
```

This is the "running" or "runnable" state. The process could be:
- Currently executing (if it's the active process)
- Waiting for its time slice (if another process is running)

The scheduler's `lookfor` function searches for processes in state 1:

```assembly
lookfor:
    " Find next ready process
    law ulist-4
    dac 8
    law mnproc
    dac count

1:
    lac 8 i         " Get state field
    and d3
    sad d1          " State == 1?
    jmp found       " Yes, found ready process

    isz 8           " Skip to next entry
    isz 8
    isz 8
    isz 8
    isz count
    jmp 1b

    " No ready processes, idle loop
    jmp idle

found:
    " Dispatch this process
    ...
```

### State 2: In Memory, Not Ready (Blocked)

```assembly
" Example: ulist[3,0] = 2
"   Process 3 is in memory
"   Waiting for I/O or message
"   NOT eligible for scheduling
```

A process enters state 2 when it blocks on:
- **Disk I/O**: Reading or writing a file
- **Message receive**: Waiting for inter-process message
- **Sleep**: Explicitly sleeping for a time

The process remains in memory but won't be scheduled until it becomes ready (state changes back to 1).

**Example: Waiting for disk I/O:**

```assembly
.read:
    " User called read() system call
    jms finac       " Find file descriptor
    jms iread       " Read from inode

iread:
    " Determine which disk block to read
    jms pget        " Get physical block number
    jms dskrd       " Read from disk

dskrd:
    " Initiate disk transfer
    jms dsktrans    " Start I/O

    " Block until I/O completes
    lac proc        " Current process number
    alss 2          " × 4 for ulist entry
    tad ulist
    dac 8
    lac d2          " State 2 = blocked
    dac 8 i         " Set process state

    " Give up CPU
    jmp swapnow     " Swap to another process
```

When the disk interrupt fires, it sets the process back to state 1:

```assembly
" Disk interrupt handler
diskint:
    " Disk I/O completed
    lac waitproc    " Which process was waiting?
    alss 2
    tad ulist
    dac 8
    lac d1          " State 1 = ready
    dac 8 i         " Unblock process
    ...
```

### State 3: On Disk, Ready (Swapped Out)

```assembly
" Example: ulist[7,0] = 3
"   Process 7 is swapped out to disk
"   Ready to run if swapped back
"   Eligible for swap-in
```

When memory is needed for another process, the kernel swaps the current process out:

```assembly
swap:
    " Decide whether to swap current process out
    lac s.quantum   " Check time quantum
    sna             " Skip if non-zero
    jmp doswap      " Quantum expired, swap out
    jmp noswap      " Quantum remains, keep running

doswap:
    " Write process memory to disk
    lac proc        " Current process
    jms dskswap     " Swap to disk (track 06000 or 07000)

    " Update process state
    lac proc
    alss 2
    tad ulist
    dac 8
    lac d3          " State 3 = swapped out, ready
    dac 8 i

    " Select another process
    jms lookfor     " Find next ready process
    jms dskswapin   " Swap it into memory
    ...
```

### State Transitions

Here's how processes move between states:

```
State Transition Diagram:

                    ┌─────────────┐
                    │   State 0   │
                    │  NOT USED   │
                    │  (FREE)     │
                    └──────┬──────┘
                           │
                         fork()
                           │
                           ▼
    ┌──────────────────────────────────────────┐
    │              State 1                     │
    │         IN MEMORY, READY                 │
    │       (Running/Runnable)                 │
    └────┬─────────────────────┬───────────────┘
         │                     │
         │ wait for I/O        │ I/O complete
         │ wait for msg        │ message arrived
         │ sleep               │ wakeup
         │                     │
         ▼                     ▼
    ┌─────────────────────────────────┐
    │          State 2                │
    │     IN MEMORY, NOT READY        │
    │        (Blocked)                │
    └─────────────┬───────────────────┘
                  │
                  │ quantum expired
                  │ another process needs memory
                  │
                  ▼
         ┌────────────────────┐
         │     State 3        │
         │  ON DISK, READY    │
         │  (Swapped out)     │
         └────────┬───────────┘
                  │
                  │ swap in
                  │
                  ▼
         ┌────────────────────┐
         │     State 1        │
         │  IN MEMORY, READY  │
         └────────────────────┘
```

**Key transitions:**

1. **0 → 1**: `fork()` creates new process in memory, ready state
2. **1 → 2**: Process blocks on I/O or message
3. **2 → 1**: I/O completes or message arrives, process becomes ready
4. **1 → 3**: Time quantum expires, process swapped out
5. **3 → 1**: Process swapped back in
6. **1 → 0** or **2 → 0** or **3 → 0**: `exit()` terminates process

### State Checking in System Calls

Many system calls check process state:

```assembly
.wait:
    " Wait for child process to exit
1:
    jms lookchild   " Search for child in state 0 (exited)
    sna             " Found one?
    jmp .+3         " No, sleep
    " Child exited, return its PID
    jmp sysexit

    " No exited child yet, block
    lac d2          " State 2 = blocked
    dac procstate
    jmp schedule    " Give up CPU
```

### Complete State Example

Let's trace a process through all states from creation to termination:

```
Time  Event                    State  Location   Description
----  -----------------------  -----  ---------  ---------------------------
0     fork() called            1      Memory     Parent creates child
1     Child begins executing   1      Memory     Child process gets CPU
2     Child calls read()       2      Memory     Blocks waiting for disk
3     Disk I/O completes       1      Memory     Becomes ready again
4     Quantum expires          3      Disk       Swapped out to track 06000
5     Scheduler picks it       1      Memory     Swapped back in
6     Calls exit()             0      None       Process terminates, slot freed
```

## 8.5 Process Creation - fork()

The `fork()` system call is the **only way** to create a new process in Unix. It's one of the most elegant and revolutionary ideas in operating system design: create a copy of the current process, and have them both continue execution with different return values.

### The fork() Concept

When a process calls `fork()`:

1. The kernel creates a **new process table entry**
2. Allocates a **new PID**
3. **Copies** the parent's memory to the child (via disk swapping)
4. **Duplicates** all open file descriptors
5. Sets the **parent's return value** to the child's PID
6. Sets the **child's return value** to 0
7. Both processes continue execution from the **same point**

The genius is that **the same code runs in both processes**, but they can detect which one they are by checking the return value:

```assembly
" In user code:
    sys fork        " Create child process

    " Execution continues here in BOTH processes
    sza             " Skip if AC == 0 (child)
    jmp parent      " Non-zero (child PID), must be parent

child:
    " Child process code
    " AC was 0 after fork
    ...
    sys exit

parent:
    " Parent process code
    " AC contains child's PID
    ...
```

### Complete fork() Implementation

Located in `s3.s`, the `fork()` system call is about 50 lines of carefully crafted code:

```assembly
" fork - Create new process
" Returns: AC = child PID in parent
"          AC = 0 in child

.fork:
    " Step 1: Find free process slot
    law ulist-4     " Start before first entry
    dac 8           " Auto-increment pointer
    law mnproc      " Counter = 10 processes
    dac count

1:
    lac 8 i         " Get ulist[i,0] (state field)
    and d3          " Mask to state bits
    sza             " Skip if state == 0 (free)
    jmp 2f          " In use, try next

    " Found free slot
    lac 8           " Get current pointer
    tad dm4         " Back up to start of entry
    dac newproc     " Save new process number
    jmp found

2:
    isz 8           " Skip words 1, 2, 3
    isz 8
    isz 8
    isz count       " Decrement loop counter
    jmp 1b          " Try next slot

    " No free slots - fork fails
    lac dm1         " Return -1
    jmp sysexit

found:
    " Step 2: Allocate new PID
    isz nproc       " Increment global PID counter
    lac nproc       " Get new PID
    dac childpid    " Save it

    " Step 3: Set up new process table entry
    lac newproc     " Address of new entry
    dac 8
    lac d1          " State 1 = in memory, ready
    dac 8 i         " ulist[new,0] = 1

    lac childpid    " Child PID
    dac 8 i         " ulist[new,1] = PID

    lac swaptrack   " Get available swap track
    dac 8 i         " ulist[new,2] = swap track

    dza             " Clear word 3
    dac 8 i         " ulist[new,3] = 0

    " Step 4: Copy parent's userdata to child
    "         This includes:
    "         - All open file descriptors
    "         - Current directory
    "         - User ID
    "         - Saved registers

    law userdata    " Source = parent's userdata
    dac from
    law childdata   " Destination = child's userdata
    dac to
    law 64          " Copy 64 words
    dac count
    jms copy        " Perform block copy

    " Step 5: Update child's userdata fields
    lac childpid
    dac childdata+5 " Child's upid = new PID

    lac upid        " Parent's PID
    dac childdata+6 " Child's uppid = parent PID

    dza
    dac childdata+0 " Child's uac = 0 (return value)

    " Step 6: Increment reference counts for open files
    "         Both parent and child now point to same files
    law ufil        " File descriptor table
    dac 8
    law 30          " 30 file descriptor slots
    dac count

1:
    lac 8 i         " Get file descriptor
    sza             " Skip if unused (0)
    jms incref      " Increment reference count
    isz count
    jmp 1b

    " Step 7: Write child to disk (swap out)
    lac newproc     " Child process number
    jms dskswap     " Write to swap track

    " Child is now on disk in state 1 (ready)
    " When scheduler picks it, it will be swapped in

    " Step 8: Return to parent with child PID
    lac childpid    " Load child PID
    dac uac         " Set return value
    jmp sysexit     " Return to user mode
```

### Parent/Child Relationship

After fork completes:

**Parent process:**
- Continues execution after the `sys fork` instruction
- AC contains the child's PID (non-zero)
- Can wait for child to terminate using `wait()` system call
- Can send messages to child using its PID

**Child process:**
- Starts execution at the **same point** (after `sys fork`)
- AC contains 0 (distinguishing it from parent)
- Has PPID set to parent's PID
- Has its own copy of all file descriptors
- Shares the same files (same file table entries)

**Shared resources:**
- Open files (both processes have descriptors to same file table entries)
- Current directory inode number
- User ID

**Separate resources:**
- Process ID (different PIDs)
- Memory (child has its own copy on disk)
- Process state (independent scheduling)

### Memory Copying via Swapping

This is the clever part: PDP-7 Unix doesn't have enough memory to hold both parent and child simultaneously. Instead:

1. **Parent is in memory** when fork is called
2. **Child's memory is created** by swapping:
   - Allocate a swap track (06000 or 07000)
   - Write parent's memory to that track
   - Mark child as state 3 (swapped out, ready)
3. **Parent continues** running in memory
4. **Child waits** on disk until scheduled
5. When child is scheduled, it's **swapped in** (and parent swapped out)

This is much simpler than copying memory within RAM, which would require:
- Temporary buffer space
- Complex memory management
- Dual mapping of address space

**Performance cost**: Each fork takes about 100ms—50ms to write child to disk, 50ms to eventually swap it in.

### Process Table Setup

After fork, the process table looks like this:

```
Before fork (1 process):
ulist[0]: State=1, PID=42, Track=06000   (parent, in memory)
ulist[1]: State=0, PID=0,  Track=0       (unused)
...

After fork (2 processes):
ulist[0]: State=1, PID=42, Track=06000   (parent, in memory)
ulist[1]: State=3, PID=43, Track=07000   (child, on disk, ready)
...

userdata (parent):
  uac = 43 (child PID)
  upid = 42
  uppid = 1 (init)

childdata (on disk track 07000):
  uac = 0 (child return value)
  upid = 43
  uppid = 42 (parent)
```

### Return Value Difference

The **magic** of fork is the different return values:

```assembly
" Before fork (parent only):
"   AC = (doesn't matter)
"   upid = 42

    sys fork

" After fork returns to PARENT:
"   AC = 43 (child PID)
"   upid = 42 (still parent)

" When child is scheduled:
"   AC = 0 (child return value)
"   upid = 43 (now child)
```

This is set up in two places:

**For parent** (in fork code):
```assembly
    lac childpid    " Load child PID
    dac uac         " Set parent's return AC
```

**For child** (in fork code):
```assembly
    dza
    dac childdata+0 " Set child's uac = 0
```

When child is later swapped in, `uac` is restored to AC, giving it 0.

### Full Annotated fork() Code with Comments

Here's the complete implementation with detailed annotations:

```assembly
.fork:
    "────────────────────────────────────────────────────────
    " STEP 1: FIND FREE PROCESS SLOT
    "────────────────────────────────────────────────────────
    law ulist-4     " Start at ulist-4 (auto-inc will add 4)
    dac 8           " Set up auto-increment pointer 8
    law mnproc      " Load -10 (negative count)
    dac count       " Initialize loop counter

findslot:
    lac 8 i         " Load ulist[i,0] via auto-increment
                    " This also advances pointer by 1
    and d3          " Mask to get state bits (0-1)
    sza             " Skip if state == 0 (free slot)
    jmp tryslot     " State != 0, try next slot

    " Found free slot!
    lac 8           " Get current pointer value
    tad dm4         " Subtract 4 to get entry start
    dac newproc     " Save entry address
    jmp found       " Proceed to allocate

tryslot:
    isz 8           " Skip ulist[i,1]
    isz 8           " Skip ulist[i,2]
    isz 8           " Skip ulist[i,3]
                    " Pointer now at ulist[i+1,0]
    isz count       " Increment counter (toward 0)
    jmp findslot    " Continue if not yet 0

    " All slots full - fork fails
    lac dm1         " Load -1
    jmp sysexit     " Return error to user

found:
    "────────────────────────────────────────────────────────
    " STEP 2: ALLOCATE NEW PROCESS ID
    "────────────────────────────────────────────────────────
    isz nproc       " Increment global PID counter
    lac nproc       " Load new PID value
    dac childpid    " Save for later use

    "────────────────────────────────────────────────────────
    " STEP 3: INITIALIZE PROCESS TABLE ENTRY
    "────────────────────────────────────────────────────────
    lac newproc     " Load entry address
    dac 8           " Set up pointer

    lac d1          " State 1 = in memory, ready
    dac 8 i         " ulist[new,0] = 1

    lac childpid    " Load child PID
    dac 8 i         " ulist[new,1] = childpid

    lac swaptrack   " Get free swap track (06000 or 07000)
    dac 8 i         " ulist[new,2] = track

    dza             " Zero accumulator
    dac 8 i         " ulist[new,3] = 0

    "────────────────────────────────────────────────────────
    " STEP 4: COPY PARENT'S USERDATA TO CHILD
    "────────────────────────────────────────────────────────
    " This creates duplicate of parent's entire state:
    " - Saved registers (AC, MQ, PC, rq)
    " - User ID
    " - All 30 file descriptors
    " - Current directory
    " - Kernel stack

    law userdata    " Source address
    dac from
    law childdata   " Destination (temporary buffer)
    dac to
    law 64          " Copy 64 words
    dac count
    jms copy        " Block copy routine

    "────────────────────────────────────────────────────────
    " STEP 5: CUSTOMIZE CHILD'S USERDATA
    "────────────────────────────────────────────────────────
    " Update fields that must differ from parent:

    lac childpid
    dac childdata+5 " upid = new child PID

    lac upid        " Parent's PID
    dac childdata+6 " uppid = parent PID

    dza
    dac childdata+0 " uac = 0 (child's fork return value)

    "────────────────────────────────────────────────────────
    " STEP 6: INCREMENT FILE REFERENCE COUNTS
    "────────────────────────────────────────────────────────
    " Both processes now share the same open files
    " Must increment reference counts so files aren't
    " closed prematurely when one process closes them

    law ufil        " File descriptor table
    dac 8           " Set up pointer
    law 30          " 30 slots
    dac count

copyfd:
    lac 8 i         " Get file descriptor
    sza             " Skip if 0 (unused)
    jms incref      " Increment reference count in file table
    isz count
    jmp copyfd

    "────────────────────────────────────────────────────────
    " STEP 7: SWAP CHILD TO DISK
    "────────────────────────────────────────────────────────
    " Child can't run yet - need to free memory
    " Write child's memory image to its swap track

    lac newproc     " Child process number
    lac childdata   " Child's userdata (in temp buffer)
    jms dskswap     " Write to track 06000 or 07000

    " Update child's state
    lac newproc
    alss 2          " × 4 for entry offset
    tad ulist
    dac 8
    lac d3          " State 3 = on disk, ready
    dac 8 i         " Update ulist[new,0]

    "────────────────────────────────────────────────────────
    " STEP 8: RETURN TO PARENT
    "────────────────────────────────────────────────────────
    lac childpid    " Load child PID
    dac uac         " Set parent's return value
    jmp sysexit     " Return to user mode

    " Parent continues execution with AC = child PID
    " Child is on disk, will run when scheduled
```

### Execution Trace Example

Let's trace a complete fork operation:

```
Initial State (parent process 42):
  Memory 0-7777:  Parent's code and data
  userdata.upid:  42
  userdata.uppid: 1
  userdata.uid:   12 (user "ken")
  ulist[0]:       State=1, PID=42, Track=06000

────────────────────────────────────────────────────────────

Parent executes:  sys fork

T=0ms: Enter .fork
  - Search process table
  - Find free slot at ulist[1]

T=1ms: Allocate PID
  - nproc: 42 → 43
  - childpid = 43

T=2ms: Initialize ulist[1]
  - ulist[1,0] = 1 (state: in memory, ready)
  - ulist[1,1] = 43 (PID)
  - ulist[1,2] = 07000 (swap track)
  - ulist[1,3] = 0

T=3ms: Copy userdata
  - Copy 64 words: userdata → childdata buffer
  - All registers, files, directory copied

T=4ms: Customize child's userdata
  - childdata.uac = 0
  - childdata.upid = 43
  - childdata.uppid = 42

T=5ms: Update file references
  - For each open file, increment refcount
  - Both processes now share files

T=50ms: Swap child to disk
  - Write 2048 words to track 07000
  - Takes ~45ms for disk I/O

T=51ms: Update child state
  - ulist[1,0] = 3 (on disk, ready)

T=52ms: Return to parent
  - uac = 43
  - Return to user mode

────────────────────────────────────────────────────────────

Final State:
  Memory 0-7777:  Parent's code and data (unchanged)

  Parent (PID 42):
    AC = 43 (child PID)
    State = 1 (in memory, ready, running)

  Child (PID 43):
    AC = 0 (swapped-out value, not yet seen)
    State = 3 (on disk, ready, waiting)
    Disk track 07000: Complete memory image

  Process table:
    ulist[0]: State=1, PID=42, Track=06000
    ulist[1]: State=3, PID=43, Track=07000

────────────────────────────────────────────────────────────

Later (when child is scheduled):

T=100ms: Swap child in
  - Swap parent to track 06000
  - Read child from track 07000
  - Restore childdata to userdata

T=150ms: Child begins execution
  - AC = 0 (restored from uac)
  - Execution continues after 'sys fork'
  - Child detects AC=0 and knows it's child
```

## 8.6 Process Termination - exit()

The `exit()` system call terminates the current process. It's simpler than fork—no new process to create, just cleanup and notification.

### What exit() Does

1. **Close all open files** (release file descriptors)
2. **Send exit message** to parent process
3. **Free process table entry** (set state to 0)
4. **Never return** (process ceases to exist)

### Complete exit() Implementation

Located in `s3.s`:

```assembly
" exit - Terminate current process
" Never returns to caller

.exit:
    "────────────────────────────────────────────────────────
    " STEP 1: CLOSE ALL OPEN FILE DESCRIPTORS
    "────────────────────────────────────────────────────────
    law ufil        " File descriptor table
    dac 8           " Auto-increment pointer
    law 30          " 30 file descriptor slots
    dac count

closeloop:
    lac 8 i         " Get file descriptor
    sza             " Skip if unused (0)
    jms closefd     " Close this file
    isz count       " Decrement counter
    jmp closeloop   " Next descriptor

    "────────────────────────────────────────────────────────
    " STEP 2: SEND EXIT MESSAGE TO PARENT
    "────────────────────────────────────────────────────────
    " Parent may be waiting for child to finish
    " Send message with our PID so parent can collect

    lac upid        " Our process ID
    dac mesg        " Message = our PID
    lac uppid       " Parent's PID
    jms smes        " Send message to parent

    " If parent has exited (uppid=0), message goes nowhere
    " In real PDP-11 Unix, child would be reparented to init

    "────────────────────────────────────────────────────────
    " STEP 3: FREE PROCESS TABLE ENTRY
    "────────────────────────────────────────────────────────
    lac proc        " Current process number
    alss 2          " × 4 for entry offset
    tad ulist       " Add base address
    dac 8           " Pointer to our entry

    dza             " Zero accumulator
    dac 8 i         " ulist[proc,0] = 0 (state = unused)
    dac 8 i         " ulist[proc,1] = 0 (clear PID)
    dac 8 i         " ulist[proc,2] = 0 (clear track)
    dac 8 i         " ulist[proc,3] = 0

    " Process table entry is now free for reuse

    "────────────────────────────────────────────────────────
    " STEP 4: SCHEDULE ANOTHER PROCESS
    "────────────────────────────────────────────────────────
    " We can't return to user mode - process is gone!
    " Must immediately switch to another process

    jms schedule    " Find next ready process
                    " This never returns
```

### Cleanup Operations

#### Closing File Descriptors

When a process exits, all its open files must be closed:

```assembly
closefd:
    " Input: AC = file descriptor number
    dac fd          " Save fd

    " Get file table entry
    lac fd
    tad filelist    " Address of file table
    dac 8
    lac 8 i         " Get file structure pointer
    dac fptr

    " Decrement reference count
    lac fptr
    dac 8
    isz 8           " Point to refcount field
    lac 8 i         " Get current refcount
    cma             " Complement
    tad d1          " Add 1 (equivalent to subtract 1)
    dac 8 i         " Store decremented refcount

    sza             " Skip if now zero
    jmp notlast     " Still references, don't close file

    " Last reference - close file
    lac fptr
    jms reallyclose " Write inode, free blocks

notlast:
    " Clear descriptor slot
    lac fd
    tad ufil
    dac 8
    dza
    dac 8 i         " ufil[fd] = 0

    jmp closefd i   " Return
```

**Why decrement reference counts?** Because fork creates shared file descriptors. If parent and child both have file 3 open:
- Parent's ufil[3] = 14 (file table entry)
- Child's ufil[3] = 14 (same entry)
- File table entry 14 has refcount = 2

When child exits and closes file 3:
- Refcount: 2 → 1
- File stays open (parent still using it)

When parent later closes file 3:
- Refcount: 1 → 0
- File actually closed

### Message to Parent

The exit message allows the parent to detect termination:

```assembly
" Parent process can wait for child:
.wait:
    jms rmes        " Receive message (blocking)
    " AC now contains child PID that exited
    jmp sysexit     " Return child PID to caller
```

The message format is simple:
- **Sender**: Child process (automatically added by smes)
- **Recipient**: Parent PID (from uppid)
- **Data**: Child's PID (so parent knows which child exited)

If the parent has already exited (uppid=0 or invalid), the message is lost. In later Unix versions, orphaned processes are reparented to PID 1 (init), which periodically collects exit messages.

### Process Table Cleanup

Setting the state to 0 is critical:

```assembly
    dza
    dac 8 i         " ulist[proc,0] = 0
```

This makes the slot available for the next `fork()`. The PID is also cleared to prevent confusion:

```assembly
    dac 8 i         " ulist[proc,1] = 0
```

### No Return Path

Unlike most system calls, `exit()` does NOT call `sysexit`:

```assembly
" Normal system call:
.open:
    " ... do work ...
    jmp sysexit     " Return to user mode

" Exit is different:
.exit:
    " ... cleanup ...
    jms schedule    " Switch to another process
    " NEVER REACHED
```

The `schedule` function finds another ready process and jumps to it. There's no way back—the process is gone.

### Complete Execution Trace

Let's trace a process exiting:

```
Initial State (child process 43):
  PID: 43
  PPID: 42 (parent)
  Open files: 3, 4, 7
  State: 1 (in memory, running)

────────────────────────────────────────────────────────────

Child executes:  sys exit

T=0ms: Enter .exit

T=1ms: Close file descriptor 3
  - ufil[3] = 14 (file table entry)
  - File 14 refcount: 2 → 1 (parent still has it)
  - Keep file open
  - ufil[3] = 0 (clear descriptor)

T=2ms: Close file descriptor 4
  - ufil[4] = 7
  - File 7 refcount: 1 → 0 (last reference)
  - Really close file 7
  - Write inode to disk
  - Free disk blocks
  - ufil[4] = 0

T=3ms: Close file descriptor 7
  - ufil[7] = 21
  - File 21 refcount: 1 → 0
  - Really close file 21
  - ufil[7] = 0

T=15ms: Send exit message
  - Message: PID 43
  - Destination: PID 42 (parent)
  - smes: enqueue message

T=16ms: Free process table entry
  - ulist[1,0] = 0 (state unused)
  - ulist[1,1] = 0 (clear PID)
  - ulist[1,2] = 0 (clear track)
  - ulist[1,3] = 0

T=17ms: Schedule another process
  - Search for ready process
  - Find process 42 (parent, state 2→1, was blocked in wait)
  - Swap parent in (if needed)
  - Jump to parent's saved PC
  - Parent's AC = 43 (from message)

────────────────────────────────────────────────────────────

Final State:
  Process 43: GONE (state 0, no longer exists)
  Process 42 (parent): running, AC=43 (child PID)

  File table:
    Entry 14: refcount=1 (parent still has it open)
    Entry 7:  freed (refcount was 0)
    Entry 21: freed (refcount was 0)
```

### Orphaned Processes

What if the parent exits before the child?

```assembly
" Parent (PID 42):
    sys fork
    sza
    jmp parent

child:
    " Child process
    " ... do work ...
    sys exit        " Try to send message to parent

parent:
    " Parent doesn't wait
    sys exit        " Parent exits immediately!
```

**Problem**: Child's exit message has nowhere to go (uppid=42, but PID 42 no longer exists).

**PDP-7 Unix solution**: Message is lost. Child's exit is not collected.

**PDP-11 Unix solution** (later): Orphaned processes are reparented to PID 1 (init), which periodically calls `wait()` to collect zombies.

## 8.7 Process Swapping

With only 8K of memory and support for multiple processes, PDP-7 Unix needs a way to multiplex memory among processes. The solution is **swapping**: move inactive processes to disk, load active processes into memory.

### Why Swapping?

**The fundamental problem:**
- 8K words of memory (addresses 0-7777 octal)
- Each process needs ~2K words for code and data
- Maximum 4 processes could fit simultaneously
- But with kernel, buffers, file cache, only ~6K available for user processes
- **Conclusion**: Only 1 user process fits in memory at a time

**The solution:**
- Keep only the **active** process in memory
- Write **inactive** processes to disk (swap out)
- Read processes back when needed (swap in)
- Processes "take turns" using memory

**Advantages:**
- Support many more than 4 processes (up to 10)
- Simple memory management (no partitions, no fragmentation)
- Fair CPU sharing via time-slicing

**Disadvantages:**
- Swapping is slow (~100ms per swap)
- Context switch overhead
- Limited by disk I/O speed

### Swap Algorithm in s1.s

The swap scheduler runs at every system call exit and clock tick:

```assembly
" Swap scheduler - called before returning to user mode
swap:
    "────────────────────────────────────────────────────────
    " CHECK 1: Has time quantum expired?
    "────────────────────────────────────────────────────────
    lac s.quantum   " Time remaining in quantum
    sna             " Skip if non-zero
    jmp needswap    " Quantum expired, must swap

    " Quantum remains, keep running
    jmp noswap

needswap:
    "────────────────────────────────────────────────────────
    " CHECK 2: Is there another ready process?
    "────────────────────────────────────────────────────────
    jms lookfor     " Search for ready process
    sza             " Skip if found one
    jmp doswap      " Found another, swap out

    " No other ready process, keep running
    law quantum     " Reset quantum
    dac s.quantum
    jmp noswap

doswap:
    "────────────────────────────────────────────────────────
    " STEP 1: SAVE CURRENT PROCESS TO DISK
    "────────────────────────────────────────────────────────
    lac proc        " Current process number
    jms dskswap     " Write to disk

    " Update process state
    lac proc
    alss 2          " × 4
    tad ulist
    dac 8
    lac d3          " State 3 = on disk, ready
    dac 8 i

    "────────────────────────────────────────────────────────
    " STEP 2: LOAD NEXT PROCESS FROM DISK
    "────────────────────────────────────────────────────────
    lac nextproc    " Process to run (from lookfor)
    jms dskswapin   " Read from disk

    " Update process state
    lac nextproc
    alss 2
    tad ulist
    dac 8
    lac d1          " State 1 = in memory, ready
    dac 8 i

    " Update current process pointer
    lac nextproc
    dac proc

    " Reset quantum
    law quantum
    dac s.quantum

noswap:
    " Return to process (old or new)
    jmp swapdone
```

### Quantum-Based Preemption

Each process gets a **time quantum** of 30 clock ticks (approximately 0.5 seconds):

```assembly
" In s8.s - Constants
quantum = 30    " Clock ticks per quantum (60Hz clock)

" In s7.s - Clock interrupt handler
clkint:
    " Clock tick (60 Hz)
    isz s.quantum   " Increment quantum counter
                    " (stored as negative)
    jmp clkdone     " Not expired yet

    " Quantum expired!
    " Set flag to swap at next system call exit
    lac d1
    dac s.needswap

clkdone:
    " Continue interrupt processing
    jmp intdone
```

**How it works:**
1. s.quantum starts at -30 (negative of quantum)
2. Each clock tick, ISZ increments it (-30, -29, -28, ...)
3. When it reaches 0, ISZ skips (quantum expired)
4. Set s.needswap flag
5. At next system call exit, swap scheduler runs

**Why not swap immediately in clock interrupt?**
- Interrupts should be short
- Swapping requires disk I/O (slow)
- Safer to swap at controlled exit point

### Disk Tracks 06000/07000

Two disk tracks are reserved for swapping:

```assembly
" In s8.s - Swap tracks
swaptrk1: 06000     " First swap track
swaptrk2: 07000     " Second swap track

" Process table entries contain swap track:
"   ulist[proc,2] = 06000 or 07000
```

**Why only 2 tracks?**
- Each process needs 1 track (2048 words)
- With 10 processes max, need 10 tracks
- But only 1 process is in memory at a time
- The other 9 are on disk
- **Actually need 9 tracks, but PDP-7 Unix only supports 2!**

This is a **bug** or limitation: PDP-7 Unix cannot actually support 10 concurrent processes. In practice, only 2-3 processes were ever used simultaneously.

**Track layout:**
- Track 06000: Contains swapped-out process memory
- Track 07000: Contains another swapped-out process memory

Each track holds:
- Words 0-7777: Full 8K memory image
- Includes code, data, stack
- Does NOT include hardware registers (those are in userdata)

### Complete Swapping Implementation

The `dskswap` function in `s5.s` performs the actual I/O:

```assembly
" dskswap - Write current process memory to disk
" Input: AC = process number
" Uses track from ulist[proc,2]

dskswap:
    dac savproc     " Save process number

    "────────────────────────────────────────────────────────
    " STEP 1: GET SWAP TRACK ADDRESS
    "────────────────────────────────────────────────────────
    lac savproc
    alss 2          " × 4 for entry offset
    tad ulist
    dac 8
    isz 8           " Skip to ulist[proc,2]
    isz 8
    lac 8 i         " Get track number
    dac track

    "────────────────────────────────────────────────────────
    " STEP 2: WRITE MEMORY TO DISK
    "────────────────────────────────────────────────────────
    " Write all 8K words (addresses 0-7777)
    " DECtape track = 1024 words
    " Need 8 track writes to save 8K

    dza             " Start at memory address 0
    dac addr
    lac track       " Disk track
    dac dskaddr
    law 8           " Write 8 × 1024 words
    dac count

swploop:
    lac addr        " Memory address
    dac from
    lac dskaddr     " Disk address
    jms dskwr       " Write 1024 words

    lac addr
    tad d1024       " Advance memory pointer
    dac addr

    lac dskaddr
    tad d1          " Next disk sector
    dac dskaddr

    isz count
    jmp swploop

    "────────────────────────────────────────────────────────
    " STEP 3: WRITE USERDATA TO DISK
    "────────────────────────────────────────────────────────
    " Write userdata (64 words) to end of track
    law userdata
    dac from
    lac track
    tad d8          " Sector 8 (after memory image)
    jms dskwr       " Write 64 words

    jmp dskswap i   " Return

d1024: 1024        " Words per sector
```

The swap-in function is similar:

```assembly
" dskswapin - Read process memory from disk
" Input: AC = process number

dskswapin:
    dac savproc

    " Get track number
    lac savproc
    alss 2
    tad ulist
    dac 8
    isz 8
    isz 8
    lac 8 i
    dac track

    " Read 8K memory from disk
    dza
    dac addr
    lac track
    dac dskaddr
    law 8
    dac count

swpinloop:
    lac dskaddr     " Disk address
    lac addr        " Memory address
    dac to
    jms dskrd       " Read 1024 words

    lac addr
    tad d1024
    dac addr

    lac dskaddr
    tad d1
    dac dskaddr

    isz count
    jmp swpinloop

    " Read userdata from disk
    lac track
    tad d8
    law userdata
    dac to
    jms dskrd       " Read 64 words

    jmp dskswapin i
```

### Performance Analysis

**Swap-out time** (write process to disk):
- 8K words ÷ 1024 words/sector = 8 sectors
- Each sector write ≈ 6ms (DECtape speed)
- Total: 8 × 6ms = **48ms**
- Plus userdata (64 words) ≈ 1ms
- **Total swap-out: ~50ms**

**Swap-in time** (read process from disk):
- Same as swap-out: **~50ms**

**Total context switch time:**
- Swap-out: 50ms
- Swap-in: 50ms
- Overhead (scheduling, state update): 2ms
- **Total: ~102ms**

**Throughput impact:**
- With 30-tick quantum (0.5s) and 102ms swap time
- Effective CPU utilization: 500ms / (500ms + 102ms) = **83%**
- 17% overhead from swapping

**Comparison with other systems:**
- **Multics** (1969): Paging overhead ~5% (much faster disk)
- **OS/360** (batch): No swapping, 0% overhead (but no multitasking)
- **Modern Linux**: Context switch ~1-10μs (4-5 orders of magnitude faster!)

### Complete Execution Trace

Let's trace a full swap cycle between two processes:

```
Initial State:
  Process 42 (shell): State 1, in memory
  Process 43 (user program): State 3, on disk (track 07000)
  s.quantum = -5 (5 ticks remaining)
  Current proc = 42

────────────────────────────────────────────────────────────

T=0ms: Clock tick (59th this quantum)
  - ISZ s.quantum: -5 → -4
  - Quantum not yet expired

T=16ms: Clock tick (60th this quantum)
  - ISZ s.quantum: -1 → 0
  - Skip occurs, quantum expired
  - Set s.needswap = 1

T=17ms: Process 42 makes system call (read)
  - Enter system call handler
  - Process read operation
  - Return to swap scheduler

T=20ms: Swap scheduler runs
  - Check s.needswap: 1 (must swap)
  - Call lookfor: finds process 43 (state 3)
  - Decide to swap

T=21ms: Swap out process 42
  - dskswap(42)
  - Write memory 0-7777 to track 06000
  - Write userdata to track 06000, sector 8
  - DECtape transfer: 48ms

T=69ms: Swap out complete
  - Update ulist[42,0] = 3 (on disk, ready)

T=70ms: Swap in process 43
  - dskswapin(43)
  - Read track 07000 to memory 0-7777
  - Read userdata from track 07000, sector 8
  - DECtape transfer: 48ms

T=118ms: Swap in complete
  - Update ulist[43,0] = 1 (in memory, ready)
  - Set proc = 43
  - Reset s.quantum = -30

T=120ms: Resume process 43
  - Restore AC, MQ from userdata
  - Jump to saved PC
  - Process 43 is now running!

────────────────────────────────────────────────────────────

Final State:
  Process 42: State 3, on disk (track 06000)
  Process 43: State 1, in memory, running
  s.quantum = -30
  Current proc = 43

  Total swap time: 100ms
  Processes "traded places" in memory
```

## 8.8 Scheduling

Process scheduling in PDP-7 Unix is refreshingly simple: **round-robin** with equal time quanta and no priorities. Every process gets exactly 30 clock ticks (0.5 seconds) before being preempted.

### Simple Round-Robin

The scheduler has one goal: **find the next ready process**. That's it. No priority calculations, no fairness adjustments, no complex heuristics.

```assembly
" lookfor - Find next ready process
" Returns: AC = process number, or 0 if none ready

lookfor:
    "────────────────────────────────────────────────────────
    " STRATEGY: Search process table circularly, starting
    "           after current process
    "────────────────────────────────────────────────────────

    lac proc        " Current process number
    tad d1          " Start with next process
    dac search      " Initialize search pointer

    law mnproc      " Counter = 10 (max processes)
    dac count

searchloop:
    lac search      " Get candidate process number
    dac temp

    " Wrap around if past end
    lac temp
    sad mnproc      " At limit?
    dza             " Yes, wrap to 0
    dac search

    " Get process state
    lac search
    alss 2          " × 4 for entry offset
    tad ulist
    dac 8
    lac 8 i         " Get ulist[search,0]
    and d3          " Mask to state bits

    " Check if ready
    sad d1          " State 1 = in memory, ready?
    jmp foundready
    sad d3          " State 3 = on disk, ready?
    jmp foundready

    " Not ready, try next
    lac search
    tad d1
    dac search
    isz count
    jmp searchloop

    " No ready processes found
    dza             " Return 0
    jmp lookfor i

foundready:
    lac search      " Return process number
    jmp lookfor i
```

### Quantum = 30 Clock Ticks

The time quantum is a compile-time constant:

```assembly
" In s8.s
quantum = 30        " Clock ticks per quantum
                    " At 60Hz, this is 0.5 seconds
```

**Why 30 ticks (0.5 seconds)?**

**Too short** (e.g., 10 ticks = 0.17s):
- Frequent context switches
- High swapping overhead (102ms per swap)
- Poor throughput

**Too long** (e.g., 300 ticks = 5s):
- Poor responsiveness
- Feels like batch processing
- User waits long time for interaction

**30 ticks is a compromise:**
- User gets response within 1-2 seconds
- Swapping overhead only ~20%
- Feels reasonably interactive

**Comparison with other systems:**
- **Multics** (1969): 200ms quantum (similar)
- **Unix v6** (1975): 100ms quantum (faster hardware)
- **Modern Linux**: 1-10ms quantum (much faster I/O)

### No Priorities

**Every process is equal.** There are no:
- Priority levels (nice values)
- Real-time processes
- Interactive vs. batch distinction
- Aging or starvation prevention

This simplicity is both a strength and weakness:

**Strengths:**
- Predictable scheduling (easy to reason about)
- No priority inversion problems
- No starvation (everyone gets equal time)
- Minimal code complexity

**Weaknesses:**
- CPU-bound processes can make system feel sluggish
- No way to prioritize important work
- Batch jobs get same treatment as interactive shell

**In practice**, with 1-2 users and simple programs, priorities weren't needed. The system was fast enough.

### The lookfor Function - Complete Code

Here's the full scheduler with detailed comments:

```assembly
lookfor:
    "────────────────────────────────────────────────────────
    " Find next ready process using round-robin search
    " Returns: AC = process number (0-9), or 0 if none ready
    "────────────────────────────────────────────────────────

    lac proc        " Start with current process
    tad d1          " Look at next one first
    dac search      " search = proc + 1

    law mnproc      " Initialize counter
    dac count       " Will check all 10 slots

searchloop:
    "────────────────────────────────────────────────────────
    " Wrap around if we've gone past last slot
    "────────────────────────────────────────────────────────
    lac search
    sad mnproc      " search == 10?
    dza             " Yes, wrap to 0
    dac search      " search = 0

    "────────────────────────────────────────────────────────
    " Get process table entry
    "────────────────────────────────────────────────────────
    lac search      " Process number
    alss 2          " × 4 (4 words per entry)
    tad ulist       " Add base address
    dac 8           " Set up auto-increment pointer

    lac 8 i         " Load ulist[search,0]
    and d3          " Mask to state bits (0-1)
    dac pstate      " Save for comparison

    "────────────────────────────────────────────────────────
    " Check for ready states (1 or 3)
    "────────────────────────────────────────────────────────
    lac pstate
    sad d1          " State 1 (in memory, ready)?
    jmp foundone    " Yes!

    lac pstate
    sad d3          " State 3 (on disk, ready)?
    jmp foundone    " Yes!

    " State 0 (unused) or 2 (blocked) - skip this process

    "────────────────────────────────────────────────────────
    " Try next process
    "────────────────────────────────────────────────────────
    lac search
    tad d1          " search++
    dac search

    isz count       " Decrement counter
    jmp searchloop  " Continue if more to check

    "────────────────────────────────────────────────────────
    " Checked all processes, none ready
    "────────────────────────────────────────────────────────
    jmp idle        " Idle loop (wait for interrupt)

foundone:
    "────────────────────────────────────────────────────────
    " Found ready process
    "────────────────────────────────────────────────────────
    lac search      " Return process number
    jmp lookfor i   " Return to caller
```

### Idle Loop

What happens when **no processes are ready**? The system enters an idle loop:

```assembly
idle:
    " All processes are blocked or swapped out
    " Wait for interrupt to make something ready

    " Enable interrupts
    " (on PDP-7, interrupts are always enabled in user mode)

idleloop:
    " Spin waiting for interrupt
    " When clock tick or I/O interrupt occurs,
    " interrupt handler may unblock a process

    jms lookfor     " Check again
    sza             " Found ready process?
    jmp schedule    " Yes, run it

    jmp idleloop    " No, keep waiting
```

**What wakes the system from idle?**
- **Clock interrupt**: May deliver a message or wake sleeping process
- **Disk interrupt**: I/O completes, process becomes ready
- **Keyboard interrupt**: Input arrives, shell becomes ready
- **Display interrupt**: Output completes

### Complete Scheduling Example

Let's trace scheduling decisions over time:

```
Initial State:
  Process 1 (init):  State 2 (blocked, waiting for message)
  Process 42 (sh):   State 1 (in memory, ready, running)
  Process 43 (user): State 3 (on disk, ready)
  Current process: 42
  Quantum: -10 (10 ticks remaining)

────────────────────────────────────────────────────────────

T=0ms: Process 42 running
  - Executing user commands
  - Quantum counts down

T=150ms: Clock tick (10 ticks later)
  - ISZ s.quantum: 0
  - Quantum expired
  - Set s.needswap = 1

T=151ms: Process 42 makes system call
  - Enter kernel
  - swap() scheduler runs
  - lookfor() searches:
    - Check proc 43: State 3 (on disk, ready) ✓
  - Decision: Swap out 42, swap in 43

T=200ms: Context switch completes
  - Process 42: State 3 (on disk)
  - Process 43: State 1 (in memory)
  - Current proc = 43
  - Quantum reset to -30

T=700ms: Process 43 blocks on I/O
  - Calls read(), disk starts
  - Process 43: State 2 (blocked)
  - lookfor() searches:
    - Check proc 1: State 2 (blocked) ✗
    - Check proc 42: State 3 (on disk, ready) ✓
  - Decision: Swap in 42

T=800ms: Context switch completes
  - Process 43: State 2 (in memory, blocked)
  - Process 42: State 1 (in memory, ready)
  - Current proc = 42

T=850ms: Disk interrupt
  - I/O for process 43 completes
  - Process 43: State 1 (ready, but in memory!)
  - Now TWO processes ready (42 and 43)
  - But only one can be in memory!
  - Current process 42 continues

T=1300ms: Quantum expires for process 42
  - lookfor() searches:
    - Check proc 43: State 1 (in memory, ready) ✓
  - Decision: No swap needed!
  - Both in memory, just switch context
  - Current proc = 43

────────────────────────────────────────────────────────────

Note: In real PDP-7 Unix, two processes can't both be in
memory. One must be swapped. The example above shows a
simplified view. In reality:
  - When proc 43's I/O completes, it stays State 2
  - State only becomes 1 when scheduled
  - Only one process is ever State 1 at a time
```

## 8.9 Inter-Process Communication

PDP-7 Unix provides a simple message-passing system for inter-process communication. Processes can send and receive short messages identified by the sender's and recipient's PIDs.

### smes - Send Message

```assembly
" smes - Send message
" Input:  AC = recipient PID
"         mesgdata = message value
" Returns: AC = 0 on success, -1 if queue full

.smes:
    dac rpid        " Save recipient PID

    "────────────────────────────────────────────────────────
    " STEP 1: FIND FREE MESSAGE SLOT
    "────────────────────────────────────────────────────────
    law mesqueue    " Message queue array
    dac 8
    law nmesgs      " Maximum messages
    dac count

findmsg:
    lac 8 i         " Get message slot
    sza             " Skip if empty (0)
    jmp trynext

    " Found free slot
    jmp gotslot

trynext:
    isz 8           " Skip to next slot
    isz 8           " (each message is 2 words)
    isz count
    jmp findmsg

    " No free slots
    lac dm1         " Return -1 (error)
    jmp sysexit

gotslot:
    "────────────────────────────────────────────────────────
    " STEP 2: STORE MESSAGE
    "────────────────────────────────────────────────────────
    lac rpid        " Recipient PID
    dac 8 i         " mesqueue[slot,0] = recipient

    lac mesgdata    " Message value
    dac 8 i         " mesqueue[slot,1] = data

    "────────────────────────────────────────────────────────
    " STEP 3: WAKE UP RECIPIENT IF BLOCKED
    "────────────────────────────────────────────────────────
    lac rpid        " Which process to wake?
    jms wakeup      " Change state 2 → 1

    dza             " Return 0 (success)
    jmp sysexit
```

### rmes - Receive Message (Blocking)

```assembly
" rmes - Receive message
" Blocks until message arrives for current process
" Returns: AC = message value
"          rmespid = sender PID

.rmes:
    "────────────────────────────────────────────────────────
    " STEP 1: SEARCH FOR MESSAGE TO US
    "────────────────────────────────────────────────────────
checkagain:
    law mesqueue    " Start of message queue
    dac 8
    law nmesgs      " Message count
    dac count

searchmsg:
    lac 8 i         " Get recipient PID from message
    sza             " Skip if empty slot
    jmp checkmsg

    " Empty slot, try next
    jmp nextmsg

checkmsg:
    lac 8 i         " Get recipient (already loaded)
    sad upid        " Message for us?
    jmp gotmsg      " Yes!

nextmsg:
    isz 8           " Skip to next message
    isz 8
    isz count
    jmp searchmsg

    "────────────────────────────────────────────────────────
    " STEP 2: NO MESSAGE FOUND - BLOCK
    "────────────────────────────────────────────────────────
    lac d2          " State 2 = blocked
    dac procstate   " Update our state

    jms schedule    " Give up CPU
    " When we wake up, a message has arrived
    jmp checkagain  " Search again

gotmsg:
    "────────────────────────────────────────────────────────
    " STEP 3: EXTRACT MESSAGE AND CLEAR SLOT
    "────────────────────────────────────────────────────────
    lac 8           " Pointer to message
    tad dm1         " Back up to recipient field
    dac 8
    lac 8 i         " Get recipient (for verification)
    lac 8 i         " Get message data
    dac mesgdata    " Save message value

    " Clear message slot
    lac 8
    tad dm1
    dac 8
    dza
    dac 8 i         " mesqueue[slot,0] = 0 (free)
    dac 8 i         " mesqueue[slot,1] = 0

    " Return message value
    lac mesgdata
    jmp sysexit
```

### Message Queue Structure

The message queue is a simple array in `s8.s`:

```assembly
" Message queue - 10 messages maximum
nmesgs = 10

mesqueue: .=.+nmesgs*2    " 10 messages × 2 words = 20 words

" Each message:
"   Word 0: Recipient PID (0 = free slot)
"   Word 1: Message data
```

**Example message queue:**

```
Address  Slot  Word  Value   Meaning
-------  ----  ----  ------  ---------------------------
mesqueue  0     0    000042  Message for PID 42
mesqueue  0     1    000123  Data = 123

mesqueue  1     0    000001  Message for PID 1 (init)
mesqueue  1     1    000043  Data = 43 (child exited)

mesqueue  2     0    000000  Free slot
mesqueue  2     1    000000

mesqueue  3     0    000042  Another message for PID 42
mesqueue  3     1    000077  Data = 77

...
```

### Use in init

The `init` process uses messages to detect child termination:

```assembly
" In init.s - Login process
init:
    " Fork shell for user
    sys fork
    sza
    jmp parent

child:
    " Execute shell
    sys exec; shell
    sys exit        " If exec fails

parent:
    " Parent waits for child to exit
    dac childpid    " Save child PID

waitloop:
    sys rmes        " Receive message (blocks)

    " AC now contains message
    " For exit, message = child PID
    sad childpid    " Is it our child?
    jmp childdone   " Yes!

    " Message from someone else, ignore
    jmp waitloop

childdone:
    " Child has exited, spawn new login
    jmp init        " Start over
```

**Message flow:**
1. Init forks shell (PID 42)
2. Init blocks in `rmes`
3. User types "exit" in shell
4. Shell calls `sys exit`
5. Exit sends message: recipient=1 (init), data=42 (shell PID)
6. Init wakes up with AC=42
7. Init detects child termination
8. Init spawns new login

### Full IPC Implementation

Let's examine the complete message-passing mechanism:

```assembly
" ============================================================
" smes - Send message to another process
" ============================================================
.smes:
    " User setup:
    "   sys smes; pid
    "   Message data in AC

    " Get recipient PID from user instruction
    lac urq         " Return address
    dac 8
    lac 8 i         " Get argument (recipient PID)
    dac rpid

    " Get message data from AC
    lac uac         " User's AC
    dac mesgdata

    "────────────────────────────────────────────────────────
    " Find free message slot
    "────────────────────────────────────────────────────────
    law mesqueue-2  " Start before first entry
    dac 8
    law nmesgs      " Counter = 10
    dac count

sloop:
    isz 8           " Advance to next message
    isz 8           " (2 words per message)
    lac 8 i         " Get recipient field
    sza             " Skip if 0 (free)
    jmp snext       " In use, try next

    " Found free slot
    jmp sfound

snext:
    isz 8           " Skip data field
    isz count
    jmp sloop

    " Queue full
    lac dm1         " Error return
    jmp sysexit

sfound:
    "────────────────────────────────────────────────────────
    " Store message
    "────────────────────────────────────────────────────────
    lac 8           " Pointer to slot
    tad dm1         " Back to recipient field
    dac 8
    lac rpid        " Recipient PID
    dac 8 i         " Store
    lac mesgdata    " Message data
    dac 8 i         " Store

    "────────────────────────────────────────────────────────
    " Wake recipient if blocked
    "────────────────────────────────────────────────────────
    lac rpid
    jms findproc    " Find in process table
    sza             " Skip if not found
    jmp checkstate

    " Process not found
    jmp sdone

checkstate:
    dac pnum        " Save process number
    alss 2          " × 4
    tad ulist
    dac 8
    lac 8 i         " Get state
    and d3
    sad d2          " State 2 (blocked)?
    jmp wakeproc    " Yes, wake it

    " Not blocked, message will wait
    jmp sdone

wakeproc:
    lac d1          " State 1 = ready
    dac 8 i         " Update process state

sdone:
    dza             " Success
    jmp sysexit

" ============================================================
" rmes - Receive message (blocking)
" ============================================================
.rmes:
    " No user arguments needed
    " Returns message data in AC

rcvloop:
    "────────────────────────────────────────────────────────
    " Search message queue for message to us
    "────────────────────────────────────────────────────────
    law mesqueue-2
    dac 8
    law nmesgs
    dac count

rloop:
    isz 8
    isz 8
    lac 8 i         " Get recipient PID
    sza             " Skip if empty
    jmp rcheck      " Check if for us

    " Empty slot
    jmp rnext

rcheck:
    lac 8 i         " Get recipient again
    sad upid        " For us?
    jmp rfound      " Yes!

rnext:
    isz 8           " Skip data field
    isz count
    jmp rloop

    "────────────────────────────────────────────────────────
    " No message found - block
    "────────────────────────────────────────────────────────
    lac proc        " Our process number
    alss 2
    tad ulist
    dac 8
    lac d2          " State 2 = blocked
    dac 8 i         " Update our state

    jms schedule    " Give up CPU
    " When awakened, try again
    jmp rcvloop

rfound:
    "────────────────────────────────────────────────────────
    " Extract message and free slot
    "────────────────────────────────────────────────────────
    lac 8           " Pointer to data field
    tad dm1         " Back to recipient field
    dac 8
    lac 8 i         " Skip recipient
    lac 8 i         " Get data
    dac mesgdata    " Save

    " Free the slot
    lac 8
    tad dm2         " Back to start
    dac 8
    dza
    dac 8 i         " Clear recipient
    dac 8 i         " Clear data

    " Return message data
    lac mesgdata
    jmp sysexit
```

### Message-Passing Execution Trace

Let's trace a complete message exchange:

```
Initial State:
  Process 1 (init): State 2 (blocked in rmes)
  Process 42 (shell): State 1 (running)
  Message queue: all empty

────────────────────────────────────────────────────────────

T=0ms: Shell decides to exit
  - User typed "exit"
  - Shell prepares to call exit()

T=1ms: Shell calls exit()
  - Enter .exit system call
  - Close all files (3ms)

T=4ms: Exit sends message to parent
  - rpid = uppid = 1 (init)
  - mesgdata = upid = 42 (shell PID)
  - Call smes

T=5ms: smes searches for free message slot
  - mesqueue[0,0] = 0 (free!)
  - Found slot 0

T=6ms: smes stores message
  - mesqueue[0,0] = 1 (recipient = init)
  - mesqueue[0,1] = 42 (data = shell PID)

T=7ms: smes wakes init
  - Find process 1 in table
  - State = 2 (blocked)
  - Change to state 1 (ready)

T=8ms: Exit continues
  - Free process table entry
  - Process 42 no longer exists

T=9ms: Schedule another process
  - lookfor finds process 1 (init, state 1)
  - Swap init into memory

T=60ms: Init resumes in rmes
  - Was blocked at rloop
  - Jump to rcvloop to search again

T=61ms: rmes searches message queue
  - mesqueue[0,0] = 1 (for init!) ✓
  - mesqueue[0,1] = 42
  - Found message!

T=62ms: rmes extracts message
  - mesgdata = 42
  - Clear mesqueue[0,0] = 0
  - Clear mesqueue[0,1] = 0

T=63ms: rmes returns
  - AC = 42 (child PID)
  - Init knows child 42 exited

T=64ms: Init spawns new login
  - jmp init (restart)
  - Fork new shell

────────────────────────────────────────────────────────────

Final State:
  Process 1 (init): State 1 (running, spawning new shell)
  Process 42 (shell): Gone (exited)
  Message queue: empty again
```

## 8.10 Context Switching

Context switching is the mechanism that saves one process's state and restores another's. In PDP-7 Unix, this happens during system calls and interrupts.

### Save/Restore Mechanism

**Save context** (on system call entry):

```assembly
" System call trap entry (location 020)
020:
    dac uac         " Save AC
    law 020         " Return address
    dac urq         " Save return point
    lac 017         " Get MQ register
    dac umq         " Save MQ

    " Other registers saved elsewhere:
    " - PC saved by hardware in rq
    " - Link saved implicitly

    " Kernel can now freely modify AC, MQ
```

**Restore context** (on system call exit):

```assembly
sysexit:
    " Restore all user registers
    lac umq         " Get saved MQ
    dac 017         " Restore to MQ register

    lac urq         " Get saved return address
    dac 8           " Set up indirect jump

    lac uac         " Restore AC (contains return value)

    jmp 8 i         " Return to user mode
    " PC restored implicitly by jmp
```

### Register Preservation

The PDP-7 has very few registers:
- **AC** (accumulator): Must be saved/restored
- **MQ** (multiplier-quotient): Must be saved/restored
- **PC** (program counter): Saved implicitly by trap hardware
- **Link** (carry bit): Usually doesn't need explicit save

**Why so few?** The PDP-7 architecture is extremely simple. Most "registers" are actually memory locations:
- Auto-increment pointers (locations 010-017)
- Temporary variables (allocated in memory)

### User/Kernel Mode Transition

**User mode → Kernel mode** (system call):

```
1. User executes: sys open; file

2. Hardware trap:
   - PC saved in hardware rq register
   - Jump to location 020

3. Kernel entry (020):
   - Save AC to uac
   - Save MQ to umq
   - Save rq to urq
   - Set .insys flag

4. Kernel runs:
   - Dispatch to .open
   - Execute system call
   - Modify AC (return value)

5. Kernel exit (sysexit):
   - Restore MQ from umq
   - Restore AC from uac
   - Clear .insys flag
   - Jump indirect through urq

6. Hardware return:
   - PC restored
   - User continues after 'sys' instruction
```

**Interrupt** (asynchronous):

```
1. User running:
   - Executing normal code
   - E.g., lac x; tad y; dac z

2. Hardware interrupt:
   - PC saved in hardware rq
   - Jump to interrupt vector

3. Interrupt handler:
   - Save AC, MQ (if needed)
   - Process interrupt (disk, clock, TTY)
   - Restore AC, MQ
   - jmp rq i (return)

4. User resumes:
   - Continues as if nothing happened
   - (unless interrupt changed process state)
```

### Complete Code Analysis

Here's the full context switch path:

```assembly
" ============================================================
" SYSTEM CALL ENTRY - Save user context
" ============================================================
020:
    " Hardware trap brings us here
    " rq register contains return address (user PC)
    " AC contains whatever user left in it
    " MQ contains whatever user left in it

    dac uac         " Save AC to userdata+0

    law 020         " Our entry address
    dac urq         " Save as return point (userdata+2)

    lac 017         " Get MQ from memory location 017
    dac umq         " Save to userdata+1

    " Check for recursive system call
    lac s.insys     " Inside-system-call flag
    sna             " Skip if non-zero
    jmp .+3         " Not recursive, OK

    " Recursive call - panic!
    error

    " Set flag
    lac d1
    dac s.insys     " Mark as inside system call

    "────────────────────────────────────────────────────────
    " Get system call number from user instruction
    "────────────────────────────────────────────────────────
    lac urq         " Return address
    dac 8
    lac 8 i         " Get instruction (system call #)
    dac syscall     " Save it

    "────────────────────────────────────────────────────────
    " Dispatch to handler
    "────────────────────────────────────────────────────────
    lac syscall
    sad maxsys      " Beyond max?
    error           " Invalid system call

    " Jump to handler via swp table
    lac syscall
    tad swp         " Add to dispatch table base
    dac 8
    jmp 8 i         " Indirect jump to handler

" ============================================================
" SYSTEM CALL EXIT - Restore user context
" ============================================================
sysexit:
    " Called by all system call handlers when done
    " AC contains return value for user

    dac uac         " Save return value

    " Clear inside-system-call flag
    dza
    dac s.insys

    "────────────────────────────────────────────────────────
    " Check if swapping needed
    "────────────────────────────────────────────────────────
    jms swap        " Swap scheduler
    " May swap out current process and swap in another
    " If swapped, this returns in new process context!

    "────────────────────────────────────────────────────────
    " Restore user registers
    "────────────────────────────────────────────────────────
    lac umq         " Get saved MQ
    dac 017         " Restore to MQ memory location

    lac urq         " Get return address
    dac 8           " Set up for indirect jump

    lac uac         " Get return value (last thing!)

    " Return to user mode
    jmp 8 i         " Jump indirect through return address

    " Now back in user mode!
    " PC is restored by jmp
    " AC contains return value
    " MQ is restored
    " All other state unchanged

" ============================================================
" CLOCK INTERRUPT - Minimal context save
" ============================================================
clkint:
    " Hardware saved PC in rq
    " We must save/restore AC if we modify it

    dac tempa       " Save AC

    " Update quantum
    isz s.quantum   " Increment (stored negative)
    jmp clkmore     " Not expired

    " Quantum expired
    lac d1
    dac s.needswap  " Set flag for next system call

clkmore:
    " Update time-of-day clock
    isz s.time

    " Restore AC
    lac tempa

    " Return from interrupt
    jmp rq i        " Jump indirect through rq (PC restore)

" ============================================================
" PROCESS SWITCH - Complete context exchange
" ============================================================
switch:
    " Switch from current process to another
    " This is called by swap scheduler

    " Current process is already saved to disk
    " (userdata written to swap track)

    " Load new process from disk
    lac newproc     " Process number to load
    jms dskswapin   " Read from swap track

    " Now userdata contains new process's context
    " Update current process pointer
    lac newproc
    dac proc

    " Reset quantum
    law quantum
    dac s.quantum

    " Restore new process's registers
    lac umq
    dac 017         " Restore MQ

    lac urq
    dac 8           " Set up return address

    lac uac         " Restore AC (last!)

    " Jump to new process
    jmp 8 i

    " We're now running in the new process!
    " Its PC, AC, MQ, all state restored
```

### Context Switch Timeline

Let's trace a complete context switch with exact register values:

```
Initial State (Process 42, shell):
  AC = 001234
  MQ = 005677
  PC = 003456 (about to execute 'sys fork')
  rq = (undefined)

Memory (userdata):
  uac = (stale)
  umq = (stale)
  urq = (stale)

────────────────────────────────────────────────────────────

T=0: Process 42 executes 'sys fork' at PC=003456

T=1: Hardware trap
  - Save PC to rq: rq = 003457 (next instruction)
  - Jump to 020

T=2: Save context (location 020)
  - uac = AC = 001234
  - urq = 020
  - umq = MQ = 005677
  - s.insys = 1

T=3: Dispatch to .fork
  - Execute fork logic
  - Create child process
  - Modify uac = 43 (child PID)

T=50: Fork swaps child to disk
  - Child process now on track 07000

T=51: Fork returns
  - jmp sysexit

T=52: sysexit
  - s.insys = 0
  - Call swap()

T=53: Swap decides to switch processes
  - Current quantum expired
  - Find process 43 (child, ready)
  - Swap out process 42

T=100: Swap process 42 to disk
  - Write memory 0-7777 to track 06000
  - Write userdata to track 06000
    - Saved uac = 43
    - Saved umq = 005677
    - Saved urq = 020

T=101: Update process 42 state
  - ulist[42,0] = 3 (on disk, ready)

T=102: Swap in process 43 from disk
  - Read track 07000 to memory 0-7777
  - Read userdata from track 07000
    - uac = 0 (child return value)
    - umq = 005677 (inherited from parent)
    - urq = 020 (same return point)

T=150: Resume process 43
  - proc = 43
  - Restore MQ = 005677
  - Restore AC = 0
  - jmp 020 (urq)

T=151: Process 43 running
  - PC = 003457 (after 'sys fork')
  - AC = 0 (child!)
  - MQ = 005677
  - Detects AC=0, runs child code

────────────────────────────────────────────────────────────

Later: Process 43 quantum expires, swap back to 42

T=500: Swap process 43 out, process 42 in

T=550: Resume process 42
  - Read userdata from disk
  - uac = 43
  - umq = 005677
  - urq = 020
  - Restore AC = 43
  - jmp 020

T=551: Process 42 running
  - PC = 003457 (after 'sys fork')
  - AC = 43 (parent!)
  - MQ = 005677
  - Detects AC=43, runs parent code
```

## 8.11 The Complete Process Lifecycle

Let's trace a process through its entire life from creation to termination, showing exact memory and process table state at each stage.

### Stage 0: Before fork

```
Process Table:
  ulist[0]: State=1, PID=1, Track=06000  (init, in memory)
  ulist[1]: State=0, PID=0, Track=0      (unused)
  ulist[2]: State=1, PID=42, Track=07000 (shell, in memory)
  ulist[3-9]: State=0 (all unused)

Memory (0-7777):
  0000-1777: Kernel code
  2000-3777: Shell code
  4000-7777: Shell data/stack

Current Process: 42 (shell)

userdata (shell):
  uac: 000000
  umq: 000000
  urq: 000000
  upid: 42
  uppid: 1
  uid: 12 (user "ken")
  ufil[3]: 14 (stdin/terminal)
  ufil[4]: 14 (stdout/terminal)
  ucdir: 41 (root directory)
```

### Stage 1: Fork Called

```
T=0ms: Shell executes: sys fork

Process enters .fork system call
  - Save context to userdata
  - Find free process slot: ulist[1] available
  - Allocate PID: nproc 42 → 43
  - Initialize ulist[1]:
    - State = 1
    - PID = 43
    - Track = 06000

Process Table:
  ulist[0]: State=1, PID=1, Track=06000  (init)
  ulist[1]: State=1, PID=43, Track=06000 (child, being created)
  ulist[2]: State=1, PID=42, Track=07000 (shell, parent)
```

### Stage 2: Child Copied

```
T=1-3ms: Copy parent to child
  - Copy userdata → childdata
  - Update childdata:
    - uac = 0
    - upid = 43
    - uppid = 42
  - Increment file reference counts

childdata (temporary buffer):
  uac: 0 (child return value)
  umq: 000000
  urq: 020 (same return point)
  upid: 43 (child PID)
  uppid: 42 (parent PID)
  uid: 12 (inherited)
  ufil[3]: 14 (shared stdin)
  ufil[4]: 14 (shared stdout)
  ucdir: 41 (inherited cwd)

File Table:
  Entry 14: refcount 1 → 2 (both processes share it)
```

### Stage 3: Child Swapped Out

```
T=50ms: Swap child to disk
  - Write memory to track 06000
  - Write childdata to track 06000
  - Update state to 3

Process Table:
  ulist[0]: State=1, PID=1, Track=06000  (init)
  ulist[1]: State=3, PID=43, Track=06000 (child, on disk, ready)
  ulist[2]: State=1, PID=42, Track=07000 (shell, in memory)

Disk Track 06000:
  Sectors 0-7: Shell memory image (8K)
  Sector 8: childdata (64 words)
```

### Stage 4: Parent Returns

```
T=52ms: Fork returns to parent
  - uac = 43 (child PID)
  - sysexit restores context
  - Parent continues execution

Memory (shell process):
  PC = 003457 (after 'sys fork')
  AC = 43
  Shell code detects AC != 0, runs parent path
```

### Stage 5: Parent Waits

```
T=100ms: Parent calls wait
  - sys wait
  - Enter .wait system call
  - Search for exited child (state 0)
  - None found
  - Block: ulist[2,0] = 2
  - Schedule another process

Process Table:
  ulist[0]: State=1, PID=1, Track=06000  (init)
  ulist[1]: State=3, PID=43, Track=06000 (child, ready)
  ulist[2]: State=2, PID=42, Track=07000 (shell, blocked)
```

### Stage 6: Child Scheduled

```
T=101ms: Scheduler picks child
  - lookfor finds process 43 (state 3)
  - Swap parent to disk (track 07000)
  - Swap child in (from track 06000)

T=150ms: Child begins execution
  - Memory loaded from track 06000
  - userdata restored
  - AC = 0
  - PC = 003457 (same as parent!)
  - Child code detects AC == 0, runs child path

Process Table:
  ulist[0]: State=1, PID=1, Track=06000  (init)
  ulist[1]: State=1, PID=43, Track=06000 (child, running)
  ulist[2]: State=3, PID=42, Track=07000 (shell, on disk)

Memory (child process):
  0000-1777: Kernel code (same)
  2000-3777: Shell code (same as parent)
  4000-7777: Shell data (copy from parent)

userdata (child):
  uac: 0
  upid: 43
  uppid: 42
  ufil[3]: 14 (shares file with parent)
```

### Stage 7: Child Executes

```
T=151ms: Child runs
  - Executes its code
  - Maybe opens more files
  - Does computation
  - Time quantum expires

T=650ms: Child quantum expires
  - Swap out child (track 06000)
  - Swap in another process (maybe parent)

Process switches back and forth...
```

### Stage 8: Child Exits

```
T=5000ms: Child calls exit
  - sys exit
  - Enter .exit system call

T=5001ms: Close files
  - ufil[3] = 14, refcount 2 → 1 (parent still has it)
  - Don't actually close file

T=5002ms: Send exit message
  - Message to PID 42 (parent)
  - Data = 43 (child PID)
  - Enqueue in message queue

Message Queue:
  mesqueue[0,0]: 42 (recipient = parent)
  mesqueue[0,1]: 43 (data = child PID)

T=5003ms: Wake parent
  - Find process 42 in table
  - State 2 → 1 (unblock)

T=5004ms: Free process slot
  - ulist[1,0] = 0
  - ulist[1,1] = 0
  - ulist[1,2] = 0

Process Table:
  ulist[0]: State=1, PID=1, Track=06000  (init)
  ulist[1]: State=0, PID=0, Track=0      (freed!)
  ulist[2]: State=1, PID=42, Track=07000 (shell, ready)

T=5005ms: Schedule another process
  - lookfor finds process 42
  - Never return to child (gone!)
```

### Stage 9: Parent Wakes

```
T=5050ms: Parent swapped in
  - Was blocked in wait()
  - Message available
  - Receive message: AC = 43

T=5051ms: Wait returns
  - Parent's AC = 43 (child PID)
  - Parent knows child exited

Parent code:
  sys wait
  " Returns here with AC = 43
  " Child has exited
```

### Memory Diagrams at Each Stage

**Stage 1 (Before fork):**
```
┌────────────────────────────────────┐
│         Memory (8K)                │
├────────────────────────────────────┤
│ 0000-1777:  Kernel                 │
│ 2000-3777:  Shell Code             │
│ 4000-7777:  Shell Data             │
└────────────────────────────────────┘

Disk Track 06000: Empty
Disk Track 07000: Empty
```

**Stage 3 (Child swapped out):**
```
┌────────────────────────────────────┐
│         Memory (8K)                │
├────────────────────────────────────┤
│ 0000-1777:  Kernel                 │
│ 2000-3777:  Shell Code (parent)    │
│ 4000-7777:  Shell Data (parent)    │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│    Disk Track 06000 (child)        │
├────────────────────────────────────┤
│ Sector 0-7:  Memory image 0-7777   │
│ Sector 8:    userdata (64 words)   │
│              - uac = 0              │
│              - upid = 43            │
│              - uppid = 42           │
└────────────────────────────────────┘
```

**Stage 6 (Child running):**
```
┌────────────────────────────────────┐
│         Memory (8K)                │
├────────────────────────────────────┤
│ 0000-1777:  Kernel                 │
│ 2000-3777:  Shell Code (child)     │
│ 4000-7777:  Shell Data (child)     │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│    Disk Track 06000 (empty)        │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│    Disk Track 07000 (parent)       │
├────────────────────────────────────┤
│ Sector 0-7:  Memory image 0-7777   │
│ Sector 8:    userdata              │
│              - uac = 43             │
│              - upid = 42            │
│              - uppid = 1            │
└────────────────────────────────────┘
```

**Stage 8 (Child exited):**
```
┌────────────────────────────────────┐
│         Memory (8K)                │
├────────────────────────────────────┤
│ 0000-1777:  Kernel                 │
│ 2000-3777:  (transitioning)        │
│ 4000-7777:  (transitioning)        │
└────────────────────────────────────┘

Process 43: GONE (state 0)

┌────────────────────────────────────┐
│    Disk Track 07000 (parent)       │
│    Ready to swap back in           │
└────────────────────────────────────┘
```

### Process Table State Transitions

```
Timeline of Process Table Changes:

T=0 (before fork):
  [0]: State=1 PID=1   (init)
  [1]: State=0 PID=0   (free)
  [2]: State=1 PID=42  (shell)

T=1 (fork allocates slot):
  [0]: State=1 PID=1
  [1]: State=1 PID=43  (child allocated)
  [2]: State=1 PID=42

T=50 (child swapped out):
  [0]: State=1 PID=1
  [1]: State=3 PID=43  (on disk)
  [2]: State=1 PID=42

T=100 (parent blocks in wait):
  [0]: State=1 PID=1
  [1]: State=3 PID=43
  [2]: State=2 PID=42  (blocked)

T=150 (child swapped in):
  [0]: State=1 PID=1
  [1]: State=1 PID=43  (running)
  [2]: State=3 PID=42  (swapped out)

T=5003 (child exits, parent wakes):
  [0]: State=1 PID=1
  [1]: State=0 PID=0   (freed)
  [2]: State=1 PID=42  (ready)

T=5050 (parent resumes):
  [0]: State=1 PID=1
  [1]: State=0 PID=0
  [2]: State=1 PID=42  (running)
```

## 8.12 Historical Context

### Multiprogramming in 1969

In 1969, the computing landscape was dominated by batch processing and early time-sharing experiments:

**IBM System/360 (batch processing):**
- Jobs submitted on punched cards
- Queued and run sequentially
- No interaction during execution
- Job Control Language (JCL) for setup
- Memory partitions (fixed or variable)
- Typical job turnaround: hours to days

**CTSS (Compatible Time-Sharing System, MIT):**
- First successful time-sharing system (1961)
- Multiple users on IBM 7094
- Processes called "jobs"
- Two-level scheduler (core and drum)
- Complex resource accounting
- Required expensive hardware modifications

**Multics (MIT/Bell Labs/GE):**
- Ambitious multi-user system
- Virtual memory with paging
- Segmentation and protection rings
- Very complex (millions of lines of code)
- Required special GE-645 hardware
- Still experimental in 1969

### PDP-7 Unix Process Management Compared

**Simplicity vs. Multics:**

| Feature | Multics | PDP-7 Unix |
|---------|---------|------------|
| Process structure | Complex descriptor | 4 words |
| User state | 100+ words | 64 words |
| Scheduling | Multi-level queues | Round-robin |
| Priorities | Yes (dynamic) | No |
| Memory management | Paging + segmentation | Swapping |
| Protection | Rings 0-7 | None (single user) |
| Lines of code | ~1000s | ~200 |

**Speed vs. CTSS:**

| Operation | CTSS | PDP-7 Unix |
|-----------|------|------------|
| Fork | ~5 seconds | ~100ms |
| Context switch | ~500ms | ~100ms |
| System call | ~10ms | ~1ms |

**Philosophy:**

- **Batch systems**: Jobs are separate, sequential
- **Time-sharing systems**: Jobs share CPU with complex scheduling
- **Unix**: Processes are cheap, create freely

### How Unix Differed

**Key innovations in PDP-7 Unix:**

1. **Lightweight processes**
   - Minimal per-process overhead (4 words)
   - Fast creation (100ms fork vs. 5s in CTSS)
   - Made processes disposable

2. **Uniform abstraction**
   - Init, shell, and user programs all use same process model
   - No distinction between system and user processes
   - All processes created via fork

3. **Simple round-robin**
   - No priority calculations
   - No complex queues
   - Predictable, fair

4. **Swapping, not paging**
   - Entire process in/out
   - No page tables or TLB
   - Simple to implement

5. **Parent/child relationships**
   - Process tree structure
   - Exit messages to parent
   - Foundation for job control (later)

**What Unix sacrificed:**

- No memory protection (single user anyway)
- No priorities (not needed for 1-2 users)
- No sophisticated scheduling (round-robin enough)
- Limited number of processes (10 max)

**What Unix gained:**

- Simplicity (200 lines vs. 1000s)
- Speed (100ms operations vs. seconds)
- Understandability (easy to read/modify)
- Portability (no special hardware needed)

### Influence on Modern Operating Systems

The PDP-7 Unix process model influenced **every subsequent Unix variant**:

**PDP-11 Unix (1971-1973):**
- Kept basic process structure
- Added process groups
- Introduced standard file descriptors (0, 1, 2)
- Added pipes (inter-process data flow)

**Unix v6 (1975):**
- Refined fork/exec separation
- Added nice (priority control)
- Improved scheduler
- Process states expanded

**BSD Unix (1977-1995):**
- Added job control (foreground/background)
- Virtual memory (demand paging)
- Sophisticated scheduler (4.4BSD)
- Process groups and sessions

**System V (1983-1997):**
- Shared memory IPC
- Semaphores and message queues (more sophisticated than PDP-7)
- Real-time scheduling classes
- Lightweight processes (threads precursor)

**Linux (1991-present):**
- Retains fork/exec model
- Completely Fair Scheduler (CFS)
- Namespaces and cgroups (containers)
- But still: fork creates process, exit terminates it

**Modern influence:**
- **fork/exec**: Still the Unix process creation model
- **PID**: Still identifies processes
- **Parent/child**: Still tracked (getppid())
- **exit messages**: Evolved into wait() family
- **Round-robin**: Foundation for fair schedulers

**What changed:**
- **Virtual memory**: Replaces swapping (copy-on-write fork)
- **Threads**: Multiple execution contexts per process
- **Priorities**: Nice values, real-time classes
- **Namespaces**: Process isolation for containers
- **Cgroups**: Resource limits and accounting

**What stayed the same:**
- Fork creates process
- Exit terminates process
- PIDs identify processes
- Parent/child relationships matter
- System calls transition to kernel mode

### The Genius of Simplicity

In 1969, Dennis Ritchie and Ken Thompson made processes **so cheap** that programs could create them freely. This wasn't possible on contemporary systems where process creation took seconds and consumed significant resources.

This single design decision enabled:
- **Pipes** (fork, connect stdout to stdin, exec)
- **Job control** (background processes)
- **Shell programming** (pipelines of simple tools)
- **The Unix philosophy** (small programs, combined freely)

From a simple process table with 4 words per entry and a swap area on two disk tracks came **the foundation of modern computing**. Every web server, database, and application running on Unix-like systems today inherits this design.

That's the power of simplicity.

---

## Summary

This chapter explored the process management system in PDP-7 Unix:

1. **Process Abstraction**: The revolutionary concept of lightweight processes in 1969
2. **Process Table**: Just 4 words per process, supporting up to 10 processes
3. **User Data**: 64 words of saved state (registers, files, directory)
4. **Process States**: 4 states encoded in 2 bits (unused, ready, blocked, swapped)
5. **fork()**: Complete implementation of process creation with memory copying
6. **exit()**: Process termination with cleanup and parent notification
7. **Swapping**: Memory multiplexing via disk tracks (100ms per swap)
8. **Scheduling**: Simple round-robin with 30-tick quantum
9. **IPC**: Message-passing for parent/child communication
10. **Context Switching**: Register save/restore mechanism
11. **Complete Lifecycle**: Full trace from fork to exit with memory diagrams
12. **Historical Context**: How PDP-7 Unix differed from and influenced other systems

The genius of PDP-7 Unix process management was its **extreme simplicity**. With just 200 lines of code, it provided multiprogramming on a tiny machine—and established patterns still used in operating systems today, 55 years later.

---

**Next Chapter**: [Chapter 9 - Device Drivers and I/O](09-device-drivers.md)

**Previous Chapter**: [Chapter 7 - File System Implementation](07-filesystem.md)
