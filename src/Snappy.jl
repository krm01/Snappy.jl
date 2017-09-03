module Snappy

export
    compress,
    uncompress

@static if VERSION < v"0.6"
    ⊻ = $
end

include("varint.jl")
include("internal.jl")


"""
    compress(input::Vector{UInt8})

Compress a byte array using the snappy compression library.
"""
function compress(input::Vector{UInt8})
    length(input) > typemax(UInt32) && error("Input too large.")
    local sourcelen::UInt32 = length(input)

    # preallocate the output buffer, and resize down afterwards.
    output = zeros(UInt8, maxlength_compressed(sourcelen))
    outputindex = encode32!(output, 1, sourcelen)
    table = alloc_hashtable(sourcelen)

    for i in 0:K_BLOCK_SIZE:sourcelen
        fill!(table, 0xffff) # see compress_fragment! for explanation of using 0xffff
        outputindex = compress_fragment!(output, outputindex,
            input, i+1, min(i+K_BLOCK_SIZE, endof(input)), table)
    end

    return resize!(output, outputindex-1)
end
# for convenience
compress(input::String) = compress(Vector{UInt8}(input))


"""
    uncompress(input::Vector{UInt8})

Uncompress a snappy encoded byte array.
"""
function uncompress(input::Vector{UInt8})
    output_size, offset = length_uncompressed(input)
    output = zeros(UInt8, output_size)
    uncompressed_len = decompress_all_tags!(output, input, offset)
    (output_size != uncompressed_len-1) && error("Invalid input.")
    return output
end


# Compressed data can be defined as:
#    compressed := item* literal*
#    item       := literal* copy
#
# The trailing literal sequence has a space blowup of at most 62/60
# since a literal of length 60 needs one tag byte + one extra byte
# for length information.
#
# Item blowup is trickier to measure.  Suppose the "copy" op copies
# 4 bytes of data.  Because of a special check in the encoding code,
# we produce a 4-byte copy only if the offset is < 65536.  Therefore
# the copy op takes 3 bytes to encode, and this type of item leads
# to at most the 62/60 blowup for representing literals.
#
# Suppose the "copy" op copies 5 bytes of data.  If the offset is big
# enough, it will take 5 bytes to encode the copy op.  Therefore the
# worst case here is a one-byte literal followed by a five-byte copy.
# I.e., 6 bytes of input turn into 7 bytes of "compressed" data.
#
# This last factor dominates the blowup, so the final estimate is:
"""
    maxlength_compressed(sourcelen::Integer)

Return the maximum possible output size (in bytes) for a given input.
"""
function maxlength_compressed(sourcelen::Integer)
    return 32 + sourcelen + (sourcelen ÷ 6) # this is division, that op sure looks like plus though
end


"""
    length_uncompressed(input::Vector{UInt8})

Read uncompressed length encoded as a varint32 from the start of the array.
"""
function length_uncompressed(input::Vector{UInt8})
    return parse32(input, start(input))
end

end
