
const global K_MAX32 = 5

"""
    parse32(buf::Vector{UInt8}, offset::UInt)

Reads and returns a varint32 from `buf`. Raises an error if no varint
can be parsed.
RETURNS: (varint, nBytesRead)
"""
function parse32(buf::Vector{UInt8})
    local b::UInt32 = convert(UInt32, buf[1])
    local result::UInt32 = b & 0x7f
    (b < 0x80) && return (result, 1)

    b = buf[2]; result |= (b & 0x7f) << 7
    (b < 0x80) && return (result, 2)

    b = buf[3]; result |= (b & 0x7f) << 14
    (b < 0x80) && return (result, 3)

    b = buf[4]; result |= (b & 0x7f) << 21
    (b < 0x80) && return (result, 4)

    b = buf[5]; result |= (b & 0x7f) << 28
    (b < 0x10) && return (result, 5)

    error("Could not decode varint32.")
end


"""
    encode32!(buf::Vector{UInt8}, offset::Int, value::UInt32)

Encodes `value` into `buf` starting at `offset`. Returns the index
just past the last byte of the varint32.
"""
function encode32!(buf::Vector{UInt8}, offset::Integer, value::UInt32)
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
