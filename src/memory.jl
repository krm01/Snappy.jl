
const global IS_LITTLE_ENDIAN = (Base.ENDIAN_BOM == 0x04030201)
const global IS_64_BIT = (Sys.WORD_SIZE == 64)

# significantly faster routines, but uses pointer tricks to bypass julia's memory safety mechanisms
@static if IS_LITTLE_ENDIAN
    @inline function load32u(a::Vector{UInt8}, i::Int)
        return unsafe_load(reinterpret(Ptr{UInt32}, pointer(a,i)))
    end
    @inline function load64u(a::Vector{UInt8}, i::Int)
        return unsafe_load(reinterpret(Ptr{UInt64}, pointer(a,i)))
    end
    @inline function load128u(a::Vector{UInt8}, i::Int)
        return unsafe_load(reinterpret(Ptr{UInt128}, pointer(a, i)))
    end

    @inline function store32u!(a::Vector{UInt8}, i::Int, u::UInt32)
        unsafe_store!(reinterpret(Ptr{UInt32}, pointer(a, i)), u)
    end
    @inline function unaligned_copy_64u!(dst::Vector{UInt8}, di::Int, src::Vector{UInt8}, si::Int)
        unsafe_store!(reinterpret(Ptr{UInt64}, pointer(dst, di)), load64u(src, si))
    end
    @inline function unaligned_copy_128u!(dst::Vector{UInt8}, di::Int, src::Vector{UInt8}, si::Int)
        unsafe_store!(reinterpret(Ptr{UInt128}, pointer(dst, di)), load128u(src, si))
    end
else
    @inline function load32u(a::Vector{UInt8}, i::Int)
        return hton(unsafe_load(reinterpret(Ptr{UInt32}, pointer(a,i))))
    end
    @inline function load64u(a::Vector{UInt8}, i::Int)
        return hton(unsafe_load(reinterpret(Ptr{UInt64}, pointer(a,i))))
    end
    @inline function load128u(a::Vector{UInt8}, i::Int)
        return hton(unsafe_load(reinterpret(Ptr{UInt128}, pointer(a, i))))
    end

    @inline function store32u!(a::Vector{UInt8}, i::Int, u::UInt32)
        unsafe_store!(reinterpret(Ptr{UInt32}, pointer(a, i)), ntoh(u))
    end
    @inline function unaligned_copy_64u!(dst::Vector{UInt8}, di::Int, src::Vector{UInt8}, si::Int)
        unsafe_store!(reinterpret(Ptr{UInt64}, pointer(dst, di)), ntoh(load64u(src, si)))
    end
    @inline function unaligned_copy_128u!(dst::Vector{UInt8}, di::Int, src::Vector{UInt8}, si::Int)
        unsafe_store!(reinterpret(Ptr{UInt128}, pointer(dst, di)), ntoh(load128u(src, si)))
    end
end
