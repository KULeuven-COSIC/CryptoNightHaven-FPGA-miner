# Mining CryptoNight Haven on the Varium C1100

This repository presents our work-in-progress towards a CryptoNight Haven [Varium C1100](https://www.xilinx.com/content/dam/xilinx/publications/product-briefs/varium-c1100-product-brief.pdf) FPGA-miner. This project was undertaken in the context of the Xilinx 2021 Adaptive Computing Challenge.  

:warning: The project is still work-in-progress. The miner is unfortunately not functional.


## Setup

Our project uses a similar setup to the `rtl_kernels` in the [Vitis Accel Examples Repostiory](https://github.com/Xilinx/Vitis_Accel_Examples/tree/master/rtl_kernels). Have a look at the latest Xilinx documentation on [compiling and executing](https://xilinx.github.io/Vitis_Accel_Examples/2021.2/html/compile_execute.html).

### Makefile

The top-level `Makefile` defines several targets for execution. Use

```make
make help
```
for further info.

## Execution

Execution is controlled through the `Makefile`. After execution finishes, the software will print out 8 Control and Status Registers ( `CSR[7:0]` ). These registers collect information on the hardware execution:

```verilog
 csr0_to_sw <= {cn_counter[15:0] , pre_counter[15:0] };
 csr1_to_sw <= {out_counter[15:0], post_counter[15:0]};
 csr2_to_sw <= cycle_counter[31:0];
 csr3_to_sw <= latency;
 csr4_to_sw <= m00_axi_w_counter;
 csr5_to_sw <= m01_axi_w_counter;
 csr6_to_sw <= m01_axi_r_counter;
 csr7_to_sw <= m02_axi_r_counter;
```


- `pre_counter`: amount of block header data (with differing nonces) fed to `pre_cn` (initial `keccak`) module
- `cn_counter`: amount of data passed from `pr_cn` to `cn`
- `post_counter`: amount of data passed from `cn` to `final_hashes`
- `out_counter`: for how many hash results are computed
- `cycle_counter`: the number of clock ticks between `start` and `exit`
- `latency`: the number of clock ticks between `start` to first `cn_output`
- `m0{x}_axi_{r,w}_counter`: ammount of axi transactions handled:
  - `m00_axi_w_counter `for explode, writing the scratch pad data to memory. write-only in bursts
  - `m01_axi_w_counter` and `m01_axi_r_counter` for shuffle operations. one beat (not burst) read and write operations.
  - `m02_axi_2_counter` for implode, reading the final state of the scratch pad memory. read-only in bursts.



## Additional Information: Project Structure

 - `build`: contains the `.xo` and `.xclbin` files as well as all the
   files from compiling and synthesizing the design. Vivado makes a
   tmp project while packaging, it is useful to keep this for debugging
   purposes.
- `common`: include files
 - `package`: contains the config files for `v++`. 
   - `cfg/*.cfg`: connect kernels to each other and to memory. 
   - `scripts/package.tcl`: packaging script
   - `config.mk` : makefile configurations
 - `run`: contains simulation/emulation results and the compiled host
   application. 
 - `src`: contains source files for the host, the rtl kernels, as well as tcl
   scripts for packaging them.


