
# NOTE: this assumes "libsnappy" is an available library dependency and in the load path.

# Native ccall versions, temporary for comparisons
function ccall_compress(input::Vector{UInt8})
    size_in = length(input)
    output = zeros(UInt8, ccall((:snappy_max_compressed_length, "libsnappy"), Csize_t, (Csize_t,), size_in))
    outputindex = Ref{Csize_t}(length(output))
    ccall((:snappy_compress, "libsnappy"),
        Cint,
        (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Ref{Csize_t}),
        input, size_in, output, outputindex)
    resize!(output, outputindex[])
    return output
end

function ccall_uncompress(input::Array{UInt8})
    size_in = length(input)
    uncompressed_len = Ref{Csize_t}(0)
    ccall((:snappy_uncompressed_length, "libsnappy"),
        Cint,
        (Ptr{UInt8}, Csize_t, Ref{Csize_t}),
        input, size_in, uncompressed_len)
    output = zeros(UInt8, uncompressed_len[])
    ccall((:snappy_uncompress, "libsnappy"),
        Cint,
        (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Ref{Csize_t}),
        input, size_in, output, uncompressed_len)
    return output
end
