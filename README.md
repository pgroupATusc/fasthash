# FASTHash: FPGA-Based High Throughput Parallel Hash Table
Source Code for the paper Titled FASTHash: FPGA-Based High Throughput Parallel Hash Table published in ISC high performance 2020

## Abstract
Hash table is a fundamental data structure that provides efficient data store and access. It is a key component in AI applications which rely on building a model of the environment using observations and performing lookups on the model for newer observations. In this work, we develop FASTHash, a “truly” high throughput parallel hash table implementation using FPGA on-chip SRAM. Contrary to state-of-the-art hash table implementations on CPU, GPU, and FPGA, the parallelism in our design is data independent, allowing us to support p parallel queries (equation M1) per clock cycle via p processing engines (PEs) in the worst case. Our novel data organization and query flow techniques allow full utilization of abundant low latency on-chip SRAM and enable conflict free concurrent insertions. Our hash table ensures relaxed eventual consistency - inserts from a PE are visible to all PEs with some latency. We provide theoretical worst case bound on the number of erroneous queries (true negative search, duplicate inserts) due to relaxed eventual consistency. We customize our design to implement both static and dynamic hash tables on state-of-the-art FPGA devices. Our implementations are scalable to 16 PEs and support throughput as high as 5360 million operations per second with PEs running at 335 MHz for static hashing and 4480 million operations per second with PEs running at 280 MHz for dynamic hashing. They outperform state-of-the-art implementations by 5.7x and 8.7x respectively.

## Hardware/Tools
1. Targeted FPGA: Xilinx U250 <br />
2. Tools: Xilinx Vivado 2019.2  <br />

## Directory Structure
### rtl
This directory contains the RTL source code for the FastHASH implementation.

### test
This directory contains unit-level testbench for the RTL code.

## Setting up the projects
1. Create a new project using Xilinx Vivado and use Xilinx U250 FPGA as the targeted device. <br />
2. Include project files in rtl folder. <br />
3. Run synthesis and implementation flow. <br />
4. For simulating internal modules (Unit tests), use test benches in test folder <br />
