# Chapter 3: Assembly Language and Programming

## Introduction

Assembly language is the bridge between human thought and machine execution—a symbolic representation of the binary instructions that the CPU actually executes. For PDP-7 Unix, assembly wasn't just a tool; it was the *only* tool. Every line of the operating system, every utility, every tool was hand-crafted in PDP-7 assembly language.

This chapter will teach you PDP-7 assembly language programming from first principles. By the end, you'll be able to read and write PDP-7 assembly code, understand the Unix source code in detail, and appreciate the elegant solutions that Thompson and Ritchie created under severe constraints.

### Why Assembly for Unix?

In 1969, there were compelling reasons to write an operating system in assembly language:

**Performance Requirements:**
- **Direct hardware control** - Operating systems need access to CPU registers, memory management hardware, and I/O devices
- **No overhead** - High-level languages added layers of abstraction that consumed precious memory and CPU cycles
- **Predictable timing** - Interrupt handlers and device drivers required precise control over execution timing

**Resource Constraints:**
- **8K words of memory** (16 KB total) - No room for a compiler, runtime library, or generated code overhead
- **Limited development tools** - C didn't exist yet; BCPL was available but too large for the PDP-7
- **Self-hosting requirement** - The system had to be able to assemble itself, which meant the assembler itself had to fit in memory

**Cultural Context:**
- **Standard practice** - In 1969, all operating systems were written in assembly
- **Expertise available** - Thompson and Ritchie were expert assembly programmers
- **Tools existed** - Assemblers were simple, well-understood tools

The Unix assembler (`as.s`) is itself a marvel of compact design—a complete two-pass assembler in approximately 800 lines of assembly code.

### The Relationship to Machine Code

Assembly language and machine code are nearly identical—assembly is just the human-readable form:

```
Assembly         Machine Code      Meaning
─────────────────────────────────────────────────────────────
lac 100          020100           Load AC from location 100
dac result       040567           Store AC to location named 'result'
tad d1           140023           Add contents of 'd1' to AC
jmp loop         120045           Jump to address labeled 'loop'
```

The assembler's job is simple: convert symbolic names to numeric addresses and translate mnemonics to opcodes.

**Without assembly (pure machine code):**
```
020100    " What does this mean? You have to know!
140023    " What's at location 023? A constant? A variable?
040567    " Where is 567? What's stored there?
120045    " Is this a jump? To where?
```

**With assembly (symbolic):**
```assembly
   lac count      " Load the counter - clear intent
   tad d1         " Add 1 to it - obvious purpose
   dac count      " Store it back - straightforward
   jmp loop       " Jump to loop - explicit destination
```

Assembly provides:
1. **Symbolic labels** instead of numeric addresses
2. **Mnemonic opcodes** instead of binary codes
3. **Comments** for documentation
4. **Expressions** for calculations (e.g., `buffer+64`)
5. **Pseudo-operations** for data definition and assembly control

### The Unix Assembler Capabilities

The PDP-7 Unix assembler (`as.s`) supports:

**Basic Features:**
- **Two-pass assembly** - First pass builds symbol table, second pass generates code
- **Local and global labels** - Numeric labels (1:, 2:) for local scope, alphanumeric for global
- **Forward references** - Can jump to labels defined later in the source
- **Expression evaluation** - Arithmetic on symbols and constants
- **Multiple files** - Can assemble and link separate source files

**Directives:**
- `.=.+n` - Reserve space (increment location counter by n)
- `.=addr` - Set location counter to absolute address
- `name = value` - Define symbolic constant
- `i` suffix - Indirect addressing (e.g., `lac 100 i`)

**Advanced Features:**
- **System call macro** - `sys` generates proper system call sequence
- **String packing** - Assembler packs two 9-bit characters per word
- **Octal constants** - Native format for 18-bit words
- **Symbol table output** - For debugging (used by `db.s`)

### What You'll Learn

This chapter progresses through:

1. **Fundamentals** - Number systems, instruction formats, basic operations
2. **Core Programming** - Data manipulation, control flow, subroutines
3. **Advanced Techniques** - Multi-precision arithmetic, bit manipulation, optimization
4. **System Integration** - System calls, calling conventions, library usage
5. **Complete Programs** - Full working examples you can study and modify

Each section builds on the previous, with extensive code examples drawn from actual Unix sources and original tutorial programs.

Let's begin.

---

## 1. Number Systems and Notation

Before writing assembly code, you must become fluent in **octal** (base-8) notation. While decimal is natural for humans and hexadecimal is common today, octal was the lingua franca of PDP-7 programming.

### Why Octal for 18-Bit Words?

The PDP-7's 18-bit word size made octal the natural choice:

```
Binary (18 bits):    001 010 011 100 101 110
                     └─┘ └─┘ └─┘ └─┘ └─┘ └─┘
Octal (6 digits):     1   2   3   4   5   6

18 bits = exactly 6 octal digits (000000 to 777777)
```

**Compare the alternatives:**

```
Decimal: 18 bits = 0 to 262,143 (6 digits, awkward)
         No clean relationship between bits and digits
         Hard to see bit patterns

Octal:   18 bits = 000000 to 777777 (6 digits, perfect)
         Each digit represents exactly 3 bits
         Bit patterns immediately visible

Hex:     18 bits = 0x00000 to 0x3FFFF (5 digits, odd)
         Last digit only uses 2 bits (0-3)
         Awkward for 18-bit word boundaries
```

**Examples showing octal's advantage:**

```assembly
" Setting specific bits is intuitive in octal:
   lac 0177        " Binary: 000 000 001 111 111
                   "           0   0   1   7   7
                   " Sets bits 0-6 (useful for masking 7-bit ASCII)

   lac 0600000     " Binary: 110 000 000 000 000
                   "           6   0   0   0   0
                   " Sets bits 17-16 (high-order flags)

   lac 0707070     " Binary: 111 000 111 000 111 000
                   "           7   0   7   0   7   0
                   " Every other 3-bit group set
```

### Octal Digit Values

Each octal digit represents a 3-bit binary value:

| Octal | Binary | Decimal |
|-------|--------|---------|
| 0     | 000    | 0       |
| 1     | 001    | 1       |
| 2     | 010    | 2       |
| 3     | 011    | 3       |
| 4     | 100    | 4       |
| 5     | 101    | 5       |
| 6     | 110    | 6       |
| 7     | 111    | 7       |

**Reading 18-bit octal numbers:**

```
Octal:    123456
Digits:   1  2  3  4  5  6
Bits:    17 14 11  8  5  2
         ↓  ↓  ↓  ↓  ↓  ↓
Binary:  001 010 011 100 101 110
Bit #:   ││││││││││││││││││
         17────────────────0

Decimal: 1×8^5 + 2×8^4 + 3×8^3 + 4×8^2 + 5×8^1 + 6×8^0
       = 1×32768 + 2×4096 + 3×512 + 4×64 + 5×8 + 6×1
       = 32768 + 8192 + 1536 + 256 + 40 + 6
       = 42798 (decimal)
```

### Converting Between Number Systems

#### Octal to Decimal

Multiply each digit by its positional value (powers of 8):

```
Example: 01234 (octal) to decimal

01234₈ = 1×8³ + 2×8² + 3×8¹ + 4×8⁰
       = 1×512 + 2×64 + 3×8 + 4×1
       = 512 + 128 + 24 + 4
       = 668₁₀
```

#### Decimal to Octal

Repeatedly divide by 8, collecting remainders:

```
Example: 1000 (decimal) to octal

1000 ÷ 8 = 125 remainder 0    ─┐
 125 ÷ 8 =  15 remainder 5     │
  15 ÷ 8 =   1 remainder 7     │ Read upward
   1 ÷ 8 =   0 remainder 1    ─┘

Result: 1750₈

Verify: 1×512 + 7×64 + 5×8 + 0×1 = 512 + 448 + 40 = 1000 ✓
```

#### Octal to Binary

Each octal digit converts directly to 3 bits:

```
Example: 07654 (octal) to binary

0 7 6 5 4
↓ ↓ ↓ ↓ ↓
000 111 110 101 100

Result: 000 111 110 101 100 (binary)
Grouped: 000111110101100 (binary)
```

#### Binary to Octal

Group binary digits by threes, starting from the right:

```
Example: 1101110101 (binary) to octal

  1 101 110 101
  ↓  ↓   ↓   ↓
  1  5   6   5

Result: 1565₈
```

### Common Octal Values in Unix

Memorizing these common values will speed your reading of Unix source code:

**Powers of 2:**
```
Decimal    Octal      Binary (18-bit)        Usage
────────────────────────────────────────────────────────────
1          000001     000 000 000 000 001    Bit 0
2          000002     000 000 000 000 010    Bit 1
4          000004     000 000 000 000 100    Bit 2
8          000010     000 000 000 001 000    Bit 3
16         000020     000 000 000 010 000    Bit 4
32         000040     000 000 000 100 000    Bit 5
64         000100     000 000 001 000 000    Bit 6
128        000200     000 000 010 000 000    Bit 7
256        000400     000 000 100 000 000    Bit 8
512        001000     000 001 000 000 000    Bit 9
1024       002000     000 010 000 000 000    Bit 10
2048       004000     000 100 000 000 000    Bit 11
4096       010000     001 000 000 000 000    Bit 12
8192       020000     010 000 000 000 000    Bit 13
```

**Character values (7-bit ASCII):**
```
Decimal    Octal      Character
─────────────────────────────────
0          000        NUL (null)
8          010        BS (backspace)
9          011        HT (tab)
10         012        LF (line feed / newline)
13         015        CR (carriage return)
32         040        SP (space)
48         060        '0'
57         071        '9'
65         0101       'A'
90         0132       'Z'
97         0141       'a'
122        0172       'z'
127        0177       DEL (delete)
```

**Memory addresses:**
```
Octal      Decimal    Usage in Unix
────────────────────────────────────────────────────────
000000     0          Low memory start
000010     8          Auto-increment register 0
000017     15         Auto-increment register 7
000020     16         System call trap vector
007777     4095       End of 4K page
010000     4096       Start of second 4K page
017700     8176       Disk buffer (dskbuf)
017777     8191       Highest address in 8K memory
```

**Bit masks:**
```
Octal      Binary (18-bit)         Usage
─────────────────────────────────────────────────────────
000001     000 000 000 000 001     Bit 0 only
000177     000 000 001 111 111     Bits 0-6 (7-bit ASCII)
000377     000 000 011 111 111     Bits 0-7 (8-bit byte)
001777     000 001 111 111 111     Bits 0-9 (10 bits)
007777     000 111 111 111 111     Bits 0-11 (12 bits)
017777     001 111 111 111 111     Bits 0-13 (13 bits)
037777     011 111 111 111 111     Bits 0-14 (14 bits)
077777     111 111 111 111 111     Bits 0-15 (15 bits)
177777     All bits except 17      Sign bit mask (negative)
777777     111 111 111 111 111     All bits (also -1 in two's complement)
```

### Practice Exercises

Test your understanding with these conversions:

**Exercise 1:** Convert octal to decimal
```
a) 0100 octal = ?        (Answer: 64)
b) 0777 octal = ?        (Answer: 511)
c) 010000 octal = ?      (Answer: 4096)
d) 077777 octal = ?      (Answer: 32767)
```

**Exercise 2:** Convert decimal to octal
```
a) 100 decimal = ?       (Answer: 0144)
b) 256 decimal = ?       (Answer: 0400)
c) 1000 decimal = ?      (Answer: 01750)
d) 8191 decimal = ?      (Answer: 017777)
```

**Exercise 3:** Identify what these octal numbers represent
```
a) 000177               (Answer: 7-bit ASCII mask, decimal 127)
b) 000012               (Answer: Line feed character '\n', decimal 10)
c) 017700               (Answer: Disk buffer address, decimal 8176)
d) 777777               (Answer: -1 in two's complement, all bits set)
```

### Two's Complement Negative Numbers

The PDP-7 uses **two's complement** representation for negative numbers:

```
Positive numbers:    0 (000000) to +131071 (377777)
Bit 17 = 0          Sign bit clear

Negative numbers:    -1 (777777) to -131072 (400000)
Bit 17 = 1          Sign bit set
```

**Converting positive to negative:**

Method 1: Invert all bits and add 1
```
+5 in binary:    000 000 000 000 101 (000005 octal)
Invert bits:     111 111 111 111 010
Add 1:           111 111 111 111 011 (777773 octal) = -5
```

Method 2: Subtract from 2^18
```
-5 = 2^18 - 5 = 262144 - 5 = 262139 = 777773 octal
```

**Common negative values:**
```
Decimal    Octal      Binary (18-bit)
────────────────────────────────────────────
-1         777777     111 111 111 111 111
-2         777776     111 111 111 111 110
-4         777774     111 111 111 111 100
-8         777770     111 111 111 111 000
-16        777760     111 111 111 110 000
-64        777700     111 111 111 000 000
-128       777600     111 111 110 000 000
-256       777400     111 111 100 000 000
-512       777000     111 111 000 000 000
-1024      776000     111 110 000 000 000
```

**Using negative constants for countdown loops:**

```assembly
" Loop 10 times using negative counter
   -10                " Load AC with -10 (777766 octal)
   dac count          " Initialize counter

loop:
   " ... body of loop ...

   isz count          " Increment: -10 → -9 → ... → -1 → 0
                      " When reaches 0, skip next instruction
   jmp loop           " Jump back (skipped when count = 0)

   " ... continue after loop ...

count: 0
```

This technique is ubiquitous in Unix source code because it's more efficient than comparing to a positive limit.

---

## 2. Basic Instruction Tutorial

Let's learn PDP-7 assembly by writing actual code, starting with the simplest operations and building to complete programs.

### Your First Instruction: LAC (Load AC)

The most fundamental operation is loading a value into the Accumulator (AC):

```assembly
" Load a constant
   lac d1            " Load AC with contents of location 'd1'
                     " If d1 contains the value 1, AC becomes 1

" The constant definition
d1: 1                " Location labeled 'd1' contains value 1
```

**Execution trace:**
```
Before:  AC = ??????? (unknown)
         Memory[d1] = 1

Execute: lac d1

After:   AC = 1
         Memory[d1] = 1 (unchanged)
```

**Common usage pattern:**
```assembly
" Constants defined at end of program
d0: 0
d1: 1
d2: 2
d8: 8
dm1: -1              " Negative one (777777 octal)

" Used throughout the code
   lac d1            " Load 1
   lac d8            " Load 8
   lac dm1           " Load -1
```

This pattern appears throughout Unix because literal constants aren't directly supported—you must load from memory.

### DAC (Deposit AC) - Storing Values

Once you have a value in AC, you store it with DAC:

```assembly
" Store AC to a variable
   lac d1            " Load 1 into AC
   dac count         " Store AC (value 1) to location 'count'

" Memory allocation
count: 0             " Reserve one word, initialize to 0
```

**Execution trace:**
```
Before:  AC = 1
         Memory[count] = 0

Execute: dac count

After:   AC = 1 (unchanged)
         Memory[count] = 1
```

### TAD (Two's Complement Add) - Addition

Add a value to AC:

```assembly
" Add 1 to AC
   lac count         " Load current count (assume it's 5)
   tad d1            " Add 1 to AC
   dac count         " Store result back (now 6)

" Constants
count: 5
d1: 1
```

**Execution trace:**
```
Before:  AC = 5
         Memory[d1] = 1

Execute: tad d1

After:   AC = 6 (5 + 1)
         Link = 0 (no carry)
```

**Addition with carry:**
```assembly
" Adding two large numbers that produce carry
   lac value1        " Load 0400000 (131072 decimal)
   tad value2        " Add 0400000 (131072 decimal)
                     " Result = 262144, but max positive = 131071
                     " So: AC = 0 (overflow), Link = 1 (carry)

value1: 0400000
value2: 0400000
```

### A Complete Example: Increment a Variable

```assembly
" Program: Increment a counter
" Loads count, adds 1, stores result

start:
   lac count         " Load current value of count
   tad d1            " Add 1
   dac count         " Store new value
   hlt               " Halt (stop execution)

" Data area
count: 0             " Counter variable (starts at 0)
d1: 1                " Constant 1

" Result: count becomes 1
```

**Step-by-step execution:**
```
1. lac count    : AC ← 0         (load initial value)
2. tad d1       : AC ← 0 + 1 = 1 (add one)
3. dac count    : count ← 1      (store result)
4. hlt          : Stop
```

### Subtraction Using Two's Complement

There's no subtract instruction—use negative constants:

```assembly
" Decrement a counter
   lac count         " Load count (assume 10)
   tad dm1           " Add -1 (same as subtract 1)
   dac count         " Store result (now 9)

count: 10
dm1: -1              " 777777 octal
```

**Why this works:**
```
10 + (-1) = 9

In binary (simplified to show concept):
  00001010  (10)
+ 11111111  (-1 in two's complement)
──────────
  00001001  (9)
```

### Simple Arithmetic Examples

**Example 1: Add two numbers**
```assembly
" Compute: result = a + b

   lac a             " Load first number
   tad b             " Add second number
   dac result        " Store sum

a: 42                " First number
b: 17                " Second number
result: 0            " Will contain 59
```

**Example 2: Compute expression (a + b) - c**
```assembly
" result = (a + b) - c

   lac a             " Load a
   tad b             " Add b (AC = a + b)
   tad neg_c         " Add -c (AC = a + b - c)
   dac result        " Store result

a: 100
b: 50
neg_c: -30           " Negative c
result: 0            " Will contain 120
```

**Example 3: Add three numbers**
```assembly
" sum = a + b + c

   lac a             " Load a
   tad b             " Add b
   tad c             " Add c
   dac sum           " Store sum

a: 10
b: 20
c: 30
sum: 0               " Will contain 60
```

### CLA (Clear AC) - Starting Fresh

Often you need to zero the AC:

```assembly
" Clear AC to zero
   cla               " AC ← 0

" Common pattern: clear and add
   cla               " Start with 0
   tad value1        " AC = 0 + value1 = value1
   tad value2        " AC = value1 + value2
   dac sum           " Store sum
```

This is more efficient than loading zero from memory.

### LAS (Load AC with Switches) - Reading Input

On the PDP-7, the front panel had 18 toggle switches:

```assembly
" Read switch register into AC
   las               " AC ← switch register value

" Typical use: manual program input
start:
   las               " Read number from switches
   dac number        " Store it
   hlt               " Halt for next input

number: 0
```

Operators could manually enter numbers by setting switches and running the program.

### Practice Programs

**Program 1: Simple calculator**
```assembly
" Add two numbers from switches

   las               " Read first number from switches
   dac operand1      " Store it
   hlt               " Halt (operator sets second number)

   las               " Read second number
   dac operand2      " Store it

   lac operand1      " Load first number
   tad operand2      " Add second number
   dac result        " Store sum
   hlt               " Halt (result available)

operand1: 0
operand2: 0
result: 0
```

**Program 2: Accumulate sum**
```assembly
" Add numbers until total reaches 100

start:
   cla               " Start with sum = 0
   dac sum           " Initialize sum

loop:
   lac sum           " Load current sum
   tad increment     " Add 5
   dac sum           " Store new sum

   lac limit         " Load limit (100)
   tad neg_sum       " Subtract sum (limit - sum)
   sma               " Skip if minus (sum > limit)
   jmp loop          " Continue if sum <= limit

   hlt               " Done

sum: 0
increment: 5
limit: 100
neg_sum: 0           " Updated each iteration
```

(We'll learn SMA and JMP in the Control Flow section)

---

## 3. Addressing Modes in Practice

The PDP-7 supports several addressing modes that dramatically affect how you write code. Understanding these modes is crucial for reading Unix source code.

### Direct Addressing (Default Mode)

**Direct addressing** means the instruction contains the actual memory address:

```assembly
   lac 1000          " Load AC from address 1000 (octal)
                     " AC ← Memory[1000]
```

**Visual representation:**
```
┌──────────────┐
│ Instruction  │  lac 1000
└──────┬───────┘
       │
       └──────┐
              ↓
         ┌─────────┐
Address  │  1000   │  Value: 42
         └─────────┘
              ↓
           AC = 42
```

**Usage in code:**
```assembly
" Direct addressing with labels
   lac counter       " Load from address of 'counter'
   dac result        " Store to address of 'result'

counter: 5
result: 0
```

The assembler resolves labels to addresses, so `lac counter` becomes `lac 0234` if counter is at address 0234.

### Indirect Addressing (i Suffix)

**Indirect addressing** means the instruction points to a location containing the *address* of the data:

```assembly
   lac 1000 i        " Load AC from Memory[Memory[1000]]
                     " AC ← Memory[Memory[1000]]
```

**Visual representation:**
```
┌──────────────┐
│ Instruction  │  lac 1000 i
└──────┬───────┘
       │
       └──────┐
              ↓
         ┌─────────┐
Address  │  1000   │  Value: 2500  ← Points to another address
         └─────────┘
              │
              └──────┐
                     ↓
                ┌─────────┐
Address         │  2500   │  Value: 42  ← Actual data
                └─────────┘
                     ↓
                  AC = 42
```

**Why indirect addressing?**

1. **Pointers** - Access data through a pointer variable
2. **Dynamic addressing** - Address computed at runtime
3. **Arrays** - Traverse data structures
4. **Function parameters** - Pass addresses as arguments

**Example: Using a pointer**
```assembly
" Direct vs. Indirect

" Direct: Access 'value' directly
   lac value         " AC ← Memory[value] = 42

" Indirect: Access 'value' through 'ptr'
   lac ptr i         " AC ← Memory[Memory[ptr]]
                     " Memory[ptr] = address of 'value'
                     " Memory[value] = 42
                     " So: AC ← 42

value: 42
ptr: value           " ptr contains address of value
```

**Example: Changing what pointer points to**
```assembly
" Setup
   law value1        " Load address of value1
   dac ptr           " ptr now points to value1

   lac ptr i         " AC ← Memory[Memory[ptr]] = 10

   law value2        " Load address of value2
   dac ptr           " ptr now points to value2

   lac ptr i         " AC ← Memory[Memory[ptr]] = 20

value1: 10
value2: 20
ptr: 0
```

### LAW (Load Address Word) - Loading Addresses

To work with pointers, you need to load addresses:

```assembly
" LAW loads an address into AC
   law array         " AC ← address of 'array'
                     " NOT the contents of array!

" Now use it as a pointer
   dac ptr           " ptr ← address of array
   lac ptr i         " AC ← array[0] (first element)

array: 1; 2; 3; 4; 5
ptr: 0
```

**LAW vs LAC:**
```assembly
   law value         " AC ← address of value (e.g., 1000)
   lac value         " AC ← contents of value (e.g., 42)

value: 42            " Stored at address 1000 (example)
```

### Auto-Increment Addressing (Locations 8-15)

**The most powerful feature** of the PDP-7: locations 010-017 (octal) automatically increment when used indirectly.

**Memory locations 8-15 (decimal) = 010-017 (octal):**

```assembly
" Setup: Use location 8 as auto-increment pointer
   law array-1       " Load address one before array
   dac 8             " Store in location 8 (010 octal)

" Now each access increments the pointer
   lac 8 i           " 1st access: AC ← array[0], then 8 ← 8+1
   lac 8 i           " 2nd access: AC ← array[1], then 8 ← 8+1
   lac 8 i           " 3rd access: AC ← array[2], then 8 ← 8+1

array: 10; 20; 30; 40; 50
```

**Step-by-step execution:**
```
Initial state:
   Location 8 = address of array-1 = 999 (example)
   Memory[1000] = 10
   Memory[1001] = 20
   Memory[1002] = 30

Instruction: lac 8 i

Step 1: Read Memory[8] = 999
Step 2: Increment Memory[8] ← 1000 (auto-increment!)
Step 3: Load AC ← Memory[999+1] = Memory[1000] = 10

Next instruction: lac 8 i

Step 1: Read Memory[8] = 1000
Step 2: Increment Memory[8] ← 1001
Step 3: Load AC ← Memory[1001] = 20

And so on...
```

**Why start at array-1?**

The auto-increment happens *before* the access, so we start one before to hit the first element:

```assembly
" Method 1: Start one before (standard Unix practice)
   law array-1       " Point to array-1
   dac 8
   lac 8 i           " Increments to array, reads array[0]

" Method 2: Start at first element (alternative)
   law array         " Point to array[0]
   dac 8
   lac 8 i           " Reads array[0], increments to array[1]
   lac 8 i           " Reads array[1], increments to array[2]
```

Both work; Unix code consistently uses Method 1.

### Array Processing with Auto-Increment

**Example: Sum an array**
```assembly
" Sum 5 numbers in an array

   cla               " sum = 0
   dac sum

   law array-1       " Setup pointer
   dac 8

   -5                " Loop counter (count down from -5)
   dac count

loop:
   lac sum           " Load current sum
   tad 8 i           " Add next array element (auto-increments!)
   dac sum           " Store new sum

   isz count         " Increment count: -5 → -4 → ... → 0
   jmp loop          " Continue while count < 0

   hlt               " Done, sum contains result

array: 10; 20; 30; 40; 50
sum: 0
count: 0

" Result: sum = 150
```

**Execution trace:**
```
Loop iteration 1:
   sum = 0
   8 i reads array[0]=10, increments pointer
   sum = 10
   count: -5 → -4

Loop iteration 2:
   sum = 10
   8 i reads array[1]=20, increments pointer
   sum = 30
   count: -4 → -3

Loop iteration 3:
   sum = 30
   8 i reads array[2]=30, increments pointer
   sum = 60
   count: -3 → -2

Loop iteration 4:
   sum = 60
   8 i reads array[3]=40, increments pointer
   sum = 100
   count: -2 → -1

Loop iteration 5:
   sum = 100
   8 i reads array[4]=50, increments pointer
   sum = 150
   count: -1 → 0 (triggers skip)

Loop exits
```

### Two Pointers: Array Copy

Use multiple auto-increment registers for complex operations:

```assembly
" Copy source array to destination array

   law source-1      " Source pointer
   dac 8

   law dest-1        " Destination pointer
   dac 9

   -10               " Copy 10 elements
   dac count

loop:
   lac 8 i           " Read from source (auto-increment)
   dac 9 i           " Write to dest (auto-increment)

   isz count         " Decrement counter
   jmp loop          " Continue

   hlt               " Done

source: 1; 2; 3; 4; 5; 6; 7; 8; 9; 10
dest: .=.+10         " Reserve 10 words
count: 0
```

**Why this is elegant:**

Without auto-increment, you'd need:
```assembly
" Manual pointer increment (inefficient)
loop:
   lac src_ptr       " Load source address (1 instruction)
   dac temp          " Store to temp (1 instruction)
   lac temp i        " Load value (1 instruction)
   dac value         " Save value (1 instruction)

   lac dst_ptr       " Load dest address (1 instruction)
   dac temp          " Store to temp (1 instruction)
   lac value         " Load value (1 instruction)
   dac temp i        " Store value (1 instruction)

   lac src_ptr       " Increment source (1 instruction)
   tad d1
   dac src_ptr       " (3 instructions)

   lac dst_ptr       " Increment dest (1 instruction)
   tad d1
   dac dst_ptr       " (3 instructions)

   " Total: 16 instructions per iteration!
```

With auto-increment:
```assembly
loop:
   lac 8 i           " Read and increment (1 instruction)
   dac 9 i           " Write and increment (1 instruction)

   " Total: 2 instructions per iteration
```

**8× more efficient!**

### When to Use Each Mode

**Direct addressing:**
- Accessing global variables
- Reading constants
- Simple variable access
```assembly
   lac counter
   tad increment
   dac counter
```

**Indirect addressing:**
- Following pointers
- Accessing through computed addresses
- Function parameters
```assembly
   lac file_ptr i    " Access file through pointer
```

**Auto-increment (locations 8-15):**
- Array traversal
- String processing
- Block copy operations
- Sequential data access
```assembly
   lac 8 i           " Traverse array
   dac 9 i           " Copy to another array
```

### All Eight Auto-Increment Registers

Unix code uses a convention for these precious registers:

| Octal | Decimal | Typical Use |
|-------|---------|-------------|
| 010   | 8       | Primary pointer (arrays, strings) |
| 011   | 9       | Secondary pointer (destination) |
| 012   | 10      | Temporary pointer |
| 013   | 11      | String pointer |
| 014   | 12      | Buffer pointer |
| 015   | 13      | Stack pointer |
| 016   | 14      | Loop counter |
| 017   | 15      | Saved pointer |

This isn't enforced by hardware, but Unix source code follows these conventions consistently.

### Real Unix Example: Character Packing

From Unix `cat.s`, showing practical use:

```assembly
" Pack two characters into one word
" Characters are 9 bits each (PDP-7 uses 9-bit chars)

   lac ipt           " Load input pointer
   ral               " Rotate AC left (bit 17 → Link)
   lac ipt i         " Load word from input buffer
   szl               " Skip if Link Zero (even character)
   lrss 9            " Shift right 9 bits (get odd character)
   and o177          " Mask to 7-bit ASCII
   dac char          " Store character

ipt: buffer          " Input pointer
char: 0
o177: 0177           " Octal 177 = binary 001111111 (7 bits)
buffer: 0
```

This extracts individual characters from packed 18-bit words—essential for Unix's file I/O.

---

## 4. Control Flow

Sequential execution is insufficient for real programs. You need branches, loops, and subroutines.

### Unconditional Jump: JMP

The simplest control flow is the unconditional jump:

```assembly
" Infinite loop
loop:
   " ... do something ...
   jmp loop          " Jump back to 'loop' label

" Skip code
   jmp skip          " Jump over next section
   lac value1        " This is skipped
   dac result        " This is skipped
skip:
   lac value2        " Execution resumes here
```

**Execution:**
```
jmp loop → PC ← address of 'loop' label
```

The Program Counter (PC) is set to the target address, and execution continues there.

### Skip Instructions: Building Conditional Logic

The PDP-7 has no compare instruction. Instead, it has **skip instructions** that conditionally skip the next instruction:

**Skip instructions:**
- `sza` - Skip if AC Zero
- `sna` - Skip if AC Not zero (AC ≠ 0)
- `sma` - Skip if AC Minus (AC < 0, bit 17 = 1)
- `spa` - Skip if AC Plus (AC ≥ 0, bit 17 = 0)
- `szl` - Skip if Link Zero
- `snl` - Skip if Link Not zero

**Basic pattern:**
```assembly
   lac value         " Load value
   sza               " Skip next instruction if AC = 0
   jmp nonzero       " This executes if AC ≠ 0

   " Code for AC = 0 case
   jmp continue

nonzero:
   " Code for AC ≠ 0 case

continue:
   " Execution continues
```

### Conditional Execution Examples

**Example 1: If-Then**
```assembly
" If count == 0, reset it to 10

   lac count         " Load count
   sza               " Skip if zero
   jmp continue      " Not zero, skip reset

   " This executes only if count was 0
   lac d10           " Load 10
   dac count         " Store to count

continue:
   " ... rest of program ...

count: 0
d10: 10
```

**Example 2: If-Then-Else**
```assembly
" If value < 0, set result = -1, else result = +1

   lac value         " Load value
   sma               " Skip if minus (negative)
   jmp positive      " Value is positive or zero

negative:
   " Value is negative
   lac dm1           " Load -1
   dac result
   jmp continue

positive:
   " Value is positive or zero
   lac d1            " Load +1
   dac result

continue:
   " ... rest of program ...

value: -5            " Example: negative value
result: 0
d1: 1
dm1: -1
```

**Example 3: Multiple conditions**
```assembly
" Classify value: negative, zero, or positive

   lac value         " Load value
   sza               " Skip if zero
   jmp notzero

iszero:
   lac msg_zero      " Handle zero case
   jmp continue

notzero:
   sma               " Skip if minus
   jmp positive

negative:
   lac msg_neg       " Handle negative case
   jmp continue

positive:
   lac msg_pos       " Handle positive case

continue:
   " ... continue ...

value: 42
msg_neg: -1
msg_zero: 0
msg_pos: 1
```

### SAD (Skip if AC Different) - Comparison

Compare AC to a memory value:

```assembly
   lac count         " Load count
   sad limit         " Skip if AC ≠ Memory[limit]
   jmp equal         " AC = limit, jump to equal

notequal:
   " AC ≠ limit
   jmp continue

equal:
   " AC = limit

continue:
   " ...

count: 10
limit: 10
```

**Inverted logic (skip if equal):**
```assembly
" Skip if AC = limit (by inverting logic)

   lac count
   sad limit         " Skip if different
   skp               " Skip next instruction (only if equal)
   jmp different     " Jumped to if different

equal:
   " AC = limit
   jmp continue

different:
   " AC ≠ limit

continue:
   " ...
```

Wait, what's `skp`? That's our next topic!

### SKP (Skip Unconditionally)

`skp` always skips the next instruction:

```assembly
   skp               " Always skip next instruction
   lac value1        " This is skipped
   lac value2        " Execution resumes here
```

**Why is this useful?**

Combined with conditional skips for inverted logic:

```assembly
" Standard: Skip if zero
   lac count
   sza               " Skip if AC = 0
   jmp nonzero       " Execute if AC ≠ 0
   " ... code for AC = 0 ...

" Inverted: Don't skip if zero
   lac count
   sza               " Skip if AC = 0
   skp               " Skipped if AC = 0, so only executes if AC ≠ 0
   jmp zero          " Execute if AC = 0
   " ... code for AC ≠ 0 ...
```

This pattern appears frequently in Unix code for cleaner logic flow.

### ISZ (Increment and Skip if Zero) - Counting Loops

The most important loop instruction:

```assembly
" ISZ: Memory[addr] ← Memory[addr] + 1
"      If result = 0, skip next instruction

   -10               " Load -10 (negative count)
   dac count         " count = -10

loop:
   " ... loop body ...

   isz count         " Increment count (-10 → -9 → ... → 0)
                     " When count reaches 0, skip next instruction
   jmp loop          " Jump back (skipped when count = 0)

   " ... continue after loop ...

count: 0
```

**Execution trace:**
```
count = -10
isz count → count = -9 (not zero, don't skip)
jmp loop  → repeat

count = -9
isz count → count = -8 (not zero, don't skip)
jmp loop  → repeat

...

count = -1
isz count → count = 0 (zero! skip next instruction)
jmp loop  → SKIPPED

Execution continues after jmp loop
```

**Why use negative counters?**

Using positive counters would require comparison:
```assembly
" Inefficient: positive counter
   cla
   dac count         " count = 0

loop:
   " ... body ...

   lac count
   tad d1            " count++
   dac count

   sad limit         " Compare to limit
   skp
   jmp done          " Exit if equal
   jmp loop          " Continue

done:
   " ...

count: 0
limit: 10
d1: 1

" This requires 7 instructions for loop control!
```

With negative counter and ISZ:
```assembly
" Efficient: negative counter
   -10
   dac count

loop:
   " ... body ...

   isz count         " Just 2 instructions
   jmp loop          " for loop control!

count: 0
```

**This is why Unix code is full of negative loop counters.**

### Complete Loop Examples

**Example 1: Count down from 100 to 0**
```assembly
start:
   -100              " Load -100
   dac counter       " Initialize counter

loop:
   " ... loop body (executes 100 times) ...

   isz counter       " -100 → -99 → ... → -1 → 0
   jmp loop          " Continue while counter < 0

   hlt               " Done

counter: 0
```

**Example 2: Array initialization**
```assembly
" Zero out 64 words starting at buffer

   law buffer-1      " Setup pointer
   dac 8

   -64               " 64 iterations
   dac count

loop:
   dzm 8 i           " Deposit zero to memory at pointer
                     " (auto-increments pointer)

   isz count         " Increment count
   jmp loop          " Continue

   hlt               " Done

buffer: .=.+64       " Reserve 64 words
count: 0
```

**Example 3: Nested loops (2D array)**
```assembly
" Zero a 10×10 array

   -10               " Outer loop: 10 rows
   dac outer

   law array-1       " Array base pointer
   dac 8

outer_loop:
   -10               " Inner loop: 10 columns per row
   dac inner

inner_loop:
   dzm 8 i           " Zero element, advance pointer

   isz inner         " Inner loop control
   jmp inner_loop

   isz outer         " Outer loop control
   jmp outer_loop

   hlt               " Done

array: .=.+100       " 10×10 = 100 words
outer: 0
inner: 0
```

### DZM (Deposit Zero to Memory) - Efficient Clearing

A special instruction for zeroing memory:

```assembly
   dzm location      " Memory[location] ← 0
                     " More efficient than:
                     "   cla
                     "   dac location
```

Used extensively for initialization:

```assembly
" Clear multiple variables
   dzm sum
   dzm count
   dzm total
   dzm result
```

### JMS (Jump to Subroutine) - Function Calls

The fundamental mechanism for subroutines:

```assembly
" Call a subroutine
   jms subr          " Jump to subroutine
   " Execution returns here

" Continue main program
   hlt

" Subroutine definition
subr: 0              " Return address stored here!
   " ... subroutine body ...
   jmp subr i        " Return (indirect jump through return address)
```

**How JMS works:**

```
Before JMS:
   PC = 100 (address of JMS instruction)

Execute: jms subr (assume subr is at address 500)

Step 1: Memory[500] ← 101 (next instruction after JMS)
Step 2: PC ← 501 (address after label 'subr:')
Step 3: Execute subroutine body starting at 501

When subroutine executes: jmp subr i

Step 1: Load address from Memory[500] = 101
Step 2: PC ← 101
Step 3: Execution resumes after original JMS
```

**Visual representation:**
```
Main program:
   100: jms subr     ←─────┐
   101: next instr         │ Return here
   102: ...                │
                           │
Subroutine:               │
   500: 0           ───────┘ Return address stored here
   501: lac x              ← Execution starts here
   502: tad y
   503: dac z
   504: jmp subr i        ─→ Indirect jump to Memory[500]
```

### Subroutine Examples

**Example 1: Simple subroutine**
```assembly
" Main program
start:
   lac d5            " Load parameter
   dac param

   jms double        " Call subroutine
   " Result is in AC

   dac result        " Store result
   hlt

" Subroutine: double the parameter
double: 0            " Return address
   lac param         " Load parameter
   tad param         " Add it again (doubles it)
   jmp double i      " Return with result in AC

param: 0
result: 0
d5: 5
```

**Example 2: Subroutine with multiple calls**
```assembly
start:
   lac a
   dac param
   jms square        " square(a)
   dac result1

   lac b
   dac param
   jms square        " square(b)
   dac result2

   lac c
   dac param
   jms square        " square(c)
   dac result3

   hlt

" Subroutine: square a number (using repeated addition)
square: 0
   lac param         " Load n
   dac count         " Use as counter
   cla               " result = 0
   dac result

   lac count         " Check for negative
   sma
   jmp sq_loop       " Positive, continue

   dzm result        " Negative not supported, return 0
   jmp square i

sq_loop:
   lac result
   tad param         " Add param to result
   dac result

   isz count         " Done?
   lac count
   sza
   jmp sq_loop

   lac result        " Load result into AC
   jmp square i      " Return

param: 0
count: 0
result: 0
result1: 0
result2: 0
result3: 0
a: 5
b: 7
c: 10
```

**Example 3: Recursive subroutine (advanced)**

Recursion requires a stack to save return addresses:

```assembly
" Factorial (simplified, no stack for clarity)
" factorial(n) = n * factorial(n-1), base case: factorial(0) = 1

start:
   lac d5            " Calculate factorial(5)
   dac n
   jms factorial
   dac result        " Result in AC
   hlt

factorial: 0
   lac n             " Load n
   sza               " If n = 0
   jmp fact_recurse

   " Base case: return 1
   lac d1
   jmp factorial i

fact_recurse:
   " Recursive case: n * factorial(n-1)
   " (This is simplified; real recursion needs stack)
   lac n
   tad dm1           " n - 1
   dac n             " Update n (WRONG for real recursion!)

   jms factorial     " factorial(n-1)

   " Multiply result by n
   " (Multiplication code omitted for brevity)

   jmp factorial i

n: 0
result: 0
d1: 1
d5: 5
dm1: -1
```

**Note:** Real recursion requires saving return addresses and local variables on a stack. Unix doesn't use much recursion due to memory constraints.

---

## 5. Data Structures

Assembly language has no built-in data types. Everything is an 18-bit word. You create structure through convention and careful programming.

### Constants

Define constants with simple labels:

```assembly
" Decimal constants (common values)
d0: 0
d1: 1
d2: 2
d8: 8
d10: 10
d64: 64

" Octal constants (bit patterns)
o7: 07               " Octal 7 = binary 111
o177: 0177           " ASCII mask (7 bits)
o777: 0777           " 9-bit mask

" Negative constants
dm1: -1              " 777777 octal
dm2: -2              " 777776 octal
```

**Why not use literals?**

The PDP-7 has no immediate addressing mode. You can't write:
```assembly
   lac 42            " ERROR: This loads from address 42!
```

You must load from memory:
```assembly
   lac d42           " Correct: loads value 42 from location d42
d42: 42
```

### Single-Word Variables

Reserve storage with labels:

```assembly
" Uninitialized variables
count: 0
sum: 0
result: 0

" Initialized variables
total: 100
limit: 1000
flag: -1

" Character variables
char: 0              " Will hold a 9-bit character
newline: 012         " Line feed character (octal 12 = decimal 10)
```

### Arrays (Sequential Storage)

Arrays are consecutive memory locations:

```assembly
" Method 1: Explicit initialization
scores: 95; 87; 92; 78; 88

" Method 2: Reserve uninitialized space
buffer: .=.+64       " Reserve 64 words (all zero)

" Method 3: Mixed
data: 1; 2; 3; 4     " First 4 elements initialized
      .=.+96         " Next 96 elements reserved
```

**The `.=.+n` directive:**

`.` is the location counter (current assembly address). `.=.+n` means "increment location counter by n", effectively reserving n words.

**Accessing arrays:**

```assembly
" Method 1: Direct indexing (inefficient)
   lac array         " array[0]
   lac array+1       " array[1]
   lac array+2       " array[2]

" Method 2: Computed address (complex)
   law array         " Base address
   tad index         " Add index
   dac temp
   lac temp i        " Load element

" Method 3: Auto-increment (efficient!)
   law array-1
   dac 8
   lac 8 i           " array[0], pointer advances
   lac 8 i           " array[1], pointer advances
   lac 8 i           " array[2], pointer advances
```

**Multi-dimensional arrays:**

```assembly
" 2D array: 10 rows × 5 columns = 50 elements
" Stored row-major: [0][0], [0][1], ..., [0][4], [1][0], ...

matrix: .=.+50       " 10×5 = 50 words

" Access matrix[row][col]
" Address = base + (row × 5) + col

" Example: Access matrix[3][2]
   lac d3            " row = 3
   tad d3            " ×2
   tad d3            " ×3
   tad d3            " ×4
   tad d3            " ×5 (row × columns)
   tad d2            " + col (2)
   tad matrix_addr   " + base address
   dac temp
   lac temp i        " Load matrix[3][2]

matrix_addr: matrix
d2: 2
d3: 3
temp: 0
```

### Structures (Grouped Data)

Group related data:

```assembly
" Structure: File descriptor
" Fields: fd.fileno, fd.mode, fd.position

file1:
   fd1.fileno: 3     " File number
   fd1.mode: 1       " Mode (0=read, 1=write)
   fd1.position: 0   " Current position

file2:
   fd2.fileno: 5
   fd2.mode: 0
   fd2.position: 1024

" Access structure fields
   lac fd1.fileno    " Load file number
   lac fd1.mode      " Load mode
```

**Structure arrays:**

```assembly
" Array of file descriptors (3 words each)
" 10 files × 3 words = 30 words

files: .=.+30        " Reserve space

" Access file[i].field
" Address = files + (i × 3) + field_offset

" Field offsets
.fileno = 0
.mode = 1
.position = 2

" Access file[3].position
   lac d3            " File index
   tad d3            " ×2
   tad d3            " ×3 (i × structure_size)
   tad .position     " + field offset (2)
   law files         " + base
   tad temp          " ...
   " (Complex addressing needed)
```

**Better: Define structure template**

```assembly
" Template for file descriptor structure
.define filestruct
   filestruct.fileno: 0
   filestruct.mode: 0
   filestruct.position: 0
.enddef

" Create instances
file1:
   0; 0; 0           " Fields initialized to 0

file2:
   3; 1; 0           " fileno=3, mode=1, position=0

" Access with offsets
   law file1         " Load structure address
   tad d1            " + offset for 'mode' field
   dac temp
   lac temp i        " Load mode field
```

### Character Strings (Packed)

The PDP-7 packs 2 characters per word (each character is 9 bits):

```
Word structure (18 bits):
┌─────────┬─────────┐
│  Char1  │  Char2  │
│ (bits   │ (bits   │
│ 17-9)   │  8-0)   │
└─────────┴─────────┘
```

**Defining strings:**

```assembly
" String "HELLO" (5 chars = 3 words)
" Pairs: 'H''E', 'L''L', 'O''\0'

msg: 0510; 0514; 0517; 00   " 'HE', 'LL', 'O\0'

" Or use assembler syntax (if supported)
msg: "Hello\0"     " Assembler packs automatically
```

**Character encoding (9-bit ASCII):**

```
Character   Octal   Binary (9-bit)
──────────────────────────────────
'A'         0101    001 000 001
'H'         0510    101 001 000
'E'         0505    101 000 101
'L'         0514    101 001 100
'O'         0517    101 001 111
' '         040     000 100 000
'\n'        012     000 001 010
'\0'        000     000 000 000
```

**Extracting characters:**

```assembly
" Extract left character (bits 17-9)
   lac word          " Load packed word
   lrss 9            " Logical right shift 9 bits
   and o777          " Mask to 9 bits (optional)

" Extract right character (bits 8-0)
   lac word          " Load packed word
   and o777          " Mask to lower 9 bits

o777: 0777           " 9-bit mask
word: 0510           " 'HE'
```

**String processing example:**

```assembly
" Count characters in null-terminated string

   law string-1      " Setup pointer
   dac 8

   cla               " count = 0
   dac count

loop:
   lac 8 i           " Get next word (2 chars)
   dac word          " Save it

   " Check left character
   lrss 9            " Get high char
   and o777          " Mask
   sza               " If zero, done
   jmp count_left

   " Left char is null, done
   jmp done

count_left:
   lac count         " count++
   tad d1
   dac count

   " Check right character
   lac word          " Reload word
   and o777          " Get low char
   sza               " If zero, done
   jmp count_right

   " Right char is null, done
   jmp done

count_right:
   lac count         " count++
   tad d1
   dac count

   jmp loop          " Next word

done:
   hlt               " Result in count

string: 0510; 0514; 0517; 0  " "HELLO" (5 chars)
count: 0
word: 0
o777: 0777
d1: 1
```

### Linked Lists (Advanced)

While uncommon due to memory constraints, linked lists are possible:

```assembly
" Node structure:
" .data (1 word)
" .next (1 word - pointer to next node)

" List: 10 → 20 → 30 → NULL

node1:
   10                " data
   node2             " next pointer

node2:
   20                " data
   node3             " next pointer

node3:
   30                " data
   0                 " next = NULL

" Traverse list
   law node1         " Start at head
   dac ptr

traverse:
   lac ptr           " Load current pointer
   sza               " If NULL, done
   jmp process_node

   hlt               " Done

process_node:
   dac temp          " Save pointer
   lac temp i        " Load data field
   " ... process data ...

   " Advance to next node
   lac temp          " Reload pointer
   tad d1            " + 1 (offset to next field)
   dac temp
   lac temp i        " Load next pointer
   dac ptr           " Update ptr

   jmp traverse      " Continue

ptr: 0
temp: 0
d1: 1
```

---

## 6. Advanced Techniques

Now that you understand the basics, let's explore sophisticated programming techniques used in Unix.

### Multi-Precision Arithmetic

The PDP-7's 18-bit words are sometimes insufficient. Unix uses **double-precision (36-bit)** arithmetic for file sizes and time values.

**36-bit number representation:**
```
High word (18 bits)    Low word (18 bits)
┌──────────────────┬──────────────────┐
│  Bits 35-18      │  Bits 17-0       │
└──────────────────┴──────────────────┘

Example: 1000000 (decimal)
High: 000003    (3 × 2^18 = 786432)
Low:  0105100   (35136)
Total: 786432 + 35136 = 821568... wait, that's wrong!

Correct calculation:
1000000 decimal = 03641100 octal = 0364 1100 (36 bits)
Split: High = 000003 (upper 18 bits), Low = 0641100 (lower 18 bits)
```

**36-bit addition:**

```assembly
" Add two 36-bit numbers: (high1,low1) + (high2,low2)

   " Add low words first
   lac low1          " Load low word of first number
   tad low2          " Add low word of second number
                     " Link receives carry out
   dac result_low    " Store low word of result

   " Add high words with carry
   lac high1         " Load high word of first number
   tad high2         " Add high word of second number
                     " Link from previous add is carry in!
   dac result_high   " Store high word of result

" Example: 100000 + 50000 = 150000
" 100000 octal = 000000 + 0303240 (high=0, low=0303240)
" 50000 octal  = 000000 + 0141510 (high=0, low=0141510)

high1: 0
low1: 0303240
high2: 0
low2: 0141510
result_high: 0       " Will be 0
result_low: 0        " Will be 0444750 (150000 octal)
```

**Why the Link carries:**

```
Step 1: Add low words
   low1 = 0303240
   low2 = 0141510
   sum  = 0444750 (no carry, Link = 0)

Step 2: Add high words
   high1 = 0
   high2 = 0
   Link  = 0 (carry from previous)
   sum   = 0 + 0 + 0 = 0
```

**Example with carry:**

```assembly
" 500000 + 500000 = 1000000
" 500000 octal = 001 + 0731100
" (High = 1, Low = 0731100 — wait, that's wrong too!)

" Let me recalculate:
" 500000 decimal = 0x7A120 hex = 1750440 octal
" High 18 bits: 001
" Low 18 bits:  0731100... no, still wrong.

" The issue is I'm confusing decimal and octal. Let me be clear:

" 500000 DECIMAL = 1750440 OCTAL
" Split into 18-bit words:
" 001 750440 (too long!)
" Actually: 1750440 octal = 18 bits? No, that's 19+ bits.

" Ah! 500000 decimal doesn't fit in 18 bits.
" Max 18-bit value = 2^18 - 1 = 262143 decimal

" Better example: Add 200000 + 150000 (decimal)

" First convert to octal:
" 200000 dec = 605620 octal (18-bit, fits)
" 150000 dec = 444750 octal (18-bit, fits)
" Sum = 350000 dec = 1252370 octal (19-bit, needs 2 words!)

" 1252370 octal in 36-bit:
" High: 000001 (bit 18)
" Low:  0252370 (bits 17-0)

   lac low1          " 0605620
   tad low2          " + 0444750 = 1252370
                     " Result: 0252370, Carry: Link = 1
   dac result_low    " 0252370

   lac high1         " 0
   tad high2         " + 0 = 0
                     " + Link (1) = 1
   dac result_high   " 1

low1: 0605620        " 200000 decimal
low2: 0444750        " 150000 decimal
high1: 0
high2: 0
result_high: 0       " Result: 1 (high word)
result_low: 0        " Result: 0252370 (low word)
                     " Together: 1,252370 octal = 350000 decimal
```

**36-bit comparison:**

```assembly
" Compare (high1,low1) with (high2,low2)
" Return: AC < 0 if less, 0 if equal, > 0 if greater

   " Compare high words first
   lac high1
   tad neg_high2     " high1 - high2
   sza               " If not equal, done
   jmp done          " AC contains result

   " High words equal, compare low words
   lac low1
   tad neg_low2      " low1 - low2

done:
   " AC contains comparison result
   dac result

high1: 1
low1: 0100000
high2: 0
low2: 0777777
neg_high2: -0        " (Precomputed -high2)
neg_low2: -0777777   " (Precomputed -low2)
result: 0
```

### Multiplication by Shifting

The PDP-7 has multiply/divide instructions, but shifting is often more efficient for powers of 2:

**Multiply by 2 (shift left 1):**

```assembly
   lac value         " Load value
   cll               " Clear Link
   als 1             " Arithmetic Left Shift 1 bit
   dac result        " Result = value × 2

value: 100           " Decimal 64
result: 0            " Will be 200 (decimal 128)
```

**Multiply by 8 (shift left 3):**

```assembly
   lac value         " Load value
   cll               " Clear Link
   als 3             " Shift left 3 bits
   dac result        " Result = value × 8

value: 10            " Decimal 8
result: 0            " Will be 100 (decimal 64)
```

**Divide by 2 (shift right 1):**

```assembly
   lac value         " Load value
   cll               " Clear Link
   lrs 1             " Logical Right Shift 1 bit
   dac result        " Result = value ÷ 2

value: 100           " Decimal 64
result: 0            " Will be 40 (decimal 32)
```

**Why shifting is faster:**

```assembly
" Multiply by 8 using addition (slow)
   lac value
   tad value         " ×2
   tad value         " ×3
   tad value         " ×4
   tad value         " ×5
   tad value         " ×6
   tad value         " ×7
   tad value         " ×8
   " 8 instructions!

" Multiply by 8 using shift (fast)
   lac value
   cll
   als 3             " ×8
   " 3 instructions!
```

### Bit Manipulation

**Set specific bits:**

```assembly
" Set bit 5 in flags
   lac flags
   or bit5           " OR to set bit
   dac flags

flags: 0
bit5: 040            " Octal 40 = binary 000000000000100000 (bit 5)
```

**Clear specific bits:**

```assembly
" Clear bit 5 in flags
   lac flags
   and not_bit5      " AND to clear bit
   dac flags

flags: 077
not_bit5: 777737     " All bits except bit 5 (complement of 040)
```

**Toggle specific bits:**

```assembly
" Toggle bit 5 in flags
   lac flags
   xor bit5          " XOR to toggle
   dac flags

flags: 040
bit5: 040            " Result: flags becomes 0 (toggle off)
```

**Test specific bit:**

```assembly
" Test if bit 5 is set
   lac flags
   and bit5          " Mask to bit 5
   sza               " Skip if zero (bit not set)
   jmp bit_set       " Bit is set

bit_clear:
   " Bit 5 is clear
   jmp continue

bit_set:
   " Bit 5 is set

continue:
   " ...

flags: 077
bit5: 040
```

**Extract bit field:**

```assembly
" Extract bits 9-6 from value (4-bit field)

   lac value         " Load value
   lrss 6            " Shift right 6 bits
   and o17           " Mask to 4 bits (binary 1111)
   dac field         " Result is bits 9-6

value: 07654         " Binary: 111 110 101 100
                     " Bits 9-6: 1010 = octal 12
field: 0             " Will be 012

o17: 017             " Mask: 000000000000001111
```

**Pack bit fields:**

```assembly
" Pack two 8-bit values into one word

   lac value1        " Load first value (8 bits)
   cll
   als 8             " Shift left 8 bits
   or value2         " OR with second value
   dac packed        " Result: value1 in bits 15-8, value2 in bits 7-0

value1: 0123         " 8-bit value (bits 7-0)
value2: 0456         " 8-bit value (bits 7-0)
packed: 0            " Will be 0123456 (concatenated)
```

### Rotate Operations

**RAL/RAR (Rotate AC Left/Right):**

```assembly
" Rotate AC left (19-bit rotate: Link + AC)
   lac value         " Load 000123
   cll               " Link = 0
   ral               " Rotate left
                     " Before: Link=0, AC=000123 (binary: 0 001010011)
                     " After:  Link=0, AC=000246 (binary: 0 010100110)

" Rotate AC right
   lac value         " Load 000246
   cll               " Link = 0
   rar               " Rotate right
                     " Result: Link=0, AC=000123

value: 000123
```

**RCL/RCR (Rotate Combined Left/Right):**

```assembly
" Rotate 19 bits (Link + AC) left
   lac value         " Load value
   stl               " Set Link to 1
   rcl               " Rotate combined left
                     " Rotates all 19 bits (Link + 18-bit AC)

" Rotate 19 bits right
   lac value
   cll               " Clear Link
   rcr               " Rotate combined right
```

**Practical use: Test high bit**

```assembly
" Test if bit 17 (sign bit) is set

   lac value         " Load value
   ral               " Rotate left (bit 17 → Link)
   snl               " Skip if Link Not set
   jmp positive      " Bit 17 was 0 (positive)

negative:
   " Bit 17 was 1 (negative)
   jmp continue

positive:
   " Bit 17 was 0 (positive)

continue:
   " ...

value: 777777        " Negative (-1)
```

### Optimized Character Handling

**Extract character from packed word:**

From Unix source code (cat.s pattern):

```assembly
" Extract one character from packed word
" Two 9-bit chars per word: [char0][char1]
" ipt points to word, ipt bit 0 selects which char

   lac ipt           " Load pointer (includes char index in bit 0)
   ral               " Rotate left: bit 0 → Link
   lac ipt i         " Load word from buffer
   szl               " Skip if Link = 0 (even char, left char)
   lrss 9            " Odd char: shift right 9 bits
   and o177          " Mask to 7-bit ASCII
   dac char          " Store character

   " Advance pointer to next character
   lac ipt
   tad half          " Add 0.5 (in fixed point: 0400000)
   dac ipt           " Next char (toggles bit 0, carries to bit 1)

ipt: buffer          " Pointer to packed buffer
char: 0
o177: 0177           " 7-bit ASCII mask
half: 0400000        " Half-word increment
buffer: 0
```

This elegant code uses bit 0 of the pointer to track odd/even characters!

### Loop Unrolling for Performance

**Standard loop (5 iterations):**

```assembly
   -5
   dac count
loop:
   " ... body (assume 10 instructions) ...
   isz count         " 1 instruction
   jmp loop          " 1 instruction
   " Total: 5 × (10 + 2) = 60 instructions executed
```

**Unrolled loop (no loop overhead):**

```assembly
   " ... body (10 instructions) ...
   " ... body (10 instructions) ...
   " ... body (10 instructions) ...
   " ... body (10 instructions) ...
   " ... body (10 instructions) ...
   " Total: 5 × 10 = 50 instructions executed
   " Savings: 10 instructions (16% faster!)
```

Unrolling trades code size for speed—worthwhile for tight inner loops.

---

## 7. The Unix Assembler

The assembler (`as.s`) is a remarkably compact two-pass assembler that assembles itself—a bootstrap marvel.

### Two-Pass Assembly Process

**Pass 1: Build Symbol Table**

1. **Read source file** line by line
2. **Track location counter** (current assembly address)
3. **Record labels** and their addresses in symbol table
4. **Handle directives** (`.=`, `.=.+n`)
5. **Don't generate code** yet (just scan)

**Pass 2: Generate Code**

1. **Re-read source file** from beginning
2. **Look up symbols** in symbol table (built in Pass 1)
3. **Evaluate expressions** (e.g., `array+10`)
4. **Generate machine code** with resolved addresses
5. **Write output** to object file

**Why two passes?**

Forward references require two passes:

```assembly
   jmp forward       " Pass 1: Don't know address of 'forward' yet
                     " Pass 2: Look up 'forward' in symbol table

   " ... more code ...

forward:             " Pass 1: Record this address in symbol table
   lac value
```

### Symbol Table

The symbol table maps names to addresses:

```
Symbol Table (after Pass 1):
┌─────────────┬─────────┐
│  Symbol     │ Address │
├─────────────┼─────────┤
│  start      │  0000   │
│  loop       │  0012   │
│  count      │  0034   │
│  value      │  0035   │
│  d1         │  0036   │
└─────────────┴─────────┘
```

**Symbol types:**

- **Labels** - Code locations (e.g., `loop:`)
- **Variables** - Data locations (e.g., `count: 0`)
- **Constants** - Defined values (e.g., `maxsize = 100`)
- **Global symbols** - Exported to linker
- **Local symbols** - Numeric labels (1:, 2:, etc.)

### Forward and Backward References

**Backward reference** (already defined):

```assembly
loop:                " Defined here (address known)
   lac count
   isz count
   jmp loop          " Backward ref: address already in symbol table
```

**Forward reference** (not yet defined):

```assembly
   jmp done          " Forward ref: address unknown in Pass 1
                     " Pass 2: look up 'done' in symbol table

   " ... code ...

done:                " Defined here
   hlt
```

**Local labels** (numeric):

```assembly
   jmp 1f            " Forward ref to label '1'
1:
   lac value
   jmp 2f            " Forward ref to label '2'

1:                   " Reused label '1' (local scope)
   dac result
   jmp 1b            " Backward ref to previous '1'

2:
   hlt
```

- `1f` = forward reference to next label `1:`
- `1b` = backward reference to previous label `1:`

This allows reusing simple numeric labels without conflict.

### Expression Evaluation

The assembler can evaluate arithmetic expressions:

```assembly
" Simple arithmetic
   lac array+5       " Address of array plus 5
   lac buffer+64     " 64 words beyond buffer
   law value-1       " One before value

" Constants
size = 100           " Define constant
   lac size          " Use constant (assembler substitutes 100)

" Complex expressions
   lac array+(size*2)    " array + (size × 2)
   law buffer+(size-1)   " buffer + (size - 1)
```

**Expression operators:**

- `+` - Addition
- `-` - Subtraction
- `*` - Multiplication
- `/` - Division
- `&` - Bitwise AND
- `|` - Bitwise OR (some assemblers)

**Evaluation rules:**

- Constants and symbols are operands
- Standard operator precedence (* / before + -)
- Parentheses for grouping
- All arithmetic is 18-bit

### Assembler Directives

**Location counter assignment:**

```assembly
   .=1000            " Set location counter to 1000 (octal)
                     " Next instruction assembles at 1000

   .=.+10            " Advance location counter by 10
                     " Reserve 10 words
```

**Constant definition:**

```assembly
size = 100           " Define size as 100
mask = 0177          " Define mask as octal 177
```

**String and data:**

```assembly
msg: "Hello\0"       " String (packed, 2 chars/word)
data: 1; 2; 3; 4     " Array of values
buffer: .=.+64       " Reserve 64 words (uninitialized)
```

### Code from as.s

The assembler's core loop (simplified):

```assembly
" Pass 1: Build symbol table
pass1:
   " Read line from source
   jms getline

   " Check for label (ends with ':')
   jms checklabel
   sza
   jms addlabel      " Add to symbol table with current location

   " Process instruction/directive
   jms parseline     " Parse mnemonic and operands

   " Update location counter
   lac location
   tad d1            " location++
   dac location

   " Check for end of file
   lac eof_flag
   sza
   jms pass1         " Continue Pass 1

   " Start Pass 2
   jms pass2
```

**Symbol table lookup:**

```assembly
" lookup: Find symbol in table
" Input: symbol name in AC
" Output: AC = address (or -1 if not found)

lookup: 0
   dac symbol_name   " Save symbol

   law symtab-1      " Point to symbol table
   dac 8

   lac symtab_count  " Number of entries
   dac count

lkloop:
   lac 8 i           " Get next symbol entry
   sad symbol_name   " Compare to search name
   jmp found         " Match!

   lac 8 i           " Skip address field
   isz count         " Continue?
   jmp lkloop

   " Not found
   lac dm1           " Return -1
   jmp lookup i

found:
   lac 8 i           " Load address
   jmp lookup i      " Return

symbol_name: 0
symtab: .=.+1000     " Symbol table (500 entries max)
symtab_count: 0
count: 0
dm1: -1
```

### Macro Expansion (sys)

The `sys` pseudo-op generates system call sequences:

```assembly
" Source code:
sys read; 3; buffer; 64

" Expands to:
   jms 020           " System call trap
   4                 " Read syscall number
   3                 " File descriptor
   buffer            " Buffer address
   64                " Count
```

The assembler recognizes `sys` and expands it during assembly.

### Linking Multiple Files

The assembler can combine multiple source files:

```bash
as file1.s file2.s file3.s
```

**File1.s:**
```assembly
   jms subr          " Call subroutine in file2
   hlt

.globl subr          " Declare external symbol
```

**File2.s:**
```assembly
subr:                " Define subroutine
   lac value
   jmp subr i

.globl subr          " Export symbol
```

The assembler resolves cross-file references during linking.

---

## 8. Calling Conventions

For code to interoperate, programs must follow conventions for subroutine calls.

### Parameter Passing

**Method 1: Global variables (simplest)**

```assembly
" Caller
   lac arg1_val      " Set up arguments
   dac param1
   lac arg2_val
   dac param2

   jms multiply      " Call function

   lac result        " Get result
   dac answer

" Callee
multiply: 0
   lac param1
   " ... multiply param1 * param2 ...
   dac result
   jmp multiply i

param1: 0
param2: 0
result: 0
```

**Method 2: Inline arguments (more flexible)**

```assembly
" Caller
   jms multiply
   arg1_val          " Arguments follow call
   arg2_val
   " Execution resumes here with result in AC

" Callee
multiply: 0
   lac multiply i    " Load return address
   dac ret_addr      " Save it

   lac ret_addr i    " Load first argument
   isz ret_addr      " Advance return address
   dac param1

   lac ret_addr i    " Load second argument
   isz ret_addr      " Advance return address
   dac param2

   " ... compute result in AC ...

   lac ret_addr      " Load return address
   jmp multiply i    " Return (indirect through multiply)

ret_addr: 0
param1: 0
param2: 0
```

**Method 3: AC and MQ registers**

```assembly
" Caller
   lac arg1          " First argument in AC
   lmq               " Second argument in MQ (or save AC, load arg2)
   jms function
   " Result in AC

" Callee
function: 0
   dac param1        " Save AC (arg1)
   lacq              " Load MQ
   dac param2        " Save MQ (arg2)

   " ... compute ...
   " Put result in AC

   jmp function i

param1: 0
param2: 0
```

### Return Values

**Return value in AC:**

```assembly
" Function
square: 0
   lac param
   " ... square the value ...
   " Leave result in AC
   jmp square i      " Return with result in AC

" Caller
   jms square
   dac result        " Save return value from AC
```

**Return value in memory:**

```assembly
" Function
process: 0
   " ... computation ...
   dac result        " Store result
   jmp process i

" Caller
   jms process
   lac result        " Load result from memory
```

**Multiple return values (AC + MQ):**

```assembly
" Function returns quotient in AC, remainder in MQ
divide: 0
   lac dividend
   " ... division algorithm ...
   " Quotient in AC
   " Remainder in MQ
   lmq               " Store remainder in MQ
   jmp divide i

" Caller
   jms divide
   dac quotient      " Save AC (quotient)
   lacq              " Load MQ
   dac remainder     " Save MQ (remainder)
```

### Register Usage Conventions

Unix code follows these conventions:

**Caller-saved registers:**
- **AC** - Accumulator (caller must save if needed after call)
- **MQ** - Multiplier-Quotient (caller must save)
- **Link** - Carry/borrow bit (caller must save)

**Callee-saved registers:**
- **Auto-increment registers (8-15)** - Callee should preserve if used

**Example: Saving registers**

```assembly
" Caller saves AC
   lac important     " Value we need after call
   dac saved_ac      " Save it

   jms function      " Call may destroy AC

   lac saved_ac      " Restore AC
   dac result        " Use saved value

saved_ac: 0
```

**Callee saves registers:**

```assembly
function: 0
   " Save registers we'll use
   lac 8             " Save R8
   dac saved_r8
   lac 9             " Save R9
   dac saved_r9

   " ... use R8 and R9 ...

   " Restore registers
   lac saved_r8
   dac 8
   lac saved_r9
   dac 9

   jmp function i

saved_r8: 0
saved_r9: 0
```

### Library Function Example

From Unix: `betwen` (check if value is between bounds)

```assembly
" betwen: Check if value is in range [low, high]
" Call: jms betwen; value; low; high
" Return: AC = 0 if in range, -1 if out of range

betwen: 0
   lac betwen i      " Load return address
   dac ret
   isz ret           " Skip to first arg

   lac ret i         " Load value
   isz ret
   dac value

   lac ret i         " Load low
   isz ret
   dac low

   lac ret i         " Load high
   isz ret
   dac high_val

   " Check if value < low
   lac value
   tad neg_low       " value - low
   sma               " Skip if negative
   jmp check_high

   " value < low, out of range
   lac dm1
   jmp betwen_ret

check_high:
   " Check if value > high
   lac value
   tad neg_high      " value - high
   spa               " Skip if positive or zero
   jmp in_range

   " value > high, out of range
   lac dm1
   jmp betwen_ret

in_range:
   " In range
   cla

betwen_ret:
   lac ret
   dac betwen        " Update return address
   jmp betwen i      " Return

ret: 0
value: 0
low: 0
high_val: 0
neg_low: 0           " Precomputed -low
neg_high: 0          " Precomputed -high
dm1: -1
```

---

## 9. System Call Interface

User programs interact with the kernel through system calls.

### The sys Pseudo-Operation

The `sys` macro generates a system call:

```assembly
sys read; fd; buffer; count
```

**Expands to:**

```assembly
   jms 020           " Jump to system call trap (location 020)
   4                 " System call number (4 = read)
   fd                " Argument 1
   buffer            " Argument 2
   count             " Argument 3
```

**Location 020** is the system call trap vector. All system calls enter the kernel here.

### System Call Conventions

**Entry:**
1. User executes `jms 020`
2. Return address (next instruction) stored at location 020
3. PC jumps to 021 (kernel entry point)
4. Kernel saves user state
5. Kernel reads syscall number from return address
6. Kernel dispatches to appropriate handler

**Exit:**
1. Kernel restores user state
2. Kernel advances return address past arguments
3. Kernel returns to user code
4. AC contains return value

**Return values:**
- **Positive** - Success (e.g., byte count, file descriptor)
- **Zero** - Success (for operations with no data)
- **Negative** - Error (usually -1)

### Common System Calls

**File operations:**

```assembly
" open: Open file
" Call: sys open; filename; mode
" Return: AC = file descriptor (or -1 on error)

   sys open; filename; 0     " 0 = read mode
   sma                       " Skip if negative (error)
   jmp error
   dac fd                    " Save file descriptor

" read: Read from file
" Call: sys read; fd; buffer; count
" Return: AC = bytes read (or -1 on error)

   sys read; fd; buffer; 64
   sma
   jmp error
   dac bytes_read

" write: Write to file
" Call: sys write; fd; buffer; count
" Return: AC = bytes written

   sys write; fd; buffer; 64
   dac bytes_written

" close: Close file
" Call: sys close; fd
" Return: AC = 0 on success, -1 on error

   sys close; fd
```

**Process operations:**

```assembly
" fork: Create child process
" Call: sys fork
" Return: AC = 0 in child, child PID in parent

   sys fork
   sza                       " Skip if zero (child)
   jmp parent                " Non-zero: parent process

child:
   " This is the child process
   " AC = 0
   jmp continue

parent:
   " This is the parent process
   " AC = child PID
   dac child_pid

continue:
   " ...

" exit: Terminate process
" Call: sys exit
" Return: Never returns

   sys exit                  " Process terminates

" getuid: Get user ID
" Call: sys getuid
" Return: AC = user ID (negative if superuser)

   sys getuid
   dac uid
```

### Error Handling

Check for errors after every system call:

```assembly
" Pattern 1: Check for negative (error)
   sys open; filename; 0
   sma                       " Skip if minus (error)
   jmp error_handler         " Handle error
   dac fd                    " Success, save fd

" Pattern 2: Check for specific error
   sys read; fd; buffer; 100
   tad dm1                   " Add -1
   sza                       " If AC was -1, now 0
   jmp success

error:
   " Handle error (read returned -1)
   jmp continue

success:
   " Process data

continue:
   " ...
```

**Common error patterns:**

```assembly
" open failed: file not found
   sys open; filename; 0
   sma
   jmp file_not_found

" read failed: I/O error or EOF
   sys read; fd; buffer; count
   sma
   jmp read_error

" write failed: disk full or permission denied
   sys write; fd; buffer; count
   sad count                 " Check if bytes_written = count
   skp
   jmp incomplete_write      " Didn't write all bytes
```

### Complete System Call Example

```assembly
" Program: Copy file to output
" Usage: Reads from file descriptor 3, writes to fd 1 (stdout)

start:
   " Open input file
   sys open; infile; 0       " Mode 0 = read
   sma                       " Error?
   jmp open_error
   dac in_fd                 " Save file descriptor

read_loop:
   " Read block
   sys read; in_fd; buffer; 64
   sma                       " Error?
   jmp read_error
   sza                       " EOF (0 bytes)?
   jmp got_data
   jmp done                  " EOF, exit

got_data:
   dac byte_count            " Save count

   " Write block
   sys write; d1; buffer; byte_count
   sma                       " Error?
   jmp write_error

   jmp read_loop             " Continue

done:
   sys close; in_fd
   sys exit                  " Terminate

open_error:
   " Handle open error
   sys exit

read_error:
   " Handle read error
   sys exit

write_error:
   " Handle write error
   sys exit

" Data
infile: "input\0"
buffer: .=.+64               " 64-word buffer
in_fd: 0
byte_count: 0
d1: 1                        " stdout file descriptor
```

---

## 10. Complete Programs

Let's build complete, working programs that demonstrate everything you've learned.

### Program 1: Character Counter

Count characters in a file:

```assembly
" charcount: Count characters read from stdin
" Usage: charcount < file

start:
   " Initialize counter
   cla
   dac count
   dac count_high            " 36-bit counter

read_loop:
   " Read one block
   sys read; 0; buffer; 64
   sma                       " Error?
   jmp error
   sza                       " EOF?
   jmp got_data
   jmp done                  " EOF, print result

got_data:
   " AC contains byte count for this block
   dac nread

   " Add to total count (36-bit addition)
   lac count                 " Low word
   tad nread
   dac count

   lac count_high            " High word (with carry)
   tad d0                    " Add 0 + carry from Link
   dac count_high

   jmp read_loop             " Continue reading

done:
   " Print result (simplified: just halt with count in memory)
   " Real version would convert to decimal and print
   hlt

error:
   sys exit

" Data
buffer: .=.+64
count: 0                     " Character count (low word)
count_high: 0                " Character count (high word)
nread: 0
d0: 0
```

### Program 2: File Copier (cp)

Copy input file to output file:

```assembly
" cp: Copy standard input to standard output
" Usage: cp < input > output

start:
loop:
   " Read from stdin (fd 0)
   sys read; 0; buffer; 64
   sma                       " Error?
   jmp error
   sza                       " EOF?
   jmp got_data

   " EOF reached, exit
   sys exit

got_data:
   " AC = number of bytes read
   dac nread

   " Write to stdout (fd 1)
   sys write; 1; buffer; nread
   sma                       " Error?
   jmp error

   jmp loop                  " Continue

error:
   " Error occurred, exit
   sys exit

" Data
buffer: .=.+64               " I/O buffer (64 words)
nread: 0                     " Bytes read

" File descriptors (constants)
stdin = 0
stdout = 1
```

**Annotated version with comments:**

```assembly
" ========================================
" cp: Copy standard input to standard output
" ========================================
"
" This program reads data from file descriptor 0 (standard input)
" and writes it to file descriptor 1 (standard output).
" It continues until EOF is reached on input.
"
" Memory usage: ~70 words
" ========================================

start:
loop:
   " ─────────────────────────────────────
   " Read up to 64 words from stdin
   " ─────────────────────────────────────
   sys read; 0; buffer; 64
                        " System call #4: read
                        " Arg1: fd = 0 (stdin)
                        " Arg2: buffer address
                        " Arg3: count = 64 words
                        " Returns: AC = bytes read (or -1)

   sma                  " Skip if Minus (AC < 0)
                        " If AC >= 0, fall through
                        " If AC < 0, error occurred
   jmp error            " Handle read error

   sza                  " Skip if Zero (AC == 0)
                        " If AC != 0, fall through (data read)
                        " If AC == 0, EOF reached
   jmp got_data         " Process data

   " ─────────────────────────────────────
   " EOF: No more data, exit cleanly
   " ─────────────────────────────────────
   sys exit             " System call #14: exit
                        " Process terminates (no return)

got_data:
   " ─────────────────────────────────────
   " We read some data (AC = byte count)
   " Save count and write to stdout
   " ─────────────────────────────────────
   dac nread            " Store byte count for write

   sys write; 1; buffer; nread
                        " System call #5: write
                        " Arg1: fd = 1 (stdout)
                        " Arg2: buffer address
                        " Arg3: nread (count from read)
                        " Returns: AC = bytes written

   sma                  " Check for write error
   jmp error            " Handle write error

   jmp loop             " Continue reading/writing

error:
   " ─────────────────────────────────────
   " I/O error: exit immediately
   " ─────────────────────────────────────
   sys exit             " Terminate with error

" ========================================
" Data Area
" ========================================

buffer: .=.+64          " I/O buffer
                        " Reserve 64 words (128 bytes)
                        " Shared for both read and write

nread: 0                " Number of bytes read
                        " Saved from read syscall
                        " Used as count for write

" ========================================
" Constants (could be defined but not needed here
" since we use literal fd numbers 0 and 1)
" ========================================
```

### Program 3: Line Counter (wc -l)

Count lines in input:

```assembly
" linecount: Count newline characters in input
" Usage: linecount < file

start:
   " Initialize line counter
   cla
   dac line_count

read_loop:
   " Read block
   sys read; 0; buffer; 64
   sma
   jmp error
   sza
   jmp got_data
   jmp done              " EOF

got_data:
   dac nread             " Save byte count

   " Setup pointer to scan buffer
   law buffer-1
   dac 8

   lac nread             " Loop count = nread
   dac temp
   cla
   tad temp              " Negate for countdown
   dac count

scan_loop:
   " Get next word (2 chars)
   lac 8 i               " Auto-increment pointer
   dac word              " Save word

   " Check left character (bits 17-9)
   lrss 9                " Shift right 9 bits
   and o777              " Mask to 9 bits
   sad newline           " Is it newline?
   jmp found_nl_left

   " Check right character (bits 8-0)
   lac word
   and o777              " Mask to 9 bits
   sad newline           " Is it newline?
   jmp found_nl_right

   jmp next_word

found_nl_left:
   lac line_count
   tad d1
   dac line_count
   jmp check_right       " Still need to check right char

found_nl_right:
   lac line_count
   tad d1
   dac line_count

check_right:
   " Check if we need to check right char
   " (Only if we didn't already via found_nl_left)

next_word:
   isz count             " More words?
   jmp scan_loop

   jmp read_loop         " Read next block

done:
   " Print line count (simplified: just halt)
   " Real implementation would convert to decimal and print
   hlt

error:
   sys exit

" Data
buffer: .=.+64
line_count: 0
nread: 0
word: 0
count: 0
temp: 0
newline: 012             " Newline character (octal 12 = decimal 10)
o777: 0777               " 9-bit mask
d1: 1
```

### Program 4: Simple grep (Search)

Find lines containing a pattern:

```assembly
" search: Find lines containing "error"
" Usage: search < file

start:
   " Initialize
   cla
   dac match_count

read_loop:
   " Read line
   jms readline          " Read one line into line_buf
   sma                   " Error or EOF?
   jmp check_line
   jmp done              " EOF or error

check_line:
   " Search for "error" in line
   jms search_pattern
   sza                   " Found?
   jmp found_match

   jmp read_loop         " No match, continue

found_match:
   " Write matching line
   sys write; 1; line_buf; line_len

   " Increment match count
   lac match_count
   tad d1
   dac match_count

   jmp read_loop

done:
   " Print count and exit
   hlt

" ─────────────────────────────────────
" readline: Read one line into line_buf
" Return: AC = line length (or -1 on EOF/error)
" ─────────────────────────────────────
readline: 0
   cla
   dac line_len
   law line_buf-1
   dac 9

rl_loop:
   " Read one character
   sys read; 0; char_buf; 1
   sma
   jmp rl_error
   sza
   jmp rl_got_char
   jmp rl_eof

rl_got_char:
   lac char_buf
   dac 9 i               " Store in line buffer

   " Check for newline
   and o777              " Mask to character
   sad newline
   jmp rl_done           " End of line

   " Continue
   lac line_len
   tad d1
   dac line_len

   " Check buffer full
   lac line_len
   sad d100              " Max line length
   skp
   jmp rl_loop

   " Buffer full
   jmp rl_done

rl_done:
   lac line_len          " Return length
   jmp readline i

rl_eof:
   lac dm1               " Return -1
   jmp readline i

rl_error:
   lac dm1               " Return -1
   jmp readline i

" ─────────────────────────────────────
" search_pattern: Search for "error" in line_buf
" Return: AC = 0 if not found, 1 if found
" ─────────────────────────────────────
search_pattern: 0
   " Simplified: just check if 'e' is in line
   " Real implementation would do substring match

   law line_buf-1
   dac 8

   lac line_len
   dac count

sp_loop:
   lac 8 i
   and o777              " Mask to character
   sad char_e            " Is it 'e'?
   jmp sp_found

   isz count
   jmp sp_loop

   " Not found
   cla
   jmp search_pattern i

sp_found:
   lac d1                " Return 1
   jmp search_pattern i

" Data
line_buf: .=.+100        " Line buffer (max 100 chars)
char_buf: 0              " Single char buffer
line_len: 0
match_count: 0
count: 0
newline: 012
o777: 0777
char_e: 0145             " Character 'e' (octal 145)
d1: 1
d100: 100
dm1: -1
```

---

## 11. Debugging Assembly Code

Debugging assembly is challenging but systematic. Unix provides the `db.s` debugger.

### Using db.s (The Debugger)

The PDP-7 Unix debugger allows you to:

- **Examine memory** - Display contents of memory locations
- **Set breakpoints** - Stop execution at specific addresses
- **Single-step** - Execute one instruction at a time
- **Modify memory** - Change values while debugging
- **Display registers** - Show AC, MQ, Link, PC

**Basic db commands:**

```
100/          " Display location 100 (octal)
100:value     " Set location 100 to value
AC/           " Display AC
PC/           " Display PC
100;          " Set breakpoint at 100
proceed       " Continue execution
step          " Execute one instruction
```

### Reading Core Dumps

When a program crashes, Unix can dump memory to a file:

```
Core dump structure:
┌──────────────┐
│ User data    │  Process state (AC, MQ, etc.)
├──────────────┤
│ Program      │  Code memory
│ memory       │
├──────────────┤
│ Data area    │  Variables and buffers
└──────────────┘
```

**Analyzing a crash:**

1. **Find PC value** - Where did it crash?
2. **Examine instruction** - What was executing?
3. **Check AC, MQ** - What values were involved?
4. **Trace backwards** - What led to this state?

### Common Assembly Errors

**1. Uninitialized pointers:**

```assembly
" BUG: pointer not initialized
   lac 8 i           " R8 contains garbage!
                     " Accesses random memory
                     " CRASH or wrong data

" FIX: Initialize pointer
   law array-1
   dac 8             " Now R8 points to array
   lac 8 i           " Correct
```

**2. Infinite loops:**

```assembly
" BUG: Counter never reaches zero
   lac d10           " WRONG: Positive counter
   dac count

loop:
   " ... body ...
   isz count         " Increments: 10 → 11 → 12 → ...
                     " Never reaches 0!
   jmp loop          " INFINITE LOOP

" FIX: Use negative counter
   -10               " Correct: Negative counter
   dac count

loop:
   " ... body ...
   isz count         " -10 → -9 → ... → -1 → 0
   jmp loop          " Exits when count = 0
```

**3. Incorrect addressing mode:**

```assembly
" BUG: Forgot indirect
   law array
   dac ptr
   lac ptr           " WRONG: Loads address, not data

" FIX: Use indirect
   lac ptr i         " Correct: Loads data from address in ptr
```

**4. Register clobbering:**

```assembly
" BUG: Subroutine destroys R8
   law array-1
   dac 8             " Setup R8

   jms subr          " Call subroutine
                     " Subroutine uses R8 internally!

   lac 8 i           " WRONG: R8 was changed!

" FIX: Save and restore
subr: 0
   lac 8             " Save R8
   dac saved_r8

   " ... use R8 ...

   lac saved_r8      " Restore R8
   dac 8
   jmp subr i

saved_r8: 0
```

**5. Off-by-one errors:**

```assembly
" BUG: Loop executes wrong number of times
   -10
   dac count

loop:
   " ... body ...

   lac count
   tad d1            " WRONG: Manual increment
   dac count
   sza
   jmp loop          " Executes 11 times! (0-10)

" FIX: Use ISZ correctly
   -10
   dac count

loop:
   " ... body ...

   isz count         " Correct: Executes 10 times
   jmp loop
```

**6. Sign extension issues:**

```assembly
" BUG: Treating negative as positive
   lac value         " value = 777777 (-1)
   tad d1            " Add 1
                     " Result: 0 (correct)

   " But if you compare unsigned:
   lac value         " -1 (appears as 262143 unsigned!)
   sad d100          " Compare to 100
   " Incorrect comparison!

" FIX: Be aware of signed vs unsigned
```

### Debugging Strategies

**1. Add trace points:**

```assembly
" Insert at key points to trace execution

   lac checkpoint1
   tad d1
   dac checkpoint1   " Increment checkpoint counter

" Check checkpoint values in debugger
```

**2. Simplify:**

```assembly
" Instead of complex expression:
   lac array+(index*5)+offset

" Break into steps:
   lac index
   tad index         " ×2
   tad index         " ×3
   tad index         " ×4
   tad index         " ×5
   dac temp          " Save index×5

   law array
   tad temp
   tad offset
   " Now easier to debug step-by-step
```

**3. Instrument code:**

```assembly
" Save intermediate values for inspection

   lac result1
   dac debug1        " Save for debugging

   tad result2
   dac debug2        " Save intermediate sum

   tad result3
   dac final         " Final result

" Examine debug1, debug2 in debugger
```

**4. Test incrementally:**

```assembly
" Test each subroutine separately

start:
   " Test subr1
   jms test_subr1
   hlt

   " Test subr2
   jms test_subr2
   hlt

" Don't test everything at once!
```

---

## 12. Practical Tips and Best Practices

### Code Organization

**Group related code:**

```assembly
" ========================================
" String Utilities
" ========================================

strlen: 0
   " ... implementation ...

strcpy: 0
   " ... implementation ...

strcmp: 0
   " ... implementation ...

" ========================================
" Math Functions
" ========================================

multiply: 0
   " ... implementation ...

divide: 0
   " ... implementation ...
```

**Consistent naming:**

```assembly
" Constants: descriptive names
buffer_size = 64
max_files = 10

" Variables: brief but clear
file_count: 0
current_pos: 0

" Labels: verb or action
process_data:
check_error:
init_table:
```

### Performance Optimization

**Use auto-increment:**

```assembly
" Slow (7 instructions per iteration):
loop:
   lac ptr
   dac temp
   lac temp i
   " ... process ...
   lac ptr
   tad d1
   dac ptr

" Fast (2 instructions per iteration):
loop:
   lac 8 i
   " ... process ...
```

**Minimize memory accesses:**

```assembly
" Slow (loads from memory each time):
loop:
   lac count
   tad d1
   dac count
   lac count
   tad d1
   dac count

" Fast (keep in AC when possible):
loop:
   lac count
   tad d1            " count + 1
   tad d1            " count + 2
   dac count
```

**Use DZM instead of CLA + DAC:**

```assembly
" Slower:
   cla
   dac value

" Faster:
   dzm value
```

### Memory Conservation

**Reuse buffers:**

```assembly
" Instead of multiple buffers:
buffer1: .=.+64
buffer2: .=.+64
buffer3: .=.+64      " 192 words!

" Reuse single buffer:
buffer: .=.+64       " 64 words
" Use for different purposes at different times
```

**Pack data:**

```assembly
" Instead of separate flags:
flag1: 0
flag2: 0
flag3: 0
flag4: 0             " 4 words

" Use bit flags:
flags: 0             " 1 word, 18 bits available!
                     " Bit 0 = flag1
                     " Bit 1 = flag2
                     " etc.
```

### Documentation

**Comment thoroughly:**

```assembly
" ========================================
" Function: find_max
" Purpose: Find maximum value in array
" Input: Array address in R8, count in 'count'
" Output: Maximum value in AC
" Modifies: AC, R8, temp
" ========================================
find_max: 0
   " Initialize max to first element
   lac 8 i           " Get first element
   dac max           " Save as max so far

   " Loop through remaining elements
   -count
   dac loop_count

fm_loop:
   lac 8 i           " Get next element
   dac current       " Save it

   " Compare with current max
   lac max
   tad neg_current   " max - current
   spa               " Skip if positive or zero (max >= current)
   jmp fm_update     " Current > max, update

   jmp fm_continue   " max >= current, continue

fm_update:
   lac current       " Update max
   dac max

fm_continue:
   isz loop_count    " More elements?
   jmp fm_loop

   lac max           " Return max in AC
   jmp find_max i

max: 0
current: 0
neg_current: 0
loop_count: 0
```

---

## Summary

You've now learned PDP-7 assembly language from the ground up:

**Fundamentals:**
- Octal number system and why it's natural for 18-bit words
- Basic instructions (LAC, DAC, TAD, CLA)
- Addressing modes (direct, indirect, auto-increment)

**Control Flow:**
- Conditional execution with skip instructions
- Loops using ISZ and negative counters
- Subroutines with JMS

**Data Structures:**
- Variables, arrays, structures
- Character strings (packed 2 per word)
- Multi-precision arithmetic

**Advanced Techniques:**
- Bit manipulation and shifting
- Multiplication and division optimizations
- Performance tuning

**System Integration:**
- System calls via `sys` pseudo-op
- Calling conventions
- Error handling

**Complete Programs:**
- Character counter
- File copier
- Line counter
- Pattern searcher

**Debugging:**
- Using `db.s` debugger
- Common errors and fixes
- Debugging strategies

You're now ready to read and understand the PDP-7 Unix source code. The techniques you've learned here appear throughout the system—from the kernel to user utilities.

In the next chapter (Chapter 4), we'll explore the overall system architecture, showing how these assembly language programs combine to create a complete operating system.

**Practice exercises:**

1. Write a program to reverse an array in place
2. Implement a substring search function
3. Create a decimal-to-octal conversion utility
4. Write a simple calculator (add, subtract, multiply, divide)
5. Implement a bubble sort algorithm

The best way to learn assembly is to write code. Study the Unix sources, experiment with your own programs, and gradually build your understanding of this elegant, minimalist system.

---

*"The PDP-7 was not a very powerful machine, but it was big enough to build Unix."*
— Ken Thompson
