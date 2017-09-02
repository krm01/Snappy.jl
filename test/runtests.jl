include("../src/Snappy.jl")

using Snappy
using Base.Test

@testset "round trip compression tests      " begin

    testfiles = [
        "alice29.txt",
        "asyoulik.txt",
        "html",
        "html_x_4",
        "kppkn.gtb",
        "lcet10.txt",
        "fireworks.jpeg",
        "geo.protodata",
        "paper-100k.pdf",
        "plrabn12.txt",
        "urls.10K",
        "random1.bin",
        "random2.bin",
        "random3.bin",
        "smallrandom1.bin",
    ]
    for file in testfiles
        raw = read("$(Base.source_dir())/testdata/$(file)")
        a = compress(raw)
        b = uncompress(a)
        @test hash(a) != hash(raw) # just make sure it isn't identity
        @test hash(b) != hash(a)
        @test hash(raw) == hash(b)
    end
end

@testset "random generated compression tests" begin

    wordsize = 1 << 4
    dictsize = 1 << 6
    maxwords = 1 << 16

    dictionary = [rand(UInt8, rand(1:wordsize)) for _ in 1:dictsize]
    for i in 1:50
        raw = vcat((dictionary[rand(1:dictsize)] for _ in 1:rand(1:maxwords))...)
        a = compress(raw)
        b = uncompress(a)
        @test hash(a) != hash(raw)
        @test hash(b) != hash(a)
        @test hash(raw) == hash(b)
    end
    # run some of the tests using the string wrapper
    for i in 1:50
        raw = vcat((dictionary[rand(1:dictsize)] for _ in 1:rand(1:maxwords))...)
        a = compress(String(raw))
        b = uncompress(a)
        @test hash(a) != hash(raw)
        @test hash(b) != hash(a)
        @test hash(raw) == hash(b)
    end

end

@testset "corrupted data tests              " begin

    src = "making sure we don't crash with corrupted input"
    dst = compress(src)

    @test length(dst) > 3

    dst[2] = ~dst[2]
    dst[4] = dst[3]

    @test_throws ErrorException uncompress(dst)

    # This is testing for a security bug - a buffer that decompresses to 100k
    # but we lie in the snappy header and only reserve 0 bytes of memory :)
    src = repeat("A", 100000)
    dst = compress(src)
    dst[1] = dst[2] = dst[3] = dst[4] = 0

    @test_throws ErrorException uncompress(dst)

    dst[1] = dst[2] = dst[3] = 0xff
    # This decodes to about 2 MB; much smaller, but should still fail.
    dst[4] = 0x00

    @test_throws ErrorException uncompress(dst)

    # try reading stuff in from a bad file.
    testfiles = [
        "baddata1.snappy",
        "baddata2.snappy",
        "baddata3.snappy",
    ]
    for file in testfiles
        raw = read("$(Base.source_dir())/testdata/$(file)")
        @test Snappy.length_uncompressed(raw)[1] < (1<<20)
        @test_throws ErrorException uncompress(raw)
    end

    # corrupted varint tests
    raw = [0xf0]
    @test_throws ErrorException Snappy.parse32(raw, 1)
    @test_throws ErrorException uncompress(raw)

    raw = [0x80, 0x80, 0x80, 0x80, 0x80, 0x0a]
    @test_throws ErrorException Snappy.parse32(raw, 1)
    @test_throws ErrorException uncompress(raw)

    raw = [0xfb, 0xff, 0xff, 0xff, 0x7f]
    @test_throws ErrorException Snappy.parse32(raw, 1)
    @test_throws ErrorException uncompress(raw)

    # check for an infinite loop caused by a copy with offset==0
    raw = [0x40, 0x12, 0x00, 0x00]
    #  0x40                 Length
    #  0x12, 0x00, 0x00     Copy with offset==0, length==5
    @test_throws ErrorException uncompress(raw)

    raw = [0x05, 0x12, 0x00, 0x00]
    #  0x05                 Length
    #  0x12, 0x00, 0x00     Copy with offset==0, length==5
    @test_throws ErrorException uncompress(raw)
end

@testset "simple tests                      " begin

    test_strings = map((e)->Vector{UInt8}(e), [
        "",
        "a",
        "ab",
        "abc",
        "aaaaaaa" * repeat("b", 16) * "aaaaa" * "abc",
        "aaaaaaa" * repeat("b", 256) * "aaaaa" * "abc",
        "aaaaaaa" * repeat("b", 2047) * "aaaaa" * "abc",
        "aaaaaaa" * repeat("b", 65536) * "aaaaa" * "abc",
        "abcaaaaaaa" * repeat("b", 65536) * "aaaaa" * "abc",
    ])

    for raw in test_strings
        a = compress(raw)
        b = uncompress(a)
        @test hash(a) != hash(raw)
        @test hash(b) != hash(a)
        @test hash(raw) == hash(b)
    end

    # verify max blowup (lots of four-byte copies)
    raw = reinterpret(UInt8, rand(UInt32, 20000))
    raw = vcat(raw, flipdim(raw, 1))
    a = compress(raw)
    b = uncompress(a)
    @test hash(a) != hash(raw)
    @test hash(b) != hash(a)
    @test hash(raw) == hash(b)

    # encode a range of varint values
    buf = zeros(UInt8, 5)
    for i in 0:30
        offset = Snappy.encode32!(buf, 1, UInt32(1 << i))
        val, offset2 = Snappy.parse32(buf, 1)
        @test val == UInt32(1 << i)
        @test offset == offset2
    end
end

@testset "find_match_length tests           " begin

    function test_find_match_length(a::String, b::String, limit::Int)
        a = Vector{UInt8}(a)
        b = Vector{UInt8}(b)
        c = vcat(a, b)
        return Snappy.find_match_length(c, start(a), endof(a)+1, endof(a)+limit)
    end

    # Hit s1_limit in 64-bit loop, hit s1_limit in single-character loop.
    @test 6 == test_find_match_length("012345", "012345", 6)
    @test 11 == test_find_match_length("01234567abc", "01234567abc", 11)

    # Hit s1_limit in 64-bit loop, find a non-match in single-character loop.
    @test 9 == test_find_match_length("01234567abc", "01234567axc", 9)

    # Same, but edge cases.
    @test 11 == test_find_match_length("01234567abc!", "01234567abc!", 11)
    @test 11 == test_find_match_length("01234567abc!", "01234567abc?", 11)

    # Find non-match at once in first loop.
    @test 0 == test_find_match_length("01234567xxxxxxxx", "?1234567xxxxxxxx", 16)
    @test 1 == test_find_match_length("01234567xxxxxxxx", "0?234567xxxxxxxx", 16)
    @test 4 == test_find_match_length("01234567xxxxxxxx", "01237654xxxxxxxx", 16)
    @test 7 == test_find_match_length("01234567xxxxxxxx", "0123456?xxxxxxxx", 16)

    # Find non-match in first loop after one block.
    @test 8 == test_find_match_length("abcdefgh01234567xxxxxxxx",
                                   "abcdefgh?1234567xxxxxxxx", 24)
    @test 9 == test_find_match_length("abcdefgh01234567xxxxxxxx",
                                   "abcdefgh0?234567xxxxxxxx", 24)
    @test 12 == test_find_match_length("abcdefgh01234567xxxxxxxx",
                                    "abcdefgh01237654xxxxxxxx", 24)
    @test 15 == test_find_match_length("abcdefgh01234567xxxxxxxx",
                                    "abcdefgh0123456?xxxxxxxx", 24)

    # 32-bit version:

    # Short matches.
    @test 0 == test_find_match_length("01234567", "?1234567", 8)
    @test 1 == test_find_match_length("01234567", "0?234567", 8)
    @test 2 == test_find_match_length("01234567", "01?34567", 8)
    @test 3 == test_find_match_length("01234567", "012?4567", 8)
    @test 4 == test_find_match_length("01234567", "0123?567", 8)
    @test 5 == test_find_match_length("01234567", "01234?67", 8)
    @test 6 == test_find_match_length("01234567", "012345?7", 8)
    @test 7 == test_find_match_length("01234567", "0123456?", 8)
    @test 7 == test_find_match_length("01234567", "0123456?", 7)
    @test 7 == test_find_match_length("01234567!", "0123456??", 7)

    # Hit s1_limit in 32-bit loop, hit s1_limit in single-character loop.
    @test 10 == test_find_match_length("xxxxxxabcd", "xxxxxxabcd", 10)
    @test 10 == test_find_match_length("xxxxxxabcd?", "xxxxxxabcd?", 10)

    # NOTE: this test is from the original C++, but I think it's invalid for julia.
    #   the strings it's comparing are only 12 characters - how can it have
    #   a match length of 13? I suspect the test passes in C++ because it
    #   reads 1 past the end of the string and ends up comparing the null
    #   terminators of each, and includes that as part of the "match length".
    @test_broken 13 == test_find_match_length("xxxxxxabcdef", "xxxxxxabcdef", 13)
    # repeating the test with explicitly including a terminator in the strings
    #   will test the same functionality as the above test is supposed to.
    @test 13 == test_find_match_length("xxxxxxabcdef\0", "xxxxxxabcdef\0", 13)

    # Same, but edge cases.
    @test 12 == test_find_match_length("xxxxxx0123abc!", "xxxxxx0123abc!", 12)
    @test 12 == test_find_match_length("xxxxxx0123abc!", "xxxxxx0123abc?", 12)

    # Hit s1_limit in 32-bit loop, find a non-match in single-character loop.
    @test 11 == test_find_match_length("xxxxxx0123abc", "xxxxxx0123axc", 13)

    # Find non-match at once in first loop.
    @test 6 == test_find_match_length("xxxxxx0123xxxxxxxx",
                                   "xxxxxx?123xxxxxxxx", 18)
    @test 7 ==test_find_match_length("xxxxxx0123xxxxxxxx",
                                   "xxxxxx0?23xxxxxxxx", 18)
    @test 8 == test_find_match_length("xxxxxx0123xxxxxxxx",
                                   "xxxxxx0132xxxxxxxx", 18)
    @test 9 == test_find_match_length("xxxxxx0123xxxxxxxx",
                                   "xxxxxx012?xxxxxxxx", 18)

    # Same, but edge cases.
    @test 6 == test_find_match_length("xxxxxx0123", "xxxxxx?123", 10)
    @test 7 == test_find_match_length("xxxxxx0123", "xxxxxx0?23", 10)
    @test 8 == test_find_match_length("xxxxxx0123", "xxxxxx0132", 10)
    @test 9 == test_find_match_length("xxxxxx0123", "xxxxxx012?", 10)

    # Find non-match in first loop after one block.
    @test 10 == test_find_match_length("xxxxxxabcd0123xx",
                                    "xxxxxxabcd?123xx", 16)
    @test 11 == test_find_match_length("xxxxxxabcd0123xx",
                                    "xxxxxxabcd0?23xx", 16)
    @test 12 == test_find_match_length("xxxxxxabcd0123xx",
                                    "xxxxxxabcd0132xx", 16)
    @test 13 == test_find_match_length("xxxxxxabcd0123xx",
                                    "xxxxxxabcd012?xx", 16)

    # Same, but edge cases.
    @test 10 == test_find_match_length("xxxxxxabcd0123", "xxxxxxabcd?123", 14)
    @test 11 == test_find_match_length("xxxxxxabcd0123", "xxxxxxabcd0?23", 14)
    @test 12 == test_find_match_length("xxxxxxabcd0123", "xxxxxxabcd0132", 14)
    @test 13 == test_find_match_length("xxxxxxabcd0123", "xxxxxxabcd012?", 14)

end
