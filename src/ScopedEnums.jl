module ScopedEnums

import Core.Intrinsics.bitcast
export ScopedEnum, @scopedenum

function namemap end

"""
    ScopedEnum{T<:Integer}

The abstract supertype of all enumerated types defined with [`@scopedenum`](@ref).
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


macro scopedenum(T::Union{Symbol,Expr}, syms...)
    isempty(syms) && arg_error(LazyString("no arguments given for ScopedEnum", T))

    basetype = Int32;
    typename = T;
    T = :__T__
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
        println("syms is an Expression")
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
        primitive type $(esc(T)) <: ScopedEnum{$(esc(basetype))} $(sizeof(basetype)*8) end
        function $(esc(T))(x::Integer)
            $(membershiptest(:x,values)) || args_error($(Expr(:quote, typename)), x)
            return bitcast($(esc(basetype)), convert($(basetype),x))
        end
        ScopedEnums.namemap(::Type{$(esc(T))}) = $(esc(namemap))
        Base.typemin(x::Type{$(esc(T))}) = $(esc(typename))($lo)
        Base.typemax(x::Type{$(esc(T))}) = $(esc(typename))($hi)
        let inst = (Any[ $(esc(T))(v) for v in $values]...,)
            Base.instances(::Type{$(esc(T))}) = inst
        end
    end
    if isa(typename,Symbol)
        for (i,sym) in namemap
            push!(blk.args,:(const $(esc(sym)) = $(esc(T))($i)))
        end
    end
    return Expr(:toplevel, Expr(:module,false,esc(modname),blk),nothing)
end

end

