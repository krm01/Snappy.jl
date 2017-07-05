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



raw = """Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse placerat ipsum sit amet orci interdum, in vestibulum erat faucibus. Mauris posuere facilisis dapibus. Donec turpis magna, porta quis hendrerit eget, malesuada ut mauris. Sed elementum, nisl sit amet ultrices efficitur, sapien tellus pharetra sapien, nec posuere diam orci nec ante. Phasellus et neque faucibus, tincidunt ante ut, eleifend urna. Aliquam ac varius massa. Aliquam ultricies sollicitudin euismod. Etiam ut maximus risus. Donec tincidunt mi sit amet rutrum consectetur. Ut interdum et sapien sit amet tristique. Mauris ligula massa, sollicitudin ut porttitor nec, finibus vitae elit. Pellentesque sit amet mattis metus, ac ornare nulla. Proin ultricies felis malesuada tortor pharetra dignissim. Integer suscipit, odio quis pharetra scelerisque, urna nibh molestie dolor, quis tincidunt augue libero at est.

Aenean eu tristique justo. Proin laoreet porta nisi in viverra. Aenean nec erat bibendum, laoreet tellus sit amet, porttitor elit. Phasellus eleifend varius risus quis ullamcorper. In hac habitasse platea dictumst. Pellentesque vestibulum in magna eu venenatis. Duis lacinia rhoncus ligula a vehicula. Morbi vitae consectetur urna. In nec lorem auctor, vehicula nibh vitae, malesuada augue. Mauris eget accumsan felis.

Cras vulputate porta feugiat. Maecenas velit justo, tristique id scelerisque quis, congue eu sem. Fusce in mi interdum, accumsan nulla non, facilisis metus. Mauris volutpat dapibus orci, in malesuada urna suscipit ut. Sed venenatis dui sit amet quam scelerisque blandit. Sed id tincidunt neque, egestas consectetur nisl. Maecenas molestie aliquet mauris vitae faucibus. Ut dapibus elementum ante, non tincidunt purus vestibulum sed. Aliquam non pellentesque arcu, egestas luctus libero. Vestibulum a risus quis orci blandit porta. Integer ultricies neque sit amet enim convallis dignissim. Nulla in magna metus. Donec vehicula vestibulum purus, non blandit nulla dignissim in. Cras eu lacus eu ante faucibus luctus. Proin ut justo ac purus bibendum feugiat eget et risus.

Donec ac elit varius tellus convallis posuere sit amet eget sapien. Morbi rhoncus elementum ex a viverra. In eu tempus tellus, eget posuere justo. Sed lobortis, nulla a imperdiet convallis, urna dui facilisis lacus, ut condimentum sem dui eget ligula. Interdum et malesuada fames ac ante ipsum primis in faucibus. Donec auctor justo dictum nunc semper tincidunt. In hac habitasse platea dictumst. Fusce sit amet aliquet diam.

Vivamus sollicitudin, erat pellentesque bibendum ornare, dui nulla cursus tortor, eget sollicitudin sem lectus sed dolor. Sed molestie libero nec malesuada venenatis. Vivamus fringilla nulla et metus varius, a lobortis urna tincidunt. Quisque nisi risus, placerat id nibh quis, viverra lacinia nunc. Fusce tempus in ipsum ut sollicitudin. Aliquam rutrum porta gravida. Vivamus et gravida lacus, vel ultricies neque. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam vitae sapien sapien. Phasellus felis ligula, venenatis auctor turpis quis, lacinia tempus odio. Sed commodo turpis maximus, congue augue non, ullamcorper ante. Donec volutpat venenatis metus, aliquam commodo augue aliquam sed. Donec a viverra dui. Nullam sit amet tortor quis felis sagittis dictum."""

#raw = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse placerat ipsum sit amet orci interdum, in vestibulum erat faucibus."
println(compress(raw))
#Juno.@step compress(raw)

end
