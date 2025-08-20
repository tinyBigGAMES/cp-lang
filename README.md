![E-Lang](media/e-lang.png)
[![Chat on Discord](https://img.shields.io/discord/754884471324672040?style=for-the-badge)](https://discord.gg/tPWjMwK) [![Follow on Bluesky](https://img.shields.io/badge/Bluesky-tinyBigGAMES-blue?style=for-the-badge&logo=bluesky)](https://bsky.app/profile/tinybiggames.com)  
> 🚧 **E-Lang is Work in Progress**
>
> E-Lang is currently under active development and evolving quickly. Some features described in this documentation may be incomplete, experimental, or subject to significant changes as the project matures.
>
> We welcome your feedback, ideas, and issue reports — your input will directly influence the direction and quality of E-Lang as we strive to build the ultimate modern programming language.

## C Power, Pascal Clarity

E-Lang is a modern programming language that combines **C99 semantics with Pascal-style syntax**, giving you the raw power and flexibility of C with the clean, readable elegance of Pascal.

### Why E-Lang?

- **🚀 C99 Performance** - Full access to pointers, manual memory management, and low-level system programming
- **📖 Pascal Readability** - Clean, self-documenting syntax that's easy to read and maintain  
- **🔧 Modern Features** - Variable declarations anywhere, conditional expressions, and contemporary language conveniences
- **⚡ Zero Overhead** - Compiles to efficient native code with no runtime penalties
- **🔄 Familiar Yet Fresh** - Easy transition for C and Pascal developers

## Quick Example

```pascal
#include <stdio.e>

function main(): int32
begin
    msg: string := "Hello, E-Lang!";
    count: int32 := 42;
    
    if count > 0 then
        printf("%s Count: %d\n", msg, count)
    else
        printf("Nothing to count\n");
    
    return 0;
end
```

## Key Features

### 🎯 **Hybrid Design**
- C99 logic and capabilities under the hood
- Pascal's clean, structured syntax on the surface
- Best of both worlds without compromise

### 🔧 **Rich Type System**
```pascal
// Basic types
x: int32 := 100;
y: float := 3.14;
flag: bool := true;

// Sized integers
byte_val: uint8 := 255;
big_num: int64 := 9223372036854775807;

// Pointers and arrays
ptr: ^int32;
numbers: array[10] of int32;

// Records (structs)
type Point = record
    x, y: float;
end;
```

### ⚙️ **Powerful Control Flow**
```pascal
// Modern for loops
for i := 0; i < 10; i := i + 1 do
    printf("Count: %d\n", i);

// Pascal-style for loops  
for i := 1 to 100 do
    process(i);

// Pattern matching
case value of
    1..10: printf("Small");
    11..50: printf("Medium"); 
    else printf("Large");
end;
```

### 🔗 **C99 Compatibility**
```pascal
#include <stdlib>
#define MAX_SIZE 1024

function allocate_buffer(): ^char
begin
    buffer: ^char := malloc(MAX_SIZE);
    return buffer;
end;
```

---

<div align="center">

**Built with ❤️ by [tinyBigGAMES](https://tinybiggames.com)**

*"Where systems programming meets elegance"*

</div>