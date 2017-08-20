include("../src/Snappy.jl")

using Snappy
using Base.Test

@testset "round_trip_compression_tests      " begin

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
@testset "invalid_data_tests                " begin

    testfiles = [
        "baddata1.snappy",
        "baddata2.snappy",
        "baddata3.snappy",
    ]
    for file in testfiles
        raw = read("$(Base.source_dir())/testdata/$(file)")
        @test_throws ErrorException uncompress(raw);
    end
end

@testset "generated_random_compression_tests" begin

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
