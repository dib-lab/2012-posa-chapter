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

Introduction
============

Bioinformatics and Big Data
---------------------------

The field of bioinformatics seeks to understand the mechanisms which sustain and
perpetuate life on Earth by examining information about the combination of and
function of the molecules associated with these activities. The combinations and
functions of these molecules are examined at different scales, the most common
being nucleotides (the smallest) and proteins. A chemical and mechanical 
process, known as sequencing, extracts nucleotide sequences from the DNA and 
RNA present in terrestrial life. These sequences are recorded using an
*alphabet* of one letter per molecule. Various analyses are performed on this
sequence data to determine how it is structured into larger building blocks and
how it relates to other sequence data. This serves as the basis for the study of
biological evolution and development, genetics, and the treatment of disease.

Data on nucleotide chains comes from the sequencing process in named strings of
letters known as *reads*. (The use of the term *read* in the bioinformatic sense
is an unfortunate collision with the use of the term in the computer science and
software engineering sense. This is especially true as the performance of
reading reads can be tuned, as we will discuss. We will try to disambiguate this 
unfortunate collision as much as we can in this chapter.) To analyze larger 
scale structures and processes, the nucleotide sequences of multiple reads 
must be fit together. This fitting is different than a jigsaw puzzle in that 
the picture is often not known a priori and that the pieces overlap one 
another. A further complication is introduced in that the reads are not 
perfect and may contain a variety of errors, such as insertions or deletions 
of nucleotides or representations of nucleotides with the wrong letters. While 
having redundant reads can help in the assembly or fitting of the puzzle 
pieces, it is also a hindrance because the various sequencing techniques all 
have a certain probability for producing errors and this means that the number 
of errors scales with the volume of data.

As sequencing technology has improved, the volume of sequence data being
produced has begun to exceed the capabilities of computer hardware employing
conventional methods for analyzing such data. This trend is expected to
continue and is part of what is known as the *Big Data* problem in the high
performance computing (HPC) and analytics communities. With hardware becoming 
a limiting factor, increasing attention has turned to ways to mitigate the
problem with software solutions. In this chapter, we present one such software
solution and how we tuned it to efficiently handle terabytes of data.

What is the ``khmer`` Software?
-------------------------------

``khmer``, in addition to being an ethnic group indigenous to Southeast Asia, is
the name of our suite of software tools for preprocessing large amounts of 
sequence data prior to its analysis with conventional tools. As part of the
preprocessing the software performs, sequences are decomposed into overlapping
substrings of a given length, *k*. As chains of many molecules are often
referred to as *polymers*, chains of a specific number of molecules are called
*k-mers* in bioinformatics, each substring representing one such chain. (The
hyphen between ``k`` and ``mer`` is a frequent convention and perhaps the ``h``
in the name of the software represents this.)

Since we want to tell you about how we measured and tuned this piece of open 
source software, we'll skip over much of the theory behind it. Suffice it to say
that k-mer counting is central to much of its operation. To compactly count a
large number of k-mers, a data structure known as a *Bloom filter* is used.
Armed with k-mer counts, we can then exclude highly redundant data from further
processing. And, we can also treat low abundance sequence data as probable 
errors and exclude it from further processing as well. We call such exclusion 
or filtering *digital normalization* and it is one of the major innovations 
that this software has lent to bioinformatics processing. This normalization
process greatly reduces the amount of raw sequence data needed for further
analysis while mostly preserving information of interest.

For the curious, the ``khmer`` sources and documentation can be cloned from
GitHub at http://github.com/ged-lab/khmer.git .

Profiling and Measurement
=========================

Although simple reading of the code revealed some areas which were clearly
performance bottlenecks, we wanted to empirically identify and quantify where 
the problem spots were. (We're scientists and so its close to second nature for
us to want to "empirically identify and quantify" things.) Using a combination
of readily available open source tools and built-in instrumentation, we think
that we got a pretty good idea of where the weakest performances were. 

Tools
-----

While we don't want to spend too much time on the specifics of the performance
profiling tools which we used, we do want to give a shout out to these pieces of
open source software and briefly mention how we used them.

Manual Instrumentation
----------------------

Examining the performance of a piece of software with independent, external
profilers is all well and good, but how better to discover the finer details of
your software's performance than have it tell you itself? To this end, we
created an extensible framework to internally measure things such as
throughputs, iteration counts, and timings around atomic or fine-grained
operations within the software itself. As a means of keeping us honest, we 
internally collected some numbers that could be compared with measurements 
from the external profilers.

To ensure that the overhead of the manually-inserted internal instrumentation is
not present in production code, we carefully wrapped it in conditional 
compilation directives so that a build can specify to exclude it.

Tuning
======

Making software work more efficiently is quite a gratifying experience,
especially in the face of trillions of bytes passing through it. Our narrative
will now wander through the various measures we took to improve efficiency. We
divide these into two parts: optimization of the reading and parsing of 
input data and optimization of the manipulation and writing of the Bloom 
filter contents.

Data Pump and Parser Operations
-------------------------------

Discussion of various optimizations here....

Bloom Filter Operations
-----------------------

Discussion of Rose' work here....

Parallelization
===============

With the proliferation of multi-core architectures in today's world, it is
tempting to try taking advantage of them. However, unlike many other problem
domains, such as computational fluid dynamics or molecular dynamics, our Big
Data problem is essentially IO-bound. Beyond a certain point, throwing
additional threads at it does not help as the bandwidth to the storage media is
saturated and the threads simply end up with increased blocking or IO wait
times. That said, utilizing some threads can be useful, particularly if the data
to be processed is held in physical RAM, which generally has a much higher
bandwidth than online storage. As part of our tuning, we took over cache
management from the operating system so that we could efficiently make large
blocks of data available in physical RAM. Thus, the stage was set for threads to
work on the data without contending for limited bandwidth to the storage
medium.

Thread-safety and Threading
---------------------------

People often confuse the notion of something being thread-safe with that of
something being threaded. As part of our parallelization work, we remodeled
portions of the C++ core implementation to be thread-safe without making any
assumptions about a particular threading model. Therefore, the Python
``threading`` module can be used in the scripts which use the Python wrapper
around the core implementation, or a C++ driver around the core could use
a higher level abstraction, like OpenMP, or explicitly implement threading with
``pthreads``, for example.

Data Pump and Parser Operations
-------------------------------

The multi-core machines one encounters in the HPC world may have multiple memory
controllers, where one controller is closer (in terms of signal travel
distance) to one CPU than another CPU. These are Non-Uniform Memory Access
(NUMA) architectures. A ramification of working with machines of this
architecture is that memory fetch times may vary significantly depending on
physical address. As bioinformatics software often requires a large memory
footprint to run, it is often found running on these machines. Therefore, if one
is using multiple threads, which may be pinned to various *NUMA nodes*, the
locality of the physical RAM must be taken into consideration. Part of our
performance tuning consisted of allocating segments of our data cache in a
properly localized manner.

A couple of tidbits about atomization and locking here....

Also some notes on coordination between parser threads for reads which span
cache segment boundaries....

Bloom Filter Operations
-----------------------

More tidbits about atomization and locking here....

Other Considerations
====================

Design Abstractions
-------------------

To aid in some of the performance tuning, we found it strongly desirable to
refactor the design of the software's data pump and parser. Previously, the data
pump and parser had been deeply intertwined. To improve our ability to
accommodate new file formats, manage a data cache, and parallelize the parser,
we broke the monolithic data pump and parser machinery into multiple pieces,
each with a distinct interface. As a result, we are now able to support
additional file formats without having to worry the intimate details of
parallelization everytime.

Build System
------------

Obviously, our main focus was in making the software execute more efficiently
and hence more quickly. But, if you've ever built any considerable amount of
software, especially the same piece of software over and over again, then you've
probably wanted to speed up the build process as well. We certainly encountered
such a desire and will briefly discuss the work enable successful parallel
builds of our software.

Future Directions
=================

Further performance tuning can be done on this software. Some of this tuning is
fairly low-hanging fruit, which simply needs to yet be plucked. But, other
portions of this tuning wander into the territory of being research problems. We
briefly discuss both kinds of tuning and the additional impacts we hope to see.

.. vim: set ft=rst sw=3 sts=3 tw=80:
