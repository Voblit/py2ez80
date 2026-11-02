# py2ez80 reference

This is a guide to help you get aclimitized to the difference between py2ez80-transpiled-python and normal python.

---

## 1. Key Differences 

Because Py2eZ80 transpiles to C before compiling to ez80 machine code, there are some key differences.

Variables are statically typed *but* can be converted to other types using `str()`, `float()`, or `int()`. A variable keeps the type of the first value it is assigned, so don't store a string in something that started out as a number. Lists and tuples are fixed-size arrays by default, and dynamic resizing via `append` has overhead at runtime, so use it sparingly instead of pretending you are in an actual python enviroment (see the Lists section for exactly when you get a fixed array and when you get a growable list). `dict` and `set` constructs parse safely into stubs (`NULL`) so old programs don't explode, but they are not fully implemented as dynamic hash maps. A random quirk I also noticed is that it occasionally spits out an error for some nested empty lines and comments, so try to avoid them, and if the program starts screaming at you, remove all of those blank lines and comments before making an issue on this repo.

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

### Strings

```python
name = "Hello"
first = name[0]
if first == "H":
    print(name + " world")
print("score: " + str(42))
n = int("123")
size = len(name)

```

### Lists

```python
MAX = 50
table = [0] * MAX
table[3] = 7
words = []
words.append("hi")
words.append("there")
print(len(words), words[1])
last = words.pop()

```

### Exceptions

```python
try:
    raise 1
except:
    print("caught")
finally:
    print("done")

```

---

## 3. List of supported python features
the current python features are supported: 
* [x] Global and local variables
* [x] math operations (`+`, `-`, `*`, `/`, `//`, `%`) and the shortcuts (`+=`, `-=`, `*=`, `/=`)
* [x] Comparisons and logic (`==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`)
* [x] Conditions (`if`, `elif`, `else`)
* [x] Loops (`while` loops and `for` loops using `range()`)
* [x] Loop control (`break`, `continue`, `pass`)
* [x] Custom functions, parameters, and recursion
* [x] **Primitives:** `int`, `float`, `bool`, `str`
* [x] **Strings:** indexing (`s[i]`), comparing (`==`, `!=`, `<`, ...), joining with `+` / `+=`, `len()`, and `\n` / `\t` escapes
* [x] **Lists:** Regular list that support operations on them like `.append()` and `.pop()`, plus `len()`, indexing and preallocating with `[0] * N`
* [x] **Tuples:** Uneditable arrays
* [x] **Dictionaries & Sets** (stubs only, see Key Differences)
* [x] **Classes** (partial: class definitions parse, but methods and attributes are very limited)
* [x] `print()`: Prints text to the screen. Several values are printed on one line separated by spaces
* [x] `input()`: Asks for text on the home screen (shows a `:` prompt) and gives it back as a string
* [x] `len()`: Check array, list or string length
* [x] `import [program name]`: this allows you to import any python program in the project folder. The inbuilt math and random imports are still there. Keep in mind that any imported program must still be compatible with this list, as it is also transpiled.
* [x] Exceptions (`try`, `except`, `finally`, `raise`)
* [x] Graphics Library: explained below.
* [x] Variable conversions: Convert variables from one variable type to another using `int()`, `float()`, or `str()`
* [x] Any other TI C function (like `os_GetCSC()`) can be called directly, explained below.
---

## 4. Details & limits

### Numbers
* `int` is the calculator's native 24-bit integer, so it goes from -8,388,608 to 8,388,607 and wraps around past that.
* `float` is single precision (about 7 digits). Printing a float always shows 6 decimals, e.g. `3.140000`.
* `/` between two ints cuts off the decimals like C does (`7 / 2` is `3`). `//` does the same on purpose. If you want real division, convert one side: `float(7) / 2`.
* `True` and `False` are just `1` and `0`. `print(True)` and `print(False)` still show the words.
* `**`, `in`, `is`, and one-line `x if y else z` are not supported yet.

### Strings
* Comparing strings with `==`, `!=`, `<`, etc. compares the text, like in Python.
* `s[i]` gives back a one-character string.
* Adding a number to a string converts it for you: `"score: " + 5` works. You can also use `str()` yourself.
* `int("12")` and `float("1.5")` turn text into numbers.
* Strings made by `+`, `str()` and `input()` take up memory that is only given back when the program ends. Building a long string one character at a time in a big loop can run the calculator out of memory.

### Lists
* A list at the top of your program like `[1, 2, 3]`, or `[0] * N` where `N` is a number or a constant you set once at the top (like `MAX_TABLE = 200`), becomes a fixed-size array. Arrays can be up to 2000 items. This is the fastest and safest kind.
* `[]`, any list you call `.append()` on, any list made inside a function, and `[0] * n` where `n` is not a constant become growable lists. These support `.append(x)`, `.pop()`, `len(x)`, `x[i]` and `x[i] = y`.
* `x[i] += 1` is not supported, write `x[i] = x[i] + 1`.
* There is no bounds checking. Reading or writing past the end of a list or array does not raise `IndexError`, it quietly overwrites other memory and can crash the calculator or CEmu. Check your indexes yourself.
* `for x in my_list` is not supported, use `for i in range(len(my_list))` or a `while` loop. `range()` takes one or two arguments (no step).
* `len()` on a fixed array only works on arrays defined at the top of your program, not on ones passed into a function. Pass the length as a parameter instead.
* A list that mixes different types (like `[1, "a", 2.5]`) switches the whole program into a slower tagged-value mode. Avoid it if you can.

### Functions & variables
* You don't write types. Each parameter takes its type from what you pass in the first time you call the function, and the return type comes from what you return. Always call a function with the same kinds of values. A parameter of a function that is never called is treated as an `int`.
* Variables made inside a function are local to it, so recursion is safe.
* A variable that is set at the top of your program is a global, and functions that assign to it change the global. You can still write `global x` like in normal python.
* Functions can be defined in any order, and call each other freely.
* Not supported: default arguments, keyword arguments (`f(x=1)`), `*args`, `lambda`, and functions inside functions.
* A function that has no `return` gives back `0`.

### Printing
* `print(a, b, c)` prints everything on one line with spaces between, then a new line.
* Lists print like `[1, 2, 3]`.
* The screen is 26 characters wide, so longer lines wrap.

### Exceptions
* `try`, `except`, `finally` and `raise` work, with one `except` block per `try`. `raise` takes a number (an error code), for example `raise 1`. The number is not used for anything, it just jumps to the `except` block.
* The name after `except` (like `except ValueError:`) is accepted but ignored, so every `except` catches everything. `except ... as e` is not supported.
* Don't nest `try` blocks inside each other, and avoid `return` inside a `try`. All of them share one jump point.

### Imports
* `import math` gives you `math.sqrt(x)` (and returns a float).
* `import random` gives you `random.seed(n)`, `random.randint(a, b)` (both ends included) and `random.random()` (a float from 0 to 1). Without `random.seed()` you get the same numbers every time you start the program.
* Importing one of your own programs (`import mytools`) makes `mytools.func()` available. Functions in an imported program should only take and return whole numbers, because the header file generated for them only knows about `int`.

---
---
## 5. The `graphics` Library Reference

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
| `graphics.text(str, x, y)` | `gfx_PrintStringXY(str, x, y);` | Renders text string at coordinate (x, y). Accepts string expressions too, like `graphics.text("SCORE " + str(score), 10, 10)`. |
| `graphics.text_color(color)` | `gfx_SetTextFGColor(color)` | Changes color of text. |
| `graphics.sprite(w, h, data)` | `gfx_MallocSprite(w, h)` + copy | Makes a sprite from a list of palette indices (`w * h` numbers). Gives back the sprite. |
| `graphics.draw(s, x, y)` | `gfx_Sprite(s, x, y);` | Draws a sprite at `(x, y)`. |
| `graphics.draw_t(s, x, y)` | `gfx_TransparentSprite(s, x, y);` | Draws a sprite, skipping every pixel that uses the transparent color. |
| `graphics.transparent(color)` | `gfx_SetTransparentColor(color);` | Sets which palette index counts as see-through for `draw_t` and `scale_t`. |
| `graphics.scale(s, x, y, sw, sh)` | `gfx_ScaledSprite_NoClip(...)` | Draws a sprite made `sw` times wider and `sh` times taller. |
| `graphics.scale_t(s, x, y, sw, sh)` | `gfx_ScaledTransparentSprite_NoClip(...)` | Same as `scale`, but with transparency. |
| `graphics.flip_x(s)` | `gfx_FlipSpriteX(s, out)` | Gives back a new sprite flipped left to right. |
| `graphics.flip_y(s)` | `gfx_FlipSpriteY(s, out)` | Gives back a new sprite flipped top to bottom. |
| `graphics.rotate(s)` | `gfx_RotateSpriteC(s, out)` | Gives back a new sprite turned 90 degrees clockwise. |
| `graphics.get_sprite(x, y, w, h)` | `gfx_GetSprite(s, x, y)` | Copies a `w` by `h` piece of the screen into a new sprite. |
| `graphics.free(s)` | `free(s);` | Gives a sprite's memory back. Only for sprites made with `sprite`, `get_sprite`, `flip_x`, `flip_y` or `rotate`, never for ones from `load`. |
| `graphics.load("name")` | `((gfx_sprite_t*)name)` | Gets a sprite made by `convimg` (see below) by the name it has in your `gfx` folder. |
| `graphics.palette("name")` | `gfx_SetPalette(name, sizeof_name, 0);` | Switches to a palette made by `convimg`. |

### Sprites

A sprite is a small picture made of palette colors. You write it as a plain list of palette indices (the same numbers you give to `graphics.set_rgb` and `graphics.color`), going left to right, top to bottom.

```python
import graphics
BALL = [0, 0, 3, 3, 3, 3, 0, 0, 0, 3, 2, 4, 4, 4, 3, 0, 3, 4, 4, 4, 4, 4, 4, 3, 3, 4, 4, 5, 5, 4, 4, 3, 3, 4, 4, 5, 5, 4, 4, 3, 3, 4, 4, 4, 4, 4, 4, 3, 0, 3, 4, 4, 4, 4, 3, 0, 0, 0, 3, 3, 3, 3, 0, 0]
graphics.init()
graphics.set_rgb(3, 200, 60, 60)
graphics.transparent(0)
ball = graphics.sprite(8, 8, BALL)
graphics.draw_t(ball, 20, 60)
graphics.swap()

```

* The data has to be a list variable, like `BALL` above. Writing the list straight inside `graphics.sprite(...)` is not supported.
* A sprite can be up to 255 by 255. If the list is shorter than `w * h`, the rest of the sprite is filled with color `0`.
* Call `graphics.transparent(0)` (or whatever index you want see-through) before using `draw_t` or `scale_t`.
* `graphics.draw` and `graphics.draw_t` are clipped, so it is safe to draw partly off the screen. `graphics.scale` and `graphics.scale_t` are not clipped, so they skip drawing completely when the scaled sprite would not fit on the screen.
* Sprites take up memory that stays used until you call `graphics.free(s)`. Make them once at the start, not every frame in a loop, and free ones you are done with.
* Sprites can be passed into and returned from your own functions like any other value.

### Sprites from images (convimg)

If you would rather draw your sprites as PNG files, py2ez80 can use the toolchain's `convimg` tool for you.

1. Make a folder called `gfx` next to your `.py` file.
2. Put your PNG files in it, together with a `convimg.yaml` that says how to convert them. This one makes a sprite called `ball` out of `ball.png`:

```yaml
palettes:
  - name: global_palette
    fixed-entries:
      - color: {index: 0, r: 255, g: 0, b: 128}
      - color: {index: 1, r: 255, g: 255, b: 255}
    images: automatic

converts:
  - name: sprites
    palette: global_palette
    transparent-color-index: 0
    images:
      - ball.png

outputs:
  - type: c
    include-file: gfx.h
    palettes:
      - global_palette
    converts:
      - sprites

```

3. Use them in your program. A sprite is named after its image file, so `ball.png` becomes `"ball"`.

```python
import graphics
graphics.init()
graphics.palette("global_palette")
graphics.transparent(0)
graphics.fill(1)
ball = graphics.load("ball")
graphics.draw_t(ball, 40, 60)
graphics.swap()

```

* When your program uses `graphics.load` or `graphics.palette`, py2ez80 copies the `gfx` folder into the build and runs `convimg` for you before compiling. Programs that don't use them ignore the folder completely.
* The names you pass in have to match your `convimg.yaml` exactly. `graphics.palette` takes the palette name and `graphics.load` takes the image name, both as plain strings (not variables).
* A loaded sprite works with every sprite call above (`draw`, `draw_t`, `scale`, `flip_x` and so on).
* Never call `graphics.free` on a loaded sprite. It lives inside your program, not in the free memory.
* `graphics.palette` replaces the whole palette, so colors you set earlier with `graphics.set_rgb` may change. Do it right after `graphics.init()`.
* Only the plain C output of `convimg` is supported. AppVar and compressed outputs, and tilemaps, are not.

---

## 6. Built-in TI Functions

* `os_ClrHome()`: Clears the text home screen.
* `os_GetCSC()`: Polls the keypad for any keypress (returns a number for different keys, I haven't been able to record all of them so it will require your own testing). Non-blocking.
* Any other function name that is not defined in your program and is not built in is sent to the C compiler as a direct call, with your arguments passed as they are. That means other CEdev functions work too as long as they take and return whole numbers, for example `os_GetCSC()`.

---

## Extra Misc. Notes

* If it ever screams: `make: *** No rule to make target `src\gfx\gfx.h', needed by `obj/src/main.c.bc'.  Stop.`, then run a command (varies depending on OS, of course,) to delete `CEdev\build_project\obj`.

---
