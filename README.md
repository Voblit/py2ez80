<p align="center">
<div align="center">
 
  # Py2eZ80
<img src=image_banner.png />

### Ahead-of-Time Python Transpiler and Native SDK for the TI-84 Plus CE

  <a href="https://github.com/Voblit/py2ez80/actions">
  </a>
  <img src="https://img.shields.io/badge/Written%20In-D-BA595E?logo=d" />
  <img src="https://img.shields.io/badge/Source-Python_3-3776AB?logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/Target-eZ80_CPU-FF6F00" />
  <a href="https://github.com/Voblit/py2ez80">
    <img src="https://img.shields.io/github/languages/code-size/Voblit/py2ez80" />
  </a>
  <a href="https://github.com/Voblit/py2ez80/releases">
    <img src="https://img.shields.io/github/downloads/Voblit/py2ez80/total?color=brightgreen" />
  </a>
  <a href="https://github.com/Voblit/py2ez80/stargazers">
    <img src="https://img.shields.io/github/stars/Voblit/py2ez80" />
  </a>
  <a href="https://github.com/Voblit/py2ez80/releases/latest">
    <img src="https://img.shields.io/github/v/release/Voblit/py2ez80?include_prereleases" />
  </a>
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

*Compile standard Python scripts directly into bare-metal binary .8xp executables.*

[Overview](#overview) | [Why Py2eZ80](#why-py2ez80) | [Prerequisites and Setup](#prerequisites-and-setup) | [Features](#features) | [Language Support](#language-support) | [Quickstart](#quickstart) | [Architecture](#architecture) | [License](#license)

</div>

---

## Overview

Py2eZ80 is an Ahead-of-Time (AOT) transpiler built in D. It takes standard Python code and translates it directly into optimized C99 targeting the Zilog eZ80 processor inside the TI-84 Plus CE.

Instead of running a heavy interpreter like MicroPython on the calculator, Py2eZ80 compiles your code down to native machine code on your PC before sending it over. You get the readable syntax and convenience of Python with the raw speed, small memory footprint, and instant startup times of native C programs.

```text
+-----------------+       +-----------------+       +-----------------+       +-----------------+
|  Python Source  |  -->  |     Py2eZ80     |  -->  |   eZ80 C Code   |  -->  |  CEdev Toolchain|  --> .8xp Native Binary
|   (script.py)   |       | (Lex/Parse/Gen) |       |    (main.c)     |       | (CEdev Folder)  |      (Runs directly)
+-----------------+       +-----------------+       +-----------------+       +-----------------+

```

---

## Why Py2eZ80?

Writing C or C++ for the TI-84 Plus CE gives you peak performance, but it can be tedious for quick scripts or logic-heavy apps. Py2eZ80 bridges the gap: write high-level Python on your PC, then build and run a lightweight `.8xp` file on hardware.

| Feature | Built-in TI Python | Py2eZ80 Transpiler |
| --- | --- | --- |
| **Execution Method** | Crummy On-Device interpereter | bare-metal assembly |
| **Startup Speed** | Takes a second | Instant |
| **Performance** | Interpreted (slower execution) | Full native hardware speed |
| **Dependencies** | Requires TI Python OS app and python chip | Standalone `.8xp` |
| **RAM Usage** | High usage, low given amount (because of the coprocessor for python) | Native processing, much faster |
| **Hardware Access** | Supposedly None | C libraries able to directly touch the chip |

---

## Prerequisites and Setup

Py2eZ80 compiles Python source files down to C and uses the **CEdev toolchain** behind the scenes to generate `.8xp` files.

### 1. Requirements

* **D Compiler:** [DMD](https://dlang.org/) or LDC2 installed and added to your system PATH.
* **CEdev SDK:** Download the [CEdev toolchain release](https://github.com/CE-Programming/toolchain/releases).

### 2. Setting Up the `CEdev` Folder

Py2eZ80 expects the CEdev toolchain to exist in a folder named `CEdev` inside the main `py2ez80` directory.

1. Download the latest release archive of CEdev.
2. Extract the archive contents directly into your project root as a subfolder named `CEdev`.
3. Make sure your folder looks like this:

```text
py2ez80/
├── CEdev/
│   ├── cedev.bat
│   ├── build_project/
│   └── ... (CEdev toolchain files)
├── src/
│   ├── main.d
│   ├── lexer.d
│   └── ...
├── py2ez80.exe
└── README.md

```

If `CEdev\cedev.bat` is present in that directory, Py2eZ80 can automatically handle background builds and output binary files without extra configuration.

---

## What Py2eZ80 Provides

Py2eZ80 handles the entire build process under the hood:

* **Zero-Interpreter Output:** Outputs pure C99 code to be further compiled with CEdev.
* **Automated Pipeline:** Parses Python, creates necessary Makefiles, triggers `CEdev`, and copies the final `.8xp` program all at once.
* **Name Truncation:** Shrinks names down to the max name length (8 characters) on the CE. (for example, `space_invaders.py` converts to `SPACE_IN.8xp`).
* **Data Type Mapping:** Automatically infers primitive types (`int`, `float`, `bool`, `str`), arrays, and dynamic data structures.
* **OOP Structure Lowering:** Translates Python classes into native C `struct` representations.
* **Exception Engine:** Lowers Python `try`, `except`, `finally`, and `raise` blocks into standard C `setjmp` and `longjmp` execution commands.
* **Standard Library Lowering:** Converts module calls like `import math` to standard C system headers like `<math.h>`.

---

## Language Support

### Syntax & Control Flow

* [x] Global and local variable declarations & reassignments
* [x] Compound arithmetic operations (`+=`, `-=`, `*=`, `/=`)
* [x] Conditionals (`if`, `elif`, `else`)
* [x] Loops (`while` loops and `for` loops using `range()`)
* [x] Loop control statements (`break`, `continue`, `pass`)
* [x] Custom functions, parameter passing, and recursion

### Data Structures & Types

* [x] **Primitives:** `int`, `float`, `bool`, `str`
* [x] **Lists:** Lowered array structures supporting operations like `.append()`
* [x] **Tuples:** Fixed-length immutable arrays
* [x] **Dictionaries & Sets:** Struct-backed pointer abstractions
* [x] **Classes:** Class definitions lowered to standard C structures

### Built-ins & Standard Library

* [x] `print()`: Mapped directly to formatted output routines (`printf`)
* [x] `input()`: String buffer reading
* [x] `len()`: Array length evaluation
* [x] `import math`: Maps math operations directly to native eZ80 `<math.h>` functions
* [x] Exception handling (`try`, `except`, `finally`, `raise`)

---

## Quickstart

### 1. Build the Compiler

Clone the repository, ensure your D compiler is available, and build `py2ez80`:

```powershell
git clone https://github.com/Voblit/py2ez80.git
cd py2ez80

dmd src/main.d src/lexer.d src/parser.d src/ast.d src/codegen.d -of=py2ez80
Get-ChildItem *.obj -ErrorAction SilentlyContinue | Remove-Item -Force

```

### 2. Add the CEdev Toolchain

Before transpiling your code, make sure the CEdev SDK is placed in the root directory alongside `py2ez80.exe`:

*note: if there is no .exe and it is just called py2ez80, just add the .exe extension, it will work!*
1. Download the [latest CEdev SDK release](https://github.com/CE-Programming/toolchain/releases).
2. Extract the downloaded archive directly into your `py2ez80` folder so that `py2ez80.exe` and the `CEdev` folder sit in the exact same directory:

```text
py2ez80/
├── CEdev/
│   ├── cedev.bat
│   └── ...
├── py2ez80.exe
└── ...

```

### 3. Write a Python Script

Create a script named `demo.py`:

```python
import math
import random

class Particle:
    pass

def calculate_distance(x, y):
    return math.sqrt(x * x + y * y)

print("--- Py2eZ80 Engine ---")


random.seed(42)

scores = [100, 250, 500]
player_name = "Hero"
energy = 100.0

crit_chance = random.random()
bonus_damage = random.randint(15, 50)
print("Random Crit Chance:")
print(crit_chance)
print("Random Bonus Damage:")
print(bonus_damage)

for i in range(0, 3):
    energy -= 10.5
    scores.append(i * 50 + random.randint(1, 10))

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

### 4. Transpile and Build

Run `py2ez80.exe` targeting your Python script:

```powershell
.\py2ez80.exe demo.py

```

### 5. Build Output

Py2eZ80 runs the compilation pipeline and outputs status updates directly to your terminal:

```text
2 warnings generated.
[lto opt] obj\lto.bc
[convimg] description
[linking] bin\DEMO.bin
[success] bin\DEMO.8xp, 7810 bytes.


================================================================================
                   MAKE COMPLETED, CHECK FOR ANY ERRORS ABOVE
================================================================================


Press any key to continue . . .
[3/4] Copying DEMO.8xp to root project directory...
[4/4] Success! Final calculator output: C:\path\to\py2ez80\DEMO.8xp

```

Transfer the resulting `DEMO.8xp` file to your TI-84 Plus CE using **TI Connect CE** or **TIlp**, press `PRGM`, and launch your application.

---


## Architecture

The compiler codebase is structured into clean, modular D source files:

```text
src/
├── main.d        # CLI interface, project workspace setup, process management
├── lexer.d       # Lexical analyzer for tokenizing Python source code
├── parser.d      # Recursive-descent parser producing Abstract Syntax Trees
├── ast.d         # Strongly-typed AST node structure definitions
└── codegen.d     # C code generator, type analysis, and runtime preamble injector

```

---

## License

This project is licensed under the [MIT License](https://www.google.com/search?q=LICENSE).


