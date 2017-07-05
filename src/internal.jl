
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

load32u(x) = reinterpret(UInt32, x)[1]
load64u(x) = reinterpret(UInt64, x)[1]
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
    ip = candidate = next_emit = base_ip = 1
    ip_limit = length(vinput) - K_INPUT_MARGIN_BYTES
    if length(vinput) >= K_INPUT_MARGIN_BYTES
        while true

            matchfound = false
            for i in Skip32(ip += 1, ip_limit)
                ip = i
                cur_hash = hashdword(load32u(vinput[i:i+3]), shift)
                candidate = base_ip + table[cur_hash]
                table[cur_hash] = i - base_ip
                if load32u(vinput[candidate:candidate+3]) == load32u(vinput[i:i+3])
                    matchfound = true
                    outputindex = emit_literal!(output, outputindex, vinput[next_emit:i-1])
                    break
                end
            end

            while matchfound
                matched = 4 + find_match_length(@view(vinput[candidate+4:end]), @view(vinput[ip+4:end]))
                outputindex = emit_copy!(output, outputindex, ip - candidate, matched)
                ip += matched
                next_emit = ip

                # potential early exit
                (ip >= ip_limit) && break

                input_bytes = load64u(vinput[ip-1:ip+6])
                prev_hash = hashdword(input_bytes % UInt32, shift)
                table[prev_hash] = ip - base_ip - 1
                cur_hash = hashdword((input_bytes >>> 8) % UInt32, shift)
                candidate = base_ip + table[cur_hash]
                table[cur_hash] = ip - base_ip
                ((input_bytes >>> 8) % UInt32 != load32u(vinput[candidate:candidate+3])) && break
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
    # TODO: change to unsafe_copy!
    unsafe_copy!(output, outputindex+=1, literal, 1, len)
    return outputindex + len
end

# TODO: This is probably a problem point for off-by-one, dealing with "offset" and "len"
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

# TODO: This is probably a problem point for off-by-one, dealing with "offset" and "len"
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
        return outputindex
    end
end

function find_match_length(s1::AbstractArray, s2::AbstractArray)
    matched = 0
    len = min(length(s1), length(s2))
    for i in 1:8:len-8
        a1, a2 = load64u(s1[i:i+7]), load64u(s2[i:i+7])
        matched_bytes = (trailing_zeros(a1 ⊻ a2) >> 3)
        matched += matched_bytes
        (a1 != a2) && break
    end
    for i in matched+1:len
        (s1[i] != s2[i]) && break
        matched += 1
    end
    return matched
end
