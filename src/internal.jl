
using Juno

if VERSION < v"0.6"
    ⊻ = $
end

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
                candidate = base_ip + table[cur_hash]
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
    # naive implementation, also the fastest I've found so far
    # --------
    matched = 0
    while s1[i1] == s2[i2] && i2 <= length(s2)
        matched += 1
        i1 += 1
        i2 += 1
    end
    return matched
end

@inline function find_match_length(s1::AbstractArray, i1::Integer, s2::AbstractArray, i2::Integer, len::Integer)
    # "fast" direct port from C. slower than the while loop checking every index.
    matched = 0
    if i2 < len - 8
        a1, a2 = load64u(s1, i1), load64u(s2, i2)
        if a1 != a2
            return (trailing_zeros(a1 ⊻ a2) >> 3)
        else
            i2 += 8
            matched += 8
        end
    end

    while i2 <= len - 8
        a1, a2 = load64u(s1, i1+matched), load64u(s2, i2)
        if a1 == a2
            i2 += 8
            matched += 8
        else
            matched_bytes = (trailing_zeros(a1 ⊻ a2) >> 3)
            matched += matched_bytes
            return matched
        end
    end

    while i2 < len
        if s1[i1+matched] == s2[i2]
            i2 +=1
            matched += 1
        else
            return matched
        end
    end
    return matched
end


@inline function incremental_copy_slow!(v1, i1, v2, i2, len)
    # TODO: or is it? just use this everywhere for now, try the fast version later.
    while i2 < len
        @inbounds v1[i1] = v2[i2]
        i1 += 1
        i2 += 1
    end
end
