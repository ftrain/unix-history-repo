# Frontmatter {.unnumbered}

## About This Work {.unnumbered}

This comprehensive technical reference documents the PDP-7 Unix operating system, one of the most significant software artifacts in computing history. Written in 1969-1970 by Ken Thompson and Dennis Ritchie at Bell Labs, this code represents the birth of Unix and, by extension, the foundation of modern computing.

## Purpose and Scope {.unnumbered}

This work provides:

- **Complete technical documentation** of every component in the PDP-7 Unix system
- **Literate programming presentation** with extensive narrative explanation accompanied by code
- **Historical analysis** of how Unix evolved and the development patterns that emerged
- **Hardware context** explaining the PDP-7 computer architecture and its constraints
- **Cross-referenced** comprehensive coverage enabling deep understanding of system interactions

## How to Read This Book {.unnumbered}

This reference is organized to support multiple reading paths:

### For the Curious Reader

Start with:
- Chapter 1: Historical Context
- Chapter 2: PDP-7 Hardware Architecture
- Chapter 4: System Architecture Overview
- Chapter 11: User Utilities (cat, cp, chmod, etc.)

### For the Systems Programmer

Focus on:
- Chapter 3: Assembly Language and Programming
- Chapter 5: The Kernel Deep Dive
- Chapter 7: File System Implementation
- Chapter 8: Process Management
- Chapter 9: Device Drivers and I/O

### For the Programming Language Enthusiast

Read:
- Chapter 10: Development Tools
- Chapter 12: The B Language System
- Chapter 3: Assembly Language

### For the Computer Historian

Study:
- Chapter 1: Historical Context
- Chapter 13: Code Evolution and Development Patterns
- Chapter 14: Legacy and Impact

### For Complete Mastery

Read sequentially from start to finish, consulting the Index and Glossary as needed.

## Conventions Used {.unnumbered}

### Code Formatting

- **Inline code** appears in `monospace font`
- **Code blocks** are syntax-highlighted and annotated:

```assembly
" This is a comment in PDP-7 assembly
lac value       " Load accumulator from location 'value'
tad constant    " Two's complement add
dac result      " Deposit (store) accumulator to 'result'
```

### Cross-References

- **File references** use the format: `filename:line` (e.g., `init.s:42`)
- **Chapter cross-references** link to relevant sections
- **Index entries** appear in **bold** on first significant use

### Octal Notation

Following PDP-7 conventions, all numbers are octal unless otherwise specified:
- `0177` = octal 177 = decimal 127
- `017777` = octal 17777 = decimal 8191
- Decimal numbers explicitly marked: `127₁₀`

### Assembly Language Syntax

PDP-7 Unix uses distinctive syntax:
- **Comments** begin with `"` (double quote) and continue to end of line
- **Labels** end with `:` (colon)
- **System calls** use `sys` directive: `sys open; filename; 0`
- **Indirect addressing** indicated by `i`: `lac i pointer`

## Acknowledgments {.unnumbered}

This work would not be possible without:

- **Ken Thompson** and **Dennis Ritchie** - creators of Unix
- **Dennis Ritchie** (posthumous) - for preserving the original source code printouts
- **Warren Toomey** and the **Unix Heritage Society (TUHS)** - for Unix archaeology and preservation
- **The pdp7-unix project contributors** - for resurrecting Unix from scanned printouts
- **The Computer History Museum** - for making the source code publicly accessible
- **Digital Equipment Corporation** - for creating the PDP-7 computer
- **The retrocomputing community** - for keeping this history alive

## License and Usage {.unnumbered}

The original PDP-7 Unix source code is released under multiple historical licenses:

- **Caldera License** - Covering ancient Unix versions
- **Historical research** - Source code available for educational purposes

This documentation is released under the **Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0)**. You are free to:

- **Share** - copy and redistribute the material
- **Adapt** - remix, transform, and build upon the material

Under the following terms:

- **Attribution** - You must give appropriate credit
- **ShareAlike** - Distribute derivative works under the same license

## Note on Historical Accuracy {.unnumbered}

This documentation is based on:

1. **Original source code** scanned from printouts dated 1970-1971
2. **DEC PDP-7 technical manuals** from the 1960s
3. **Historical research** by computer historians
4. **Modern reconstruction** through the pdp7-unix project

Every effort has been made to ensure technical accuracy. Where historical records are ambiguous or incomplete, this is noted in the text.

## Version Information {.unnumbered}

- **Documentation Version**: 1.0
- **Source Code**: PDP-7 Unix (circa 1970, commit 16fdb21)
- **Repository**: unix-history-repo
- **Documentation Date**: November 2025

---

*"A language that doesn't affect the way you think about programming is not worth knowing."*
— Alan Perlis

*"Unix is simple. It just takes a genius to understand its simplicity."*
— Dennis Ritchie

*"One of my most productive days was throwing away 1000 lines of code."*
— Ken Thompson
