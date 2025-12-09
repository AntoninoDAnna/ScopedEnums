using Revise, EnumClasses

# check that declarations are working 
@enumclass Fruits apple=1 orange=2 kiwi=3
@enumclass Test2 a=1 b c d
@enumclass Test3 a b=3 c d=6
@enumclass Test4::Int16 a b c d

@enumclass WFlag::UInt32 begin
    Fullscreen         =  0x00000001
    #...
    Maximized          =  0x00000080
    #...
end

flag::UInt32 = 0x0
flag |= WFlag.Fullscreen | WFlag.Maximized
is_fullscreen = (flag & WFlag.Fullscreen)!=0x0
is_maximixed = (flag & WFlag.Maximized) != 0x0

#unset WFlag.Maximized
flag = flag & (~WFlag.Maximized)
is_fullscreen = (flag & WFlag.Fullscreen)!=0x0
is_maximixed = (flag & WFlag.Maximized) != 0x0

# Checking that I can define enums inside a module
module Testing
using EnumClasses
@enumclass Test1 a b c d
@enumclass Test2 a=1 b c d
@enumclass Test3 a b=3 c d=6
@enumclass Test4::Int16 a b c d
@enumclass Test5::UInt8 begin
    a=0x01
    b=0x02
        c=0x04
    d=0x08
end
end




     
