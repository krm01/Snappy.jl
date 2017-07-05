module Snappy

export
    compress,
    maxlength_compressed,
    isvalid_compressed,
    uncompress,
    length_uncompressed

include("varint.jl")
include("internal.jl")

using Juno

function compress(input::Vector{UInt8})
    sourcelen = length(input)
    try
        sourcelen = convert(UInt32, sourcelen)
    catch e
        error("input too large.")
    end
    # preallocate the output buffer, and resize down afterwards. faster than vcat'ing dynamic arrays
    output = Vector{UInt8}(maxlength_compressed(sourcelen))
    # TODO: REMOVE this when everything works, just helpful for debugging!
    fill!(output, 0xff)
    outputindex = encode32!(output, 1, sourcelen)
    table = alloc_hashtable(sourcelen)
    for i in 1:K_BLOCK_SIZE+1:sourcelen
        fill!(table, 0)
        inputv = @view input[i:min(i+K_BLOCK_SIZE, end)]
        outputindex = compress_fragment!(inputv, output, outputindex, table)
    end
    return resize!(output, outputindex-1)
end


function maxlength_compressed(sourcelen::Integer)
    # so sayeth the Google
    return 32 + sourcelen + (sourcelen ÷ 6)
end



# TODO: NOT YET IMPLEMENTED
function isvalid_compressed(input::Vector{UInt8})
    false
end


# TODO: NOT YET IMPLEMENTED
function uncompress(input::Vector{UInt8})
    convert(Vector{UInt8}, "uncompress: not implemented")
end


# TODO: NOT YET IMPLEMENTED
function length_uncompressed(input::Vector{UInt8})
    0
end


# convenience wrappers for operating on Strings
compress(input::String) = compress(convert(Vector{UInt8}, input))

isvalid_compressed(input::String) = isvalid_compressed(convert(Vector{UInt8}, input))

length_uncompressed(input::String) = length_uncompressed(convert(Vector{UInt8}, input))

end
