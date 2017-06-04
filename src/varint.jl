
const global K_MAX32 = 5


"""
    parse32(buf::Vector{UInt8}, offset::Int)

Reads and returns a varint32 from `buf` starting from `offset`. Raises
an Error if no varint van be parsed.
"""
function parse32(buf::Vector{UInt8}, offset::Int)
    local b::UInt8 = buf[offset]
    local result::UInt32 = b & 127
    offset += 1

    if (b < 128) return result end
    b = buf[offset]; offset += 1; result |= (b & 127) << 7
    if (b < 128) return result end
    b = buf[offset]; offset += 1; result |= (b & 127) << 14
    if (b < 128) return result end
    b = buf[offset]; offset += 1; result |= (b & 127) << 21
    if (b < 128) return result end
    b = buf[offset]; offset += 1; result |= (b & 127) << 28
    if (b < 16) return result end

    error("Could not decode varint32.")
end


"""
    encode32!(buf::Vector{UInt8}, offset::Int, value::UInt32)

Encodes `value` into `buf` starting at `offset`. Returns the index
just past the last byte of the varint32.
"""
function encode32!(buf::Vector{UInt8}, offset::Int, value::UInt32)
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
    return offset += 1
end
