module Snappy

export
    compress,
    uncompress,
    length_uncompressed,
    maxlength_compressed,
    isvalid_compressed

include("varint.jl")

# DONE --------
function htsize(source_len)
    htsize = 256
    while htsize < K_MAX_HASHTABLE_SIZE && htsize < source_len
        htsize <<= 1
    end
    return htsize
end

# DONE --------
function length_uncompressed(compressed::Vector{UInt8})
    return parse32(compressed, 1)
end

# DONE --------
function maxlength_compressed(source_len)
    return 32 + source_len + div(source_len,6)
end

# bool IsValidCompressed(Source* compressed);
function isvalid_compressed()
end

# size_t Compress(Source* source, Sink* sink);
function compress(uncompressed::Vector{UInt8})
    N = length(uncompressed)
    if N > typemax(UInt32)
        error("Input too large.")
    end
    N %= UInt32
    # preallocate the compressed buffer
    compressed = Vector{UInt8}(maxlength_compressed(N))
    encode32!(compressed, 1, N)

    table::UInt16 = htsize(N)

end

# bool Uncompress(Source* compressed, Sink* uncompressed);
function uncompress()
end


const global K_BLOCK_SIZE = (1 << 16)
const global K_MAX_HASHTABLE_SIZE = (1 << 14)

end
