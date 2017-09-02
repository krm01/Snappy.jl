
# 64-bit, little endian
# significantly faster routines, but uses pointer tricks to bypass julia's memory safety mechanisms
@inline function load32u(a::Vector{UInt8}, i::Integer)
    return unsafe_load(reinterpret(Ptr{UInt32}, pointer(a,i)))
end
@inline function load64u(a::Vector{UInt8}, i::Integer)
    return unsafe_load(reinterpret(Ptr{UInt64}, pointer(a,i)))
end
@inline function load128u(a::Vector{UInt8}, i::Integer)
    return unsafe_load(reinterpret(Ptr{UInt128}, pointer(a, i)))
end
@inline function store32u!(a::Vector{UInt8}, i::Integer, u::UInt32)
    unsafe_store!(reinterpret(Ptr{UInt32}, pointer(a, i)), u)
end
@inline function unaligned_copy_64u!(dst::Vector{UInt8}, di::Integer, src::Vector{UInt8}, si::Integer)
    unsafe_store!(reinterpret(Ptr{UInt64}, pointer(dst, di)), load64u(src, si))
end
@inline function unaligned_copy_128u!(dst::Vector{UInt8}, di::Integer, src::Vector{UInt8}, si::Integer)
    unsafe_store!(reinterpret(Ptr{UInt128}, pointer(dst, di)), load128u(src, si))
end
