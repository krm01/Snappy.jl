module Snappy

export
    compress,
    uncompress

include("varint.jl")
include("internal.jl")


function compress(input::Vector{UInt8})
    local sourcelen::UInt32
    local inputv::Vector{UInt8}
    try
        sourcelen = convert(UInt32, length(input))
    catch e::InexactError
        error("Input too large.")
    end

    # preallocate the output buffer, and resize down afterwards. faster than vcat'ing dynamic arrays I think
    output = Vector{UInt8}(maxlength_compressed(sourcelen))
    outputindex = encode32!(output, 1, sourcelen)
    table = alloc_hashtable(sourcelen)
    for i in 1:K_BLOCK_SIZE+1:sourcelen
        fill!(table, 0)
        # TODO for some reason it's faster to copy than use a view?
        # inputv = @view input[i:min(i+K_BLOCK_SIZE, end)]
        inputv = input[i:min(i+K_BLOCK_SIZE, end)]
        outputindex = compress_fragment!(inputv, output, outputindex, table)
    end
    return resize!(output, outputindex-1)
end


function maxlength_compressed(sourcelen::Integer)
    return 32 + sourcelen + (sourcelen ÷ 6)
end


function uncompress(input::Vector{UInt8})
    output_size, offset = length_uncompressed(input)
    output = Vector{UInt8}(output_size)
    try
        uncompressed_len = decompress_all_tags!(output, input, start(input) + offset)
        (output_size != uncompressed_len-1) && error("Invalid input.")
    catch BoundsError
        error("Invalid input.")
    end

    return output
end


function length_uncompressed(input::Vector{UInt8})
    return parse32(input, start(input))
end


# for convenience
compress(input::String) = compress(convert(Vector{UInt8}, input))

end
