using ScopedEnums

# check that declarations are working 
@scopedenum Fruits apple=1 orange=2 kiwi=3

f(x::Fruits.Type) = "I'm a Fruit with value: $(Int(x))"

f(Fruits.apple)

@scopedenum Test2 a=1 b c d
@scopedenum Test3 a b=3 c d=6
@scopedenum Test4::Int16 a b c d
@scopedenum Test5::UInt8 begin
    a=0x01
    b=0x02
    c=0x04
    d=0x08
end

# Checking that I can define enums inside a module
module Testing
using ScopedEnums
@scopedenum Test1 a b c d
@scopedenum Test2 a=1 b c d
@scopedenum Test3 a b=3 c d=6
@scopedenum Test4::Int16 a b c d
@scopedenum Test5::UInt8 begin
    a=0x01
    b=0x02
        c=0x04
    d=0x08
end
end




     
