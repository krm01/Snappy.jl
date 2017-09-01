
@static if VERSION < v"0.6"
    ⊻ = $
end

include("memory.jl")

const global K_BLOCK_SIZE = 1 << 16
const global K_INPUT_MARGIN_BYTES = 15
const global K_MAX_HASH_TABLE_SIZE = 1 << 14

const global SNAPPY_LITERAL = 0x00
const global SNAPPY_COPY_1_BYTE_OFFSET = 0x01
const global SNAPPY_COPY_2_BYTE_OFFSET = 0x02
const global SNAPPY_COPY_4_BYTE_OFFSET = 0x03

const global WORDMASK = UInt32[
    0x00000000, 0x000000ff, 0x0000ffff, 0x00ffffff, 0xffffffff
]

const global CHAR_TABLE = UInt16[
    0x0001, 0x0804, 0x1001, 0x2001, 0x0002, 0x0805, 0x1002, 0x2002,
    0x0003, 0x0806, 0x1003, 0x2003, 0x0004, 0x0807, 0x1004, 0x2004,
    0x0005, 0x0808, 0x1005, 0x2005, 0x0006, 0x0809, 0x1006, 0x2006,
    0x0007, 0x080a, 0x1007, 0x2007, 0x0008, 0x080b, 0x1008, 0x2008,
    0x0009, 0x0904, 0x1009, 0x2009, 0x000a, 0x0905, 0x100a, 0x200a,
    0x000b, 0x0906, 0x100b, 0x200b, 0x000c, 0x0907, 0x100c, 0x200c,
    0x000d, 0x0908, 0x100d, 0x200d, 0x000e, 0x0909, 0x100e, 0x200e,
    0x000f, 0x090a, 0x100f, 0x200f, 0x0010, 0x090b, 0x1010, 0x2010,
    0x0011, 0x0a04, 0x1011, 0x2011, 0x0012, 0x0a05, 0x1012, 0x2012,
    0x0013, 0x0a06, 0x1013, 0x2013, 0x0014, 0x0a07, 0x1014, 0x2014,
    0x0015, 0x0a08, 0x1015, 0x2015, 0x0016, 0x0a09, 0x1016, 0x2016,
    0x0017, 0x0a0a, 0x1017, 0x2017, 0x0018, 0x0a0b, 0x1018, 0x2018,
    0x0019, 0x0b04, 0x1019, 0x2019, 0x001a, 0x0b05, 0x101a, 0x201a,
    0x001b, 0x0b06, 0x101b, 0x201b, 0x001c, 0x0b07, 0x101c, 0x201c,
    0x001d, 0x0b08, 0x101d, 0x201d, 0x001e, 0x0b09, 0x101e, 0x201e,
    0x001f, 0x0b0a, 0x101f, 0x201f, 0x0020, 0x0b0b, 0x1020, 0x2020,
    0x0021, 0x0c04, 0x1021, 0x2021, 0x0022, 0x0c05, 0x1022, 0x2022,
    0x0023, 0x0c06, 0x1023, 0x2023, 0x0024, 0x0c07, 0x1024, 0x2024,
    0x0025, 0x0c08, 0x1025, 0x2025, 0x0026, 0x0c09, 0x1026, 0x2026,
    0x0027, 0x0c0a, 0x1027, 0x2027, 0x0028, 0x0c0b, 0x1028, 0x2028,
    0x0029, 0x0d04, 0x1029, 0x2029, 0x002a, 0x0d05, 0x102a, 0x202a,
    0x002b, 0x0d06, 0x102b, 0x202b, 0x002c, 0x0d07, 0x102c, 0x202c,
    0x002d, 0x0d08, 0x102d, 0x202d, 0x002e, 0x0d09, 0x102e, 0x202e,
    0x002f, 0x0d0a, 0x102f, 0x202f, 0x0030, 0x0d0b, 0x1030, 0x2030,
    0x0031, 0x0e04, 0x1031, 0x2031, 0x0032, 0x0e05, 0x1032, 0x2032,
    0x0033, 0x0e06, 0x1033, 0x2033, 0x0034, 0x0e07, 0x1034, 0x2034,
    0x0035, 0x0e08, 0x1035, 0x2035, 0x0036, 0x0e09, 0x1036, 0x2036,
    0x0037, 0x0e0a, 0x1037, 0x2037, 0x0038, 0x0e0b, 0x1038, 0x2038,
    0x0039, 0x0f04, 0x1039, 0x2039, 0x003a, 0x0f05, 0x103a, 0x203a,
    0x003b, 0x0f06, 0x103b, 0x203b, 0x003c, 0x0f07, 0x103c, 0x203c,
    0x0801, 0x0f08, 0x103d, 0x203d, 0x1001, 0x0f09, 0x103e, 0x203e,
    0x1801, 0x0f0a, 0x103f, 0x203f, 0x2001, 0x0f0b, 0x1040, 0x2040,
]


@inline hashdword(bytes::UInt32, shift::Unsigned) = (bytes * 0x1e35a7bd) >> shift
@inline log2floor(n::UInt32) = n == 0 ? -1 : 31 ⊻ leading_zeros(n)

function alloc_hashtable(n::Unsigned)
    htsize = 256
    while htsize < K_MAX_HASH_TABLE_SIZE && htsize < n
        htsize <<= 0x01
    end
    return zeros(UInt16, htsize)
end

function compress_fragment!(input::Vector{UInt8}, ip::Signed, ip_end::Signed, output::Vector{UInt8}, outputindex::Signed, table::Vector{UInt16})
    local shift::UInt = 32 - log2floor(convert(UInt32,length(table)))
    candidate = next_emit = base_ip = ip
    input_size = ip_end-ip+1
    ip_limit = ip_end - K_INPUT_MARGIN_BYTES

    @inbounds if input_size >= K_INPUT_MARGIN_BYTES
        while true
            next_hash = hashdword(load32u(input, ip+=1), shift)
            next_ip = ip

            skip = 32
            while true
                ip = next_ip
                cur_hash = next_hash
                bytes_between_hash_lookups = skip >> 0x05
                skip += 1
                next_ip = ip + bytes_between_hash_lookups

                # early exit
                (next_ip > ip_limit) && @goto emit_remainder

                # the table needs to hold indices up to 65536, but is constrained to a UInt16.
                # so we subtract 1 when storing, and add 1 when retrieving. the trick is that
                # +1 should only happen when retrieving values that have already been stored,
                # that is to say, the default value needs to be 0. so rather than filling the
                # array with 0's, fill it with 0xffff instead, and force the overflow back to 0.
                # in this case the addition is not associative, the +1 needs to evaluate on the
                # table first to force the overflow, and only then then add to base_ip.
                #
                # it is.. unfortunate that array indices are 1-based. the rest of the code can likely
                # be refactored and made more better, but as most of it is a ported from C, it is
                # easier to handle it this way for now.
                next_hash = hashdword(load32u(input, next_ip), shift)
                candidate = base_ip + (table[cur_hash+1] + 0x0001)
                table[cur_hash+1] = (ip - base_ip) - 1

                (load32u(input, candidate) == load32u(input,ip)) && break
            end
            outputindex = emit_literal!(output, outputindex, input, next_emit, ip-next_emit, true)

            while true
                matched = 4 + find_match_length(input, candidate+4, ip+4, ip_end)
                outputindex = emit_copy!(output, outputindex, ip - candidate, matched)
                ip += matched
                next_emit = ip

                # potential early exit
                (ip >= ip_limit) && @goto emit_remainder

                prev_hash = hashdword(load32u(input, ip-1), shift)
                input_bytes = load32u(input, ip)
                cur_hash = hashdword(input_bytes, shift)
                table[prev_hash+1] = ip - base_ip - 1 - 1
                candidate = base_ip + (table[cur_hash+1] + 0x0001)
                table[cur_hash+1] = ip - base_ip - 1

                (input_bytes != load32u(input, candidate)) && break
            end
        end
    end
    @label emit_remainder
    if next_emit <= ip_end
        outputindex = emit_literal!(output, outputindex, input, next_emit, ip_end-next_emit+1, false)
    end
    return outputindex
end

@inline function emit_literal!(output::Vector{UInt8}, outputindex::Signed, input::Vector{UInt8}, inputindex::Signed, len::Signed, allow_fast_path::Bool)
    local n::UInt32 = (len - 1) % UInt32
    if (allow_fast_path && len <= 16)
        output[outputindex] = SNAPPY_LITERAL | ((n << 2) % UInt8)
        unaligned_copy_128u!(output, outputindex+=1, input, inputindex)
        return outputindex + len
    end
    if len < 60
        fb = SNAPPY_LITERAL | ((n << 2) % UInt8)
        output[outputindex] = fb
    else
        count = 0
        base = outputindex
        while n > 0
            output[outputindex+=1] = n % UInt8
            n >>= 8; count += 1;
        end
        output[base] = SNAPPY_LITERAL | (((59+count) << 2) % UInt8)
    end
    copy!(output, outputindex+=1, input, inputindex, len)
    return outputindex + len
end

@inline function emit_copy_upto_64!(output::Vector{UInt8}, outputindex::Signed, offset::Signed, len::Signed)
    if len < 12 && offset < 2048
        output[outputindex] = (SNAPPY_COPY_1_BYTE_OFFSET + ((len - 4) << 2) + ((offset >> 3) & 0xe0)) % UInt8
        output[outputindex+1] = (offset & 0xff) % UInt8
        outputindex += 2
    else
        local u::UInt32 = SNAPPY_COPY_2_BYTE_OFFSET + ((len - 1) << 2) + (offset << 8)
        store32u!(output, outputindex, u)
        outputindex += 3
    end
    return outputindex
end

@inline function emit_copy!(output::Vector{UInt8}, outputindex::Signed, offset::Signed, len::Signed)
    if len < 12
        outputindex = emit_copy_upto_64!(output, outputindex, offset, len)
        return outputindex
    else
        while len >= 68
            outputindex = emit_copy_upto_64!(output, outputindex, offset, 64)
            len -= 64
        end
        if len > 64
            outputindex = emit_copy_upto_64!(output, outputindex, offset, 60)
            len -= 60
        end
        outputindex = emit_copy_upto_64!(output, outputindex, offset, len)
    end
    return outputindex
end

@static if IS_64_BIT && IS_LITTLE_ENDIAN
# Fast implementation for 64bit little endian
    @inline function find_match_length(a::Vector{UInt8}, i1::Signed, i2::Signed, limit::Signed)
        matched = 0

        # check (limit - 7) instead of (limit - 8) because 1-based arrays
        if i2 <= limit - 7
            a1 = load64u(a, i1)
            a2 = load64u(a, i2)
            if a1 != a2
                return trailing_zeros(a1 ⊻ a2) >> 3
            else
                i2 += 8
                matched = 8
            end
        end
        while i2 <= limit - 7
            if load64u(a, i2) == load64u(a, i1+matched)
                i2 += 8
                matched += 8
            else
                x = load64u(a, i2) ⊻ load64u(a, i1+matched)
                matching_bits = trailing_zeros(x)
                matched += (matching_bits >> 3)
                return matched
            end
        end
        while i2 <= limit && a[i1+matched] == a[i2]
            i2 += 1
            matched += 1
        end
        return matched
    end
else
# 32bit version
    @inline function find_match_length(a::Vector{UInt8}, i1::Signed, i2::Signed, limit::Signed)
        matched = 0
        while i2 <= limit - 4 && load32u(a, i2) == load32u(a, i1+matched)
            i2 += 4
            matched += 4
        end
        if IS_LITTLE_ENDIAN && i2 <= limit - 4
            x = load32u(a, i2) ⊻ load32u(a, i1+matched)
            matching_bits = trailing_zeros(x)
            matched += (matching_bits >> 3)
        else
            while i2 <= limit && a[i1+matched] == a[i2]
                i2 += 1
                matched += 1
            end
        end
        return matched
    end
end


function decompress_all_tags!(output::Vector{UInt8}, input::Vector{UInt8}, ip::Signed)
    ip_limit = endof(input)
    op = start(output)
    op_limit = endof(output)

    while ip < ip_limit

        c = input[ip]
        ip += 1
        entry = CHAR_TABLE[c+1]
        len = entry & 0xff
        taglen = entry >> 11

        if ip+4 <= ip_limit
            tag = load32u(input, ip)
        else
            tag = load32u(vcat(input[ip:ip_limit], zeros(UInt8, 4)), 1)
        end

        trailer = tag & WORDMASK[taglen+1]
        ip += taglen

        if ((c & 0x3) % UInt8) != SNAPPY_LITERAL
            copy_offset = (entry & 0x700)
            op = copy_copy!(output, op, copy_offset + trailer, len)
        else
            op, ip = copy_literal!(output, op, input, ip, len + trailer)
        end
    end
    return op
end


@inline function copy_copy!(output::Vector{UInt8}, op::Integer, offset::Integer, len::Integer)
    avail_out = endof(output) - op + 1
    (op - start(output) <= offset - 0x01) && error("Invalid input: corrupt copy offset")
    if len <= 16 && offset >= 8 && avail_out >= 16
        # use two 64s instead of a 128, because op - offset can be < 16. A 128 copy might overwrite into op.
        unaligned_copy_64u!(output, op, output, op - offset)
        unaligned_copy_64u!(output, op + 8, output, op - offset + 8)
    else
        (avail_out < len) && error("Invalid input: corrupt copy length")
        incremental_copy!(output, op, op - offset, len)
    end
    return op + len
end


@inline function incremental_copy!(output::Vector{UInt8}, op::Integer, src::Integer, len::Integer)
    @inbounds for i in 0:len-1
        output[op+i] = output[src+i]
    end
end


@inline function copy_literal!(output::Vector{UInt8}, op::Integer, input::Vector{UInt8}, ip::Integer, len::Integer)
    avail_out = endof(output) - op + 1
    avail_in = endof(input) - ip + 1
    (avail_out < len || avail_in < len) && error("Invalid input: corrupt literal")

    # fast path, can copy more than the literal but that's OK here. most literals are short.
    if len <= 16 && avail_out >= 16 && avail_in >= 16
        unaligned_copy_128u!(output, op, input, ip)
    else
        copy!(output, op, input, ip, len)
    end
    return op+len, ip+len
end
