
<p align="center">
<div align="center">
  
  # Py2eZ80
<img src=image_banner.png />

### Python To ez80 Assembly Converter for the Ti84+CE

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

[Overview](#overview) | [Why Py2eZ80](#why-py2ez80) |[Dependancies and Getting Started](#getting-started) | [Language Support](#language-support) | [Testing](#test) | [Building it Thyself](#building-from-source) | [Architecture](#architecture) | [License](#license)

</div>

---

## Overview

Py2eZ80 is an Ahead-of-Time (AOT) transpiler built in D. It takes a Python .py file in and then produces your .8xp out. Instead of directly compiling python to assembly, it transpiles it to C and then calls the CEdev toolchain.

Instead of running a large (and slow) interpereter on the calculator, or doing how the Ti84+CE Python Edition does (having a secondary chip for interpereting,) it directly converts python to an .8xp, giving you the ease of a simple language like python while allowing it still to be compiled and fast.

---

## Why Py2eZ80?

Writing C or C++ for the TI-84 Plus CE gives you peak performance, but it can be a hard ask, since a lot of people are more used to python, and python can be considered a much easier program to code in. py2ez80 gives the best of both worlds, python for coding and C/asm for running!

| Feature | TI Python (on ONLY select models) | Py2eZ80 Transpiler |
| --- | --- | --- |
| **Ran by** | An on-calc interpereter that is further bottlenecked by being on a seperate chip  | Really fast Assembly |
| **Speed** | Slow and bottlenecked | As fast as the ez80 goes! |
| **Dependencies** | Requires TI Python OS app + A calc that supports it | Ability to run ASM |
| **RAM Usage** | Lots (because of interpereting) | None (if archiving) |

---

## Getting Started

Py2eZ80 uses the CEdev Toolchain to outsource the direct assembly conversion, most probably because I am not intelligent enough to touch that stuff.

>  **Note:** The [Releases](https://github.com/Voblit/py2ez80/releases) page only provides EXEs for windows users. Although windows is obviously the better OS, I get that some may want to run it on other operating systems, and thus need to [build it on your own time](#building-from-source).

### 1. Requirements

* **Py2eZ80**: Download `py2ez80.exe` directly from [Releases](https://github.com/Voblit/py2ez80/releases).
  
* **Linux / macOS:** Install [DMD](https://dlang.org/) and see [how to diy it](#building-from-source) below.
  
* **CEdev SDK:** Download the [CEdev toolchain](https://github.com/CE-Programming/toolchain/releases).

### 2. Setting Up the `CEdev` Folder

Py2eZ80 expects the CEdev toolchain to exist in a folder named `CEdev` inside whatever directory it resides in.

1. Download the CEdev toolchain, please make it a new one because the code is quite fragile and might die if the folders are configured.
2. Put the CEdev folder right next to py2ez80! 
3. Make sure your folder looks like this:

**Windows:**

```text
py2ez80/
├── CEdev/
│   ├── cedev.bat
│   ├── build_project/
│   └── ...
├── py2ez80.exe
├── ...
└── README.md
```

**Linux / macOS:**

```text
py2ez80/
├── CEdev/
│   ├── build_project/
│   └── ...
├── py2ez80
├── ...
└── README.md
```
---

## Language Support

### Syntax & Control Flow

* [x] Global and local variables
* [x] math operations (`+=`, `-=`, `*=`, `/=`)
* [x] Conditions (`if`, `elif`, `else`)
* [x] Loops (`while` loops and `for` loops using `range()`)
* [x] Loop control (`break`, `continue`, `pass`)
* [x] Custom functions, parameters, and recursion
* [x] **Primitives:** `int`, `float`, `bool`, `str`
* [x] **Lists:** Regular list that support operations on them like `.append()`
* [x] **Tuples:** Uneditable arrayd
* [x] **Dictionaries & Sets** 
* [x] **Classes** 
* [x] `print()`: Prints text to the screen
* [x] `input()`: Uses getkey
* [x] `len()`: Check array length
#### THERE ARE ONLY TWO SUPPORTED LIBRARIES (CURRENTLY). MORE ARE COMING SOON.
* [x] `import math`: Allows for math 
* [x] `import random`: Allows for random functions
* [x] Exceptions (`try`, `except`, `finally`, `raise`)
---

## Test

an easy way to see the capabilities of Py2eZ80, and get to learn how it works, is to try a small sample program.

### 1. Get the `py2ez80` program

* **Windows:** Download `py2ez80.exe` from [Releases](https://github.com/Voblit/py2ez80/releases).
* **Linux / macOS:** Build from source (see [Building from Source](https://www.google.com/search?q=%23building-from-source)).

### 2. Write a Python Script

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

### 3. Build

Run Py2eZ80:

**Linux / macOS:**

```bash
./py2ez80 demo.py

```

**Windows:**

```powershell
.\py2ez80.exe demo.py

```

#### CLI Options

* **Magical Wizard Mode:** Run without arguments or add `--wizard`:
```bash
./py2ez80 --wizard

```


* **Transpile to C Only (`--only-c`):** Generates `.c` code without calling the CEdev toolchain and getting an `.8xp`:
```bash
./py2ez80 --only-c demo.py

```


* **Multi-file Processing (`--multi`):** do multiple programs at once:
```bash
./py2ez80 --multi script1.py script2.py

```



### 4. Output

Py2eZ80 will transpile your Python code, construct a C project, run the CEdev compiler, and output a native `.8xp` file to the root of the folder it is in:

```text
[1/4] Transpiling demo.py -> CEdev/build_project/src/main.c...
[2/4] Invoking CEdev toolchain for DEMO...
[3/4] Copying DEMO.8xp to root project directory...
[4/4] Success! Final calculator output: /path/to/wherever/py2ez80/is/DEMO.8xp

```

Transfer `DEMO.8xp` to your TI-84 Plus CE, and run it!

---

## Building from Source

Because I am a lazy bum and cannot provide linux/macOS binaries, you need to make them yourselves!

### Requirements

Install the **DMD** compiler (or `dlang` package via your package manager):

```bash
# Linux (Ubuntu / Debian)
sudo apt install dmd

# macOS (Homebrew)
brew install dmd

```

### Compiling `py2ez80`

1. Clone the repository:
```bash
git clone https://github.com/Voblit/py2ez80.git
cd py2ez80

```


2. Build it using `rdmd`:
**Linux / macOS:**
```bash
rdmd --build-only -of=py2ez80 src/main.d src/lexer.d src/parser.d src/ast.d src/codegen.d && rm -f py2ez80.o

```


**Windows (PowerShell):**
```powershell
rdmd --build-only -of=py2ez80 resource.res src/main.d src/lexer.d src/parser.d src/ast.d src/codegen.d
Get-ChildItem *.obj, *.o -ErrorAction SilentlyContinue | Remove-Item -Force

```
*(add the file extension .exe afterwards)*

3. Make sure the executable has run permissions (Linux/macOS):
```bash
chmod +x py2ez80

```



---

## Architecture

The final compiled program is split up into these source files:

```text
src/
├── main.d         # the band director, CLI doer, and a magical wizard
├── lexer.d        # Lexical analyzer
├── parser.d       # Abstract Syntax Tree maker
├── ast.d          # Strongly-typed AST
└── codegen.d      # C code generator

```

---

## License

This project is licensed under the [MIT LICENSE](https://opensource.org/license/mit).
