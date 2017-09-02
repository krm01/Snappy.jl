
@static if VERSION < v"0.6"
    ⊻ = $
end

const global IS_LITTLE_ENDIAN = (Base.ENDIAN_BOM == 0x04030201)
const global IS_64_BIT = (Sys.WORD_SIZE == 64)

if IS_LITTLE_ENDIAN && IS_64_BIT
    include("fastmemory.jl")
else
    include("safememory.jl")
end

# byte patterns for each of the tag types in the compression format.
const global SNAPPY_LITERAL = 0x00
const global SNAPPY_COPY_1_BYTE_OFFSET = 0x01
const global SNAPPY_COPY_2_BYTE_OFFSET = 0x02
const global SNAPPY_COPY_4_BYTE_OFFSET = 0x03


# : snappy.h
# the size of a compression block. note that many parts of the compression
# code assumes that K_BLOCK_SIZE <= 65536; in particular, the hash table
# can only store 16-bit offsets, and emit_copy! also assumes the offset
# is 65535 bytes or less.
#
# note that there might be older data around that is compressed with larger
# block sizes, so the decompression code should not rely on the
# non-existence of long backreferences.
const global K_BLOCK_SIZE = 1 << 16
const global K_INPUT_MARGIN_BYTES = 15
const global K_MAX_HASH_TABLE_SIZE = 1 << 14

# : snappy-internal.h
# data stored per entry in lookup table:
#      range   bits-used       description
#      ------------------------------------
#      1..64   0..7            literal/copy length encoded in opcode byte
#      0..7    8..10           copy offset encoded in opcode byte / 256
#      0..4    11..13          extra bytes after opcode
#
# we use eight bits for the length even though 7 would have sufficed
# because of efficiency reasons:
#      (1) extracting a byte is faster than a bit-field
#      (2) it properly aligns copy offset so we do not need a <<8
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

# mapping from i in range [0,4] to a mask to extract the bottom 8*i bits.
const global WORDMASK = UInt32[
    0x00000000, 0x000000ff, 0x0000ffff, 0x00ffffff, 0xffffffff
]


# : snappy.cc
# any hash function will produce a valid compressed bitstream, but a good
# hash function reduces the number of collisions and thus yields better
# compression for compressible input, and more speed for incompressible
# input. Of course, it doesn't hurt if the hash function is reasonably fast
# either, as it gets called a lot.
@inline hashdword(bytes::UInt32, shift::Unsigned) = (bytes * 0x1e35a7bd) >> shift


# : snappy.cc
# leturn floor(log2(n)) for positive integer n. returns -1 iff n == 0.
@inline log2floor(n::UInt32) = n == 0 ? -1 : 31 ⊻ leading_zeros(n)


# : snappy.cc
# use smaller hash table when length(input) is smaller, since we
# fill the table, incurring O(hash table size) overhead for
# compression, and if the input is short, we won't need that
# many hash table entries anyway.
function alloc_hashtable(n::Unsigned)
    htsize = 256
    while htsize < K_MAX_HASH_TABLE_SIZE && htsize < n
        htsize <<= 0x01
    end
    return zeros(UInt16, htsize)
end

# : snappy.cc
# flat array compression that does not emit the "uncompressed length"
# prefix. compresses "input" bytes into "output".
#
# REQUIRES: "input" is at most "K_BLOCK_SIZE" bytes long.
# REQUIRES: "output" array has been allocated with at least
# "maxlength_compressed(length(input))" bytes of memory.
# REQUIRES: All elements in "table" are initialized to 0xffff.
# REQUIRES: "length(table)" is a power of two.
#
# returns an index into output one past the end of the compressed
# "input" bytes. The compressed length of "input" is outputindex-1.
function compress_fragment!(output::Vector{UInt8}, outputindex::Integer, input::Vector{UInt8}, ip::Integer, ip_end::Integer, table::Vector{UInt16})
    local shift::UInt = 32 - log2floor(convert(UInt32,length(table)))
    candidate = next_emit = base_ip = ip
    input_size = ip_end-ip+1
    ip_limit = ip_end - K_INPUT_MARGIN_BYTES

    @inbounds if input_size >= K_INPUT_MARGIN_BYTES
        while true

            # : snappy.cc
            # the body of this loop calls emit_literal! once and then emit_copy! one or
            # more times (the exception is that when we're close to exhausting
            # the input we @goto emit_remainder).
            #
            # in the first iteration of this loop we're just starting, so
            # there's nothing to copy, so calling emit_literal! once is
            # necessary. and we only start a new iteration when the
            # current iteration has determined that a call to emit_literal! will
            # precede the next call to emit_copy! (if any).
            #
            # step 1: scan forward in the input looking for a 4-byte-long match.
            # if we get close to exhausting the input then @goto emit_remainder.
            #
            # heuristic match skipping: if 32 bytes are scanned with no matches
            # found, start looking only at every other byte. if 32 more bytes are
            # scanned (or skipped), look at every third byte, etc.. When a match is
            # found, immediately go back to looking at every byte. this is a small
            # loss (~5% performance, ~0.1% density) for compressible data due to more
            # bookkeeping, but for non-compressible data (such as JPEG) it's a huge
            # win since the compressor quickly "realizes" the data is incompressible
            # and doesn't bother looking for matches everywhere.
            #
            # the "skip" variable keeps track of how many bytes there are since the
            # last match; dividing it by 32 (ie. right-shifting by five) gives the
            # number of bytes to move ahead for each iteration.
            skip = 32
            next_hash = hashdword(load32u(input, ip+=1), shift)
            next_ip = ip

            # this loop is a do {...} while (load32u(input, candidate) == load32u(input,ip))
            while true
                ip = next_ip
                cur_hash = next_hash
                bytes_between_hash_lookups = skip >> 0x05
                skip += 1
                next_ip = ip + bytes_between_hash_lookups

                # early exit if no match is found and we're nearing the end of the input
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
                # easier to handle it this way for now. TODO (krm01): consider using the neat new
                # feature that allows arrays with arbitrary indexes and start it from 0.
                next_hash = hashdword(load32u(input, next_ip), shift)
                candidate = base_ip + (table[cur_hash+1] + 0x0001)
                table[cur_hash+1] = (ip - base_ip) - 1

                (load32u(input, candidate) == load32u(input,ip)) && break
            end

            # : snappy.cc
            # step 2: a 4-byte match has been found. we'll later see if more
            # than 4 bytes match. but, prior to the match, input
            # bytes [next_emit, ip) are unmatched. emit them as "literal bytes."
            outputindex = emit_literal!(output, outputindex, input, next_emit, ip-next_emit, true)

            # : snappy.cc
            # step 3: call emit_copy!, and then see if another emit_copy! could
            # be our next move. repeat until we find no match for the
            # input immediately after what was consumed by the last emit_copy! call.
            #
            # if we exit this loop normally then we need to call emitLiteral next,
            # though we don't yet know how big the literal will be. we handle that
            # by proceeding to the next iteration of the main loop. we also can exit
            # this loop via goto if we get close to exhausting the input.
            while true

                # : snappy.cc
                # we have a 4-byte match at ip, and no need to emit any
                # "literal bytes" prior to ip.
                matched = 4 + find_match_length(input, candidate+4, ip+4, ip_end)
                outputindex = emit_copy!(output, outputindex, ip - candidate, matched)
                ip += matched
                next_emit = ip

                # early exit if no match is found and we're nearing the end of the input
                (ip >= ip_limit) && @goto emit_remainder

                # : snappy.cc
                # we are now looking for a 4-byte match again. we read
                # table[hashdword(load32u(input, ip), shift)] for that.
                # to improve compression, we also update the table at ip-1 and ip.
                prev_hash = hashdword(load32u(input, ip-1), shift)
                input_bytes = load32u(input, ip)
                cur_hash = hashdword(input_bytes, shift)

                # we need to do the same awkward +0x0001, -1 trick here.
                table[prev_hash+1] = ip - base_ip - 1 - 1
                candidate = base_ip + (table[cur_hash+1] + 0x0001)
                table[cur_hash+1] = ip - base_ip - 1

                # another do {...} while () break
                (input_bytes != load32u(input, candidate)) && break
            end
        end
    end
    @label emit_remainder
    # emit the remaining bytes as a literal
    if next_emit <= ip_end
        # we are near the end of the input, so can't allow emit_literal! to
        # write beyond its bounds. calling with false indicates to use the slow/safe path.
        outputindex = emit_literal!(output, outputindex, input, next_emit, ip_end-next_emit+1, false)
    end
    return outputindex
end

@inline function emit_literal!(output::Vector{UInt8}, outputindex::Integer, input::Vector{UInt8}, inputindex::Integer, len::Integer, allow_fast_path::Bool)
    # : snappy.cc
    # the vast majority of copies are below 16 bytes, for which a
    # call to memcpy is overkill. this fast path can sometimes
    # copy up to 15 bytes too much, but that is okay in the
    # main loop, since we have a bit to go on for both sides:
    #
    #   - the input will always have K_INPUT_MARGIN_BYTES = 15 extra
    #     available bytes, as long as we're in the main loop, and
    #     if not, allow_fast_path = false.
    #   - the output will always have 32 spare bytes (see
    #     maxlength_compressed).
    local n::UInt32 = (len - 1) % UInt32
    if (allow_fast_path && len <= 16)
        # fits in tag byte
        output[outputindex] = SNAPPY_LITERAL | ((n << 2) % UInt8)
        unaligned_copy_128u!(output, outputindex+=1, input, inputindex)
        return outputindex + len
    end
    if len < 60
        # fits in tag byte
        fb = SNAPPY_LITERAL | ((n << 2) % UInt8)
        output[outputindex] = fb
    else
        # encode in upcoming bytes
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

@inline function emit_copy_upto_64!(output::Vector{UInt8}, outputindex::Integer, offset::Integer, len::Integer)
    if len < 12 && offset < 2048
        # offset fits in 11 bits. the 3 highest go in the top of the first byte,
        # and the rest go in the second byte.
        output[outputindex] = (SNAPPY_COPY_1_BYTE_OFFSET + ((len - 4) << 2) + ((offset >> 3) & 0xe0)) % UInt8
        output[outputindex+1] = (offset & 0xff) % UInt8
        outputindex += 2
    else
        # write 4 bytes, though we only care about 3 of them. The output buffer
        # is required to have some slack, so the extra byte won't overrun it.
        local u::UInt32 = SNAPPY_COPY_2_BYTE_OFFSET + ((len - 1) << 2) + (offset << 8)
        store32u!(output, outputindex, u)
        outputindex += 3
    end
    return outputindex
end

@inline function emit_copy!(output::Vector{UInt8}, outputindex::Integer, offset::Integer, len::Integer)
    if len < 12
        outputindex = emit_copy_upto_64!(output, outputindex, offset, len)
        return outputindex
    else
        # : snappy.cc
        # a special case for len <= 64 might help, but so far measurements suggest
        # it's in the noise. TODO (krm01): confirm this is still true in Julia

        # emit 64 byte copies but make sure to keep at least four bytes reserved.
        while len >= 68
            outputindex = emit_copy_upto_64!(output, outputindex, offset, 64)
            len -= 64
        end
        # one or two copies will now finish the job.
        if len > 64
            outputindex = emit_copy_upto_64!(output, outputindex, offset, 60)
            len -= 60
        end
        # emit remainder.
        outputindex = emit_copy_upto_64!(output, outputindex, offset, len)
    end
    return outputindex
end


# : snappy-internal.h
# find the largest n such that
#
#   a[i1, n-1] == a[i2, n-1]
#   and n <= (limit - i2).
#
# does not read a[limit] or beyond.
# does not read a[(i1 + (limit - i2))] or beyond.
# requires that limit >= i2.
#
# separate implementation for 64-bit, little-endian cpus.
@static if IS_64_BIT && IS_LITTLE_ENDIAN
    @inline function find_match_length(a::Vector{UInt8}, i1::Integer, i2::Integer, limit::Integer)
        matched = 0

        # : snappy-internal.h
        # this block isn't necessary for correctness; we could just start looping
        # immediately. as an optimization though, it is useful. it creates some not
        # uncommon code paths that determine, without extra effort, whether the match
        # length is less than 8. in short, we are hoping to avoid a conditional
        # branch, and perhaps get better code layout from the C++ compiler.

        # it turns out, this is also true for Julia. also we check (limit - 7)
        # instead of (limit - 8) because 1-based arrays.
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

        # find out how long the match is. we loop over the data 64 bits at a
        # time until we find a 64-bit block that doesn't match; then we find
        # the first non-matching bit and use that to calculate the total
        # length of the match.
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
# 32bit version, based on above routine.
    @inline function find_match_length(a::Vector{UInt8}, i1::Integer, i2::Integer, limit::Integer)
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


function decompress_all_tags!(output::Vector{UInt8}, input::Vector{UInt8}, ip::Integer)
    ip_limit = endof(input)
    op = start(output)
    op_limit = endof(output)

    @inbounds while ip < ip_limit

        c = input[ip]
        ip += 1

        # load32u reads 4 bytes blindly from input, so when we're nearing the
        # end of the array it needs to be handled differently. the Java version
        # built up the trailer byte-by-byte, but my testing shows it is faster
        # in Julia to create a slice padded with 0 bytes and let it read over
        # into that buffer. it seems kind of silly, but...
        if ip+4 <= ip_limit
            tag = load32u(input, ip)
        else
            tag = load32u(vcat(input[ip:ip_limit], zeros(UInt8, 4)), 1)
        end

        # here we have read c, the tag byte marker, and need to extract the
        # upper six bits encoding the length. the CHAR_TABLE is a precomputed
        # lookup table. then advance ip 1 beyond the end of the tag.
        entry = CHAR_TABLE[c+1]
        len = entry & 0xff
        taglen = entry >> 11
        trailer = tag & WORDMASK[taglen+1]
        ip += taglen

        # : snappy.cc
        # ratio of iterations that have LITERAL vs non-LITERAL for different
        # inputs.
        #
        # input          LITERAL  NON_LITERAL
        # -----------------------------------
        # html|html4|cp   23%        77%
        # urls            36%        64%
        # jpg             47%        53%
        # pdf             19%        81%
        # txt[1-4]        25%        75%
        # pb              24%        76%
        # bin             24%        76%
        #
        # in the C++ version, this table was used to justify a compiler directive
        # to help with branch prediction, but no such feature exists in Julia that
        # i know of. still, copies are more common, so that case is checked first.
        if ((c & 0x3) % UInt8) != SNAPPY_LITERAL
            copy_offset = (entry & 0x700)
            op = incremental_copy!(output, op, copy_offset + trailer, len)
        else
            op, ip = copy_literal!(output, op, input, ip, len + trailer)
        end
    end
    return op
end


# snappy supports run-length encoding (RLE), so handling like this is necessary
# in cases where the input and output regions may overlap.
# for example:
#       ip ---v
#            [ab                      ]    copy length: 20
#       op -----^
# after the copy the buffer will look like:
#            [ababababababababababab  ]
@inline function incremental_copy_slow!(output::Vector{UInt8}, op::Integer, ip::Integer, len::Integer)
    for i in 0:len-1
        output[op+i] = output[ip+i]
    end
end


# : snappy.cc
# copy [src, src+(op_limit-op)) to [op, (op_limit-op)) but faster than
# IncrementalCopySlow. buf_limit is the address past the end of the writable
# region of the buffer.
#
# copy output[offset:len] to output[op:len], optimized for x64 little endian
# systems to be faster than a call to copy!() - also catches the end of the copy
# to be handled by incremental_copy_slow!
@inline function incremental_copy!(output::Vector{UInt8}, op::Integer, offset::Integer, len::Integer)
    avail_out = endof(output) - op + 1
    # this "offset - 0x01" trick is from the original C++, we could just
    # check op - start < offset, but this version is equivalent in all cases
    # except when offset == 0, a case we do not want to allow. subtracting by
    # 0x01 causes an offset of 0 to be cast to unsigned and wrap around, and
    # is then caught by this check.
    (op - start(output) <= offset - 0x01) && error("Invalid input: corrupt copy offset")
    if len <= 16 && offset >= 8 && avail_out >= 16
        # use two 64s instead of a 128, because op - offset can be < 16. A 128 copy might overwrite into op.
        unaligned_copy_64u!(output, op, output, op - offset)
        unaligned_copy_64u!(output, op + 8, output, op - offset + 8)
    else
        (avail_out < len) && error("Invalid input: corrupt copy length")
        incremental_copy_slow!(output, op, op - offset, len)
    end
    return op + len
end


# when copying literal bytes there is no concern for overlapping input
# and output regions, so take the fast path when possible and otherwise
# use copy!() , which is still faster than incremental_copy_slow!()
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
