Outline
=======

* Introduction

   * Bioinformatics and Big Data

   * What is the ``khmer`` software?

* Profiling and Measurement

   * Tools

      * gprof

      * TAU

   * Manual Instrumentation

      * ``*PerformanceMetrics`` Objects

      * ``TraceLogger`` Objects

      * Conditional compilation of manual instrumentation.

* Tuning

   * Data Pump and Parser Operations

      * Read large chunks of data directly into special in-memory cache.

      * Parse data cached in memory rather than line-by-line from source.

      * Replace locale-aware, C library ``toupper`` with a quicker macro.

      * Pass ``Read`` structs by reference; eliminate copy on return. (TODO)

   * Bloom Filter Operations

      * Reduce page faults: stash k-mer IDs in special cache before hashing.

* Parallelization

   * Thread-safety and Threading

      * C++ Thread-safety and Python Threading

      * Thread-safety from Atomic Operations

      * Thread-safety from Implicit Reentrancy

   * Data Pump and Parser Operations

      * Support streaming input from parallel gzip/bzip2/etc... decompressors.

      * Allocate special cache in segments for NUMA node locality.

      * Run one parser thread per special cache segment.

      * Coordinate split lines and read pairs with lightweight setaside buffers.

   * Bloom Filter Operations

      * Fuse ``count`` and ``get_count`` hashtable methods for atomicity.

      * Use low-level atomic operations for query and update of hashtables.

* Other Considerations

   * Design Abstractions

      * Separation of parsers into stream readers, cache managers, and parsers.

   * Build System

      * Improved dependency tree for parallel make.

      * Improved cleanup for better rebuilding and testing.

* Future Directions
   
   * Tune string allocator for reads to expected maximum sequence length,
     or use fixed buffers of that size instead of C++ strings.

   * Maybe ``mmap`` Bloom filter storage to eliminate final write-out time.

   * Expand conditionally-compiled manual instrumentation.

   * Support longer k-mer lengths without loss of performance.

   * Work on the partitioning problem.

   * Investigate the use of distributed hash tables in k-mer counting context.


Ideas for Tables and Figures
============================

* Overview Picture of the Architecture of khmer

* Schematic Drawing of a Bloom Filter in Operation

* Schematic Drawing of Multiple NUMA Nodes with Running Threads

* Code Sample of Conditionally-Compiled Manual Instrumentation

* Table of Overall Timings with Original Code vs. Various Performance Tweaks

* Table of Data Pump Timings by Filesystem/Storage Media Type

* Either of the above tables could be done up as bar charts.

* 3D Graph of Number of Threads vs. Cache Segment Size vs. Time
  (for fixed k-mer Length and Bloom Filter Size)

* 3D Graph of Number of Threads vs. k-mer Length vs. Time
  (for fixed Cache Segment Size and Bloom Filter Size)

* 3D Graph of Number of Threads vs. Bloom Filter Size vs. Time
  (for fixed k-mer Length and Cache Segment Size)

* Other permutations of the above 3 graphs.

* Some of the above 3D graphs might be best drawn as 3D bar charts.
  Also, an additional dimension may be added with a color/density scale.

.. vim: set ft=rst sw=3 sts=3 tw=80:
