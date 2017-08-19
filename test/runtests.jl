include("../src/Snappy.jl")

using Snappy
using Base.Test

@testset "round_trip_compression_tests" begin

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
    ]

    for file in testfiles
        raw = read("$(@__DIR__)/testdata/$(file)")
        @test hash(raw) == hash(uncompress(compress(raw)));
    end
end

@testset "invalid_data" begin

    testfiles = [
        "baddata1.snappy",
        "baddata2.snappy",
        "baddata3.snappy",
    ]
    for file in testfiles
        raw = read("$(@__DIR__)/testdata/$(file)")
        @test_throws ErrorException uncompress(raw);
    end
end
