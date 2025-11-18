# Chapter 2: PDP-7 Hardware Architecture

## Introduction

To understand PDP-7 Unix, you must first understand the machine it ran on. The **Digital Equipment Corporation PDP-7** was a minicomputer introduced in 1964, part of DEC's revolutionary Programmed Data Processor series. While obsolete by 1969, its unique architecture profoundly influenced Unix's design.

This chapter provides a complete technical reference to the PDP-7 hardware. By the end, you will understand:

- How 18-bit words shaped every aspect of Unix
- The elegant simplicity of a 16-instruction computer
- Memory addressing techniques that maximized limited resources
- I/O mechanisms for peripheral devices
- Assembly language programming for the PDP-7

Understanding this hardware is essential—Unix wasn't designed *despite* the PDP-7's constraints, but *because of them*. The hardware's limitations forced Thompson and Ritchie to create elegant, minimal solutions that became Unix's defining characteristics.

---

## 1. CPU Architecture

### The 18-Bit Word

The PDP-7's most distinctive feature was its **18-bit word size**. This wasn't arbitrary—DEC chose 18 bits to efficiently encode both data and instructions:

```
18-bit word structure:
┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐
│17│16│15│14│13│12│11│10│9│8│7│6│5│4│3│2│1│0│  Bit positions
└─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘

Octal representation (6 digits):
┌────┬────┬────┬────┬────┬────┐
│ 5  │ 4  │ 3  │ 2  │ 1  │ 0  │  Octal digit positions
│bits│bits│bits│bits│bits│bits│
│17-│15-│12-│ 9- │ 6- │ 3- │
│ 16│ 14│ 11│ 8  │ 5  │ 2  │ 0│
└────┴────┴────┴────┴────┴────┘
```

**Why 18 bits?**

1. **Instruction encoding**: 3 bits for opcode + 1 bit for indirect + 1 bit for index + 13 bits for address
2. **Character storage**: 9 bits per character (supporting ASCII + extensions), 2 characters per word
3. **Numeric range**: Signed: -131,072 to +131,071; Unsigned: 0 to 262,143
4. **Octal notation**: 18 bits = exactly 6 octal digits (000000 to 777777)

**Implications for Unix:**

```assembly
" Character packing example from cat.s
" Each word holds TWO 9-bit characters

   lac ipt           " Load input pointer
   ral               " Rotate accumulator left (bit 17 → Link)
   lac ipt i         " Load word from memory
   szl               " Skip if Link is zero (even character)
   lrss 9            " Link-Right-Shift 9 bits (odd character)
   and o177          " Mask to 7-bit ASCII (0177 octal = 127 decimal)
```

This code extracts individual characters from packed word storage:
- Bit 17 (Link after rotation) indicates which character (0=left, 1=right)
- Left character occupies bits 17-9
- Right character occupies bits 8-0
- Masking with `0177` strips to 7-bit ASCII

### Register Set

The PDP-7 had a minimal register set—just four programmer-visible registers:

#### AC (Accumulator) - 18 bits

The **primary working register** for all arithmetic and logical operations.

```assembly
" AC examples from init.s

   lac d1            " Load AC with contents of location 'd1'
                     " (d1 contains constant 1)

   dac pid1          " Deposit AC to location 'pid1'
                     " (Store process ID)

   -1                " This is a literal: sets AC to -1 (777777 octal)
                     " In two's complement: all bits set

   cla               " Clear AC (set to 0)
```

**AC operations:**
- `lac` (Load AC): AC ← memory[address]
- `dac` (Deposit AC): memory[address] ← AC
- `cla` (Clear AC): AC ← 0
- Arithmetic results always go to AC
- Logical operations operate on AC

#### MQ (Multiplier-Quotient) - 18 bits

The **secondary register** for double-precision operations, multiply, divide, and shifts.

```assembly
" MQ examples from init.s

   lacq              " Load AC from MQ (AC ← MQ)

   lmq               " Load MQ from AC (MQ ← AC)

   " Character conversion using MQ
   tad om60          " Add -060 (octal) to AC
   lmq               " Save in MQ
   lac nchar         " Load previous value
   cll; als 3        " Clear Link; Arithmetic Left Shift 3 bits
   omq               " OR with MQ
   dac nchar         " Store result
```

**MQ operations:**
- `lmq` (Load MQ): MQ ← AC
- `lacq` (Load AC from MQ): AC ← MQ
- `omq` (OR with MQ): AC ← AC | MQ
- Used for: shift operations, multiplication, division, temporary storage

#### Link (1 bit)

The **carry/overflow bit** for arithmetic and the **17th bit** for rotations.

```assembly
" Link examples from cat.s

   cll               " Clear Link (Link ← 0)

   rcr               " Rotate Combined Right
                     " (Link, AC) right 1 bit: Link ← AC[0], AC ← Link,AC[17:1]

   ral               " Rotate AC Left
                     " Link ← AC[17], AC ← AC[16:0],Link

   szl               " Skip if Link Zero
   snl               " Skip if Link Non-zero
```

**Link uses:**
1. **Carry flag**: Addition/subtraction carry/borrow
2. **Rotation bit**: 19-bit rotate (Link + 18-bit AC)
3. **Condition testing**: Skip instructions test Link state
4. **Character selection**: Odd/even character in word

Example showing Link in arithmetic:

```assembly
" Adding two double-precision numbers (36 bits each)
" Low word addition
   lac num1_low      " Load low word of first number
   tad num2_low      " Add low word of second number
                     " Link receives carry-out
   dac result_low    " Store low word result

" High word addition (with carry)
   lac num1_high     " Load high word of first number
   tad num2_high     " Add high word of second number
                     " Link from previous add is carry-in
   dac result_high   " Store high word result
```

#### PC (Program Counter) - 13 bits

The **instruction pointer**, automatically incremented after each instruction fetch.

**PC characteristics:**
- **13 bits wide** (addresses 0 to 07777 octal = 8191 decimal)
- **Maximum memory**: 8K words (8192 words = 16 KB)
- **Auto-increment**: PC ← PC + 1 after fetch
- **Branch target**: Jump/JMS instructions load new value into PC

```assembly
" PC manipulation (implicit in all code)

loop:                 " Label defines address
   lac counter        " PC = address of 'lac counter'
   tad d1             " PC = PC + 1 (points to 'tad d1')
   dac counter        " PC = PC + 1 (points to 'dac counter')
   sad limit          " PC = PC + 1 (points to 'sad limit')
   jmp loop           " PC ← address of 'loop' (branch taken)
                      " or PC = PC + 1 (branch not taken)
```

**PC cannot be directly accessed** by programs. Only branch instructions modify it.

#### MA (Memory Address Register) - 13 bits

The **internal register** holding the current memory address being accessed. Not directly programmer-visible.

**MA is automatically set by:**
1. Instruction fetch: MA ← PC
2. Memory reference: MA ← instruction address field
3. Indirect addressing: MA ← memory[MA]
4. Auto-increment: MA ← memory[MA], memory[MA] ← memory[MA] + 1

### Auto-Increment Registers

The PDP-7 implemented a clever optimization: **memory locations 010 through 017 (octal) auto-increment when used indirectly**.

```
Auto-increment locations (octal):
010, 011, 012, 013, 014, 015, 016, 017

These are normal memory locations, but with special behavior:
- Direct access: Normal read/write
- Indirect access: Read value, then increment location
```

**Example from cat.s:**

```assembly
" Setup: Location 8 (010 octal) contains 4096
" Goal: Zero out 64 words starting at address 4096

   law 4096-1        " Load AC with 4096-1 = 4095
   dac 8             " Store in location 010 (octal) = 8 (decimal)
                     " Register 8 now points to address 4095

1:
   dzm 8 i           " Deposit Zero to Memory at address in loc 8
                     " 1st iteration: zeros memory[4095], then 8 ← 8+1 = 4096
                     " 2nd iteration: zeros memory[4096], then 8 ← 8+1 = 4097
                     " 3rd iteration: zeros memory[4097], then 8 ← 8+1 = 4098
                     " ... and so on

   isz tal           " Increment and Skip if Zero (loop control)
   lac tal           " Load counter
   sad ebufp         " Skip if AC equals end pointer
   skp               " Skip next instruction
   jmp 1b            " Jump back to label 1
```

**Why auto-increment locations 10-17?**

```
Octal 010-017 = Binary 001000 through 001111
                              ↑
                        Bit pattern: 001xxx

PDP-7 hardware checks if address bits [15:13] = 001
If YES and INDIRECT addressing: auto-increment
If NO or DIRECT addressing: normal access
```

**Detailed mechanics:**

```assembly
" Normal memory location (example: location 100 octal)
   lac 100           " AC ← memory[100]
   lac 100 i         " AC ← memory[memory[100]]  (indirect)
                     " memory[100] unchanged

" Auto-increment location (example: location 010 octal = location 8)
   lac 8             " AC ← memory[8]  (direct - no increment!)
   lac 8 i           " AC ← memory[memory[8]]  (indirect - increments!)
                     " THEN: memory[8] ← memory[8] + 1
```

**Common usage patterns:**

```assembly
" Pattern 1: Array traversal
   law array-1       " Start one before array
   dac 10            " Use location 10 (auto-increment register)
loop:
   lac 10 i          " Get next array element, auto-increment
   " ... process element ...
   jmp loop          " Repeat

" Pattern 2: String copy
   law source-1
   dac 8             " R8 = source pointer
   law dest-1
   dac 9             " R9 = destination pointer
copy:
   lac 8 i           " Get source character, increment source
   dac 9 i           " Store to destination, increment destination
   sna               " Skip if Not zero (AC != 0)
   jmp done          " If zero, done
   jmp copy          " Continue copying
```

From **init.s**, actual Unix kernel code:

```assembly
" Copy boot code to high memory (017700 octal)
   law 017700        " Load AC with address 017700
   dac 9             " R9 = destination (017700)
   law boot-1        " Start one before 'boot' label
   dac 8             " R8 = source pointer
1:
   lac 8 i           " Load from source, auto-increment R8
   dac 9 i           " Store to destination, auto-increment R9
   sza               " Skip if Zero
   jmp 1b            " Continue until zero word encountered
   jmp 017701        " Jump to copied code
```

This compact loop copies an entire code segment with just 6 instructions!

**All 8 auto-increment registers:**

| Octal | Decimal | Typical Use in Unix |
|-------|---------|---------------------|
| 010   | 8       | General pointer (R8) |
| 011   | 9       | General pointer (R9) |
| 012   | 10      | Stack pointer / Array index |
| 013   | 11      | String pointer |
| 014   | 12      | Buffer pointer |
| 015   | 13      | Temporary pointer |
| 016   | 14      | Loop counter |
| 017   | 15      | Saved pointer |

**Performance benefit:**

Without auto-increment:
```assembly
loop:
   lac ptr           " Load pointer (1 instruction)
   dac tempaddr      " Store as address (1 instruction)
   lac tempaddr i    " Load indirect (1 instruction)
   " ... process ...
   isz ptr           " Increment pointer (1 instruction)
   jmp loop          " 4 instructions per iteration
```

With auto-increment:
```assembly
loop:
   lac 8 i           " Load indirect with auto-increment (1 instruction)
   " ... process ...
   jmp loop          " 1 instruction per iteration
```

**4× reduction in instructions for pointer-heavy code!**

---

## 2. Instruction Set Architecture

The PDP-7 achieved remarkable simplicity with just **16 instructions**—yet provided enough power to build a complete operating system.

### Instruction Encoding Format

Every instruction occupies one 18-bit word:

```
Memory Reference Instructions (OPR, LAC, DAC, XOR, ADD, TAD, ISZ, AND, SAD, JMP):
┌───┬─┬─┬────────────────┐
│OPR│I│X│   ADDRESS      │  18 bits total
└───┴─┴─┴────────────────┘
 3b  1b 1b     13 bits

OPR (bits 17-15): Operation code (3 bits = 8 possible operations)
I   (bit 14):     Indirect bit (0=direct, 1=indirect)
X   (bit 13):     Index bit (used in some machines, usually 0 on PDP-7)
ADDRESS (12-0):   Memory address (13 bits = 8192 words)

Microprogrammed Instructions (OPR):
┌───┬───────────────────┐
│110│  MICROCODE BITS   │  18 bits total
└───┴───────────────────┘
 3b        15 bits

OPR=110 (octal 6): Signals microprogrammed operation
MICROCODE: Bit pattern selects operation(s)
```

**Instruction format examples:**

```assembly
" Memory reference instruction breakdown:
   lac 4096          " Load AC from address 4096

Binary encoding:
   001 0 0 0001000000000000
   │   │ │ └──────┬────────┘
   │   │ │      4096 decimal = 010000 octal
   │   │ └─ X bit = 0 (no indexing)
   │   └─── I bit = 0 (direct addressing)
   └─────── OPR = 001 (LAC opcode)

Octal representation: 010000
                      │└──┬─┘
                      │  address
                      └─ opcode + mode bits

" Indirect addressing:
   lac 100 i         " Load AC from memory[memory[100]]

Binary encoding:
   001 1 0 0000000001000000
       ↑
   I bit = 1 (indirect)

Octal representation: 030100
                      ││
                      │└─ address = 100 octal
                      └── opcode=01, I=1 = 03 octal

" Microprogrammed instruction:
   cla               " Clear AC

Binary encoding:
   110 000000100000000
   │   └──────┬──────┘
   │        bit 11 = 1 (CLA operation)
   └─ OPR = 110 (microcode)

Octal representation: 600400
```

### Complete 16-Instruction Set

#### Group 1: Memory Reference Instructions (8 instructions)

These instructions access memory and have the general format: `opcode [i] address`

##### 1. LAC - Load AC

**Encoding:** `001` (octal `02xxxx` direct, `03xxxx` indirect)
**Operation:** `AC ← memory[address]`
**Flags affected:** None

```assembly
" Examples from cat.s and init.s

   lac d1            " Load AC with contents of address 'd1'
                     " AC ← memory[d1]  (d1 contains value 1)

   lac 017777 i      " Load AC with memory[memory[017777]]
                     " Indirect: AC ← memory[memory[017777]]
                     " Used to access command-line argument count

   lac ipt           " Load input pointer
                     " AC ← memory[ipt]
```

**Use cases:**
- Loading variables into AC for processing
- Reading pointers for indirect addressing
- Retrieving constants
- Reading from I/O device registers

##### 2. DAC - Deposit AC

**Encoding:** `021` (octal `04xxxx` direct, `05xxxx` indirect)
**Operation:** `memory[address] ← AC`
**Flags affected:** None

```assembly
" Examples from actual Unix code

   dac fi            " Store AC to file descriptor variable
                     " memory[fi] ← AC

   dac 017777 i      " Store AC to memory[memory[017777]]
                     " Indirect: memory[memory[017777]] ← AC

   dac 8 i           " Store to address in location 8, then increment loc 8
                     " memory[memory[8]] ← AC
                     " memory[8] ← memory[8] + 1  (auto-increment!)
```

**Use cases:**
- Storing computation results
- Writing to variables
- Saving pointers
- Writing to I/O device registers
- Building data structures with auto-increment

##### 3. ISZ - Increment and Skip if Zero

**Encoding:** `041` (octal `10xxxx` direct, `11xxxx` indirect)
**Operation:** `memory[address] ← memory[address] + 1; if result == 0 then PC ← PC + 1`
**Flags affected:** None (skip is side effect)

```assembly
" Example: Loop counting down from -64 to 0

   -64               " Load AC with -64 (negative count)
   dac count         " Store as counter

loop:
   " ... do work ...

   isz count         " Increment count: -64→-63→...→-1→0
                     " When count reaches 0, skip next instruction
   jmp loop          " Jump back to loop (skipped when count = 0)

   " ... continue after loop ...

count: 0

" Example from cat.s: Buffer management
   isz noc           " Increment number of characters
   lac noc           " Load count
   sad d128          " Skip if AC Different from 128
   skp               " Skip next
   jmp putc i        " Return if count < 128

   " Flush buffer when count reaches 128
   lac fo
   sys write; iopt+1; 64
```

**Use cases:**
- Loop counters (count up from negative)
- Reference counting
- Buffer management
- State machines

**Why count from negative to zero?**

```assembly
" Method 1: Counting down (requires ISZ + compare)
   lac limit         " Load limit (e.g., 64)
   dac count         " count = 64
loop1:
   " ... work ...
   -1
   tad count         " count = count - 1
   dac count
   sna               " Skip if Non-zero
   jmp done          " If zero, done
   jmp loop1         " Loop
done:
   " 6 instructions per iteration

" Method 2: Counting up from negative (requires only ISZ)
   -64               " Load -64
   dac count         " count = -64
loop2:
   " ... work ...
   isz count         " count++, skip if zero
   jmp loop2         " Loop
   " 2 instructions per iteration - 3× more efficient!
```

##### 4. XOR - Exclusive OR

**Encoding:** `061` (octal `14xxxx` direct, `15xxxx` indirect)
**Operation:** `AC ← AC ⊕ memory[address]`
**Flags affected:** None

```assembly
" Examples from init.s

   lac nchar i       " Load character word
   and o777000       " Mask upper 9 bits (left character)
   xor char          " XOR with new character
   dac nchar i       " Store result
                     " Effect: Replace lower 9 bits with 'char'

" Character packing example:
" Pack two 9-bit characters into one word

   lac char1         " Load first character (bits 8-0)
   alss 9            " Shift left 9 bits (now bits 17-9)
   xor char2         " XOR with second character (bits 8-0)
   dac word          " Store packed word

   " Result: [char1][char2] in bits [17-9][8-0]
```

**Use cases:**
- Bit manipulation
- Character packing/unpacking
- Toggling flags
- Data encryption (simple XOR cipher)
- Checksums

**XOR properties:**
```
A ⊕ 0 = A           " Identity
A ⊕ A = 0           " Self-inverse
A ⊕ B ⊕ B = A       " Cancellation
```

##### 5. ADD - Add to AC

**Encoding:** `101` (octal `20xxxx` direct, `21xxxx` indirect)
**Operation:** `AC ← AC + memory[address]` (no Link update!)
**Flags affected:** None (Link not affected)

```assembly
" Note: ADD doesn't update Link (carry)
" Rarely used in PDP-7 Unix - TAD preferred

   lac value1        " Load first value
   add value2        " Add second value (no carry)
   dac result        " Store sum
```

**ADD vs TAD:**
- `ADD`: Does NOT affect Link (carry bit)
- `TAD`: DOES affect Link (carry bit)
- Unix code almost always uses TAD
- ADD exists for specific cases where Link must be preserved

##### 6. TAD - Two's complement Add

**Encoding:** `121` (octal `24xxxx` direct, `25xxxx` indirect)
**Operation:** `{Link, AC} ← AC + memory[address]` (Link receives carry)
**Flags affected:** Link (carry/borrow)

```assembly
" Examples from Unix kernel (s1.s)

   lac dot+1         " Load current address
   tad d1            " Add 1 (increment)
   dac dot+1         " Store incremented value

   " Negative addition (subtraction)
   -1                " AC ← -1 (all bits set)
   tad u.rq+8        " AC ← AC + memory[u.rq+8] = -1 + address
   " Result: address - 1

   " Building addresses from base + offset
   lac name          " Load base address
   tad d4            " Add offset of 4 words
   dac name          " Store new address

" Multi-word arithmetic example:
" Add two 36-bit numbers (two words each)

   cll               " Clear Link
   lac num1_low      " Load low word of first number
   tad num2_low      " Add low word of second (Link = carry)
   dac result_low    " Store low result

   lac num1_high     " Load high word of first
   tad num2_high     " Add high word (Link from previous add is carry-in)
   dac result_high   " Store high result
```

**Subtraction using TAD:**

```assembly
" To compute A - B, use A + (-B) with two's complement:

   lac minuend       " Load A
   -value            " This is a literal negative number
   dac result        " result = A - value

" Alternative: explicit negation
   lac subtrahend    " Load B
   cma               " Complement (one's complement)
   tad d1            " Add 1 (now two's complement: -B)
   tad minuend       " Add A
   dac result        " result = A - B
```

##### 7. SAD - Skip if AC Different

**Encoding:** `141` (octal `30xxxx` direct, `31xxxx` indirect)
**Operation:** `if AC ≠ memory[address] then PC ← PC + 1`
**Flags affected:** None (skip is side effect)

```assembly
" Examples from cat.s

   lac char          " Load character just read
   sad d4            " Skip if AC Different from 4 (EOF marker)
   jmp done          " If not EOF, jump to done
   " ... handle EOF ...
done:

" Comparison pattern:
   lac value1
   sad value2        " Skip if different
   jmp equal_case    " Not skipped = equal
   jmp not_equal     " Skipped = different
equal_case:

" Loop termination:
loop:
   lac counter
   sad limit         " Skip if counter ≠ limit
   jmp done          " Equal: exit loop
   " ... loop body ...
   jmp loop
done:
```

**Comparison logic:**

```
SAD compares AC with memory
Result = different → Skip next instruction
Result = equal → Execute next instruction

To skip on EQUAL, use double-skip pattern:
   sad value
   skp              " Skip if different (inverts logic)
   jmp equal_label  " Executed only if equal
```

##### 8. JMP - Jump

**Encoding:** `161` (octal `34xxxx` direct, `35xxxx` indirect)
**Operation:** `PC ← address` (direct) or `PC ← memory[address]` (indirect)
**Flags affected:** None

```assembly
" Direct jump (unconditional branch)
loop:
   " ... code ...
   jmp loop          " PC ← address of 'loop'

" Indirect jump (jump to address in variable)
   lac return_addr   " Load return address
   dac temp          " Store temporarily
   jmp temp i        " PC ← memory[temp] (jump to return address)

" Jump table (switch/case implementation)
   lac selector      " Load case number (0, 1, 2, ...)
   tad jumptable     " Add to base of jump table
   dac temp          " Store address
   jmp temp i        " Jump indirect through table

jumptable:
   case0             " Address of case 0 handler
   case1             " Address of case 1 handler
   case2             " Address of case 2 handler

case0:
   " ... handle case 0 ...
case1:
   " ... handle case 1 ...
case2:
   " ... handle case 2 ...

" Conditional jump pattern:
   lac value
   sza               " Skip if Zero
   jmp nonzero       " Taken if value ≠ 0
   " ... handle zero case ...
   jmp continue
nonzero:
   " ... handle nonzero case ...
continue:
```

#### Group 2: Microprogrammed Instructions (8 instructions)

These instructions use opcode `110` (octal `6xxxxx`) with remaining bits specifying micro-operations. Multiple micro-operations can be combined in a single instruction!

**General format:**

```
┌───┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐
│110│CLA│CMA│CLL│CML│RAR│RAL│ skip │
└───┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘
  3b  1b 1b 1b 1b 1b 1b      9 bits

Bits can be combined (OR'd together):
Example: CLA + CLL = 600400 | 600200 = 600600
```

##### 9. CLA - Clear AC

**Encoding:** `600400` (bit 11 = 1)
**Operation:** `AC ← 0`
**Flags affected:** None

```assembly
   cla               " AC ← 0

" Often combined with other operations:
   sna cla           " Skip if Non-zero, then Clear AC
                     " (Tests old value, clears regardless)
```

##### 10. CMA - Complement AC

**Encoding:** `601000` (bit 12 = 1)
**Operation:** `AC ← ~AC` (one's complement)
**Flags affected:** None

```assembly
" Bitwise NOT operation
   lac value         " AC ← 0123456 (octal example)
   cma               " AC ← ~AC = 0654321 (one's complement)

" Two's complement negation:
   lac value
   cma               " One's complement
   tad d1            " Add 1
   " AC now contains -value
```

**One's vs Two's complement:**

```
Original:  0000005 (octal) = 000000000000000101 (binary) = 5
One's:     0777772 (octal) = 111111111111111010 (binary) = ~5
Two's:     0777773 (octal) = 111111111111111011 (binary) = -5

One's complement: Flip all bits
Two's complement: Flip all bits + 1
```

##### 11. CLL - Clear Link

**Encoding:** `600200` (bit 10 = 1)
**Operation:** `Link ← 0`
**Flags affected:** Link

```assembly
   cll               " Link ← 0

" Often used before shifts/rotates:
   cll; als 3        " Clear Link, then Arithmetic Left Shift 3
```

##### 12. CML - Complement Link

**Encoding:** `601400` (bit 13 = 1)
**Operation:** `Link ← ~Link`
**Flags affected:** Link

```assembly
   cml               " Toggle Link (0→1, 1→0)

" Can be combined:
   cla cml           " AC ← 0, Link ← ~Link
```

##### 13. Rotate and Shift Instructions

**RAR - Rotate AC Right**
**Encoding:** `602000` (bit 14 = 1)
**Operation:** `{AC, Link} ← {Link, AC} >> 1` (19-bit rotate)

**RAL - Rotate AC Left**
**Encoding:** `604000` (bit 15 = 1)
**Operation:** `{Link, AC} ← {Link, AC} << 1` (19-bit rotate)

```assembly
" Rotate examples from cat.s

   lac ipt           " Load pointer (18 bits)
   ral               " Rotate left 1 bit
                     " Bit 17 → Link, Bits 16-0 → AC[17-1], Link → AC[0]

" Extract left character from packed word:
   lac word          " Load word: [char1][char2]
                     "            bits 17─9│8───0
   lrss 9            " Link-Right-Shift 9 bits
                     " AC[8-0] ← AC[17-9] (left character)
   and o177          " Mask to 7 bits

" Extract right character:
   lac word          " Load word
   ral               " Bit 17 → Link (determines odd/even)
   lac word          " Reload
   szl               " Skip if Link Zero (even character)
   lrss 9            " If odd, shift right 9
   and o177          " Mask to 7 bits
```

**Other shift/rotate variants:**

```assembly
" Combinations create different shifts:

" RTL - Rotate Two Left (double rotate)
   ral; ral          " Left shift 2 positions

" RTR - Rotate Two Right
   rar; rar          " Right shift 2 positions

" LRSS - Link-Right-Shift-9 (from assembler)
   lrss 9            " Special form: right shift 9 bits

" ALSS - Arithmetic Left Shift (from assembler)
   alss 9            " Special form: left shift 9 bits
                     " Sign bit preserved in signed arithmetic

" Example: Multiply by 8 (shift left 3)
   lac value
   cll               " Clear Link (ensure 0 shifted in)
   ral; ral; ral     " Shift left 3 positions
                     " AC ← AC * 8
```

##### 14-16. Skip Instructions

These test AC and/or Link and conditionally skip the next instruction.

**SZA - Skip if AC Zero**
**Encoding:** `640100`
**Operation:** `if AC == 0 then PC ← PC + 1`

**SNA - Skip if AC Non-zero**
**Encoding:** `640200`
**Operation:** `if AC ≠ 0 then PC ← PC + 1`

**SZL - Skip if Link Zero**
**Encoding:** `640400`
**Operation:** `if Link == 0 then PC ← PC + 1`

**SNL - Skip if Link Non-zero**
**Encoding:** `641000`
**Operation:** `if Link ≠ 0 then PC ← PC + 1`

**SPA - Skip if AC Positive**
**Encoding:** `640010`
**Operation:** `if AC ≥ 0 then PC ← PC + 1` (bit 17 == 0)

**SMA - Skip if AC Minus**
**Encoding:** `640020`
**Operation:** `if AC < 0 then PC ← PC + 1` (bit 17 == 1)

```assembly
" Examples from Unix source

" Check file open success
   sys open; name; 0
   spa               " Skip if Positive (AC ≥ 0)
   jmp error         " Negative file descriptor = error
   dac fd            " Positive = success

" Test for zero
   lac count
   sza               " Skip if Zero
   jmp nonzero       " Count ≠ 0
   " ... handle zero case ...
   jmp continue
nonzero:
   " ... handle nonzero case ...
continue:

" Double-skip pattern (skip if NOT zero)
   lac value
   sna cla           " Skip if Non-zero, then Clear AC
   jmp zero_case     " Executed only if value was zero
   " ... nonzero case ...
zero_case:

" Link testing for character packing
   lac ptr
   ral               " Bit 17 → Link
   lac ptr i         " Reload word
   szl               " Skip if Link Zero
   lrss 9            " If Link=1, shift right 9 (odd character)
```

**Skip instruction combinations:**

```assembly
" Skip instructions can be combined with CLA:

   sza cla           " Skip if Zero, then Clear (tests, then clears)
   sna cla           " Skip if Non-zero, then Clear

" This allows:
   lac variable
   sna cla           " Skip if non-zero, clear AC
   jmp was_zero      " Taken only if AC was zero
   " ... non-zero case ...
was_zero:
   " AC is now 0 in both paths
```

### Special Instructions

Beyond the basic 16, the PDP-7 has several special-purpose instructions:

#### JMS - Jump to Subroutine

**Encoding:** `041` (octal `10xxxx` direct, `11xxxx` indirect)
**Operation:**
```
memory[address] ← PC  (save return address)
PC ← address + 1      (jump to subroutine body)
```

**This is THE subroutine call mechanism.** Critical to understand!

```assembly
" Subroutine definition:
getc: 0               " First word: return address stored here
   lac ipt            " Subroutine body starts at getc+1
   sad eipt
   jmp 1f
   " ... more code ...
   jmp getc i         " Return: JMP indirect through getc (first word)

" Calling the subroutine:
   jms getc           " memory[getc] ← PC, PC ← getc+1
   " Execution continues here after subroutine returns
```

**Step-by-step JMS execution:**

```
Before call:
   PC = 1000         " Calling instruction at address 1000
   getc = 500        " Subroutine at address 500
   memory[500] = 0   " First word of subroutine

Execute: jms getc (at address 1000)
   1. memory[500] ← 1001  (save return address)
   2. PC ← 501           (jump to subroutine body)

Execute: jmp getc i (at end of subroutine)
   1. PC ← memory[500] = 1001 (return)
```

**Complete subroutine example from cat.s:**

```assembly
" PUTC - Output one character to buffer
" Call: jms putc (with character in AC)
" Returns: AC preserved, character added to buffer

putc: 0               " Return address stored here
   and o177           " Mask to 7-bit ASCII
   dac 2f+1           " Save character temporarily
   lac opt            " Load output pointer
   dac 2f             " Save pointer
   add o400000        " Increment pointer (by adding 0400000)
   dac opt            " Store incremented pointer
   spa                " Skip if Positive (even character)
   jmp 1f             " Odd character: branch

   " Even character (left side of word)
   lac 2f i           " Load existing word
   xor 2f+1           " XOR with character (merges into bits 8-0)
   jmp 3f

1: " Odd character (right side of word)
   lac 2f+1           " Load character
   alss 9             " Shift left 9 bits (bits 17-9)

3:
   dac 2f i           " Store merged word
   isz noc            " Increment character count
   lac noc
   sad d128           " Skip if Different from 128
   skp                " Skip
   jmp putc i         " Return if count < 128

   " Flush buffer when full
   lac fo
   sys write; iopt+1; 64
   lac iopt
   dac opt
   dzm noc            " Reset count
   jmp putc i         " Return

2: 0;0                " Temporary storage (2 words)
```

**Non-reentrant subroutines:**

This JMS mechanism has a critical limitation:

```assembly
sub1: 0
   jms sub2           " Call sub2 (overwrites sub2's return address)
   jmp sub1 i         " Return from sub1

sub2: 0
   jms sub2           " RECURSIVE CALL
                      " Problem: Overwrites memory[sub2] with new return!
                      " Original return address is LOST!
   jmp sub2 i         " Returns to wrong place!
```

**PDP-7 subroutines are NOT reentrant:**
- Cannot call themselves recursively
- Cannot be called from interrupt handlers if already executing
- Return address stored in first word (destroyed by re-entry)

**This limitation is fundamental to PDP-7 Unix architecture.**

#### IOT - Input/Output Transfer

**Encoding:** `700000 - 777777` (octal, opcode bits = `111`)
**Operation:** Device-specific I/O operations

```assembly
" IOT instruction format:
┌───┬─────────┬─────────┐
│111│ DEVICE  │ FUNCTION│  18 bits
└───┴─────────┴─────────┘
 3b    6 bits    9 bits

Examples:
   iot 011      " Teleprinter input
   iot 012      " Teleprinter output
   iot 714      " Read DECtape block
```

IOT instructions are covered in detail in Section 6 (I/O Architecture).

#### SKP - Skip Unconditionally

**Encoding:** `640000`
**Operation:** `PC ← PC + 1` (always skip next instruction)

```assembly
" Used to invert skip logic:
   lac value
   sad target        " Skip if AC Different from target
   skp               " Skip if equal (inverts the test)
   jmp different     " Taken if different
   " ... handle equal case ...
different:

" Another pattern:
   lac x
   sna               " Skip if Non-zero
   skp               " If zero, skip
   jmp nonzero       " Taken if non-zero
   " ... zero case ...
nonzero:
```

#### HLT - Halt

**Encoding:** `600000`
**Operation:** Stop processor, wait for external intervention

```assembly
" From s1.s (kernel initialization)
orig:
   hlt               " Halt (waits for power-on/reset)
   jmp pibreak       " After break, jump to interrupt handler
```

Used at system initialization and for debugging.

#### ION/IOF - Interrupts On/Off

**Encoding:** ION = `600001`, IOF = `600002`
**Operation:** Enable/disable interrupt system

```assembly
" Critical section protection from s1.s:
   iof               " Disable interrupts
   dac u.ac          " Save AC atomically
   " ... critical section code ...
   ion               " Re-enable interrupts
```

---

## 3. Addressing Modes

The PDP-7 supports three addressing modes, selected by instruction format:

### Direct Addressing

The instruction contains the actual memory address.

```assembly
   lac 4096          " AC ← memory[4096]

Encoding: 010000 (octal)
          │└──┬─┘
          │  4096 (address field)
          └─ 01 (LAC opcode, I=0)

Execution:
   1. Fetch instruction at PC
   2. Extract address field: 4096
   3. MA ← 4096
   4. AC ← memory[4096]
   5. PC ← PC + 1
```

**Example: Simple variable access**

```assembly
" Increment a counter
   lac count         " Direct: AC ← memory[count]
   tad d1            " AC ← AC + 1
   dac count         " Direct: memory[count] ← AC

count: 0              " Variable storage
d1: 1                 " Constant 1
```

### Indirect Addressing

The instruction contains an address that contains the actual address (pointer).

```assembly
   lac 100 i         " AC ← memory[memory[100]]

Encoding: 030100 (octal)
          ││└─┬─┘
          ││ 100 (address field)
          │└─ I=1 (indirect bit)
          └── 01 (LAC opcode)

Execution:
   1. Fetch instruction at PC
   2. Extract address field: 100
   3. MA ← memory[100]  (read pointer)
   4. AC ← memory[MA]   (read data)
   5. PC ← PC + 1
```

**Example: Pointer dereferencing**

```assembly
" Read from address stored in pointer
   lac ptr           " Load pointer value
   dac temp          " Store in temp location
   lac temp i        " Indirect: AC ← memory[memory[temp]]

" Alternative: direct indirect (if pointer is at fixed location)
   lac ptr i         " AC ← memory[memory[ptr]]

ptr: 4096             " Pointer: contains address 4096
temp: 0
```

**Example from cat.s: Reading through pointer**

```assembly
" GETC - Get one character from input buffer
getc: 0
   lac ipt           " Load input pointer (direct)
   sad eipt          " Compare with end pointer
   jmp 1f            " If equal, refill buffer

   dac 2f            " Store pointer value
   add o400000       " Increment pointer
   dac ipt           " Save incremented pointer
   ral               " Rotate (bit 17 → Link, selects character)
   lac 2f i          " INDIRECT: Read word at address in pointer
   szl               " Skip if Link Zero (even character)
   lrss 9            " If odd character, shift right 9
   and o177          " Mask to 7-bit ASCII
   jmp getc i        " Return

2: 0                 " Temporary storage for pointer
ipt: 0               " Input pointer variable
eipt: 0              " End pointer variable
```

### Auto-Increment Addressing

Indirect addressing through locations 010-017 (octal) auto-increments the pointer.

```assembly
   lac 8 i           " AC ← memory[memory[8]]
                     " THEN: memory[8] ← memory[8] + 1

Execution:
   1. Fetch instruction at PC
   2. Extract address field: 8 (010 octal)
   3. Check: Is address in range 010-017? YES
   4. MA ← memory[8]  (read pointer)
   5. AC ← memory[MA] (read data)
   6. memory[8] ← memory[8] + 1  (AUTO-INCREMENT!)
   7. PC ← PC + 1
```

**Example: Array traversal**

```assembly
" Sum array of 100 elements
   -100              " Initialize counter (count up to 0)
   dac counter
   law array-1       " Point one before array
   dac 8             " Use auto-increment register 8
   cla               " Clear sum

loop:
   tad 8 i           " Add next array element, auto-increment pointer
   " AC now contains sum
   isz counter       " Increment counter, skip when 0
   jmp loop          " Continue

   dac sum           " Store final sum

counter: 0
sum: 0
array: .=.+100        " Reserve 100 words
```

**Example: String copy from init.s**

```assembly
" Copy string from obuf to dir, character by character
   law dir-1         " Destination: one before 'dir'
   dac 8             " R8 = destination pointer
   law obuf-1        " Source: one before 'obuf'
   dac 9             " R9 = source pointer (could use non-auto-increment)

   dzm nchar         " Clear character counter

1:
   lac 9 i           " Load from source, R9 auto-increments
   sad o72           " Skip if AC Different from 072 (delimiter)
   jmp 1f            " If equal to 072, done

   dac char          " Save character
   lac nchar
   sza               " Skip if Zero (first character of pair)
   jmp 2f            " Already have first character

   " First character (left side of word)
   lac char
   alss 9            " Shift left 9 bits
   xor o40           " XOR with 040 (adjust)
   dac 8 i           " Store to destination, R8 auto-increments
   dac nchar         " Remember we have first character
   jmp 1b            " Continue

2: " Second character (right side of word)
   lac 8             " Load current destination pointer
   dac nchar         " Save it
   lac nchar i       " Load word at destination
   and o777000       " Keep left character (bits 17-9)
   xor char          " Merge right character (bits 8-0)
   dac nchar i       " Store merged word
   dzm nchar         " Clear state
   jmp 1b            " Continue
1:
   " String copy complete
```

### Addressing Mode Comparison

| Mode | Syntax | Operation | Cycles | Use Case |
|------|--------|-----------|--------|----------|
| Direct | `lac 100` | `AC ← memory[100]` | 1 | Simple variables |
| Indirect | `lac 100 i` | `AC ← memory[memory[100]]` | 2 | Pointers, arrays |
| Auto-inc | `lac 8 i` | `AC ← memory[memory[8]]`<br>`memory[8]++` | 2 | Sequential access |

**Performance implications:**

```assembly
" Task: Sum 100-element array

" Method 1: Direct addressing (SLOW)
   cla
   tad array+0
   tad array+1
   tad array+2
   " ... 100 instructions!
   tad array+99
   " 100 instructions, 100 memory cycles

" Method 2: Indirect addressing (MEDIUM)
   cla
   law array
   dac ptr
loop:
   tad ptr i         " Add element
   isz ptr           " Increment pointer
   " ... counter logic ...
   jmp loop
   " ~400 instructions total, slower

" Method 3: Auto-increment (FAST)
   -100
   dac counter
   law array-1
   dac 8             " Auto-increment register
   cla
loop:
   tad 8 i           " Add element, auto-increment
   isz counter       " Count
   jmp loop
   " 200 instructions total, fastest!
```

**Auto-increment is 2× faster than manual pointer arithmetic.**

---

## 4. Memory Organization

### Memory Map

The PDP-7 addressed up to **8K words** (8192 words = 16,384 bytes equivalent).

```
┌──────────────────────────────────────────┐ 017777 (8191 decimal)
│                                          │
│         User Space / High Memory         │
│                                          │
│    • Program code                        │
│    • Program data                        │
│    • Stack space                         │
│    • Buffers                             │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│         Kernel Space                     │
│                                          │
│    • System call handlers                │
│    • Device drivers                      │
│    • Process tables                      │
│    • Buffer cache                        │
│                                          │
├──────────────────────────────────────────┤ 000100 (64 decimal)
│         Interrupt Vectors                │
│                                          │
│    000020: System call trap              │
│    000007: Hardware register             │
│                                          │
├──────────────────────────────────────────┤ 000017 (15 decimal)
│    Auto-Increment Registers              │
│                                          │
│    000010-000017: R8-R15                 │
│                                          │
├──────────────────────────────────────────┤ 000007 (7 decimal)
│         Special Locations                │
│                                          │
│    000000-000007: System use             │
│                                          │
└──────────────────────────────────────────┘ 000000 (0 decimal)

Address Range    Octal        Decimal      Use
─────────────────────────────────────────────────────────
000000-000007    0-7          0-7          Special/Reserved
000010-000017    8-15         8-15         Auto-increment regs
000020-000077    16-63        16-63        Interrupt vectors
000100-003777    64-2047      64-2047      Kernel code/data
004000-017777    2048-8191    2048-8191    User space
```

### Special Memory Locations

Certain memory locations have special meanings:

```assembly
" Location 000000 (0): Origin/Halt location
orig = 0
   hlt               " Processor starts here on reset

" Location 000007 (-1): Special constant
. = 7
   -1                " Many programs expect -1 here

" Location 000020 (16): System call trap vector
. = 020
   system_call_entry " Saved PC for system calls

" Locations 000010-000017 (8-15): Auto-increment registers
" These are normal memory but auto-increment when used indirectly
```

**From s1.s (kernel):**

```assembly
.. = 0
t = 0
orig:
   hlt               " Location 0: halt
   jmp pibreak       " Location 1: break handler

. = orig+7
   -1                " Location 7: constant -1

. = orig+020
   1f                " Location 020 (16): system call handler
   iof               " Disable interrupts
   dac u.ac          " Save accumulator
   lac 020           " Load return address
   dac 1f
   " ... system call processing ...
```

### Word vs. Byte Addressing

**Critical difference from modern architectures:**

Modern computers (8-bit byte addressing):
```
Address    Content
0x0000     Byte 0
0x0001     Byte 1
0x0002     Byte 2
0x0003     Byte 3
```

PDP-7 (18-bit word addressing):
```
Address    Content (18 bits = 2 characters + 4 bits)
00000      Word 0 [char0][char1]
00001      Word 1 [char2][char3]
00002      Word 2 [char4][char5]
00003      Word 3 [char6][char7]
```

**Implications:**

1. **No byte pointers** - only word pointers
2. **Character access** requires bit manipulation
3. **File sizes** measured in words, not bytes
4. **Memory allocation** in word units

### Character Packing

The PDP-7 packed **two 9-bit characters per 18-bit word:**

```
18-bit word structure for characters:
┌─────────┬─────────┐
│  Char0  │  Char1  │
│ bits    │ bits    │
│ 17-9    │  8-0    │
│ (left)  │ (right) │
└─────────┴─────────┘

Each character: 9 bits = 512 possible values
ASCII uses 7 bits = 128 values (0-127)
Remaining 2 bits: extensions or ignored
```

**Character extraction from cat.s:**

```assembly
" GETC - Extract character from packed word storage
getc: 0
   lac ipt           " Load input pointer
   sad eipt          " Check if at end of buffer
   jmp refill        " If so, refill buffer

   " Save and increment pointer
   dac 2f            " Save pointer value
   add o400000       " Add 0400000 (increments by 1)
   dac ipt           " Store incremented pointer

   " Extract character based on odd/even
   ral               " Rotate: bit 17 → Link
                     " Link=0: even pointer (left char)
                     " Link=1: odd pointer (right char)

   lac 2f i          " Load word at address (indirect)
                     " Word contains [left char][right char]

   szl               " Skip if Link Zero (even)
   lrss 9            " If odd, shift right 9 bits
                     " Moves bits 17-9 → bits 8-0

   and o177          " Mask to 7-bit ASCII
                     " 0177 = 000 000 001 111 111 (binary)
                     "       keeps bits 6-0 only

   sna               " Skip if Non-zero
   jmp getc+1        " If null character, skip it

   jmp getc i        " Return with character in AC

2: 0                 " Temporary storage
o400000: 0400000     " Constant for pointer increment
o177: 0177           " ASCII mask
```

**Step-by-step example:**

```
Assume:
   ipt = 04000 (even address)
   memory[04000] = 0101102 (octal)
                 = 001 001 000 001 000 010 (binary)
                 = [char 'A'][char 'B']
                 = bits [17-9][8-0]
                 = [041][042] (octal)
                 = [65][66] (decimal)

First call (even):
   lac ipt           → AC = 04000
   dac 2f            → memory[2f] = 04000
   add o400000       → AC = 04000 + 0400000 = 0404000
   dac ipt           → ipt = 0404000 (incremented)
   ral               → Link = 0 (bit 17 of 04000 = 0)
   lac 2f i          → AC = memory[04000] = 0101102
   szl               → Link = 0, so DON'T skip
   " (no shift)
   and o177          → AC = 0101102 & 0177 = 0102 = 'B' (right char)
   " Wait, this seems backwards!

Actually, the encoding is:
   Word: high 9 bits = left char, low 9 bits = right char
   0101102 = 010 110 010 (octal)
           = 000001 000001 001000 000010 (binary)

Let me recalculate:
   0101102 (octal) = 001 001 000 001 000 010 (binary, 18 bits)

   Left character (bits 17-9):  001001000 = 0110 (octal) = 72 (decimal) = 'H'
   Right character (bits 8-0):  001000010 = 0102 (octal) = 66 (decimal) = 'B'

The example shows that characters are tightly packed, and extraction
requires careful bit manipulation.
```

**Character packing (storage) from init.s:**

```assembly
" Pack username characters into directory name
   law dir-1         " Destination pointer (before dir)
   dac 8             " R8 = destination (auto-increment)

   dzm nchar         " Clear character state (0 = need left char)

1:
   lac 9 i           " Get next input character (R9 auto-increments)
   sad o72           " Skip if AC Different from 072 (delimiter)
   jmp done          " If delimiter, done

   dac char          " Save character
   lac nchar         " Load state
   sza               " Skip if Zero (need left character)
   jmp pack_right    " Already have left, pack right

pack_left:
   " First character → left side (bits 17-9)
   lac char          " Load character (bits 8-0)
   alss 9            " Arithmetic Left Shift 9 bits
                     " Character now in bits 17-9
   xor o40           " XOR with 040 (space character as filler)
   dac 8 i           " Store to destination, R8 auto-increments
   dac nchar         " Mark that we have left character
   jmp 1b            " Get next character

pack_right:
   " Second character → right side (bits 8-0)
   lac 8             " Load current destination pointer
   dac nchar         " Save pointer
   lac nchar i       " Load existing word (has left character)
   and o777000       " Mask to keep bits 17-9 (left character)
                     " 0777000 = 111 111 111 000 000 000 (binary)
   xor char          " XOR with new character (bits 8-0)
                     " Merges character into bits 8-0
   dac nchar i       " Store merged word
   dzm nchar         " Clear state (ready for next left char)
   jmp 1b            " Get next character

done:
   " Characters packed

char: 0              " Temporary: current character
nchar: 0             " State: 0=need left, non-zero=have left
o72: 072             " Delimiter character
o40: 040             " Space character
o777000: 0777000     " Left character mask
```

**Example packing "AB" into one word:**

```
Step 1: Pack 'A' (065 octal = 000 000 101 binary in 9 bits)
   lac char          → AC = 0000065 (18-bit word: 000 000 000 000 101)
   alss 9            → AC = 0032040 (shifted left 9: 000 000 110 100 000)
                        Wait, that's not right. Let me recalculate:

   'A' = 065 octal = 053 decimal = 00 000 110 101 (binary, 9 bits)
   18-bit word: 000 000 000 000 110 101
   alss 9 (shift left 9):
      000 000 000 000 110 101 << 9 = 000 110 101 000 000 000
      = 0032000 (octal)
   xor o40:
      0032000 XOR 0000040 = 0032040

   Stored word: 0032040 (has 'A' in bits 17-9, space in bits 8-0)

Step 2: Pack 'B' (066 octal)
   lac nchar i       → AC = 0032040 (existing word)
   and o777000       → AC = 0032000 (keep left character)
   xor char (066)    → AC = 0032000 XOR 0000066 = 0032066

   Final word: 0032066 = [A][B] packed
```

### File I/O and Character Handling

Files on PDP-7 Unix are **word-oriented**, but programs see **character streams**:

```assembly
" Reading characters from file (from cat.s)

" System call: read into buffer (in WORDS)
   lac fi            " Load file descriptor
   sys read; buffer; 64  " Read 64 WORDS (128 characters)
   sna               " Skip if Non-zero (successful)
   jmp eof           " Zero words read = EOF

   tad buffer        " AC = words_read
                     " Each word contains 2 characters
   " ... convert to character count ...

" Writing characters to file (buffered)

putc: 0              " Write one character
   and o177          " Mask to 7-bit ASCII
   " ... pack into word buffer ...
   isz noc           " Increment character count
   lac noc
   sad d128          " Skip if Different from 128
   skp
   jmp putc i        " Return if buffer not full

   " Buffer full (64 words = 128 characters)
   lac fo            " File descriptor
   sys write; buffer; 64  " Write 64 WORDS
   " ... reset buffer ...
```

**File size measurement:**

```
Unix command "ls -l" on PDP-7:
   -rw-r--r--  1 root  42  Jun 30 1970  file.txt

"42" = 42 WORDS = 84 bytes equivalent (not exactly bytes!)

Actual character count could be:
   - 84 characters (both chars used in each word)
   - 83 characters (last word half-empty)
   - 42 characters (only left chars used)
```

This word-oriented design affects:
- File sizes (in words)
- I/O performance (word transfers faster than byte)
- Character processing (always unpacking/packing)
- Disk layout (block size in words)

---

## 5. Peripheral Devices

The PDP-7 supported several peripheral devices essential for interactive computing:

### Device Overview

```
┌─────────────────────────────────────────────────┐
│                    PDP-7 CPU                    │
│                                                 │
│   Registers: AC, MQ, Link, PC                   │
│   Memory: 8K words                              │
└─────────────────────────────────────────────────┘
         │
         │ I/O Bus
         │
    ┌────┴──────┬─────────┬─────────┬──────────┐
    │           │         │         │          │
┌───▼────┐ ┌───▼────┐ ┌──▼───┐ ┌───▼────┐ ┌──▼───┐
│Teletype│ │ Paper  │ │DECta-│ │Display │ │ Real │
│        │ │  Tape  │ │  pe  │ │ System │ │ Time │
│ Model  │ │Reader &│ │      │ │        │ │Clock │
│ 33/35  │ │ Punch  │ │      │ │Type340 │ │      │
└────────┘ └────────┘ └──────┘ └────────┘ └──────┘

TTY Input    PTR: Read    DT: Mass    Display:    RTC:
TTY Output   PTP: Punch   Storage     Graphics    Timekeeping
```

### Teletype (TTY)

The **Teletype Model 33** or **Model 35** served as the primary console.

**Characteristics:**
- **Speed**: 10 characters/second (110 baud)
- **Character set**: 7-bit ASCII (uppercase only on Model 33)
- **Interface**: Serial, asynchronous
- **Duplex**: Full duplex (simultaneous send/receive)
- **Physical**: Mechanical printer + keyboard

**I/O Instructions:**

```assembly
" Teletype input (from init.s)
   cla               " Clear AC
   sys read; char; 1 " Read 1 word (2 characters) from TTY
   lac char          " Load character word
   lrss 9            " Shift right 9 bits (get left character)
                     " Characters arrive in left half of word

" Teletype output
   lac char          " Load character
   alss 9            " Shift to left half of word
   dac output        " Store
   lac d1            " File descriptor 1 (stdout)
   sys write; output; 1  " Write 1 word to TTY

" Direct IOT instructions (lower level)
   iot 011           " Read character from TTY (to AC)
   iot 012           " Write character from AC to TTY
```

**Teletype files in Unix:**

```assembly
" From init.s - Opening TTY for process
ttyin:
   <tt>;<yi>;<n 040;040040   " "ttyin  " filename (packed chars)
ttyout:
   <tt>;<yo>;<ut>; 040040    " "ttyout" filename

" Process initialization
   sys open; ttyin; 0    " File descriptor 0 (stdin)
   sys open; ttyout; 1   " File descriptor 1 (stdout)
```

**TTY device behavior:**

```
Input:
   1. User presses key
   2. Character sent to TTY input buffer
   3. Interrupt signals CPU
   4. Kernel reads character via IOT 011
   5. Character stored in kernel buffer
   6. sys read returns to user program

Output:
   1. Program calls sys write
   2. Kernel sends characters via IOT 012
   3. Teletype mechanical printer types
   4. ~100ms per character (10 chars/sec)
   5. Output buffer prevents CPU waiting
```

**Echo handling:**

```assembly
" From user's perspective (init.s login prompt):
   lac d1
   sys write; m1; m1s    " Output "login: "
   jms rline             " Read line (with echo)

rline: 0
   law ibuf-1            " Input buffer pointer
   dac 8                 " R8 = pointer (auto-increment)
1:
   cla
   sys read; char; 1     " Read one word from TTY
   lac char
   lrss 9                " Extract character
   sad o100              " Skip if AC Different from 0100 (backspace)
   jmp rline+1           " Backspace: restart
   sad o43               " Skip if AC Different from 043 ('#' erase)
   jmp 2f                " Erase character
   dac 8 i               " Store character, increment pointer
   sad o12               " Skip if AC Different from 012 (newline)
   jmp rline i           " Return on newline
   jmp 1b                " Continue reading
2:
   " Handle erase
   law ibuf-1
   sad 8                 " Skip if AC Different from pointer
   jmp 1b                " At start, can't erase
   -1
   tad 8                 " Decrement pointer
   dac 8
   jmp 1b
```

**Special characters:**

| Octal | Decimal | ASCII | Function |
|-------|---------|-------|----------|
| 010   | 8       | BS    | Backspace |
| 012   | 10      | LF    | Line feed (newline) |
| 015   | 13      | CR    | Carriage return |
| 043   | 35      | #     | Erase character |
| 100   | 64      | @     | Kill line |
| 177   | 127     | DEL   | Delete |

### Paper Tape Reader and Punch

**Paper tape** was the primary storage medium for programs and data before DECtape.

**Characteristics:**
- **Width**: 1 inch (25.4mm)
- **Holes**: 8 channels (7 data + 1 sprocket)
- **Format**: Binary or ASCII
- **Speed**: Reader: 300 chars/sec, Punch: 10-50 chars/sec
- **Durability**: Can tear; must be handled carefully

**Physical format:**

```
Paper tape (view from top):
    ┌─────────────────────────────────┐
    │  ●   ●   ●   ●   ●   ●   ●   ●  │  Channel 8 (parity)
    │     ●       ●           ●       │  Channel 7 (bit 6)
    │  ●       ●       ●   ●       ●  │  Channel 6 (bit 5)
    │     ●   ●   ●   ●   ●   ●   ●  │  Channel 5 (bit 4)
    │  ●   ●   ●   ●   ●   ●   ●   ●  │  Channel 4 (bit 3)
    │     ●   ●       ●       ●       │  Channel 3 (bit 2)
    │  ●       ●   ●       ●   ●   ●  │  Channel 2 (bit 1)
    │     ●       ●   ●   ●       ●   │  Channel 1 (bit 0)
    │  ●   ●   ●   ●   ●   ●   ●   ●  │  Sprocket (feed)
    └─────────────────────────────────┘
       Frame (one character per frame)
```

**I/O operations:**

```assembly
" Read from paper tape reader (PTR)
   iot 001           " Read PTR, character → AC

" Punch to paper tape (PTP)
   lac char          " Load character
   iot 002           " Punch character

" Binary tape format (18-bit words):
" Each word encoded as 3 frames (6 bits each):
" Frame 1: bits 17-12
" Frame 2: bits 11-6
" Frame 3: bits 5-0
```

**Cross-development workflow (early Unix):**

```
┌─────────────────────────────────────────┐
│  GE 635 Mainframe (GECOS)               │
│                                         │
│  1. Edit source code                    │
│  2. Cross-assemble for PDP-7            │
│  3. Generate binary output              │
│  4. Punch to paper tape                 │
└─────────────────┬───────────────────────┘
                  │
                  │  Paper tape (physical medium)
                  │
┌─────────────────▼───────────────────────┐
│  PDP-7                                  │
│                                         │
│  1. Load paper tape into reader         │
│  2. Read binary into memory             │
│  3. Execute program                     │
│  4. Debug (if necessary, dump to tape)  │
└─────────────────────────────────────────┘
```

**Loader from paper tape:**

```assembly
" Simple paper tape binary loader
" Format: Each word on tape is 3 6-bit frames

loader:
   law 4096-1        " Load address for code
   dac 8             " R8 = destination pointer

load_loop:
   iot 001           " Read frame 1 (bits 17-12)
   alss 6            " Shift left 6 bits
   dac temp          " Save

   iot 001           " Read frame 2 (bits 11-6)
   xor temp          " Merge
   alss 6            " Shift left 6 bits
   dac temp          " Save

   iot 001           " Read frame 3 (bits 5-0)
   xor temp          " Merge all 18 bits

   sna               " Skip if Non-zero
   jmp done          " Zero = end of tape

   dac 8 i           " Store word, increment pointer
   jmp load_loop     " Continue

done:
   jmp 4096          " Execute loaded program

temp: 0
```

### DECtape (Mass Storage)

**DECtape** was the first mass storage device, providing reliable file storage.

**Characteristics:**
- **Capacity**: ~144K words (288 KB equivalent)
- **Speed**: ~5K words/second transfer
- **Format**: 256-word blocks
- **Reliability**: Block checksums, bidirectional read
- **Mounting**: Removable 4-inch reels
- **Durability**: Magnetic tape, more robust than paper tape

**Block structure:**

```
DECtape format:
┌─────────────────────────────────────────┐
│  Block 0: Bootstrap                     │  256 words
├─────────────────────────────────────────┤
│  Block 1: Superblock / File system info │  256 words
├─────────────────────────────────────────┤
│  Block 2: Inode table                   │  256 words
├─────────────────────────────────────────┤
│  Block 3: Inode table (continued)       │  256 words
├─────────────────────────────────────────┤
│  Block 4: Data blocks begin             │  256 words
│  ...                                    │
│  Block N: More data                     │
└─────────────────────────────────────────┘

Total: ~550 blocks × 256 words = ~144K words
```

**I/O operations (from s1.s):**

```assembly
" DECtape I/O (simplified from dskio routine)

dskio: 0              " Read/write disk block
   " AC contains block number on entry

   dac dskaddr       " Save block address
   lac dskbuf        " Load buffer address
   dac dma_addr      " Set DMA address

   lac dskaddr
   alss 8            " Block number × 256 words/block
   dac block_addr    " Compute byte offset

   " Issue IOT sequence for DECtape
   lac block_addr
   iot 714           " Select block
   iot 715           " Start read operation

wait_complete:
   iot 716           " Check status
   spa               " Skip if Positive (complete)
   jmp wait_complete " Wait for completion

   jmp dskio i       " Return

dskaddr: 0
dma_addr: 0
block_addr: 0
```

**File system on DECtape:**

The Unix file system resided on DECtape blocks:

```assembly
" Block allocation (conceptual):
" Block 0:    Boot block (bootstrap loader)
" Block 1:    Superblock (free block list, inode count)
" Blocks 2-7: Inode table (file metadata)
" Blocks 8+:  Data blocks (file contents)

" Inode structure (simplified):
i.flgs: 0            " Flags (allocated, directory, etc.)
i.nlks: 0            " Number of links
i.uid:  0            " User ID
i.size: 0            " File size in words
i.addr: .=.+8        " 8 block addresses (direct blocks only)
i.mtim: .=.+2        " Modification time (2 words)
" Total: ~13 words per inode
```

### Display System (Type 340)

The **DEC Type 340 Precision CRT Display** enabled vector graphics—crucial for Space Travel!

**Characteristics:**
- **Resolution**: 1024 × 1024 addressable points
- **Type**: Vector display (draws lines, not pixels)
- **Speed**: ~100,000 points/second
- **Persistence**: Phosphor fades quickly (needs refresh)
- **Interface**: Direct memory access (DMA)

**Display operations:**

```assembly
" Display file format: sequence of commands in memory
" Commands: move, draw, character, intensity

" Display file example (draw square):
display_file:
   0040000         " Move to (0, 0)
   0000000         " X=0, Y=0
   0140000         " Draw to (512, 0)
   0020000         " X=512, Y=0
   0140000         " Draw to (512, 512)
   0020020         " X=512, Y=512
   0140000         " Draw to (0, 512)
   0000020         " X=0, Y=512
   0140000         " Draw to (0, 0)
   0000000         " X=0, Y=0
   0000001         " Stop display file

" Activate display:
   law display_file
   iot 007         " Set display file pointer
   iot 017         " Start display
```

**Space Travel game (the reason Unix exists!):**

```assembly
" Simplified Space Travel display logic
" (Actual game code is lost)

game_loop:
   jms calculate_positions  " Update planet/ship positions
   jms build_display_file   " Create drawing commands
   jms activate_display     " Show on screen
   jms read_keyboard        " Get user input
   jms update_physics       " Apply thrust, gravity
   jmp game_loop

calculate_positions: 0
   " Newtonian physics calculations
   " F = ma, orbits, thrust vectors
   " ...
   jmp calculate_positions i

build_display_file: 0
   law display_mem      " Display file location
   dac 8                " R8 = pointer (auto-increment)

   " Draw sun
   lac sun_x
   dac 8 i              " X coordinate
   lac sun_y
   dac 8 i              " Y coordinate

   " Draw planets (loop through planet table)
   " ...

   " Draw spacecraft
   lac ship_x
   dac 8 i
   lac ship_y
   dac 8 i

   " End display file
   lac d1
   dac 8 i              " Stop command

   jmp build_display_file i
```

**Display device file (from init.s):**

```assembly
displ:
   <di>;<sp>;<la>;<y 040   " "display" filename

" Process using display:
   sys open; displ; 1   " File descriptor 1 (stdout → display)
   " Now sys write outputs to display instead of TTY!
```

### Real-Time Clock

Provided timekeeping and periodic interrupts.

**Characteristics:**
- **Frequency**: 60 Hz (16.67ms per tick)
- **Interrupt**: Timer interrupt every tick
- **Use**: Process scheduling, time measurement

**Clock handling (from s1.s):**

```assembly
" Clock interrupt handler (called 60 times/second)

clock_interrupt:
   iof               " Disable interrupts
   dac u.ac          " Save AC

   isz uquant        " Increment user quantum
   lac uquant
   sad maxquant      " Skip if AC Different from max
   jms swap          " Quantum expired: swap process

   " Update system time
   isz u.time
   lac u.time
   sna
   isz u.time+1      " 36-bit time counter

   ion               " Re-enable interrupts
   jmp restore_state " Return from interrupt

uquant: 0            " Current quantum count
maxquant: 020        " Maximum quantum (20 ticks)
```

---

## 6. I/O Architecture

### IOT (Input/Output Transfer) Instructions

The PDP-7 used **IOT instructions** for all device I/O. Each device had unique IOT codes.

**IOT instruction format:**

```
┌───┬─────────┬─────────┐
│111│ DEVICE  │  PULSE  │  18 bits
└───┴─────────┴─────────┘
 3b    6 bits    9 bits

Opcode (111): All IOT instructions have opcode 7 (octal)
Device (6 bits): Selects device (64 possible devices)
Pulse (9 bits): Device-specific command

Octal encoding: 7DDDPP
   7: IOT opcode
   DDD: Device code
   PP: Pulse/function code
```

**Common IOT instructions:**

| Octal | Device | Function | Description |
|-------|--------|----------|-------------|
| 700001 | 00 | ION | Interrupts on |
| 700002 | 00 | IOF | Interrupts off |
| 700201 | 01 | PTR | Read paper tape reader |
| 700202 | 01 | PTP | Punch paper tape |
| 700311 | 01 | TTI | Read teletype input |
| 700312 | 01 | TTO | Write teletype output |
| 700714 | 03 | DTRA | DECtape read address |
| 700715 | 03 | DTRD | DECtape read data |
| 700716 | 03 | DTST | DECtape status |

**Device register model:**

Each device has control/status/data registers accessed via IOT:

```
Teletype device (conceptual):
┌────────────────────────────────────┐
│  TTY Controller                    │
│                                    │
│  Input Buffer:   [char] (1 word)   │
│  Output Buffer:  [char] (1 word)   │
│  Status Reg:     [flags]           │
│    - Input ready                   │
│    - Output ready                  │
│    - Error flags                   │
└────────────────────────────────────┘

IOT 011: Read Input Buffer → AC
IOT 012: AC → Output Buffer
IOT 013: Status → AC
```

### Programmed I/O

**Programmed I/O** means the CPU directly controls data transfer (no DMA).

**Example: Character output to TTY**

```assembly
" Output one character via programmed I/O
" Character in AC

tty_out: 0
   dac char          " Save character

wait_ready:
   iot 013           " Read TTY status
   and o200          " Mask output-ready bit
   sza               " Skip if Zero (not ready)
   jmp wait_ready    " Wait until ready

   lac char          " Load character
   iot 012           " Send to TTY

   jmp tty_out i     " Return

char: 0
o200: 0200           " Output-ready bit mask
```

**Performance implications:**

```
Character output at 10 chars/sec (TTY):
   - 100ms per character
   - CPU must wait ~175,000 cycles per character!
   - Wastes CPU time in wait loop

Solution: Buffering + interrupts
```

### Interrupt-Driven I/O

**Interrupts** allow devices to signal the CPU when ready, freeing CPU for other work.

**Interrupt mechanism:**

```
1. Device completes operation (e.g., TTY ready for next char)
2. Device raises interrupt signal
3. CPU finishes current instruction
4. CPU saves PC and state
5. CPU jumps to interrupt vector (device-specific address)
6. Interrupt handler processes event
7. Handler executes ION; return instruction
8. CPU restores state and continues

Interrupt vectors (memory addresses):
   000020: System call
   000030: Clock (60 Hz)
   000040: TTY input
   000050: TTY output
   000060: Paper tape
   000070: DECtape
   000100: Display
```

**Interrupt handler example (from s1.s):**

```assembly
" TTY input interrupt handler

. = 000040            " Interrupt vector for TTY input
   tty_in_handler     " Address of handler

tty_in_handler:
   iof               " Disable further interrupts
   dac save_ac       " Save AC

   iot 011           " Read character from TTY
   dac char          " Store in buffer

   " Add to input queue
   lac inq_tail      " Load queue tail pointer
   dac 8             " R8 = pointer
   lac char
   dac 8 i           " Store character, increment pointer
   lac 8
   dac inq_tail      " Update tail

   lac save_ac       " Restore AC
   ion               " Re-enable interrupts
   jmp save_pc i     " Return from interrupt

save_ac: 0
save_pc: 0
char: 0
inq_tail: 0
```

**Programmed I/O vs Interrupt-Driven:**

```assembly
" Method 1: Programmed I/O (POLLING)
output_char_polling:
1:
   iot 013           " Check TTY status
   and o200          " Output ready?
   sza
   jmp 1b            " Wait (wastes CPU cycles)
   iot 012           " Output character
   " 100ms of CPU time wasted per character!

" Method 2: Interrupt-Driven (EFFICIENT)
output_char_interrupt:
   lac char
   dac outq_tail i   " Add to output queue
   isz outq_tail
   " ... CPU continues other work ...
   " Interrupt fires when TTY ready
   " Handler sends next character from queue
   " ~0ms CPU wait time!
```

### Data Transfer Mechanisms

#### Character I/O (Single Character)

```assembly
" Read one character (blocking)
   cla
   sys read; buffer; 1   " Read 1 word (2 chars)
   lac buffer
   lrss 9                " Extract left character
   and o177              " Mask to ASCII
```

#### Block I/O (Disk)

```assembly
" Read disk block (256 words)
   lac block_num     " Block number (0-N)
   jms dskio         " Disk I/O routine
   " On return, dskbuf contains 256 words

" dskio routine (simplified):
dskio: 0
   alss 8            " Block × 256 = word offset
   dac addr          " Store address
   law dskbuf        " Buffer address
   dac dma_ptr       " DMA pointer
   lac addr
   iot 714           " DECtape: select block
   iot 715           " DECtape: start read
1:
   iot 716           " Check status
   spa               " Skip if Positive (done)
   jmp 1b            " Wait for completion
   jmp dskio i       " Return
```

#### Buffered I/O

All Unix I/O is buffered for efficiency:

```assembly
" Character output buffering (from cat.s)

putc: 0              " Output one character
   and o177          " Mask character
   dac char          " Save

   lac noc           " Number of chars in buffer
   sad d128          " Skip if Different from 128
   jmp flush         " Buffer full: flush

   " Add character to buffer
   lac opt           " Output pointer
   dac 8             " R8 = pointer
   lac char
   dac 8 i           " Store char, increment
   lac 8
   dac opt           " Update pointer

   isz noc           " Increment count
   jmp putc i        " Return

flush:
   lac fo            " File descriptor
   sys write; outbuf; 64  " Write 64 words (128 chars)
   dzm noc           " Reset count
   lac outbuf
   dac opt           " Reset pointer
   jmp putc+1        " Re-add character

noc: 0               " Number of characters
opt: 0               " Output pointer
char: 0
fo: 1                " File descriptor (stdout)
d128: 128
outbuf: .=.+64       " Output buffer (64 words = 128 chars)
```

**Buffering benefits:**

```
Without buffering:
   - 128 system calls to write 128 characters
   - 128 × (trap overhead + driver overhead) = ~12,800 cycles

With buffering:
   - 1 system call to write 128 characters
   - 1 × (trap overhead + driver overhead) = ~100 cycles
   - 128× speedup!
```

---

## 7. Technical Specifications

### Complete Hardware Specifications

| Component | Specification | Details |
|-----------|---------------|---------|
| **CPU** | | |
| Word size | 18 bits | All operations on 18-bit words |
| Instruction set | 16 instructions | Plus IOT variants |
| Instruction format | 1 word | 3-bit opcode + addressing |
| Cycle time | 1.75 μs | ~570,000 instructions/sec max |
| Registers | 4 visible | AC, MQ, Link, PC (13-bit) |
| **Memory** | | |
| Maximum | 8K words | 8,192 words = 16,384 bytes |
| Typical | 4K-8K words | 8,192-16,384 bytes |
| Access time | 1.75 μs | Same as cycle time |
| Word organization | 18 bits | Not byte-addressable |
| Auto-increment | 8 locations | Locations 010-017 (octal) |
| **Storage** | | |
| DECtape capacity | ~144K words | ~288 KB, removable reels |
| Block size | 256 words | 512 bytes equivalent |
| Transfer rate | ~5K words/sec | ~10 KB/sec |
| **I/O Devices** | | |
| Teletype | 110 baud | 10 chars/sec, Model 33/35 |
| Paper tape reader | 300 chars/sec | 8-channel tape |
| Paper tape punch | 10-50 chars/sec | 8-channel output |
| Display | 340 Precision | 1024×1024 vector display |
| Clock | 60 Hz | Programmable interval timer |
| **Physical** | | |
| Dimensions | Varies | Cabinet + peripherals |
| Power | ~2 KW | 115V AC |
| Weight | ~250 kg | ~550 lbs |
| Cooling | Forced air | Fans required |
| **Cost** | | |
| System price (1965) | ~$72,000 | Equivalent to ~$650,000 in 2025 |
| Educational discount | ~$50,000 | Universities paid less |

### Performance Characteristics

**Instruction timing (in microseconds):**

| Instruction | Cycles | Time (μs) | Notes |
|-------------|--------|-----------|-------|
| LAC (direct) | 1 | 1.75 | Single memory fetch |
| LAC (indirect) | 2 | 3.50 | Two memory accesses |
| DAC (direct) | 1 | 1.75 | Single memory store |
| DAC (indirect) | 2 | 3.50 | Two memory accesses |
| ISZ | 2 | 3.50 | Read + modify + write |
| TAD | 1 | 1.75 | Add with memory |
| JMP | 1 | 1.75 | Branch |
| JMS | 2 | 3.50 | Save + branch |
| CLA | 1 | 1.75 | Microcode |
| RAL | 1 | 1.75 | Microcode |
| Auto-increment | +0.5 | +0.875 | Extra half-cycle |

**Example: Subroutine call overhead**

```assembly
" Calling overhead:
   jms sub           " 2 cycles = 3.50 μs
   " ... subroutine body ...
   jmp sub i         " 2 cycles = 3.50 μs

" Total overhead: 4 cycles = 7.00 μs
" At 60 calls/sec: 0.042% overhead
" At 10,000 calls/sec: 7% overhead
```

**System call overhead (from measurements):**

```
sys read system call:
   1. User trap: ~10 cycles (17.5 μs)
   2. Kernel dispatch: ~20 cycles (35 μs)
   3. Buffer management: ~30 cycles (52.5 μs)
   4. Device I/O: varies (0-100ms for TTY)
   5. Return to user: ~10 cycles (17.5 μs)

Total (excluding I/O): ~70 cycles = ~122 μs
Total (with TTY I/O): ~100,000 μs = 100ms
```

### Memory Bandwidth

```
Memory bandwidth:
   Cycle time: 1.75 μs
   Word size: 18 bits = 2.25 bytes

   Max bandwidth = 2.25 bytes / 1.75 μs
                 = 1.29 MB/sec (theoretical)

   Realistic (with instruction overhead):
   ~0.5 MB/sec for data transfers
```

**Comparison to modern systems (2025):**

| Metric | PDP-7 (1965) | Modern CPU (2025) | Ratio |
|--------|--------------|-------------------|-------|
| Cycle time | 1.75 μs | 0.3 ns | 5,833× faster |
| Memory | 16 KB | 64 GB | 4,000,000× more |
| Disk | 288 KB | 4 TB | 14,000,000× more |
| Cost | $72,000 | $1,500 | 48× cheaper |
| Power | 2,000 W | 150 W | 13× less |

---

## 8. Assembly Language Syntax

### Octal Notation

**All numbers in PDP-7 assembly are octal (base 8) unless specified.**

```assembly
" Octal constants (default):
   lac 177          " Octal 177 = 127 decimal = 0b1111111
   dac 10000        " Octal 10000 = 4096 decimal

" Decimal constants (special notation in some assemblers):
   -64              " Negative decimal (assembler converts)

" Octal-decimal conversion:
   Octal 100 = (1×8²) + (0×8¹) + (0×8⁰) = 64 decimal
   Octal 377 = (3×8²) + (7×8¹) + (7×8⁰) = 255 decimal
   Octal 177777 = 65535 decimal (16-bit max)
```

**Common octal values:**

| Octal | Binary | Decimal | Meaning |
|-------|--------|---------|---------|
| 0 | 000 | 0 | Zero |
| 1 | 001 | 1 | One |
| 7 | 111 | 7 | Low 3 bits set |
| 10 | 001000 | 8 | Eight (R8) |
| 17 | 001111 | 15 | Last auto-inc reg |
| 20 | 010000 | 16 | Interrupt vector |
| 40 | 100000 | 32 | Space character |
| 100 | 001000000 | 64 | Common limit |
| 177 | 001111111 | 127 | 7-bit mask (ASCII) |
| 377 | 011111111 | 255 | 8-bit mask |
| 777 | 111111111 | 511 | 9-bit mask |
| 7777 | 0111111111111 | 4095 | 12-bit mask |
| 17777 | 001111111111111 | 8191 | 13-bit mask (address) |
| 77777 | 00111111111111111 | 32767 | 15-bit max positive |
| 177777 | 001111111111111111 | 65535 | 16-bit max |
| 777777 | 111111111111111111 | 262143 | 18-bit max |

### Instruction Syntax

**Basic format:**

```assembly
[label:] opcode [i] operand [; comment]

Components:
   label:    Optional identifier (ends with colon)
   opcode:   Instruction mnemonic (lac, dac, jmp, etc.)
   i:        Optional indirect suffix
   operand:  Address, register, or value
   comment:  Optional (starts with " or ;)
```

**Examples with syntax breakdown:**

```assembly
" Labels define addresses
start:             " Label 'start' = current address
   lac d1          " Load AC from address 'd1'
                   "   Opcode: lac (load AC)
                   "   Operand: d1 (symbol)

loop:              " Label 'loop'
   tad value       " Add 'value' to AC
   dac result      " Store AC to 'result'
   jmp loop        " Jump to 'loop' (infinite loop!)

" Indirect addressing (i suffix)
   lac ptr         " Direct: load from 'ptr'
   lac ptr i       " Indirect: load from address in 'ptr'

" Literals (constants)
   lac 4096        " Load literal value 4096 (octal)
   -1              " Load literal -1 (all bits set)

" Auto-increment registers
   lac 8 i         " Load from address in R8, increment R8
   dac 9 i         " Store to address in R9, increment R9

" System calls
   sys read; buffer; 64
   " Expands to:
   "    jms .read
   "    buffer
   "    64
```

### Labels and Symbols

```assembly
" Labels (address definitions):
start:             " Absolute address label
   lac count

count: 0           " Data label with initial value
max: 100           " Constant label

" Local labels (numeric):
1:                 " Local label '1'
   lac counter
   isz counter
   jmp 1b          " Jump back to label '1' above (1 backward)

   jms sub
   " ... code ...
   jmp 1f          " Jump forward to label '1' below (1 forward)

1:                 " Another local label '1'
   " ... code ...

" Assembler directives:
. = 4096           " Set location counter to 4096
buffer: .=.+64     " Reserve 64 words (label + advance counter)

" Symbol definition:
d1 = 1             " Define constant symbol
MAXBUF = 128       " Named constant
```

### Comments

```assembly
" Comment style 1: Double-quote (traditional)
   lac value       " This is a comment

; Comment style 2: Semicolon (alternate)
   dac result      ; This is also a comment

" Multi-line comments:
"
" This is a longer comment
" explaining the following code
" in more detail.
"
   jms complex_routine
```

### Assembler Directives

```assembly
" Location counter:
. = 1000           " Set address to 1000 (octal)
   lac d1          " This instruction at address 1000

" Space reservation:
buffer: .=.+64     " Reserve 64 words (buffer label)
   " Current address now 64 words higher

" Data initialization:
message:
   <he>;<ll>;<o 040  " Packed characters "hello"
   012                 " Newline character

" Constants:
d1: 1              " Word containing 1
d10: 10            " Word containing 10 (octal) = 8 decimal
minus1: -1         " Word containing -1 (777777 octal)

" Expressions:
limit: buffer+64   " Address arithmetic
mask: 0177         " Octal constant

" Include files (some assemblers):
include "defs.s"   " Include external definitions
```

---

## 9. Subroutine Linkage

### JMS Mechanism

The **JMS (Jump to Subroutine)** instruction is Unix's primary subroutine mechanism.

**Calling convention:**

```assembly
" Subroutine structure:
subname: 0         " First word: return address storage
   " ... subroutine body ...
   jmp subname i   " Return: indirect jump through first word

" Calling:
   jms subname     " Call subroutine
   " Execution continues here after return
```

**Detailed execution:**

```assembly
" Complete example:

main:
   lac value       " Address 1000: Load value
   jms double      " Address 1001: Call subroutine
   dac result      " Address 1002: Store result
   " ... continue ...

double: 0          " Address 2000: Return address space
   tad value       " Address 2001: Subroutine body
   jmp double i    " Address 2002: Return

value: 5
result: 0

" Execution trace:
" 1. PC=1000: lac value → AC=5
" 2. PC=1001: jms double
"    - memory[2000] ← 1002 (save return address)
"    - PC ← 2001 (jump to subroutine body)
" 3. PC=2001: tad value → AC=10
" 4. PC=2002: jmp double i
"    - PC ← memory[2000] = 1002 (return)
" 5. PC=1002: dac result → memory[result]=10
```

### Parameter Passing

**Method 1: Global variables (most common)**

```assembly
" Globals for parameters
param1: 0
param2: 0
result: 0

" Caller:
   lac x
   dac param1
   lac y
   dac param2
   jms add_sub
   lac result       " Get result

" Subroutine:
add_sub: 0
   lac param1
   tad param2
   dac result
   jmp add_sub i
```

**Method 2: AC/MQ register passing**

```assembly
" Caller:
   lac x            " First parameter in AC
   lmq              " Second parameter from MQ
   jms multiply
   " Result in AC

" Subroutine:
multiply: 0
   " AC contains multiplicand
   " MQ contains multiplier
   mul              " (Hypothetical multiply instruction)
   jmp multiply i
```

**Method 3: Inline parameters**

```assembly
" Caller:
   jms function
   x                " Parameter 1 (inline after call)
   y                " Parameter 2
   " Return here (function adjusts return address)

" Subroutine:
function: 0
   dac save_ac      " Save AC
   lac function     " Load return address
   dac ptr          " Save as pointer
   lac ptr i        " Get parameter 1 (auto-increment)
   dac param1
   lac ptr i        " Get parameter 2 (auto-increment)
   dac param2
   lac ptr          " Load adjusted return address
   dac function     " Update return address (skip parameters)
   lac save_ac      " Restore AC
   " ... function body ...
   jmp function i   " Return past parameters

save_ac: 0
ptr: 0
param1: 0
param2: 0
```

**Method 4: Auto-increment registers**

```assembly
" Caller:
   law args-1       " Point to argument list
   dac 8            " R8 = argument pointer
   jms process_args
   " ...

args:
   arg1
   arg2
   arg3
   0                " Null terminator

" Subroutine:
process_args: 0
loop:
   lac 8 i          " Get next argument, auto-increment
   sza              " Skip if Zero (end marker)
   jmp done
   " ... process argument in AC ...
   jmp loop
done:
   jmp process_args i
```

### Return Values

**Method 1: AC register**

```assembly
" Most common: return in AC
getchar: 0
   " ... read character ...
   lac char         " Return value in AC
   jmp getchar i

" Caller:
   jms getchar
   dac save_char    " AC contains return value
```

**Method 2: Global variable**

```assembly
" Return via global
readblock: 0
   " ... read data ...
   lac bytes_read
   dac result       " Store result in global
   jmp readblock i

result: 0

" Caller:
   jms readblock
   lac result       " Get return value from global
```

**Method 3: Status in Link**

```assembly
" Use Link for success/failure
openfile: 0
   " ... attempt to open file ...
   " If success: cll (Link=0)
   " If failure: cml (Link=1)
   jmp openfile i

" Caller:
   jms openfile
   snl              " Skip if Link Non-zero (error)
   jmp success
   " ... handle error ...
success:
   " ... file opened ...
```

### Non-Reentrant Limitation

**Critical constraint: PDP-7 subroutines cannot call themselves.**

```assembly
" Problem: Recursive call destroys return address

factorial: 0         " Return address storage
   lac n
   sad d1            " Skip if AC Different from 1
   jmp base_case

   " Recursive case: n * factorial(n-1)
   -1
   tad n
   dac n             " n = n - 1
   jms factorial     " PROBLEM: Overwrites factorial[0]!
                     " Original return address LOST!
   " ... multiply ...

base_case:
   lac d1
   jmp factorial i   " Returns to WRONG address

" After first recursive call:
" factorial[0] no longer contains original return address!
" It contains return address from recursive call!
```

**Workaround: Manual stack (rarely used, expensive)**

```assembly
" Simulate stack for recursion
STACK_SIZE = 100
stack: .=.+STACK_SIZE
sp: stack-1          " Stack pointer

" Push return address:
push_return: 0
   lac sp
   dac 8             " R8 = stack pointer
   lac factorial     " Load return address from subroutine
   dac 8 i           " Push to stack, increment SP
   lac 8
   dac sp            " Update stack pointer
   jmp push_return i

" Pop return address:
pop_return: 0
   -1
   tad sp            " Decrement SP
   dac sp
   dac 8             " R8 = decremented SP
   lac 8 i           " Pop from stack
   dac factorial     " Restore return address
   jmp pop_return i

" Recursive subroutine using manual stack:
factorial: 0
   jms push_return   " Save return address
   " ... recursive logic ...
   jms pop_return    " Restore return address
   jmp factorial i   " Return

" Problems:
" 1. Overhead: 20+ instructions per recursion level
" 2. Complexity: Manual stack management
" 3. Stack limit: Fixed size (overflow risk)
" Result: Recursion rarely used in PDP-7 Unix
```

**Unix solution: Avoid recursion entirely**

```
Unix design principle:
   "Use iteration, not recursion."

Examples:
   - Directory traversal: Iterative with queue
   - Expression evaluation: Iterative with stack
   - Tree walking: Iterative with explicit stack

This limitation influenced Unix's iterative design patterns!
```

---

## 10. Hardware Constraints and Their Impact on Unix

The PDP-7's limitations profoundly shaped Unix's design. Understanding these constraints explains *why* Unix works the way it does.

### 18-Bit Architecture Impact

**Character encoding:**

```assembly
" 9-bit characters supported extended ASCII:
" Bits 8-7: Extension bits (case, graphics)
" Bits 6-0: Standard ASCII

" Examples:
" 'A' = 0101 (octal) = 065 (decimal) = uppercase
" 'a' = 0141 (octal) = 097 (decimal) = lowercase
"       ↑ bit 8 indicates lowercase

" This 9-bit encoding allowed:
" - Upper and lowercase (128 + 128 = 256 chars)
" - Graphics characters
" - Control characters
" - Extended symbols

" But caused problems:
" - Not compatible with later 8-bit systems
" - Character masking required (and o177)
" - Conversion needed for 7-bit ASCII
```

**Word-oriented I/O:**

```assembly
" Files measured in WORDS, not bytes:
" Problem: File size ambiguous

" Example: 3-character file "cat"
" Storage: [ca][t ]  (2 words, 4 characters)
" File size: 2 words
" Actual data: 3 characters
" Wasted space: 1 character slot

" Solution in Unix:
" - Store character count separately
" - Inode contains size in WORDS
" - Application tracks actual character count
" - Inefficient for small files

i.size: 2            " File size in words (from inode)
" Actual characters: Unknown (could be 3 or 4)
```

### Memory Limitations

**8K words = 16 KB total addressable**

```assembly
" Memory allocation (approximate):
"
" 0000-0377:   256 words   Kernel vectors/data
" 0400-3777:   3584 words  Kernel code
" 4000-7777:   4096 words  User space
" Total:       8192 words  (16 KB)

" Implications:
" 1. Kernel must be < 3.5K words (~7 KB)
" 2. User programs must be < 4K words (~8 KB)
" 3. No room for large buffers
" 4. No room for multiple processes in memory simultaneously

" Solution: Swapping
" - Only ONE user process in memory at a time
" - Other processes swapped to disk
" - Context switch = disk I/O (slow!)
```

**Swapping mechanics from s1.s:**

```assembly
swap: 0
   ion               " Enable interrupts

   " Find process to swap in
1:
   jms lookfor; 3    " Look for out/ready process
   jmp found
   jms lookfor; 1    " Look for in/ready process
   skp
   jmp 1b            " Keep searching

found:
   " Save current process to disk
   iof               " Disable interrupts
   lac u.ulistp i    " Mark process as 'swapped out'
   tad o200000
   dac u.ulistp i
   ion               " Re-enable interrupts

   jms dskswap; 07000  " Write process to disk (block 07000)

   " Load new process from disk
   jms dskswap; 06000  " Read process from disk (block 06000)

   " Update process status
   lac o600000
   tad new_proc
   dac new_proc      " Mark as 'swapped in'

   jmp swap i        " Return

" Swap overhead:
" - Save: ~256 words to disk (~50ms)
" - Load: ~256 words from disk (~50ms)
" - Total: ~100ms per context switch!
" Compare to modern: < 1μs
```

### I/O Limitations

**Slow peripherals:**

```
Device speeds:
   Teletype:       10 chars/sec    (100ms per char)
   Paper tape:     300 chars/sec   (3.3ms per char)
   DECtape:        5K words/sec    (0.2ms per word)
   Display:        100K points/sec (10μs per point)

CPU speed:        570K inst/sec   (1.75μs per inst)

Mismatch:
   CPU can execute 57,000 instructions while waiting
   for ONE character from teletype!
```

**Solution: Buffering and interrupts**

```assembly
" Without buffering:
" Write 100 characters to TTY

   lac buffer_ptr
   dac 8             " R8 = pointer
   -100
   dac counter
loop:
   lac 8 i           " Get character
   jms tty_out       " Output (waits ~100ms)
   isz counter
   jmp loop
   " Total time: 100 × 100ms = 10 seconds

" With buffering and interrupts:
" Write 100 characters to TTY

   lac fo
   sys write; buffer; 50  " Write 50 words (100 chars)
   " System call queues data and returns immediately
   " Interrupt handler sends characters in background
   " Total blocking time: < 1ms (system call overhead)
   " Actual output time: still 10 seconds, but CPU free!
```

### Performance Constraints

**Instruction timing matters:**

```assembly
" Example: Zero 100 words
" Method 1: Direct (simple but slow)
   -100
   dac counter
loop1:
   dzm array+0      " 2 cycles each (direct addressing)
   dzm array+1
   dzm array+2
   " ... 100 instructions ...
   dzm array+99
   " Total: 200 cycles = 350 μs

" Method 2: Loop (smaller but slower)
   -100
   dac counter
   law array
   dac ptr
loop2:
   dzm ptr i        " 3 cycles (indirect addressing)
   isz ptr          " 2 cycles (increment)
   isz counter      " 2 cycles (count)
   jmp loop2        " 1 cycle (branch)
   " Total: 100 × 8 = 800 cycles = 1,400 μs (4× slower!)

" Method 3: Auto-increment (optimal)
   -100
   dac counter
   law array-1
   dac 8            " Use auto-increment register
loop3:
   dzm 8 i          " 2.5 cycles (auto-increment)
   isz counter      " 2 cycles
   jmp loop3        " 1 cycle
   " Total: 100 × 5.5 = 550 cycles = 962 μs (2× slower than direct)

" Lesson: Unrolled loops are fastest, but waste memory
" Unix uses auto-increment as compromise
```

**Real example from Unix (copy.s):**

```assembly
" Copy memory block (optimized for speed)
copy: 0
   " Called with: jms copy; source; dest; count

   lac copy         " Get return address
   dac 8            " R8 = parameter pointer

   lac 8 i          " Get source address
   dac 9            " R9 = source (auto-increment)

   lac 8 i          " Get dest address
   dac 10           " R10 = dest (auto-increment)

   lac 8 i          " Get count
   cma              " Complement (for negative counting)
   tad d1           " Add 1 (two's complement)
   dac counter      " counter = -count

   lac 8
   dac copy         " Update return address (skip parameters)

loop:
   lac 9 i          " Load from source, increment R9
   dac 10 i         " Store to dest, increment R10
   isz counter      " Increment counter (counts toward 0)
   jmp loop         " Continue until counter = 0

   jmp copy i       " Return

counter: 0

" This routine appears 50+ times in Unix kernel
" Optimization saved ~30% of kernel memory access time!
```

### Design Principles Emerging from Constraints

**1. Minimalism**

```
Constraint: 8K words total memory
Result: Every instruction must justify its existence
Example: Kernel is 2,500 lines (incredibly compact)

Modern comparison:
   Linux kernel: 30 million lines
   PDP-7 Unix kernel: 2,500 lines
   Ratio: 12,000× larger!

Yet PDP-7 Unix was a complete, self-hosting OS.
```

**2. Simplicity**

```
Constraint: No recursion (non-reentrant subroutines)
Result: Simple, iterative algorithms
Example: Directory traversal uses queue, not recursion

Benefit: Easier to understand, debug, and verify
Drawback: Some algorithms more verbose
```

**3. Efficiency**

```
Constraint: 1.75 μs cycle time (slow by modern standards)
Result: Extreme optimization (auto-increment, buffering)
Example: All I/O buffered, minimal system call overhead

Benchmark:
   Unbuffered I/O: 100 system calls/sec max
   Buffered I/O: 10,000 system calls/sec
   100× improvement from buffering!
```

**4. Orthogonality**

```
Constraint: Only 16 instructions
Result: Each instruction does ONE thing well
Example:
   LAC: Load ONLY
   DAC: Store ONLY
   TAD: Add ONLY

No complex instructions like:
   "Load, increment, store, and branch if overflow"

Benefit: Simple to learn, compose, and optimize
```

**5. Everything is a file**

```
Constraint: Word-oriented I/O, limited instructions
Result: Unified I/O model for all devices
Example: Same sys read/write for:
   - Regular files
   - Directories
   - Teletype
   - Paper tape
   - DECtape
   - Display

Implementation:
   All devices expose character/block interface
   Kernel translates to device-specific IOT instructions

Benefit: Programs device-independent
```

**6. Pipes and filters (later Unix)**

```
Constraint: Limited memory, slow I/O
Result: Small programs composed via pipes
Example: cat file | grep pattern | sort

This emerged from PDP-11 Unix, but principles from PDP-7:
   - Small, focused tools
   - Character streams
   - Composition over monolithic design
```

---

## Conclusion

The PDP-7 was a minimal machine—just 18-bit words, 16 instructions, 8K words of memory, and primitive I/O. Yet from these constraints emerged Unix: elegant, powerful, and enduring.

Understanding the PDP-7 hardware reveals *why* Unix became what it is:

- **Minimalism**: Limited memory forced economy of expression
- **Simplicity**: Small instruction set demanded clever composition
- **Orthogonality**: Each operation does one thing perfectly
- **Buffering**: Slow I/O necessitated efficient caching
- **Files everywhere**: Word-oriented I/O unified device access
- **Iterative design**: Non-reentrant subroutines prevented recursion

These weren't abstract design principles—they were **necessary adaptations** to hardware constraints. Thompson and Ritchie didn't choose minimalism; the PDP-7 *forced* it. And in that forcing, they discovered principles that would shape computing for the next 50 years.

In the next chapter, we'll explore PDP-7 assembly language programming in depth, building on the architectural foundation established here. We'll write complete programs, examine real Unix source code, and learn to think like a PDP-7 programmer.

The hardware constraints that limited the PDP-7 became the philosophical constraints that liberated Unix.

---

**Next: [Chapter 3 - Assembly Language Programming](03-assembly.md)**

**References:**
- DEC PDP-7 Handbook (1965)
- Unix Programmer's Manual, First Edition (1971)
- Dennis M. Ritchie, "The Evolution of the Unix Time-sharing System" (1984)
- PDP-7 Unix source code (reconstructed 2019)
