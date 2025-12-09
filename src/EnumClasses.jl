module EnumClasses

import Core.Intrinsics.bitcast
export EnumClass, @enumclass

function namemap end

@doc """
    EnumClass{T} <: Base.Enum{T} where {T<Integer}

Abstract supertype for all the scoped enum defined with [`@enumclass`](@ref).
    """
abstract type EnumClass{T} <: Base.Enum{T} end

basetype(::Type{<:EnumClass{T}}) where {T<:Integer} = T
#(::Type{T})(x::EnumClass{T2}) where {T<:Integer,T2<:Integer} = T(bitcast(T2,x))::T
Base.cconvert(::Type{T}, x::EnumClass{T2}) where {T<:Integer,T2<:Integer} = T(x)::T
Base.write(io::IO, x::EnumClass{T}) where {T<:Integer} = write(io, T(x))
Base.read(io::IO, ::Type{T}) where {T<:EnumClass} = T(read(io, basetype(T)))

"""
    _enumclass_hash(x::EnumClass, h::UInt)

Compute hash for an enum value `x`. This internal method will be specialized
for every enum type created through [`@enum`](@ref).
"""
_enumclass_hash(x::EnumClass, h::UInt) = invoke(hash, Tuple{Any, UInt}, x, h)
Base.hash(x::EnumClass, h::UInt) = _enumclass_hash(x, h)
Base.isless(x::T, y::T) where {T<:EnumClass} = isless(basetype(T)(x), basetype(T)(y))

Base.Symbol(x::EnumClass) = namemap(typeof(x))[Integer(x)]::Symbol

function _symbol(x::EnumClass)
    names = namemap(typeof(x))
    x = Integer(x)
    get(() -> Symbol("<invalid #$x>"), names, x)::Symbol
end

Base.print(io::IO, x::EnumClass) = print(io, _symbol(x))

function Base.show(io::IO, x::EnumClass)
    sym = _symbol(x)
    if !(get(io, :compact, false)::Bool)
        from = get(io, :module, Main)
        def = parentmodule(typeof(x))
        if from === nothing || !Base.isvisible(sym, def, from)
            show(io, def)
            print(io, ".")
        end
    end
    print(io, sym)
end

function Base.show(io::IO, ::MIME"text/plain", x::EnumClass)
    print(io, x, "::")
    show(IOContext(io, :compact => true), typeof(x))
    print(io, " = ")
    show(io, Integer(x))
end

function Base.show(io::IO, m::MIME"text/plain", t::Type{<:EnumClass})
    if isconcretetype(t)
        print(io, "EnumClass ")
        Base.show_datatype(io, t)
        print(io, ":")
        for x in instances(t)
            print(io, "\n", Symbol(x), " = ")
            show(io, Integer(x))
        end
    else
        invoke(show, Tuple{IO, MIME"text/plain", Type}, io, m, t)
    end
end


import Base: |, &, xor, nand,nor

for op in (:|,:&,:xor,:nand,:nor)
    @eval $(op)(x::T,y::T) where {T<:EnumClass} = $(op)(basetype(T)(x),basetype(T).(y))
    @eval $(op)(x::T,y) where {T<:EnumClass} = $(op)(basetype(T)(x),y)
    @eval $(op)(x,y::T) where {T<:EnumClass} = $(op)(x,basetype(T)(y))
end

Base.:~(x::T) where {T<:EnumClass} = Base.:~(basetype(T)(x))




@noinline arg_error(x) = throw(ArgumentError(x))

# generate code to test whether expr is in the given set of values
function membershiptest(expr, values)
    lo, hi = extrema(values)
    if length(values) == hi - lo + 1
        :($lo <= $expr <= $hi)
    elseif length(values) < 20
        foldl((x1,x2)->:($x1 || ($expr == $x2)), values[2:end]; init=:($expr == $(values[1])))
    else
        :($expr in $(Set(values)))
    end
end


"""
    @enumclass Name[::BaseType] value1[=x] value2[=y]

Create a `EnumClass{Basetype}` subtype with name `Name` and enum member values of `value1` and `value2` with optional assigned values of `x` and `y`, respectively. `EnumClass` differs from regular `Enum` in being scoped in a Module called `Name`. So to refer to `value1` one as to call `Name.value1`.
The main throwback of this implementation is that `Name`, being the name of the module, cannot be used as a type. The type of the enum member is `Name.Type`

# Examples

```@jldoctest
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
WindowFlag.
`@enumclass` can be also used as bitflags. 
```@jldoctest

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
"""
macro enumclass(T::Union{Symbol,Expr}, syms...)
    isempty(syms) && arg_error(LazyString("no arguments given for EnumClass", T))

    basetype = Int32;
    typename = T;
    _T = :Type
    if isa(T,Expr) && T.head === :(::) && length(T.args) == 2 && isa(T.args[1],Symbol)
        # this deal with type defined as Train::Int64     
        typename = T.args[1]
        basetype = Core.eval(__module__,T.args[2])
        if !isa(basetype, DataType) || !(basetype<:Integer) || !(isbitstype(basetype))
            arg_error(
                LazyString("invalid base type for EnumClass ", typename, ", ",T,"=::",basetype,"; basetype must be an integer primitive type"))
        end
    elseif !isa(T,Symbol)
        arg_error(LazyString("Invalid type expression for EnumClass ",T))
    end
    modname = typename;
    values = Vector{basetype}()
    seen = Set{Symbol}()
    namemap = Dict{basetype,Symbol}()
    lo = hi = i  =  zero(basetype)
    hasexpr = false

    if length(syms) == 1 && syms[1] isa Expr && syms[1].head === :block
        syms = syms[1].args
    end
    for s in syms
        s isa LineNumberNode && continue
        if isa(s,Symbol)
            if i == typemin(basetype) && !isempty(values)
                # i start at zero(basetype), so if it get to be typemin
                # it mean that we had an overflow 
                arg_error(LazyString("overflow in value \"", s, "\" of EnumClass"))
            end
        elseif isa(s,Expr) &&
               (s.head === :(=) || s.head == :kw) &&
               length(s.args) ==2 && isa(s.args[1],Symbol)
            # this I believe allows for enums defined as a=10,
            i =Core.eval(__module__, s.args[2])

            if !isa(i, Integer)
                    arg_error(LazyString("invalid value for EnumClass ", typename, ", ", s, "; values must be integers"))
            end
            i = convert(basetype, i)
            s = s.args[1]
            hasexpr = true
        else
            arg_error(LazyString("invalid argument for EnumClass ", typename, ": ", s))
        end
        s = s::Symbol
        if !Base.isidentifier(s)
            arg_error(LazyString("invalid name for EnumClass ", typename, "; \"",s,"\" is not a valid identifier"))
        end
        if hasexpr && haskey(namemap,i)
            arg_error(LazyString("both ",s," and ", namemap[i]," have value ", i, " in EnumClass ", typename, "; values must be unique"))
        end

        namemap[i] = s
        push!(values, i)
        if s in seen
            arg_error(LazyString("name \"", s, "\" in EnumClass ", typename, "is not unique"))
        end
        push!(seen,s)
        if length(values) == 1
            lo = hi = i
        else
            hi = max(hi,i)
        end
        i += oneunit(i)
    end
    blk = quote
        import Base
        primitive type $(esc(_T)) <: EnumClass{$(basetype)} $(sizeof(basetype) * 8) end
        function $(esc(_T))(x::Integer)
            $(membershiptest(:x,values)) || args_error($(Expr(:quote, typename)), x)
            return bitcast($(esc(_T)), convert($(basetype),x))
        end
        EnumClasses.namemap(::Type{$(esc(_T))}) = $(esc(namemap))
        Base.typemin(x::Type{$(esc(_T))}) = $(esc(_T))($lo)
        Base.typemax(x::Type{$(esc(_T))}) = $(esc(_T))($hi)
        let type_hash = hash($(esc(_T)))
            # Use internal `_enum_hash` to allow users to specialize
            # `Base.hash` for their own enum types without overwriting the
            # method we would define here. This avoids a warning for
            # precompilation.
            EnumClasses._enumclass_hash(x::$(esc(_T)), h::UInt) = hash(type_hash, hash(Integer(x), h))
        end
        let inst = (Any[ $(esc(_T))(v) for v in $values]...,)
            Base.instances(::Type{$(esc(_T))}) = inst
        end
    end
    if isa(typename,Symbol)
        for (i,sym) in namemap
            push!(blk.args,:(const $(esc(sym)) = $(esc(_T))($i)))
        end
    end
    return Expr(:toplevel, Expr(:module,false,esc(modname),blk),nothing)
end
    
end

