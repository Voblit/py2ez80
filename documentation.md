
# py2ez80 reference

Welcome to the **Py2eZ80** reference guide. This is a guide to help you get aclimitized to the difference between py2ez80-compiled-python and normal pythonm

---

## 1. Key Differences 

Because Py2eZ80 transpiles to C before compiling to ez80 machine code, there are some key differences.

* **Static Type Inference:** Variables are statically typed during compilation based on their initial assignment (`int`, `float`, `const char*`, or static arrays). You cannot dynamically change a variable's type later.
* **Fixed-Size Lists & Arrays:** Lists and tuples must be initialized with fixed sizes. Dynamic resizing (`append`) has small amount of overhead on runtime, so use sparsely.
* **No Dynamic Dictionaries/Sets:** `dict` and `set` constructs parse safely into stubs (`NULL`) for compatibility, but are not fully implemented as dynamic hash maps.
* **Program Entry & Exit:** Execution starts at the top-level script statements (compiled into `main()`). You must explicitly handle screen updates and key polling.

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

---
## 3. The `graphics` Library Reference

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

---

## 4. Built-in TI Functions

* `os_ClrHome()`: Clears the text home screen.
* `os_GetCSC()`: Polls the keypad for any keypress (returns non-zero if a key is pressed). Non-blocking.

---