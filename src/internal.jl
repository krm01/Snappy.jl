
if VERSION < v"0.6"
    ⊻ = $
end

const global K_BLOCK_SIZE = 1 << 15
const global K_INPUT_MARGIN_BYTES = 15
const global K_MAX_HASH_TABLE_SIZE = 1 << 14
const global K_MAXIMUM_TAG_LENGTH = 5

const global SNAPPY_LITERAL = 0x00
const global SNAPPY_COPY_1_BYTE_OFFSET = 0x01
const global SNAPPY_COPY_2_BYTE_OFFSET = 0x02
const global SNAPPY_COPY_4_BYTE_OFFSET = 0x03

const global WORDMASK = [
    0x00000000, 0x000000ff, 0x0000ffff, 0x00ffffff, 0xffffffff
]::Vector{UInt32}

const global CHAR_TABLE = [
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
]::Vector{UInt16}

@inline function load32u(a::AbstractArray, i::Integer)
    return UInt32(a[i]) | (UInt32(a[i+1]) << 8) | (UInt32(a[i+2]) << 16) | (UInt32(a[i+3]) << 24)
end
@inline function load64u(a::AbstractArray, i::Integer)
    return UInt64(a[i]) | (UInt64(a[i+1]) << 8) | (UInt64(a[i+2]) << 16) | (UInt64(a[i+3]) << 24) | (UInt64(a[i+4]) << 32) | (UInt64(a[i+5]) << 40) | (UInt64(a[i+6]) << 48) | (UInt64(a[i+7]) << 56)
end

@inline hashdword(bytes::UInt32, shift::UInt32) = (bytes * 0x1e35a7bd) >> shift
@inline log2floor(n::UInt32) = n == 0 ? -1 : 31 ⊻ leading_zeros(n)

function alloc_hashtable(n)
    htsize = 256
    while htsize < K_MAX_HASH_TABLE_SIZE && htsize < n
        htsize <<= 1
    end
    return Vector{UInt16}(htsize)
end

function compress_fragment!(vinput, output, outputindex, table)
    local shift::UInt32 = 32 - log2floor(length(table) % UInt32)
    ip = candidate = next_emit = base_ip = 1::Int
    ip_end = length(vinput)
    ip_limit = ip_end - K_INPUT_MARGIN_BYTES
    if length(vinput) >= K_INPUT_MARGIN_BYTES
        while true
            ip += 1
            next_hash = hashdword(load32u(vinput, ip), shift)
            next_ip = ip

            matchfound = false
            skip = 32
            while true
                ip = next_ip
                cur_hash = next_hash
                bytes_between_hash_lookups = skip >> 5
                skip += bytes_between_hash_lookups
                next_ip = ip + bytes_between_hash_lookups

                # early exit
                (next_ip > ip_limit) && break

                next_hash = hashdword(load32u(vinput, next_ip), shift)
                candidate = base_ip + table[cur_hash+1]
                table[cur_hash+1] = ip - base_ip

                if load32u(vinput, candidate) == load32u(vinput,ip)
                    matchfound = true
                    outputindex = emit_literal!(output, outputindex, vinput[next_emit:ip-1])
                    break
                end
            end

            while matchfound
                matched = 4 + find_match_length(vinput, candidate+4, vinput, ip+4)
                outputindex = emit_copy!(output, outputindex, ip - candidate, matched)
                ip += matched
                next_emit = ip

                # potential early exit
                (ip >= ip_limit) && break

                input_bytes = load64u(vinput, ip-1)
                prev_hash = hashdword(input_bytes % UInt32, shift)
                table[prev_hash+1] = ip - base_ip - 1
                cur_hash = hashdword((input_bytes >>> 8) % UInt32, shift)
                candidate = base_ip + table[cur_hash+1]
                table[cur_hash+1] = ip - base_ip
                ((input_bytes >>> 8) % UInt32 != load32u(vinput, candidate)) && break
            end
            (ip > ip_limit) && break
            ip += 1
        end
    end
    if next_emit < length(vinput)
        outputindex = emit_literal!(output, outputindex, vinput[next_emit:end])
    end
    return outputindex
end

@inline function emit_literal!(output, outputindex, literal)
    local len = length(literal)
    local n::UInt32 = (len - 1) % UInt32
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
    copy!(output, outputindex+=1, literal, 1, len)
    return outputindex + len
end

@inline function emit_copy_upto_64!(output, outputindex, offset, len)
    if len < 12 && offset < 2048
        output[outputindex] = (SNAPPY_COPY_1_BYTE_OFFSET + ((len - 4) << 2) + ((offset >> 3) & 0xe0)) % UInt8
        output[outputindex+=1] = (offset) % UInt8
    else
        output[outputindex] =  (SNAPPY_COPY_2_BYTE_OFFSET + ((len - 1) << 2)) % UInt8
        output[outputindex+=1] = (offset) % UInt8
        output[outputindex+=1] = (offset >>> 8) % UInt8
    end
    return outputindex + 1
end

@inline function emit_copy!(output, outputindex, offset, len)
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

@inline function find_match_length(s1::AbstractArray, i1::Integer, s2::AbstractArray, i2::Integer)
    # naive implementation, but also the fastest I've tried so far
    matched = 0
    while i2 <= length(s2) && s1[i1] == s2[i2]
        matched += 1
        i1 += 1
        i2 += 1
    end
    return matched
end

@inline function incremental_copy_slow!(dst, di, src, si, len)
    # TODO: or IS IT? just use this everywhere for now, optimize later.
    for _ in 1:len
        dst[di] = src[si]
        di += 1
        si += 1
    end
    return di
end

function decompress_all_tags!(output::Vector{UInt8}, input::Vector{UInt8}, ip)
    ip_limit = endof(input)
    op = start(output)

    while op < endof(output)

        c = input[ip]
        ip += 1

        # TODO replace this shameful hack properly. extends the input if its too small to read the uint.
        if ip+4 > ip_limit
            tag = load32u([input[ip:end]; [0x0, 0x0, 0x0, 0x0]], 1)
        else
            tag = load32u(input, ip)
        end

        entry = CHAR_TABLE[c+1]
        trailer = tag & WORDMASK[(entry >> 11)+1]
        len = entry & 0xff
        ip += (entry >> 11)

        if ((c & 0x3) % UInt8) == SNAPPY_LITERAL
            literal_length = len + trailer
            op = incremental_copy_slow!(output, op, input, ip, literal_length)
            ip += literal_length
        else
            copy_offset = (entry & 0x700)
            op = incremental_copy_slow!(output, op, output, op - (copy_offset + trailer), len)
        end
    end
end
