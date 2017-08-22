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
        x = compress(raw)
        @test length(x) < length(raw);
        @test hash(raw) == hash(uncompress(x));
    end
end

@testset "random generated compression tests" begin

    wordsize = 1 << 4
    dictsize = 1 << 6
    maxwords = 1 << 16

    dictionary = [rand(UInt8, rand(1:wordsize)) for _ in 1:dictsize]
    for i in 1:100
        raw = vcat((dictionary[rand(1:dictsize)] for _ in 1:rand(1:maxwords))...)
        x = compress(raw)
        @test hash(raw) == hash(uncompress(x));
    end
end

@testset "corrupted data tests              " begin

    src = "making sure we don't crash with corrupted input"
    dst = compress(src)

    @test length(dst) > 3

    dst[2] = ~dst[2]
    dst[4] = dst[3]

    @test_throws ErrorException uncompress(dst);

    # This is testing for a security bug - a buffer that decompresses to 100k
    # but we lie in the snappy header and only reserve 0 bytes of memory :)
    src = repeat("A", 100000)
    dst = compress(src)
    dst[1] = dst[2] = dst[3] = dst[4] = 0

    @test_throws ErrorException uncompress(dst);

    dst[1] = dst[2] = dst[3] = 0xff
    # This decodes to about 2 MB; much smaller, but should still fail.
    dst[4] = 0x00

    @test_throws ErrorException uncompress(dst);

    # try reading stuff in from a bad file.
    testfiles = [
        "baddata1.snappy",
        "baddata2.snappy",
        "baddata3.snappy",
    ]
    for file in testfiles
        raw = read("$(Base.source_dir())/testdata/$(file)")
        @test Snappy.length_uncompressed(raw)[1] < (1<<20)
        @test_throws ErrorException uncompress(raw);
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

    test_strings = map((e)->convert(Vector{UInt8},e), [
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
        x = compress(raw)
        @test length(x) <= Snappy.maxlength_compressed(length(raw))
        @test hash(raw) == hash(uncompress(x));
    end

    a = vcat([rand(UInt8, 4) for _ in 1:20000]...)
    a = vcat(a, a)
    x = compress(a)
    @test length(x) <= Snappy.maxlength_compressed(length(a))
    @test hash(a) == hash(uncompress(x))

end
