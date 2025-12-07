module ScopedEnums

import Core.Intrinsics.bitcast
export ScopedEnum, @scopedenum

function namemap end

@doc """
    ScopedEnum{T} <: Base.Enum{T} where {T<Integer}

Abstract supertype for all the scoped enum defined with [`@scopedenum`](@ref).
    """
abstract type ScopedEnum{T} <: Base.Enum{T} end

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
    @scopedenum Name[::BaseType] value1[=x] value2[=y]

Create a `ScopedEnum{Basetype}` subtype with name `Name` and enum member values of `value1` and `value2` with optional assigned values of `x` and `y`, respectively. `ScopedEnum` differs from regular `Enum` in being scoped in a Module called `Name`. So to refer to `value1` one as to call `Name.value1`. Additionaly, one can use @scopedenum as bitflags.
The main throwback of this implementation is that `Name`, being the name of the module, cannot be used as a type. The type of the enum member is `Name.Type`
julia> @scopedenum Fruits apple=1 orange=2 kiwi=3

julia> f(x::Fruits.Type) = "I'm a Fruit with: $(Int(x))"
f (generic function with 1 method)

julia> f(Fruits.apple)
"I'm a Fruit with: 1"
# Examples

```@jldoctest
julia> @scopedenum Fruits apple=1 orange=2 kiwi=3

julia> f(x::Fruits.Type) = "I'm a Fruit with value: \$(Int(x))"
f (generic function with 1 method)

julia> f(Fruits.apple)
"I'm a Fruit with: 1"

```
"""
macro scopedenum(T::Union{Symbol,Expr}, syms...)
    isempty(syms) && arg_error(LazyString("no arguments given for ScopedEnum", T))

    basetype = Int32;
    typename = T;
    _T = :Type
    if isa(T,Expr) && T.head === :(::) && length(T.args) == 2 && isa(T.args[1],Symbol)
        # this deal with type defined as Train::Int64     
        typename = T.args[1]
        basetype = Core.eval(__module__,T.args[2])
        if !isa(basetype, DataType) || !(basetype<:Integer) || !(isbitstype(basetype))
            arg_error(
                LazyString("invalid base type for ScopedEnum ", typename, ", ",T,"=::",basetype,"; basetype must be an integer primitive type"))
        end
    elseif !isa(T,Symbol)
        arg_error(LazyString("Invalid type expression for ScopedEnum ",T))
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
            if i == typemin(basetype) && isempty(values)
                # i start at zero(basetype), so if it get to be typemin
                # it mean that we had an overflow 
                arg_error(LazyString("overflow in value \"", s, "\" of ScopedEnum"))
            end
        elseif isa(s,Expr) &&
               (s.head === :(=) || s.head == :kw) &&
               length(s.args) ==2 && isa(s.args[1],Symbol)
            # this I believe allows for enums defined as a=10,
            i =Core.eval(__module__, s.args[2])

            if !isa(i, Integer)
                    arg_error(LazyString("invalid value for ScopedEnum ", typename, ", ", s, "; values must be integers"))
            end
            i = convert(basetype, i)
            s = s.args[1]
            hasexpr = true
        else
            arg_error(LazyString("invalid argument for ScopedEnum ", typename, ": ", s))
        end
        s = s::Symbol
        if !Base.isidentifier(s)
            arg_error(LazyString("invalid name for ScopedEnum ", typename, "; \"",s,"\" is not a valid identifier"))
        end
        if hasexpr && haskey(namemap,i)
            arg_error(LasyString("both ",s," and ", namemap[i]," have value ", i, " in ScopedEnum ", typename, "; values must be unique"))
        end

        namemap[i] = s
        push!(values, i)
        if s in seen
            arg_error(LazyString("name \"", s, "\" in ScopedEnum ", typename, "is not unique"))
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
        primitive type $(esc(_T)) <: ScopedEnum{$(esc(basetype))} $(sizeof(basetype)*8) end
        function $(esc(_T))(x::Integer)
            $(membershiptest(:x,values)) || args_error($(Expr(:quote, typename)), x)
            return bitcast($(esc(_T)), convert($(basetype),x))
        end
        ScopedEnums.namemap(::Type{$(esc(_T))}) = $(esc(namemap))
        Base.typemin(x::Type{$(esc(_T))}) = $(esc(_T))($lo)
        Base.typemax(x::Type{$(esc(_T))}) = $(esc(_T))($hi)
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

