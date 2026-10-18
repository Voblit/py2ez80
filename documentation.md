
# py2ez80 reference

This is a guide to help you get aclimitized to the difference between py2ez80-transpiled-python and normal python.

---

## 1. Key Differences 

Because Py2eZ80 transpiles to C before compiling to ez80 machine code, there are some key differences.

* **Static Type Inference:** Variables are statically typed during compilation based on their initial assignment (`int`, `float`, `const char*`, or static arrays). You cannot dynamically change a variable's type later unless you use `string()`, `float()`, or `int()`.
* **Fixed-Size Lists & Arrays:** Lists and tuples must be initialized with fixed sizes. Dynamic resizing (`append`) has small amount of overhead on runtime, so use sparsely.
* **No Dynamic Dictionaries/Sets:** `dict` and `set` constructs parse safely into stubs (`NULL`) for compatibility, but are not fully implemented as dynamic hash maps.

---

## 2. Example syntax

### Variables & Assignment

```python
x = 10
name = "Hello"
pi = 3.14159

```

### Control Flow

```python
if x > 5:
    print("Greater")
elif x == 5:
    print("Equal")
else:
    print("Smaller")
i = 0
while i < 10:
    i += 1
for i in range(0, 10):
    print(i)

```

### Functions

```python
def add(a, b):
    return a + b

result = add(5, 3)

```
## 3. List of supported python features
the current python features are supported: 
* [x] Global and local variables
* [x] math operations (`+=`, `-=`, `*=`, `/=`)
* [x] Conditions (`if`, `elif`, `else`)
* [x] Loops (`while` loops and `for` loops using `range()`)
* [x] Loop control (`break`, `continue`, `pass`)
* [x] Custom functions, parameters, and recursion
* [x] **Primitives:** `int`, `float`, `bool`, `str`
* [x] **Lists:** Regular list that support operations on them like `.append()`
* [x] **Tuples:** Uneditable arrays
* [x] **Dictionaries & Sets** 
* [x] **Classes** 
* [x] `print()`: Prints text to the screen
* [x] `input()`: Uses getkey
* [x] `len()`: Check array length
* [x] `import [program name]`: this allows you to import any python program in the project folder. The inbuilt math and random imports are still there. Keep in mind that any imported program must still be compatible with this list, as it is also transpiled.
* [x] Exceptions (`try`, `except`, `finally`, `raise`)
* [x] Graphics Library: explained below.
* [x] Variable conversions: Convert variables from one variable type to another using `int()`, `float()`, or `str()`
---
---
## 4. The `graphics` Library Reference

Importing `graphics` lets you create colorful graphics and whole games!

| Python | The Transpiled C | Description |
| --- | --- | --- |
| `graphics.init()` | `gfx_Begin(); gfx_SetDrawBuffer();` | Initializes palettized graphics. |
| `graphics.end()` | `gfx_End();` | puts graphics back to normal after program end. |
| `graphics.swap()` | `gfx_SwapDraw();` | Swaps the graphics buffer with the onscreen display. |
| `graphics.fill(color)` | `gfx_FillScreen(color);` | Fills the entire screen with the specified palette color index (0–255). |
| `graphics.color(color)` | `gfx_SetColor(color);` | Sets the active drawing color index for shapes and lines. |
| `graphics.set_rgb(idx, r, g, b)` | `gfx_palette[idx] = gfx_RGBTo1555(r, g, b);` | Assigns a custom 24-bit RGB color to a specific palette index. |
| `graphics.rect(x, y, w, h)` | `gfx_Rectangle(x, y, w, h);` | Draws an unfilled rectangle at `(x, y)` with width `w` and height `h`. |
| `graphics.circle(x, y, r)` | `gfx_Circle(x, y, r);` | Draws an unfilled circle centered at `(x, y)` with radius `r`. |
| `graphics.line(x1, y1, x2, y2)` | `gfx_Line(x1, y1, x2, y2);` | Draws a straight line from `(x1, y1)` to `(x2, y2)`. |
| `graphics.text(str, x, y)` | `gfx_PrintStringXY(str, x, y);` | Renders text string at coordinate (x, y). |
| `graphics.text_color(color)` | `gfx_SetTextFGColor(color)` | Changes color of text. |

---

## 4. Built-in TI Functions

* `os_ClrHome()`: Clears the text home screen.
* `os_GetCSC()`: Polls the keypad for any keypress (returns a number for different keys, I haven't been able to record all of them so it will require your own testing). Non-blocking.

---
