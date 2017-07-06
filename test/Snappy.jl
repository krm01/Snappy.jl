include("../src/Snappy.jl")
include("../src/internal.jl")

using Snappy
using Base.Test

#println(map(Int, convert(Vector{UInt8}, compress(raw))))

# @testset "find_match_length" begin
#     s2 = convert(Vector{UInt8}, "test string prefix up to here... and now they're different!")
#     s1 = convert(Vector{UInt8}, "test string prefix up to here. but then they diverge")
#     matched = find_match_length(s1, s2)
#     @test matched == 30
# end

@testset "test_fromfile" begin
    input = read("$(@__DIR__)/testdata/alice29.txt")
    expected = read("$(@__DIR__)/testdata/alice29.snappy")
    actual = compress(input)
    @test hash(actual) == hash(expected)
    @test hash(actual) == hash(expected)
end
