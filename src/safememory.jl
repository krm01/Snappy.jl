
# 32-bit
# pays a heavy cost for the array indexing
@inline function load32u(a::Vector{UInt8}, i::Integer)
    local val::UInt32 = (0x00000000
        | UInt32(a[i])
        | UInt32(a[i+1]) << 8
        | UInt32(a[i+2]) << 16
        | UInt32(a[i+3]) << 24)
    return val
end

@inline function store32u!(a::Vector{UInt8}, i::Integer, u::UInt32)
    a[i] = u % UInt8
    a[i+1] = (u >> 8) % UInt8
    a[i+2] = (u >> 16) % UInt8
    a[i+3] = (u >> 24) % UInt8
end
@inline function unaligned_copy_64u!(dst::Vector{UInt8}, di::Integer, src::Vector{UInt8}, si::Integer)
    for i in 0:7
        dst[di+i] = src[si+i]
    end
end
@inline function unaligned_copy_128u!(dst::Vector{UInt8}, di::Integer, src::Vector{UInt8}, si::Integer)
    for i in 0:15
        dst[di+i] = src[si+i]
    end
end
