# Chapter 10 - Development Tools: Building a Self-Hosting System

## 10.1 The Self-Hosting Achievement

### What Self-Hosting Means

Self-hosting is the ability of a software development system to build and maintain itself. For PDP-7 Unix in 1969, this meant:

- **Writing the assembler in assembly language** - The assembler could assemble itself
- **Using the editor to edit its own source code** - The editor was written using itself
- **Debugging tools with their own tools** - The debugger could debug itself
- **Complete development cycle on one machine** - No external tools or systems required

This created a "virtuous cycle" where improvements to the tools made it easier to improve the tools further.

### Why It Was Revolutionary in 1969

In 1969, self-hosting was extremely rare and represented a profound achievement:

**Industry Standard Practice:**
- Most development required **cross-compilation** on larger machines
- IBM mainframes used JCL (Job Control Language) with batch processing
- Code was written on coding sheets, keypunched onto cards, then submitted
- Turnaround time could be **hours or days** for a single compile-debug cycle
- Interactive development was virtually unknown outside research labs

**The Typical 1969 Workflow:**
1. Write code on paper coding forms
2. Send forms to keypunch operators
3. Keypunch operators create punched cards (often introducing errors)
4. Submit card deck to computer operator
5. Wait hours or days for batch job to run
6. Receive printout showing compilation errors
7. Repeat from step 1

**What Unix Offered:**
1. Edit code interactively with `ed`
2. Assemble immediately with `as`
3. Test and debug with `db`
4. Entire cycle takes **minutes**, not days
5. All done by the programmer, not operators

### Industry Context: Other Systems in 1969

**MULTICS (MIT/Bell Labs/GE):**
- Running on GE-645 mainframe ($7 million, room-sized)
- Required team of operators
- Had interactive editing but on expensive hardware
- Inspired Unix but was too complex

**IBM OS/360 (1964):**
- Batch processing only
- Required JCL (Job Control Language)
- Punched card input
- No interactive development

**DEC PDP-10 Time-Sharing Systems:**
- TOPS-10 emerging around 1969
- Much larger machine than PDP-7 ($120,000 vs $72,000)
- Time-sharing among many users
- Had text editors but system was complex

**Xerox PARC Alto (not until 1973):**
- First true personal workstation
- Had editors, compilers, debuggers
- Cost approximately $40,000 per unit
- Unix predated this by 4 years

**What Made Unix Different:**
- **Small machine** - PDP-7 was considered obsolete even in 1969
- **Single user** - Full machine dedicated to one programmer
- **Complete toolkit** - All tools present and working together
- **Written in assembly** - Yet still maintainable and elegant
- **Self-hosting** - The system built itself

### The Virtuous Cycle: Better Tools Enable Better Tools

The self-hosting nature of Unix created a powerful feedback loop:

```
Better Assembler
    ↓
Easier to write complex code
    ↓
Better Editor/Debugger
    ↓
Easier to improve Assembler
    ↓
(cycle repeats)
```

**Specific Examples:**

1. **Symbol Table Improvements** - As the assembler's symbol table got better, it could handle more complex programs, allowing the editor to grow more features

2. **Editor Macros** - Better editing commands made it faster to modify assembly code, which meant faster iteration on all tools

3. **Debugger Symbolic Output** - Once the debugger could display symbols, debugging the assembler and editor became much easier

4. **Expression Evaluation** - Shared code between assembler and debugger meant improvements helped both

**The Numbers Tell the Story:**

```
Tool          Lines of Code    Approximate Size
----          -------------    ----------------
Assembler     ~980 lines       4K words memory
Editor        ~760 lines       3K words memory
Debugger      ~1,220 lines     5K words memory
Loader        ~250 lines       1K words memory
--------------------------------------------
Total         ~3,210 lines     ~13K words

Entire development environment: < 26KB on modern scale!
```

Compare this to modern development environments:
- Visual Studio Code: ~200MB
- IntelliJ IDEA: ~800MB
- Eclipse: ~500MB

Unix's development tools were **10,000 times smaller** yet provided the essential functionality for self-hosting development.

---

## 10.2 The Assembler (as.s)

The assembler (`as`) is the cornerstone of the development environment. It translates assembly language source code into executable machine code through a sophisticated two-pass algorithm.

### Complete Two-Pass Assembly Algorithm

**Why Two Passes?**

The assembler must resolve **forward references** - symbols used before they're defined:

```assembly
   jmp subroutine    " Forward reference - 'subroutine' not yet defined
   lac value
   dac result

subroutine: 0        " Definition comes later
   lac input
   jmp i subroutine
```

**Pass 1: Symbol Collection**
- Read through entire source file
- Build symbol table with addresses
- Don't generate code yet
- Record forward references

**Pass 2: Code Generation**
- Read source file again
- All symbols now known
- Generate actual machine code
- Write to output file

### Main Assembly Loop

The core of the assembler is the main loop that processes each line:

```assembly
assm1:
   lac eofflg
   sza                  " Skip if zero (not at EOF)
   jmp assm2            " At EOF, go to next phase
   lac passno
   sza                  " Skip if pass 0
   jmp finis            " Pass 1 complete, finish
   jms init2            " Initialize pass 2

assm2:
   jms gchar            " Get next character
   sad d4               " Is it tab (delimiter)?
   jmp assm1            " Yes, start new line
   sad d5               " Is it newline?
   jmp assm1            " Yes, start new line
   lac char
   dac savchr           " Save character
   jms gpair            " Get operator-operand pair
   lac rator            " Load operator
   jms betwen; d1; d6   " Is it in range 1-6 (expression)?
   jmp assm3            " No, check for label
   jms expr             " Yes, evaluate expression
   lac passno
   sza
   jms process          " Pass 2: generate code
   isz dot+1            " Increment location counter
   nop
   lac dot+1
   and o17777           " Mask to 14 bits
   sad dot+1            " Check overflow
   jmp assm1            " OK, continue
   jms error; >>        " Error: address overflow
   dzm dot+1            " Reset to 0
   jmp assm1
```

**Key Variables:**
- `passno` - Current pass (0 or 1)
- `dot` - Current location counter (like `.` in modern assemblers)
- `eofflg` - End of file flag
- `rator` - Current operator being processed
- `char` - Current character being read

### Symbol Table Implementation

The symbol table is the heart of the assembler. It stores symbol names and their values:

```assembly
lookup: 0
   dzm tlookup           " Clear temporary lookup flag
1:
   -1
   tad namlstp           " Get pointer to name list
   dac 8                 " Store in auto-index register 8
   lac namsiz            " Get current size of name table
   dac namc              " Use as counter

lu1:
   lac i 8               " Load word from name table
   sad name              " Does it match first word of symbol?
   jmp 1f                " Yes, check rest of symbol
   lac d5                " No, skip to next entry
lu2:
   tad 8
   dac 8                 " Advance pointer by 5 words
   isz namc              " Increment counter
   jmp lu1               " Continue searching
```

**Symbol Table Entry Format** (5 words per symbol):

```
Word 0: First 2 characters (9 bits each)
Word 1: Second 2 characters
Word 2: Third 2 characters
Word 3: Fourth 2 characters
Word 4: Symbol value/address
```

**Example:** The symbol "buffer" would be stored as:

```
Word 0: 'b' 'u'  (0142 0165)
Word 1: 'f' 'f'  (0146 0146)
Word 2: 'e' 'r'  (0145 0162)
Word 3: ' ' ' '  (0040 0040)  [padded with spaces]
Word 4: 001234   [address where buffer is defined]
```

### Character Packing: getsc and putsc

Efficient character storage was critical with limited memory. The assembler packs two 9-bit characters per 18-bit word:

```assembly
getsc: 0
   lac i getsc           " Get pointer argument
   dac sctalp            " Save it
   isz getsc             " Advance return address
   lac i sctalp          " Load pointer value
   dac sctal             " Save actual pointer
   add o400000           " Set bit 0 (high bit)
   dac i sctalp          " Store back (marks as used)
   ral                   " Rotate accumulator left
   lac i sctal           " Load word containing characters
   szl                   " Skip if link is zero
   lrss 9                " Right shift 9 bits (get second char)
   and o177              " Mask to 7 bits
   jmp i getsc           " Return with character

putsc: 0
   and o177              " Mask character to 7 bits
   lmq                   " Load into MQ register
   lac i putsc           " Get pointer argument
   dac sctalp
   isz putsc
   lac i sctalp          " Load pointer value
   dac sctal
   add o400000           " Set high bit
   dac i sctalp
   sma cla               " Skip if minus (second char)
   jmp 1f                " First character
   llss 27               " Left shift 27 bits (move to high position)
   dac i sctal           " Store
   lrss 9                " Shift back
   jmp i putsc

1:                       " Second character
   lac i sctal           " Load existing word
   omq                   " OR with new character
   dac i sctal           " Store back
   lacq
   jmp i putsc
```

**How It Works:**

Characters are stored two per word using bit 0 of the pointer as a toggle:
- Bit 0 = 0: Next character goes in high position (bits 1-9)
- Bit 0 = 1: Next character goes in low position (bits 10-18)

Example:
```
Storing "ab":
Word initially:  000000 000000 000000
After 'a' (141): 000 141000 000000  [character in high position]
After 'b' (142): 000 141000 142000  [character in low position]
```

### Expression Evaluation

The assembler supports arithmetic expressions with operators:

```assembly
expr: 0
   jms grand             " Get rand (operand)
   -1
   dac srand             " Save on "stack"
exp5:
   lac rand
   dac r                 " Save result
   lac rand+1
   dac r+1
exp1:
   lac rator             " Load operator
   jms betwen; d1; d5    " Is it arithmetic operator?
   jmp exp3              " No, done with expression
   dac orator            " Save operator
   jms gpair             " Get next operator-operand pair
   jms grand             " Get next operand
   lac orator
   sad d4                " Is it comma (grouping)?
   jmp exp2              " Yes, handle specially
   jms oper; rand        " No, apply operator
   jmp exp1              " Continue

exp3:
   sad d5                " Is it newline (end)?
   jmp exp4              " Yes, finish
   jms error; x>         " No, syntax error
   jmp skip

exp4:
   jms pickup            " Get result from stack
   jmp i expr
```

**Supported Operators:**

- `+` (plus) - Addition
- `-` (minus) - Subtraction
- `|` (vertical bar) - Bitwise OR
- `,` (comma) - Grouping/pairing

**Example Expression:**

```assembly
   lac base+offset|0400000
```

This evaluates as:
1. Load symbol `base`
2. Add symbol `offset`
3. OR with octal constant 0400000

The expression evaluator handles operator precedence and can manage complex expressions needed for PDP-7 addressing modes.

### Forward and Backward References

One of the assembler's most sophisticated features is handling labels used before they're defined:

```assembly
assm3:
   lac rand
   sad d2                " Is operand type = 2 (label)?
   jmp assm4
   sza                   " Is it zero?
   jmp assm6             " No, error
   lac rator
   sza                   " Empty operator?
   jmp assm6
   lac rand+1            " Get operand value
   jms betwen; dm1; d10  " Is it 1-9 (forward/backward ref)?
   jmp assm6             " No
   dac name              " Yes, store as name
   tad fbxp              " Add forward/backward table pointer
   dac lvrand            " Use as index
   lac i lvrand          " Load current value
   dac name+1            " Store
   isz i lvrand          " Increment usage count
   lac o146              " 'f' character
   dac name+2            " Mark as forward ref
   dzm name+3
   jms tlookup           " Temporary lookup
   -1
   dac fbflg             " Set forward/backward flag
```

**Forward/Backward Reference System:**

Labels can be defined as numeric (1-9) with 'f' or 'b' suffix:

```assembly
1:                    " Define label "1"
   lac value
   jmp 2f             " Jump forward to label "2"
   dac result
2:                    " Define label "2"
   sys exit

elsewhere:
   jmp 1b             " Jump backward to label "1"
```

The assembler maintains a table `fbx` with 10 entries (0-9), each tracking:
- Current address of that numeric label
- How many times it's been redefined

### Object File Format

The assembler writes output to a temporary binary file in two stages:

**Pass 1:** No output (just building symbol table)

**Pass 2:** Generate code into memory buffer:

```assembly
process: 0
   lac dot+1             " Load location counter
   dac lvrand            " Save as address
   lac dot               " Load section (text vs data)
   sad d3                " Is it section 3 (unused)?
   jmp proc4             " Yes, error
   sza                   " Is it section 0 (text)?
   jmp proc1             " No, section 1 or 2
   -1
   tad cmflx+1           " Yes, adjust for common block
   cma
   tad lvrand
   dac lvrand

proc1:
   lac lvrand
   spa                   " Is address positive?
   jmp proc4             " No, error
   and o17700            " Get page number (high 7 bits)
   sad bufadd            " Same page as buffer?
   jmp proc2             " Yes, just store
   jms bufwr             " No, write buffer and read new page
   jms copyz; buf; 64    " Clear buffer
   lac lvrand
   and o17700            " Get page number
   dac bufadd            " Remember which page
   dac 1f
   lac bfi               " Buffered file input
   sys seek; 1: 0; 0     " Seek to page
   spa
   jmp proc2
   lac bfi
   sys read; buf; 64     " Read existing page

proc2:
   lac lvrand
   and o77               " Get offset within page (low 6 bits)
   jms betwen; dm1; maxsto
   dac maxsto            " Track maximum offset
   tad bufp              " Add buffer pointer
   dac lvrand            " Now points to word in buffer
   lac r
   sna                   " Is value non-zero?
   jmp proc3             " Zero, special case
   sad d3                " Is it section 3?
   jmp proc5             " Yes, undefined symbol error
   lac cmflx+1
   tad r+1               " Add common block offset
   dac r+1

proc3:
   lac r+1               " Load value
   dac i lvrand          " Store at location
   jmp i process
```

**Buffer Management:**
- 64-word pages cached in memory
- Modified pages written back to temp file
- Seeks to different pages as needed
- Final file written at end of pass 2

### Historical Context: Why Write an Assembler in Assembly?

**The Bootstrapping Problem:**

In 1969, to create a self-hosting system, you had to start somewhere. The choices were:

1. **Write assembler in machine code** (octal/binary) - Extremely tedious
2. **Use existing assembler** - PDP-7 had DEC's assembler, but:
   - DEC assembler was batch-oriented (paper tape input/output)
   - Designed for different workflow
   - Not integrated with Unix file system
   - Not customizable

3. **Write in higher-level language** - But no compiler existed yet!

**The Solution:**

1. Use DEC's assembler to assemble first version of Unix assembler
2. Unix assembler can then assemble itself
3. Now self-hosting - no longer need DEC tools

**This was revolutionary because:**
- Most systems kept requiring manufacturer's tools forever
- Unix tools were specifically designed to work together
- Self-hosting enabled rapid iteration and improvement

### Comparison to Other 1969 Assemblers

**IBM System/360 Assembler:**
- Batch processing only
- JCL (Job Control Language) required
- Input: punched cards
- Output: object deck on cards or tape
- Typical assembly: 30 minutes to several hours
- Required operator intervention

**DEC PDP-7 PAL-7 Assembler:**
- Input: paper tape
- Output: paper tape
- Single pass (no forward references except numeric labels)
- Limited expressions
- No nested includes
- Assembly time: minutes for small programs

**Unix 'as' Assembler:**
- Input: disk files
- Output: disk files
- Two pass (full forward reference support)
- Rich expression syntax
- Symbol table written for debugger
- Assembly time: seconds
- Integrated with shell and file system

**Code Size Comparison:**

```
System/360 Assembler: ~50,000 lines (estimatedµ)
DEC PAL-7:           ~5,000 lines (estimated)
Unix 'as':           ~980 lines

Unix assembler was ~5x smaller yet more capable in some ways!
```

### Complete Example: Assembling a Simple Program

**Input Source (example.s):**

```assembly
" Simple program to add two numbers

start:
   lac num1        " Load first number
   tad num2        " Add second number
   dac result      " Store result
   sys exit        " Terminate

num1: 42           " First number (octal)
num2: 37           " Second number (octal)
result: 0          " Result storage
```

**Pass 1 Processing:**

```
Line 1: Comment - skip
Line 2: Empty - skip
Line 3: Label "start" defined, dot=0
        Instruction: lac num1
        Forward reference to "num1" recorded
Line 4: Instruction: tad num2
        Forward reference to "num2" recorded
Line 5: Instruction: dac result
        Forward reference to "result" recorded
Line 6: Instruction: sys exit
        "sys" is system call, "exit" is system call number
Line 7: Empty - skip
Line 8: Label "num1" defined, dot=4, value=42
Line 9: Label "num2" defined, dot=5, value=37
Line 10: Label "result" defined, dot=6, value=0

Symbol table after pass 1:
start  = 000000
num1   = 000004
num2   = 000005
result = 000006
```

**Pass 2 Processing:**

```
Address  Machine Code   Source
-------  ------------   ------
000000   066404         lac num1      (opcode 066, address 004)
000001   040405         tad num2      (opcode 040, address 005)
000002   026406         dac result    (opcode 026, address 006)
000003   020006         sys exit      (opcode 020, syscall 6)
000004   000042         num1: 42
000005   000037         num2: 37
000006   000000         result: 0
```

The assembler has:
1. Resolved all forward references
2. Generated correct machine code
3. Created symbol table for debugger
4. Written output file "a.out"

---

## 10.3 The Editor (ed1.s + ed2.s)

The editor `ed` was the primary text editing tool in Unix. It's a **line-oriented editor**, meaning it operates on whole lines rather than individual characters on screen.

### Why Line-Based Editing in 1969?

**Technology Constraints:**

The PDP-7 Unix system used a **Teletype Model 33 ASR**:
- **Printing terminal** (like a typewriter)
- **No screen** - output is printed on paper
- **10 characters per second** (110 baud)
- **No cursor positioning** - you can't move back up the page!

**Implications:**
- Screen-based editing was impossible - the paper doesn't scroll backward
- Each command must complete before next prompt
- Minimize output - paper and ribbon cost money
- Commands must be terse - typing is slow

**Why Not Visual Editing?**

Visual editors like `vi` (1976) and `emacs` (1976) required:
- **Video terminals** with cursor positioning (VT52, VT100)
- **Higher bandwidth** (at least 1200 baud, preferably 9600)
- **Cursor control escape sequences**
- **More memory** for screen buffer

None of these existed in 1969 for the PDP-7.

### Command Set and Implementation

The editor supports these commands:

```
a  - Append text after current line
c  - Change (replace) lines
d  - Delete lines
p  - Print lines
q  - Quit
r  - Read file into buffer
w  - Write buffer to file
s  - Substitute (search and replace)
/  - Search forward
?  - Search backward
=  - Print current line number
```

**Main Command Loop:**

```assembly
advanc:
   jms rline              " Read a command line
   lac linep
   dac tal                " Set up text pointer
   dzm adrflg             " Clear address flag
   jms addres             " Parse address (if any)
   jmp comand             " No address, go to command
   -1
   dac adrflg             " Mark address present
   lac addr
   dac addr1              " Store first address
   dac addr2              " Store second address (same initially)
1:
   lac char               " Check next character
   sad o54                " Is it comma?
   jmp 2f                 " Yes, address range
   sad o73                " Is it semicolon?
   skp
   jmp chkwrp             " No, done with address
   lac addr
   dac dot                " Semicolon updates current line
2:
   jms addres             " Parse second address
   jmp error              " Invalid address
   lac addr2
   dac addr1              " Shift addresses
   lac addr
   dac addr2              " Store new second address
   jmp 1b                 " Loop for more addresses

chkwrp:
   -1
   tad addr1
   jms betwen; d1; addr2  " Check addr1 <= addr2
   jmp error              " Invalid range

comand:
   lac char               " Get command character
   sad o141               " 'a' - append?
   jmp ca
   sad o143               " 'c' - change?
   jmp cc
   sad o144               " 'd' - delete?
   jmp cd
   sad o160               " 'p' - print?
   jmp cp
   sad o161               " 'q' - quit?
   jmp cq
   sad o162               " 'r' - read?
   jmp cr
   sad o163               " 's' - substitute?
   jmp cs
   sad o167               " 'w' - write?
   jmp cw
   sad o12                " newline?
   jmp cnl                " Print next line
   sad o75                " '=' - line number?
   jmp ceq
   jmp error              " Unknown command
```

### The Append Command: Adding Text

The `a` command adds text after the current line:

```assembly
ca:
   jms newline            " Verify command line ends with newline
   jms setfl              " Set addr1=1, addr2=EOF if no address
   lac addr2
   dac dot                " Set current line
ca1:
   jms rline              " Read a line of input
   lac line
   sad o56012             " Is it ".\n" (period-newline)?
   jmp advanc             " Yes, done appending
   jms append             " No, append this line
   jmp ca1                " Read next line
```

**How Append Works:**

1. User types `a` command
2. Editor enters "append mode"
3. Each line typed is added to buffer
4. User types `.` (period alone) to exit append mode
5. Returns to command mode

**Example Session:**

```
*a                        <-- User types 'a' command
This is line 1            <-- User types content
This is line 2
This is line 3
.                         <-- User types '.' to end
*                         <-- Back to command mode
```

**The Append Implementation:**

```assembly
append: 0
   -1
   tad eofp               " Get EOF pointer
   dac 8                  " Use as destination pointer
   cma
   tad dot                " Calculate number of lines to move
   dac apt1               " Store as counter
1:
   lac i 8                " Load line pointer
   dac i 8                " Store one position later (shift down)
   -3
   tad 8                  " Move back one entry
   dac 8
   isz apt1               " Count down
   jmp 1b                 " Continue shifting
   isz eofp               " Increment EOF (one more line)
   dzm i eofp             " Mark new EOF
   isz dot                " Increment current line
   jms addline            " Add the new line content
   jmp i append
```

This shifts all lines after `dot` down by one position to make room for the new line.

### Temporary File Usage: The Disk Buffer

The editor doesn't keep all file content in memory. Instead, it uses a clever disk buffering scheme:

```assembly
" Editor data structure:
"
" lnodes (in memory):    Array of pointers to lines
"                        Each entry points to disk location
"
" dskbuf (in memory):    1024-word buffer for disk blocks
"
" /tmp/etmp (on disk):   Actual line content

" Line node structure (per line):
lnodes: .=.+1000         " 1000 line pointers (max)

" Each line pointer contains:
"   Disk block address + offset where line text starts
```

**Reading a Line:**

```assembly
gline: 0
   dac glint1             " Save line number
   jms getdsk             " Ensure disk block is in buffer
   lac glint1
   and o1777              " Get offset within block
   tad dskbfp             " Add buffer pointer
   dac ital               " Input text pointer
   lac linep
   dac otal               " Output text pointer
1:
   lac ital
   sad edskbfp            " End of disk buffer?
   skp
   jmp 2f
   lac diskin             " Yes, get next disk block
   tad d1024
   jms getdsk
   lac dskbfp
   dac ital
2:
   jms getsc; ital        " Get character from disk buffer
   jms putsc; otal        " Put character to output line
   sad o12                " Newline?
   skp
   jmp 1b                 " No, continue
   lac otal
   sma                    " Did we write anything?
   jmp 1f
   cla
   jms putsc; otal        " Ensure word is complete
1:
   lac linpm1
   cma
   tad otal               " Calculate line size
   jmp i gline            " Return line size
```

**Why This Design?**

- **Memory was tiny** - Only ~8K words available for all of ed
- **Files could be large** - Relative to memory
- **Disk access was slow** - Minimize reads/writes

The solution:
- Keep line **pointers** in memory (2 words per line = 2000 words for 1000 lines)
- Keep line **content** on disk in temporary file
- Buffer frequently accessed disk blocks

### Search and Substitution Algorithms

The `s` (substitute) command is implemented in `ed2.s`:

```assembly
cs:
   jms getsc; tal         " Get first character after 's'
   sad o40                " Space?
   jmp cs                 " Skip spaces
   sad o12                " Newline?
   jmp error              " Need delimiter
   dac delim              " Save delimiter character
   jms compile            " Compile search pattern
   lac tbufp
   dac tal1               " Set up for replacement text
1:
   jms getsc; tal         " Get replacement text
   sad delim              " Delimiter again?
   jmp 1f                 " Yes, done with replacement
   sad o12                " Newline?
   jmp error              " Can't have newline in replacement
   jms putsc; tal1        " Store replacement character
   jmp 1b
1:
   lac o12
   jms putsc; tal1        " Terminate replacement with newline
   jms newline            " Verify command ends properly
   jms setdd              " Set default addresses (current line)
   lac addr1
   sad zerop              " Line 0?
   jmp error              " Can't substitute in line 0
1:
   dac addr1              " Process this line
   lac i addr1            " Get line pointer
   jms execute            " Execute pattern match
   jmp 2f                 " No match

   " Match found - construct new line
   lac addr1
   dac dot                " Update current line
   law line-1
   dac 8                  " Source pointer
   law nlist-1
   dac 9                  " Destination pointer
   -64
   dac c1
3:
   lac i 8                " Copy line to working buffer
   dac i 9
   isz c1
   jmp 3b

   " Build new line with replacement
   -1
   tad fchrno             " First character of match
   dac linsiz             " Size so far
   rcr
   szl
   xor o400000
   tad linep
   dac tal1               " Pointer to copy up to match
   lac tbufp
   dac tal                " Pointer to replacement text
3:
   jms getsc; tal         " Get replacement character
   sad o12                " End?
   jmp 3f
   jms putsc; tal1        " Put to new line
   isz linsiz
   jmp 3b
3:
   -1
   tad lchrno             " Last character of match
   rcr
   szl
   xor o400000
   tad nlistp
   dac tal                " Pointer to rest of original line
3:
   jms getsc; tal         " Copy rest of line
   jms putsc; tal1
   isz linsiz
   sad o12                " Newline?
   skp
   jmp 3b
   jms addline            " Add modified line
2:
   lac addr1
   sad addr2              " Done with all lines?
   jmp advanc             " Yes
   tad d1
   jmp 1b                 " No, process next line
```

**How Substitution Works:**

1. Parse command: `s/pattern/replacement/`
2. Compile pattern into internal form
3. For each line in range:
   - Execute pattern match
   - If match found:
     - Copy line up to match
     - Insert replacement text
     - Copy rest of line after match
     - Add as new line
4. Return to command mode

**Example:**

```
*1,$s/Unix/UNIX/         " Substitute Unix with UNIX on all lines
*1,$s/the/THE/          " Substitute first 'the' with 'THE' on each line
```

### Pattern Compilation

The editor compiles search patterns into an internal bytecode:

```assembly
compile: 0
   law compbuf-1          " Compiled pattern buffer
   dac 8
   dzm prev               " No previous element
   dzm compflg            " Not compiling yet

cadvanc:
   jms getsc; tal         " Get next pattern character
   sad delim              " Delimiter?
   jmp cdone              " Yes, done
   dac compflg            " Mark we're compiling
   dzm lastre             " Clear last RE flag
   sad o12                " Newline?
   jmp error              " Can't have newline in pattern
   sad o136               " '^' (beginning of line)?
   jmp beglin
   sad o44                " '$' (end of line)?
   jmp endlin
   dac 1f                 " Regular character
   jmp comp               " Compile character match
   1; jms matchar; 1: 0; 0

beglin:
   jms comp               " Compile beginning-of-line match
   1; jms matbol; 0
   dzm prev
   jmp cadvanc

endlin:
   jms comp               " Compile end-of-line match
   1; jms mateol; 0
   dzm prev
   jmp cadvanc

comp: 0                   " Append instruction to compiled pattern
   -1
   tad comp
   dac 9
   lac 8
   dac prev               " Save as previous element
1:
   lac i 9                " Copy instruction words
   sna
   jmp i 9                " Zero terminates, return
   dac i 8                " Store in compiled buffer
   jmp 1b
```

**Compiled Pattern Format:**

Each pattern element compiles to instructions like:
```
jms matchar; 'c'; 0     " Match character 'c'
jms matbol; 0           " Match beginning of line
jms mateol; 0           " Match end of line
jms found; 0            " Pattern matched successfully
```

This is essentially a tiny interpreter!

### Historical Context: What Editors Existed in 1969?

**TECO (Text Editor and COrrector)** - 1962
- DEC PDP-1 and later systems
- Command language with edit buffer
- Very powerful but cryptic
- Used character-at-a-time commands
- Richard Stallman later wrote Emacs in TECO

**SOS (Son of Stopgap)** - 1965
- DEC PDP-6 and PDP-10
- Line-oriented editor
- Used line numbers
- Commands like "n:m PRINT" to print lines n through m

**EDIT** - IBM System/360
- Batch editor (edit control cards in card deck)
- Submit deck with source + edit commands
- Get back modified deck
- Turnaround time: hours

**QED** - 1965-1966
- Berkeley Timesharing System
- Strong influence on Unix `ed`
- Regular expressions
- Ken Thompson knew QED well

**What Made Unix `ed` Different:**

1. **Integrated with Unix** - Used file system, not paper tape
2. **Regular expressions** - Powerful pattern matching
3. **Simple command set** - Easy to learn basics
4. **Fast** - Disk buffer made it responsive
5. **Self-editing** - Ed was written and debugged using ed

**Ed's Influence:**

```
ed (1969)
   ↓
ex (1976) - Extended ed with more features
   ↓
vi (1976) - Visual mode of ex
   ↓
vim (1991) - Vi IMproved
   ↓
neovim (2014) - Modern fork of vim

ed also influenced:
- sed (Stream EDitor) - 1973
- awk (pattern scanning) - 1977
- grep (Get Regular ExPression) - 1973
- All regex libraries
```

Modern programmers use ed descendants every day without knowing it!

### The Ed Legacy: Modern Tools Descended from Ed

**sed - Stream Editor**

```bash
sed 's/Unix/UNIX/g' file.txt
```

This is exactly ed's substitute command applied to a stream! The syntax is identical.

**grep - Get Regular ExPression and Print**

```bash
grep 'pattern' file.txt
```

This automates ed's search command: `g/pattern/p`
- `g` = global (all lines)
- `/pattern/` = search pattern
- `p` = print

The name "grep" literally comes from this ed command!

**vi - Visual Editor**

Vi's command mode is ed:
- `:1,10d` - Delete lines 1-10 (ed syntax)
- `:%s/foo/bar/g` - Substitute on all lines (ed syntax)
- `:w` - Write file (ed command)
- `:q` - Quit (ed command)

**Regular Expressions**

Ed's pattern matching became the foundation for:
- Perl regular expressions
- JavaScript RegExp
- Python re module
- Java Pattern class
- Every regex implementation

The syntax `^beginning.*middle.*end$` comes from ed!

---

## 10.4 The Debugger (db.s)

The debugger `db` provides symbolic debugging and core dump analysis - revolutionary capabilities for 1969.

### Symbolic Debugging Concepts

Most debuggers in 1969 worked with octal or hexadecimal addresses and raw machine code. Unix `db` could display:

- **Symbol names** instead of addresses
- **Assembly mnemonics** instead of octal instruction codes
- **Symbol+offset** for partially matched addresses
- **Relative or absolute** addresses

**Example Debug Session:**

```
$ db core a.out           # Debug core dump with symbol table
52                        # Shows '$' register (PC) value
address $                 # Show address symbolically
start
```

Instead of seeing:
```
000042 = 000042          # Octal everywhere
```

You see:
```
start = 000042           # Meaningful symbol name
```

### Core Dump Analysis

When a program crashes, Unix writes a `core` file containing:
- All process memory
- Register values
- Program counter (PC)

The debugger can analyze this:

```assembly
start:
   lac nlbufp
   cma
   tad o17777             " Calculate buffer size
   cll
   idiv; 6                " Divide by 6
   cll
   lacq
   mul; 6                 " Multiply back (round down)
   lacq
   dac namesize           " Save symbol table size

   sys open; nlnamep: nlname; 0
   dac symindex           " Open symbol table file (n.out)
   sma                    " Success?
   jmp 1f                 " Yes, read symbols
2:
   dzm nlcnt              " No symbol table
   lac nlbufp
   dac nlsize
   jmp 3f
1:
   sys read; nlbuff; namesize:0  " Read symbol table
   spa                    " Success?
   jmp 2b                 " No
   dac nlcnt              " Save number read
   tad nlbufp
   dac nlsize             " Calculate end of buffer
3:
   lac symindex
   sys close              " Close symbol table

   sys open
wcorep: corename; 1       " Open core file for writing (if needed)
   dac wcore
   sys open; rcorep: corename; 0  " Open core file for reading
   dac rcore
   spa                    " Success?
   jmp error              " No, error
```

**Symbol Table Format (n.out file):**

```
Each entry is 6 words:
Word 0-3: Symbol name (8 characters, packed)
Word 4:   Relocation flag (0=absolute, 1=relocatable)
Word 5:   Value (address)
```

### Memory Examination Modes

The debugger supports multiple display modes:

```assembly
symbol:
   law prsym               " Symbol mode printer
   dac type
   jmp print

octal:
   law proct               " Octal mode printer
   dac type
   jmp print

ascii:
   law prasc               " ASCII mode printer
   dac type
   jmp print

decimal:
   law prdec               " Decimal mode printer
   dac type
   jmp print
```

**Command Examples:**

```
$ db core a.out
52
buffer/                    # Examine 'buffer' symbolically
buffer: jms getword
buffer+1/                  # Next location
getword+2
buffer,10?                 # Examine 10 locations in octal
000123 000456 000777 ...
buffer,10:                 # Examine in decimal
83 302 511 ...
buffer,10"                 # Examine as ASCII
abc...
```

### Expression Evaluation

The debugger has a sophisticated expression evaluator:

```assembly
getexp:0
   dzm errf               " Clear error flag
   lac o40
   dac rator              " Initial operator = space (none)
   dzm curval             " Clear current value
   dzm curreloc           " Clear relocation
   dzm reloc
   dzm value
   dzm opfound            " Clear operand found flag

xloop:
   jms rch                " Read character
   lmq                    " Save in MQ
   sad o44                " Is it comma (indirect)?
   skp
   jmp 1f
   jms getspec            " Yes, get special register
   jms oprand             " Process as operand
   jmp xloop
1:
   tad om60               " Subtract '0' (check if digit)
   spa                    " Positive (is digit)?
   jmp 1f                 " No
   tad om10               " Subtract 10 (check if < 10)
   sma                    " Negative (is 0-9)?
   jmp 1f                 " No
   lacq                   " Yes, get character back
   jms getnum             " Parse number
   jms oprand             " Process as operand
   jmp xloop
1:
   lacq                   " Get character
   sad o56                " Is it '.' (current address)?
   jmp 1f                 " Yes
   tad om141              " Is it 'a'-'z'?
   spa
   jmp 2f                 " No
   tad om32               " Check range
   sma
   jmp 2f
1:
   lacq
   jms getsym             " Parse symbol
   jms oprand             " Process as operand
   jmp xloop
2:
   lacq                   " Check operators
   sad o74                " Is it '<' (ASCII literal)?
   skp
   jmp 1f
   jms rch                " Get next character
   alss 9                 " Shift to high byte
   dac value              " Save as value
   dzm reloc              " Not relocatable
   jms oprand
   jmp xloop
1:
   sad o40                " Space?
   jmp xloop              " Skip it
   sad o55                " Minus?
   skp
   jmp 1f
2:
   lac o40
   sad rator              " Already have operator?
   skp
   jmp error              " Yes, error
   lacq
   dac rator              " Save as operator
   jmp xloop
1:
   sad o53                " Plus?
   jmp 2b
   lac curreloc           " Check relocation consistency
   sna
   jmp 1f
   sad d1
   skp
   dac errf               " Relocation error
1:
   lac o40
   sad rator              " No operator (end of expression)?
   jmp i getexp           " Yes, done
   dac errf               " Operator expected
   jmp i getexp
```

**Supported Expression Syntax:**

```
Symbols:        buffer, start, loop
Numbers:        42, 177, 1234
Operators:      +, -, |
Special:        ,a (AC), ,q (MQ), ,i (IC), ,0-,7 (auto-index)
ASCII:          <c (character constant)
Current:        . (current address)
Indirect:       @addr or addr@ (follow pointer)
```

**Examples:**

```
start+10                   # Symbol plus offset
buffer|020000              # Symbol OR constant
,a                         # Accumulator register
,5                         # Auto-index register 5
.                          # Current location
```

### Complete Code Walkthrough: Print Symbol

One of the most complex functions is symbolic printing:

```assembly
prsym:0
   dac word                " Save word to print
   dzm relflg              " Clear relative flag
   dzm relocflg            " Clear relocation flag
   dzm nsearch             " No specific search yet
   and o760000             " Check high bits for instruction type
   sad o760000             " Is it 'law' (load address word)?
   jmp plaw
   sad o20000              " Is it system call?
   jmp pcal
   and o740000             " Check for EAE (Extended Arithmetic)
   sad o640000             " EAE Group 1?
   jmp peae
   sad o740000             " Operate instructions?
   jmp popr
   sad o700000             " IOT (Input/Output Transfer)?
   jmp piot
   sna                     " Zero (memory reference)?
   jmp poct                " Print as octal
   jms nlsearch            " Try to find symbol
   jmp poct                " Not found, print octal
   jms wrname              " Found, print symbol name
   lac o40
   jms wchar               " Print space
   lac word
   and o20000              " Check indirect bit
   sna
   jmp 1f
   lac o151040             " Print "i "
   jms wchar
   lac word
   xor o20000              " Clear indirect bit
   dac word
1:
symadr:
   lac d1
   dac relflg              " Mark as relative
   dac relocflg            " Mark as relocatable
   lac word
   and o17777              " Extract address field
   tad mrelocv             " Adjust by relocation value
   sma                     " Check if in relocatable range
   jmp 1f
   tad relocval
   dzm relocflg            " Not relocatable
1:
pradr:
   dac addr                " Save address
   jms nlsearch            " Look up address in symbol table
   jmp octala              " Not found, print octal
pr1:
   dzm relflg
   jms wrname              " Print symbol name
   lac value
   sad addr                " Exact match?
   jmp i prsym             " Yes, done
   cma
   tad d1
   tad addr                " Calculate offset
   sma                     " Is offset positive?
   jmp 1f                  " Yes
   cma                     " No, negate
   tad d1
   dac addr
   lac o55                 " Print '-'
   jms wchar
   jmp 2f
1:
   dac addr                " Save offset
   lac o53                 " Print '+'
   jms wchar
2:
   lac addr                " Print offset value
   jms octw; 1
   jmp i prsym
```

**What This Does:**

Given a machine word like `026377`, it:

1. Checks instruction type (memory reference, operate, IOT, etc.)
2. If memory reference:
   - Extracts opcode (026 = `dac`)
   - Extracts address (377)
   - Looks up address in symbol table
   - Prints: `dac buffer+3` instead of `026377`

3. If operate instruction:
   - Looks up entire instruction
   - Prints mnemonic: `cla` instead of `740000`

**Symbol Table Search:**

```assembly
nlsearch:0
   dac match               " Save value to match
   lac brack               " Bracket for approximate match
   dac best                " Best match so far
   dzm minp                " No match yet
1:
   lac nlbufp              " Start of symbol buffer
   tad dm6                 " Back up 6 words
   dac cnlp                " Current symbol pointer

nloop:
   lac cnlp
   tad d6                  " Advance to next symbol
   dac cnlp
   lmq                     " Save in MQ
   cma
   tad nlsize              " Compare to end
   spa                     " Past end?
   jmp nlend               " Yes, done
   lac nsearch             " Specific search?
   sza
   jmp testn               " Yes, name match
   lacq                    " No, value match
   tad d3                  " Skip to value field (word 3)
   dac np
   lac i np                " Get symbol type
   sna                     " Skip if non-zero
   jmp nloop               " Zero = empty, skip
   isz np
   lac i np                " Get relocation flag
   dac treloc
   sad relocflg            " Match relocation?
   skp
   jmp nloop               " No, skip
   isz np
   lac i np                " Get value
   dac tvalue
   sad match               " Exact match?
   jmp nlok                " Yes, found!
   lac relocflg            " Relocatable?
   sna
   jmp nloop               " No, must be exact
   lac relflg              " Relative match OK?
   sna
   jmp nloop               " No
   -1
   tad tvalue              " Calculate distance
   cma
   tad match
   spa                     " Positive?
   jmp nloop               " No, skip
   dac 2f                  " Save distance
   tad mbrack              " Within bracket?
   sma
   jmp nloop               " No, too far
   lac best                " Better than best so far?
   cma
   tad d1
   tad 2f
   sma
   jmp nloop               " No
   lac 2f                  " Yes, new best match
   dac best
   lac tvalue
   dac value               " Save value
   lac treloc
   dac reloc               " Save relocation
   lac cnlp
   dac minp                " Save pointer
   jmp nloop               " Continue search
```

**Approximate Matching:**

If exact symbol not found, finds closest symbol within "bracket" (30 words):

```
Address 000157:
  - Symbol 'start' at 000100
  - Symbol 'loop' at 000150
  - Symbol 'done' at 000200

Prints: loop+7  (150 + 7 = 157, within bracket of 30)
```

This makes debugging much easier than raw octal!

### Why Debugging Was So Hard in 1969

**Before Symbolic Debuggers:**

1. **Core dumps were octal** - pages of numbers
2. **No symbol tables** - had to manually look up addresses in listings
3. **Register values in octal** - hard to interpret
4. **No expressions** - couldn't do address arithmetic
5. **No breakpoints** - couldn't stop program at specific points (on PDP-7)

**Typical 1969 Debugging Session (Without db):**

```
Program crashes, produces core dump

Core dump (partial):
000000: 066143
000001: 040157
000002: 026144
000003: 020006
...

Programmer must:
1. Look at listing to find what's at address 000000
2. Decode 066143 = lac 143 (load from address 143)
3. Find what symbol is at 143 in listing
4. Manually trace through program
5. Calculate addresses by hand
```

**With Unix db:**

```
$ db core a.out
52
$=                       # What is $? (PC register)
start+4
start/                   # What's at start?
start: lac buffer
start+1/                 # Next instruction
tad count
start+2/
dac result
start+3/
sys exit
```

Much easier!

### Modern Debugging Tools Descended from db

**gdb (GNU Debugger)** - 1986
- Direct descendant of Unix `db`
- Added:
  - Breakpoints
  - Single-stepping
  - Source-level debugging
  - Watchpoints
- Kept symbolic address resolution

**adb (Assembly DeBugger)** - 1978
- Evolution of `db` for UNIX v7
- Added formatting commands
- Better expression syntax
- Still used for kernel debugging

**lldb (LLVM Debugger)** - 2010
- Modern debugger
- Still has core dump analysis
- Still has symbolic debugging
- Still shows assembly with symbols

**The Inheritance:**

```
db (1969)
   ↓
adb (1978) - Advanced features
   ↓
dbx (1980s) - Source-level debugging
   ↓
gdb (1986) - GNU version
   ↓
lldb (2010) - Modern LLVM debugger
```

Every time you use `gdb` or `lldb` and see:

```
(gdb) print buffer
$1 = 0x12340
```

You're using concepts invented for PDP-7 Unix in 1969!

---

## 10.5 The Loader (ald.s)

The loader `ald` (Absolute LoaDer) reads programs from punched cards and loads them into executable files.

### Card Reader Input Format

The PDP-7 had a card reader attachment that could read standard **IBM 80-column punched cards**.

**Physical Card Format:**
- 80 columns wide
- 12 rows per column
- Each column encodes one character
- Hollerith code encoding

**Binary Card Format for PDP-7:**

```
Columns 1-2:    Mode and flags (binary)
Columns 3-4:    Sequence number (binary)
Columns 5-6:    Word count (binary)
Columns 7-79:   Data words (binary)
Column 80:      Checksum (binary)
```

**Card Reader Interface:**

```assembly
rawcard: 0
   lac systime i          " Get current time
   tad wtime              " Add wait time (300 = 5 seconds)
   dac tmtime             " Set timeout time
   -80                    " 80 columns per card
   dac c
   law tbuf-1             " Text buffer pointer
   dac 8
   crsb                   " Card Reader Start Binary
1:
   dzm crread i           " Clear read flag
2:
   lac systime i          " Check time
   cma
   tad tmtime             " Past timeout?
   spa
   jmp timeout            " Yes, timeout error
   lac crread i           " Has card reader read a character?
   sna
   jmp 2b                 " No, wait
   lac crchar i           " Yes, get character
   dac 8 i                " Store in buffer
   isz c                  " Count down columns
   jmp 1b                 " Continue until all 80 read
   law                    " Short delay
   dac 1f
   isz 1f
   jmp .-1
   jmp rawcard i          " Return
1: 0
```

**Card Reader Hardware Interface:**

The PDP-7 accessed the card reader through special system locations:
- `crread` (location 17) - Non-zero when character ready
- `crchar` (location 18) - Character value

The instruction `crsb` (Card Reader Start Binary) initiated card reading.

### Binary Format Parsing

Once a card is read, it's converted from 6-bit codes to 18-bit words:

```assembly
bincard: 0
   jms rawcard            " Read 80 columns into tbuf
   -24                    " 24 words fit on one card
   dac c
   law tbuf-1             " Source (6-bit codes)
   dac 8
   law buf-1              " Destination (18-bit words)
   dac 9
1:
   lac 8 i                " Get first 6-bit code
   alss 6                 " Shift left 6 bits
   dac 1f                 " Save
   lac 8 i                " Get second 6-bit code
   dac 1f+1               " Save
   lac 8 i                " Get third 6-bit code
   dac 1f+2               " Save

   " Assemble into two 18-bit words:
   " Word 1: bits 0-5 from code 1, bits 6-17 from code 2
   " Word 2: bits 0-11 from code 2, bits 12-17 from code 3

   lac 1f+1               " Get second code
   lrss 6                 " Right shift 6 bits
   xor 1f                 " Combine with first code
   dac 9 i                " Store first word

   lac 1f+1               " Get second code
   alss 12                " Left shift 12 bits
   xor 1f+2               " Combine with third code
   dac 9 i                " Store second word

   isz c                  " Count down
   jmp 1b                 " Continue
   jmp bincard i          " Return
1: 0;0;0
```

**Card Encoding:**

Three 6-bit codes → Two 18-bit words:

```
6-bit codes:   |aaaaaa|bbbbbb|cccccc|
                  ↓       ↓       ↓
18-bit words:  |aaaaaabbbbbb|bbbbbbcccccc|
                   Word 1       Word 2
```

### Checksum Verification

Each card includes a checksum to detect read errors:

```assembly
cloop:
   jms bincard            " Read and convert card
   lac buf                " Get mode/flags
   and o700               " Mask to mode bits
   sad o500               " Is it binary mode (500)?
   skp
   jmp notbin             " No, error

   -48                    " 48 words to checksum
   dac c1
   lac buf+3              " Get stored checksum
   dac sum                " Save it
   dzm buf+3              " Clear for calculation
   law buf-1              " Start of buffer
   dac 10
   cla                    " Clear accumulator
1:
   add 10 i               " Add each word
   isz c1                 " Count down
   jmp 1b                 " Continue
   sad sum                " Match stored checksum?
   skp
   jmp badcksum           " No, error
```

**Checksum Algorithm:**

1. Sum all words in card (except checksum field itself)
2. Compare to stored checksum
3. If mismatch, report error and re-read card

This catches errors from:
- Dust on card
- Bent or torn card
- Card reader mechanical problems
- Electrical noise

### Complete Implementation Analysis

The full loading process:

```assembly
loop:
   jms holcard            " Read hollerith (text) card
   lac o12                " Newline
   dac buf+4              " Add to buffer
   lac d1
   sys write; buf; 5      " Print card header (filename)
   law 017                " Mode 17 (read/write)
   sys creat; buf         " Create output file
   spa                    " Success?
   jmp ferror             " No, error
   dac fo                 " Save file descriptor
   dzm noc                " Clear word count
   law obuf               " Output buffer
   dac opt                " Output pointer
   dzm seq                " Clear sequence number

cloop:
   jms bincard            " Read binary card
   lac buf                " Get mode
   and o700
   sad o500               " Binary?
   skp
   jmp notbin

   " Verify checksum (shown above)

   lac buf+1              " Get sequence number
   sad seq                " Match expected?
   skp
   jmp badseq             " No, error

   -1
   tad buf+2              " Get word count
   cma
   dac c1                 " Use as counter
   law buf+3              " Point to data
   dac 10
1:
   lac 10 i               " Get data word
   jms putword            " Write to output
   isz c1                 " Count down
   jmp 1b                 " Continue

   isz seq                " Increment sequence number
   lac buf                " Get mode
   sma                    " High bit set (last card)?
   jmp cloop              " No, continue

   " Last card - finish up
   lac noc                " Get word count
   sna                    " Any data to write?
   jmp 1f                 " No
   dac 0f                 " Yes, set count
   lac fo                 " File descriptor
   sys write; obuf; 0;..  " Write final buffer
1:
   lac fo
   sys close              " Close file
   sys exit               " Exit

putword: 0
   dac opt i              " Store word in output buffer
   isz opt                " Advance pointer
   isz noc                " Count word
   lac noc
   sad d2048              " Buffer full? (2048 words)
   skp
   jmp putword i          " No, return
   lac fo                 " Yes, write buffer
   sys write; obuf; 2048
   dzm noc                " Reset count
   law obuf               " Reset pointer
   dac opt
   jmp putword i          " Return
```

### Physical Punched Cards in 1969

**What Cards Looked Like:**

```
 ___________________________________________________________________________
|  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  |
| :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::   |
|  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  |
| :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::  :::   |
|  ___  ___  ___  ___  ___  ___  ___  ___  ___  ___  ___  ___  ___  ___  |
| |   ||   ||   ||   ||   ||   ||   ||   ||   ||   ||   ||   ||   ||   | |
|0123456789012345678901234567890123456789012345678901234567890123456789012|
|___________________________________________________________________________|

7.375 inches wide × 3.25 inches tall
```

**Hollerith Code:**

Each column had 12 positions (rows):
```
Position:  12 11  0  1  2  3  4  5  6  7  8  9
           -- --  -  -  -  -  -  -  -  -  -  -
Character   Y  X        Numbers  →
   'A'      ●     ●  ●
   'B'      ●     ●     ●
   'C'      ●     ●        ●
   '0'                                        ●
   '1'                          ●
   '9'                                     ●
```

**Card Deck Organization:**

A program might be 50-500 cards in a deck:

```
Card 1:   Header card (program name, date)
Card 2:   Binary data - Sequence 000
Card 3:   Binary data - Sequence 001
Card 4:   Binary data - Sequence 002
...
Card N:   Binary data - Sequence XXX (last card flag set)
```

**Common Problems:**

1. **Dropped deck** - Cards out of order (sequence numbers help)
2. **Bent cards** - Won't feed through reader
3. **Torn cards** - Misread (checksum catches)
4. **Static electricity** - Cards stick together
5. **Coffee spills** - Cards unreadable

**Why ald Checks Everything:**

- Sequence numbers: Detect out-of-order cards
- Checksums: Detect read errors
- Timeouts: Detect jammed cards
- Mode checks: Detect wrong card type

**The Transition:**

By 1971-1972, Unix moved to DECTape and later disk-only:
- Faster (disk >> tape >> cards)
- More reliable
- Easier to edit
- Lower cost (no cards to buy)

But in 1969, card reader support was necessary for initial system bootstrap and sharing programs between sites.

---

## 10.6 The Development Workflow

### Write Code in ed

**Typical Editing Session:**

```
$ ed
?                       " File doesn't exist yet
a                       " Append mode
" hello.s - print hello world

   lac d1              " File descriptor 1 (stdout)
   sys write; 1f; 2f-1f
   sys exit
1:
   <he>;<ll>;<o 040; <wo>;<rl>;<d 012
2:
.                       " End append mode
w hello.s               " Write to file
123                     " 123 characters written
q                       " Quit
$
```

The programmer:
1. Creates file with `ed`
2. Types code line by line
3. Uses `.` to exit insert mode
4. Writes file with `w filename`
5. Quits with `q`

### Assemble with as

```
$ as hello.s
1
$
```

Output:
- `a.out` - Executable file
- `n.out` - Symbol table for debugger

If errors:
```
$ as hello.s
x>24                    " Syntax error on line 24
r>15                    " Relocation error on line 15
$
```

Error codes:
- `x>` - Syntax error
- `r>` - Relocation error
- `>>` - Address overflow
- `u>` - Undefined symbol
- `g>` - Garbage character

### Test and Debug

**If it works:**

```
$ a.out
hello world
$
```

**If it crashes:**

```
$ a.out
(crash - core dumped)
$ db core a.out
52                      " Error at location 52 (octal)
$=                      " What symbol?
start+4
start,10/               " Examine code
start: lac buffer
start+1: tad count
start+2: dac result
start+3: sys exit
start+4: illegal_instruction
...
```

The programmer:
1. Runs program
2. If crash, examines core dump
3. Finds error with symbolic debugging
4. Returns to editor to fix
5. Reassembles
6. Tests again

### Complete Example Workflow

**Goal:** Write a program to count characters in a file

**Step 1: Create with ed**

```
$ ed
?
a
" count.s - count characters

   sys open; 1f; 0      " Open file
   spa                  " Success?
   sys exit             " No, exit
   dac fd               " Save file descriptor
   dzm count            " Clear counter

loop:
   lac fd               " Load file descriptor
   sys read; buf; 64    " Read 64 words
   sna                  " Anything read?
   jmp done             " No, done
   dac nwords           " Save count
   law buf-1            " Buffer pointer
   dac 8
   lac nwords           " Load count
   cma                  " Negate
   dac c                " Use as counter
1:
   lac i 8              " Get word
   dac word             " Save
   jms getsc; talp      " Get first character
   sna                  " Non-zero?
   jmp 2f               " No, skip
   isz count            " Yes, count it
2:
   jms getsc; talp      " Get second character
   sna
   jmp 3f
   isz count
3:
   isz c                " Done with words?
   jmp 1b               " No, continue
   jmp loop             " Yes, read more

done:
   lac count            " Get count
   jms prnum            " Print number
   sys exit

" Print number subroutine
prnum: 0
   (code to print number)
   jmp i prnum

fd: .=.+1
count: .=.+1
nwords: .=.+1
c: .=.+1
word: .=.+1
talp: tal
tal: .=.+1
buf: .=.+64
1:
   <fi>;<le>;<na>;<me>;040040;040040
.
w count.s
456
q
$
```

**Step 2: Assemble**

```
$ as count.s
1
$
```

**Step 3: Test**

```
$ count.s
(program doesn't have execute permission yet - in early Unix)
$ a.out
324                     " Character count
$
```

**Step 4: Fix Bug (if any)**

Suppose it crashes:

```
$ a.out
(crash)
$ db core a.out
52
loop+5/                 " Examine where it crashed
loop+5: lac i 8
,8=                     " What's in register 8?
177777                  " -1 in octal - bad pointer!
$
```

Programmer realizes: forgot to initialize auto-index register!

```
$ ed count.s
456
/law buf-1/             " Find the line
law buf-1
i                       " Insert before
   cla                 " Clear accumulator first!
.
w
478                     " File now 478 bytes
q
$ as count.s
1
$ a.out
324                     " Works now!
$
```

### Comparison to Modern IDEs

**Modern IDE (Visual Studio Code, 2024):**

```
Install size:  ~200 MB
Memory usage:  ~500 MB RAM
Features:      Syntax highlighting
               Code completion
               Debugger integration
               Git integration
               Extensions
               Multiple windows
               Mouse support
               Graphics

Latency:       <100ms for most operations
```

**Unix Development Environment (1969):**

```
Install size:  ~26 KB (assembler + editor + debugger)
Memory usage:  ~8 KB RAM (one tool at a time)
Features:      Text editing (ed)
               Assembly
               Symbolic debugging
               File system integration

Latency:       <1 second for most operations
               (on a 0.1 MIPS machine!)
```

**What's Similar:**

1. **Edit-compile-debug cycle** - Same workflow
2. **Symbolic debugging** - Modern debuggers use same concepts
3. **File-based projects** - Code stored in files
4. **Command-line interface** - Programmers still use terminals
5. **Version control** - Unix had early source control

**What's Different:**

1. **Size** - 7,700x smaller (26KB vs 200MB)
2. **Graphics** - Unix used Teletype (paper), IDE uses GUI
3. **Speed** - PDP-7 0.1 MIPS, modern CPU 100,000+ MIPS (1,000,000x faster)
4. **Assistance** - No auto-complete, syntax highlighting, etc.
5. **Integration** - Modern IDEs integrate everything

**Productivity:**

Surprisingly, expert programmers were very productive with these tools:

- Ken Thompson wrote file system in ~1 month
- Dennis Ritchie added pipes in ~1 night
- Shell and utilities: weeks each

Modern programmers with IDEs aren't 1000x more productive, despite 1000x better tools. Why?

1. **Problems are harder** - More complex systems
2. **Compatibility** - Must work with legacy code
3. **Scale** - Millions of lines instead of thousands
4. **Quality demands** - More testing, documentation, security

But also:
1. **Tool complexity** - Time spent learning IDE
2. **Distractions** - Email, web, etc.
3. **Meeting overhead** - More coordination

The simple tools forced focus on the code itself.

### What Made This Revolutionary

**The Integrated Vision:**

All tools designed to work together:
- Editor saves files assembler reads
- Assembler writes symbol table debugger reads
- Debugger examines core dumps from crashed programs
- All use same file system
- All run on same machine
- All accessible to single programmer

**The Speed:**

From idea to running code: **minutes**

Industry standard in 1969: **hours to days**

This enabled:
- Rapid prototyping
- Experimentation
- Iterative refinement
- Learning by doing

**The Accessibility:**

One programmer, one machine, full development environment.

Before: Shared mainframe, batch processing, punch cards, operators.

This democratized programming.

**The Self-Hosting Loop:**

Better tools → Better programs → Better tools → ...

This created Unix's rapid evolution:
- 1969: First edition
- 1970: Second edition (pipes added)
- 1971: Third edition (major improvements)
- 1972: Fourth edition (rewritten in C!)
- 1973: Fifth edition (first widely distributed)

**The Legacy:**

Modern development still follows the Unix model:
- Text-based source files
- Command-line tools
- Symbolic debuggers
- Edit-compile-debug cycle
- Version control

The Unix development environment, written in ~3,210 lines of assembly code in 1969, created the template for all modern software development.

---

## Conclusion: Celebrating the Achievement

The PDP-7 Unix development tools represent one of computing's great achievements:

**The Numbers:**
- ~3,210 lines of assembly code
- ~26 KB total size
- Written in ~3 months (mid-1969)
- Enabled decades of innovation

**The Innovation:**
- Self-hosting system on small computer
- Symbolic debugging
- Regular expressions
- Integrated file system
- Complete development environment

**The Influence:**
- Every Unix and Linux system
- Every modern debugger
- Every text editor with regex
- Every IDE's edit-compile-debug cycle
- Every command-line tool

**The Philosophy:**
- Small, sharp tools
- Tools that work together
- Text-based interfaces
- Programmer empowerment
- Simplicity and clarity

In 1969, two programmers (Ken Thompson and Dennis Ritchie) created a complete, self-hosting development environment in assembly language on an obsolete computer. This environment was so well-designed that its descendants are still in use 55+ years later.

That is the true achievement: not just building tools, but building **the right tools** - tools so fundamental that they transcended their hardware and became timeless concepts in software development.

The PDP-7 Unix development tools prove that great software isn't about having the latest hardware or the most features. It's about clear thinking, elegant design, and tools that work together harmoniously.

This is the Unix philosophy distilled: do one thing well, make tools composable, use simple interfaces, and enable programmers to build better tools.

The virtuous cycle they created in 1969 is still spinning today.
