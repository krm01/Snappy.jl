
using Juno

const global K_BLOCK_SIZE = 1 << 15
const global K_INPUT_MARGIN_BYTES = 15
const global K_MAX_HASH_TABLE_SIZE = 1 << 14

const global SNAPPY_LITERAL = 0x00
const global SNAPPY_COPY_1_BYTE_OFFSET = 0x01
const global SNAPPY_COPY_2_BYTE_OFFSET = 0x02
const global SNAPPY_COPY_4_BYTE_OFFSET = 0x03

type Skip32
    start::Integer
    stop::Integer
end
Base.start(S::Skip32) = S.start
Base.next(S::Skip32, state) = (state, state + (32 + state - S.start + 1) >> 5)
Base.done(S::Skip32, state) = state > S.stop

function load32u(a::AbstractArray, i::Integer)
    return UInt32(a[i]) | (UInt32(a[i+1]) << 8) | (UInt32(a[i+2]) << 16) | (UInt32(a[i+3]) << 24)
end
function load64u(a::AbstractArray, i::Integer)
    return UInt64(a[i]) | (UInt64(a[i+1]) << 8) | (UInt64(a[i+2]) << 16) | (UInt64(a[i+3]) << 24) | (UInt64(a[i+4]) << 32) | (UInt64(a[i+5]) << 40) | (UInt64(a[i+6]) << 48) | (UInt64(a[i+7]) << 56)
end

load32u(x::AbstractArray) = reinterpret(UInt32, x)[1]::UInt32
load64u(x::AbstractArray) = reinterpret(UInt64, x)[1]::UInt64
hashdword(bytes::UInt32, shift::UInt32) = (bytes * 0x1e35a7bd) >> shift
log2floor(n::UInt32) = n == 0 ? -1 : 31 ⊻ leading_zeros(n)

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
    ip_limit = length(vinput) - K_INPUT_MARGIN_BYTES
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
                @assert cur_hash == hashdword(load32u(vinput, ip), shift)
                bytes_between_hash_lookups = skip >> 5
                skip += bytes_between_hash_lookups
                next_ip = ip + bytes_between_hash_lookups

                # early exit
                (next_ip > ip_limit) && break

                next_hash = hashdword(load32u(vinput, next_ip), shift)
                candidate = base_ip + table[cur_hash]
                @assert candidate >= base_ip
                @assert candidate < ip
                table[cur_hash] = ip - base_ip

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
                table[prev_hash] = ip - base_ip - 1
                cur_hash = hashdword((input_bytes >>> 8) % UInt32, shift)
                candidate = base_ip + table[cur_hash]
                table[cur_hash] = ip - base_ip
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

function emit_literal!(output, outputindex, literal)
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
    unsafe_copy!(output, outputindex+=1, literal, 1, len)
    return outputindex + len
end

function emit_copy_upto_64!(output, outputindex, offset, len)
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

function emit_copy!(output, outputindex, offset, len)
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

function find_match_length(s1::AbstractArray, s2::AbstractArray)
    # "fast" implementation from C, but is VERY SLOW in Julia
    # because the load32/64 functions are making COPIES ON THE SLICES
    # --------

    # matched = 0
    # len = min(length(s1), length(s2))
    # for i in 1:8:len-8
    #     # a1, a2 = load64u(s1[i:i+7]), load64u(s2[i:i+7])
    #     a1, a2 = load64u(s1, i), load64u(s2, i)
    #     matched_bytes = (trailing_zeros(a1 ⊻ a2) >> 3)
    #     matched += matched_bytes
    #     (a1 != a2) && break
    # end
    # for i in matched+1:len
    #     (s1[i] != s2[i]) && break
    #     matched += 1
    # end
    # return matched

    # naive, compares every index rather than every 8 like above, but no allocation overhead
    # --------
    for i in 1:min(length(s1), length(s2))
        if s1[i] != s2[i]
            return i-1
        end
    end
    return 0
end

function find_match_length(s1::AbstractArray, i1::Integer, s2::AbstractArray, i2::Integer)
    # naive implementation 2
    # --------
    matched = 0
    while s1[i1] == s2[i2]
        matched += 1
        i1 += 1
        i2 += 1
    end
    return matched
end
