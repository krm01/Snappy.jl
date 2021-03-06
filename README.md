# Snappy.jl
[![Build Status](https://travis-ci.org/krm01/Snappy.jl.svg?branch=master)](https://travis-ci.org/krm01/Snappy.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/vhvheji9o932cjde?svg=true)](https://ci.appveyor.com/project/krm01/snappy-jl)
[![codecov](https://codecov.io/gh/krm01/Snappy.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/krm01/Snappy.jl)

Julia implementation of the snappy compressor <https://github.com/google/snappy>, a fast compression library developed by Google.

You're likely looking for <https://github.com/bicycle1885/Snappy.jl>, which is the METADATA-registered Snappy package. It provides Julia bindings for the above C++ library, whereas this package is a 100% Julia reimplementation. There is little reason to use this library over the official one unless I can get it to be faster than a `ccall` (see [Performance](#performance) below), or perhaps if you cannot use binary dependencies and require pure Julia packages.

## Installation
This package is currently unregistered, and so needs to be installed with `Pkg.clone()` if you want to use it.

```julia
julia> Pkg.clone("git://github.com/krm01/Snappy.jl.git")
```

## Usage
The compression and decompression functions operate on and return byte arrays, i.e. `Vector{UInt8}`. Two functions are exported:

```julia
compress(input::Vector{UInt8})
```
```julia
uncompress(input::Vector{UInt8})
```
A `compress(input::String)` method is provided for convenience.

## Performance
This Julia implementation produces nearly identical compressed output compared to the reference C++ version, typically +/- a few bytes. This difference comes from quirks in translating 0-based array code into Julia's 1-based arrays - it can likely produce a byte-for-byte copy with some work. The compressed representation is still bidirectionally compatible however.

Currently, Julia is ≈ 20% slower for compression, and ≈ 30% slower for decompression on compressible input. The decompression routine in Julia is not as quick with handling copy backreferences, but there is likely plenty of room for improvement there.

The table below shows a throughput report on several filetypes, mostly using the sample data included with the original snappy source. The time reported is the median of 10,000 samples (except for the `large` entry, which is built from the linux kernel source code - only 100 samples were taken). These benchmarks are NOT Julia vs. a C++ program, rather Julia vs. a `ccall` to the native library.

**NOTE**: These tests were run against libsnappy-1.1.7, the latest release version, with Julia 0.6.0 on 64-bit Mac OS.

|file|size|Julia (compress)|ccall (compress)| ∆ |Julia (uncompress)|ccall (uncompress)| ∆ |
|----|---|:------------:|:------------:|---|:-----------:|:-----------:|---|
|`txt`|149K|243 MB/s|300 MB/s|+23.24%|324 MB/s|415 MB/s|+28.14%|
|`html`|100K|672 MB/s|855 MB/s|+27.31%|288 MB/s|515 MB/s|+78.28%|
|`jpeg`|120K|1.92 GB/s|1.99 GB/s|+3.8%|6.73 GB/s|6.49 GB/s|-3.6%|
|`pdf`|100K|3.43 GB/s|4.05 GB/s|+18.05%|4.24 GB/s|4.74 GB/s|+11.68%|
|`urls`|686K|357 MB/s|423 MB/s|+18.31%|332 MB/s|455 MB/s|+37.01%|
|`json`|13K|744 MB/s|1.08 GB/s|+48.74%|420 MB/s|645 MB/s|+53.48%|
|`large`|644M|361 MB/s|431 MB/s|+19.19%|247 MB/s|322 MB/s|+30.07%|

The compression/decompression routines are optimized to target 64-bit little endian systems, and will likely run slower on other platforms.

## Contributing
Feedback / PRs / issues are greatly appreciated! Developing this package is my first exposure to Julia, and I used it as a learning excercise to become familiar with the language. I tried to stick to the original C++ as close as possible, and I'm sure there's patterns and complexity that could be avoided with a more Julian approach to the problem.
