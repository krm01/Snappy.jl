
const global K_MAX32 = 5

"""
    parse32(buf::Vector{UInt8}, offset::UInt)

Reads and returns a varint32 from `buf`. Raises an error if no varint
can be parsed. Returns the value and the index just past the last
byte of the varint32.
"""
@inline function parse32(buf::Vector{UInt8}, offset::Integer)
    offset > length(buf) && @goto failure
    local b::UInt32 = convert(UInt32, buf[offset])
    local result::UInt32 = b & 0x7f

    (b < 0x80) && return (result, offset+1)
    (offset+=1) > length(buf) && @goto failure

    b = buf[offset]; result |= (b & 0x7f) << 7
    (b < 0x80) && return (result, offset+1)
    (offset+=1) > length(buf) && @goto failure

    b = buf[offset]; result |= (b & 0x7f) << 14
    (b < 0x80) && return (result, offset+1)
    (offset+=1) > length(buf) && @goto failure

    b = buf[offset]; result |= (b & 0x7f) << 21
    (b < 0x80) && return (result, offset+1)
    (offset+=1) > length(buf) && @goto failure

    b = buf[offset]; result |= (b & 0x7f) << 28
    (b < 0x10) && return (result, offset+1)

    @label failure
    error("Could not decode varint32.")
end


"""
    encode32!(buf::Vector{UInt8}, offset::Int, value::UInt32)

Encodes `value` into `buf` starting at `offset`. Returns the index
just past the last byte of the varint32.
"""
@inline function encode32!(buf::Vector{UInt8}, offset::Integer, value::UInt32)
    if value < (1 << 7)
        buf[offset] = value % UInt8
        elseif value < (1 << 14)
            buf[offset] = (value | 128) % UInt8
            buf[offset+=1] = (value >> 7) % UInt8
        elseif value < (1 << 21)
            buf[offset] = (value | 128) % UInt8
            buf[offset+=1] = (value >> 7 | 128) % UInt8
            buf[offset+=1] = (value >> 14) % UInt8
        elseif value < (1 << 28)
            buf[offset] = (value | 128) % UInt8
            buf[offset+=1] = (value >> 7 | 128) % UInt8
            buf[offset+=1] = (value >> 14 | 128) % UInt8
            buf[offset+=1] = (value >> 21) % UInt8
        else
            buf[offset] = (value | 128) % UInt8
            buf[offset+=1] = (value >> 7 | 128) % UInt8
            buf[offset+=1] = (value >> 14 | 128) % UInt8
            buf[offset+=1] = (value >> 21 | 128) % UInt8
            buf[offset+=1] = (value >> 28) % UInt8
        end
    return offset + 1
end
