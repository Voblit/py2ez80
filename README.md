<div align="center">

# Py2eZ80

### Ahead-of-Time Python Transpiler and Native SDK for the TI-84 Plus CE

<p align="center">
  <a href="https://github.com/Voblit/py2ez80/actions">
    <img src="https://img.shields.io/github/check-runs/Voblit/py2ez80/main?label=build&logo=github&style=for-the-badge" />
  </a>
  <img src="https://img.shields.io/badge/Written%20In-D-BA595E?style=for-the-badge&logo=d" />
  <img src="https://img.shields.io/badge/Source-Python_3-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/Target-eZ80_CPU-FF6F00?style=for-the-badge" />
  <a href="https://github.com/Voblit/py2ez80">
    <img src="https://img.shields.io/github/languages/code-size/Voblit/py2ez80?style=for-the-badge" />
  </a>
  <a href="https://github.com/Voblit/py2ez80/releases">
    <img src="https://img.shields.io/github/downloads/Voblit/py2ez80/total?color=brightgreen&style=for-the-badge" />
  </a>
  <a href="https://github.com/Voblit/py2ez80/stargazers">
    <img src="https://img.shields.io/github/stars/Voblit/py2ez80?style=for-the-badge" />
  </a>
  <a href="https://github.com/Voblit/py2ez80/releases/latest">
    <img src="https://img.shields.io/github/v/release/Voblit/py2ez80?include_prereleases&style=for-the-badge" />
  </a>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

*Compile standard Python scripts directly into bare-metal binary .8xp executables.*

[Overview](#overview) | [Why Py2eZ80](#why-py2ez80) | [Prerequisites and Dependencies](#prerequisites-and-dependencies) | [Features](#features) | [Language Support](#language-support) | [Quickstart](#quickstart) | [Architecture](#architecture) | [License](#license)

</div>

---

## Overview

Py2eZ80 is an Ahead-of-Time (AOT) transpiler built in D. It translates a practical subset of Python directly into optimized C code targeting the Zilog eZ80 processor inside the TI-84 Plus CE calculator.

By eliminating the need for an on-device Python interpreter (such as MicroPython or CPython), Py2eZ80 delivers the expressiveness and rapid development workflow of Python with the raw execution speed, low memory footprint, and instant startup times of native C applications.

```text
+-----------------+       +-----------------+       +-----------------+       +-----------------+
|  Python Source  |  -->  |     Py2eZ80     |  -->  |   eZ80 C Code   |  -->  |  CEdev Toolchain|  --> .8xp Native Binary
|   (script.py)   |       | (Lex/Parse/Gen) |       |    (main.c)     |       | (External Dep.) |      (Runs directly)
+-----------------+       +-----------------+       +-----------------+       +-----------------+
```

---

## Why Py2eZ80

| Metric / Feature | Standard TI Python | Py2eZ80 Transpiler |
| --- | --- | --- |
| Execution Engine | On-Calculator Interpreter | Bare-Metal Native Binary |
| Startup Time | Slow (Loads runtime into RAM) | Instant (Under 1 ms) |
| Execution Speed | Interpreted / Indirect | Maximum Hardware Capability |
| Dependencies | Requires Python App on Calc | Zero Dependencies (Standalone .8xp) |
| Memory Footprint | High Memory Overhead | Minimal RAM Allocation |
| Hardware Control | Sandboxed API | Direct TI OS and Hardware Access |

---

## Prerequisites and Dependencies

Py2eZ80 is an AOT code generator that produces standard C code. It relies on the official CEdev toolchain to perform final C compilation, linking, and packaging into the TI .8xp format.

### Important: CEdev Dependency

CEdev is a required external dependency and IS NOT bundled with Py2eZ80. You must install the CEdev SDK separately on your machine prior to compiling Python projects.

1. D Compiler: DMD or LDC2 installed and added to PATH.
2. CEdev Toolchain: Download and install the [CEdev C/C++ SDK](https://github.com/CE-Programming/toolchain). Place or link the `CEdev` folder in your project path or install it globally so `cedev.bat` / `cedev-config` is available.

---

## Features

* Zero Interpreter Overhead: Emits lightweight C C99 code compiled to machine instructions.
* Automated Compilation Pipeline: Automatically parses Python, generates custom project Makefiles, invokes the CEdev toolchain, and outputs a standalone .8xp binary in one command.
* Automated Variable Truncation: Automatically truncates program base names to meet the TI OS limit of 8 characters maximum (e.g., `test_space_invaders.py` translates to `TEST_SPA.8xp`).
* Dynamic Type Tracking: Tracks primitive integer types, floating-point literals, dynamic character strings, and arrays.
* Structured OOP Lowering: Translates Python class architectures into C `typedef struct` models.
* Exception Runtime Engine: Lowers Python `try`, `except`, `finally`, and `raise` structures into native `setjmp` and `longjmp` execution frames.
* Standard Library Mapping: Translates `import math` directly to optimized hardware routines in `<math.h>`.

---

## Language Support

### Syntax and Control Flow

* [x] Global and local variable assignments
* [x] Compound arithmetic assignments (`+=`, `-=`, `*=`, `/=`)
* [x] Conditional logic (`if`, `elif`, `else`)
* [x] `while` loops and `for` loops using `range()`
* [x] Flow control keywords (`break`, `continue`, `pass`)
* [x] Functions, argument passing, and recursive calls

### Types and Data Structures

* [x] Primitives: `int`, `float`, `bool`, `str`
* [x] Lists: Array lowering with method call support (`append()`)
* [x] Tuples: Fixed-length array structures
* [x] Dictionaries and Sets: Struct pointer abstractions
* [x] Classes: Structure definition mapping

### Built-ins and Modules

* [x] `print()`: Mapped to formatted C output (`printf`)
* [x] `input()`: String buffer capture
* [x] `len()`: Static array length calculation
* [x] `import math`: Mapped to standard system header `<math.h>`
* [x] Exception handling (`try`, `except`, `finally`, `raise`)

---

## Quickstart

### 1. Build the Compiler

Clone the repository and build the executable using DMD:

```powershell
git clone https://github.com/Voblit/py2ez80.git
cd py2ez80

Get-ChildItem *.obj -ErrorAction SilentlyContinue | Remove-Item -Force
dmd src/main.d src/lexer.d src/parser.d src/ast.d src/codegen.d -of=py2ez80
if (Test-Path .\py2ez80) { Rename-Item .\py2ez80 py2ez80.exe }

```

### 2. Create a Python Script

Create a file named `demo.py`:

```python
import math

class Particle:
    pass

def calculate_distance(x, y):
    return math.sqrt(x * x + y * y)

print("--- Py2eZ80 Engine ---")

scores = [100, 250, 500]
player_name = "Hero"
energy = 100.0

for i in range(0, 3):
    energy -= 10.5
    scores.append(i * 50)

dist = calculate_distance(30, 40)
print("Calculated Distance:")
print(dist)

try:
    if energy < 0:
        raise 1
    print("Energy Normal!")
except:
    print("Energy Depleted!")
finally:
    print("Execution complete.")

```

### 3. Transpile and Compile

Run Py2eZ80 against your source file:

```powershell
.\py2ez80.exe demo.py

```

### 4. Pipeline Execution Output

```text
[1/4] Transpiling demo.py -> CEdev\build_project\src\main.c...
[2/4] Invoking CEdev toolchain for DEMO...
================================================================================
                    TI-84 PLUS CE DEVELOPER TOOLCHAIN
================================================================================
[compiling] src\main.c
[linking] bin\DEMO.bin
[3/4] Copying DEMO.8xp to root project directory...
[4/4] Success! Final calculator output: C:\path\to\py2ez80\DEMO.8xp

```

Transfer `DEMO.8xp` to your TI-84 Plus CE using TI Connect CE or ArTi314, press `PRGM`, and launch the binary directly.

---

## Architecture

The project is structured into modular D compilation units:

```text
src/
|-- main.d        # Command-line driver, Makefile generator, process spawner
|-- lexer.d       # Lexical analyzer converting Python source to token stream
|-- parser.d      # Recursive descent parser producing AST nodes
|-- ast.d         # Abstract Syntax Tree node class definitions
`-- codegen.d     # C code emitter, scope analyzer, and runtime preamble injector

```

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

```

