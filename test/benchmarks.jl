include("../src/Snappy.jl")
include("libsnappy.jl")


using Snappy
using BenchmarkTools


testfiles = [
    "alice29.txt",
    "html",
    "fireworks.jpeg",
    "paper-100k.pdf",
    "urls.10K",
    "sample-tweet.json"
]

for file in testfiles
    println("\n\n")
    println(" ==== sample file: $file")
    input = read("$(Base.source_dir())/testdata/$(file)")

    # warm up
    ccall_uncompress(ccall_compress(input));
    uncompress(compress(input));

    m0_compress = @benchmark ccall_compress($input) evals=10^4 seconds=10
    println(" ======== compress (ccall):")
    display(m0_compress)
    println("")
    m1_compress = @benchmark compress($input) evals=10^4 seconds=10
    println(" ======== compress (Julia):")
    display(m1_compress)
    println("")
    println("---------------------------")
    println(" ============ compress comparison (median):")
    display(judge(median(m1_compress), median(m0_compress)))
    println("\n")

    output = ccall_compress(input);
    m0_uncompress = @benchmark ccall_uncompress($output) evals=10^4 seconds=10
    println(" ======== uncompress (ccall):")
    display(m0_uncompress)
    println("")
    output = compress(input);
    m1_uncompress = @benchmark uncompress($output) evals=10^4 seconds=10
    println(" ======== uncompress (Julia):")
    display(m1_uncompress)
    println("")
    println("---------------------------")
    println(" ============ compress comparison (median):")
    display(judge(median(m1_uncompress), median(m0_uncompress)))
    println("\n")

    println("==================================================")
end
