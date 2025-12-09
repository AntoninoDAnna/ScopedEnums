# EnumClasses.jl
Porting to Julia of enum classes in C++. 

This package introduce the `abstract type EnumClass`, as subtype of `Enum`, asn the macro `@enumclass` that generated enums value with similar behavior as `enum class` in C++. `EnumClass` types are Scoped Enums with overloaded bitwise operators to easily allow bitflags in Julia like in C++. This class solves the two main throwback of `@enum`, which is, two differents enums type cannot have the same enum value, and the enum values cannot be used, out of the box, in bitwise operations. 

This package  merges the ideas of two popular packages [EnumX.jl](https://github.com/fredrikekre/EnumX.jl) and [BitFlags.jl](https://github.com/jmert/BitFlags.jl). 

As in `EnumX.jl`, `@enumclass` defines a module in which it defines the enum values. As in `BitFlags.jl`, bitwise operator are oveloaded to accept also `EnumClass` object. 

To use the package, first add it to the your Registry

``` julia

julia> import Pkg
julia> Pkg.add(https://github.com/AntoninoDAnna/EnumClasses.jl.git)

```

Then you can used as

``` julia

julia> using EnumClasses

julia> @enumclass Fruits apple=1 orange=2 kiwi=3

julia> f(x::Fruits.Type) = "I'm a Fruit with value: \$(Int(x))"
f (generic function with 1 method)

julia> f(Fruits.apple)
"I'm a Fruit with: 1"

julia> Fruits.apple
apple::Type = 1

julia> Fruits.Type
EnumClass Main.Fruits.Type:
apple = 1
orange = 2
kiwi = 3

julia> print(typeof(Fruits.apple))
Main.Fruits.Type
```
    
As shown in the last line, the type of `Fruits.apple` is `Fruits.Type`, this is due to the fact the `Fruits` is a module  and therefore it cannot be a type.

Additionally, the EnumClasses can also be used as bit-flags ase

``` julia

julia> @enumclass WindowFlag::UInt32 begin
           Fullscreen         =  0x00000001
           #...
           Maximized          =  0x00000080
           #...
       end

julia> flag::UInt32 = 0x0;

julia> flag |= WindowFlag.Fullscreen | WindowFlag.Maximized
0x00000081

julia> is_fullscreen = (flag & WindowFlag.Fullscreen)!=0x0
true

julia> is_maximixed = (flag & WindowFlag.Maximized) != 0x0
true

julia> #unset WindowFlag.Maximized
       flag = flag & (~WindowFlag.Maximized)

0x00000001

julia> is_fullscreen = (flag & WindowFlag.Fullscreen)!=0x0
true

julia> is_maximixed = (flag & WindowFlag.Maximized) != 0x0
false

```
