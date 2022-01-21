#!/bin/bash

###############################################################################
# Approximate performance numbers that are specified in comments were generated
# on a machine with the following characteristics.
# Note the SMT pair of CPU 4 (i.e. CPU 40) is disabled.
###############################################################################
# > lscpu
# Architecture:            x86_64
#   CPU op-mode(s):        32-bit, 64-bit
#   Address sizes:         46 bits physical, 48 bits virtual
#   Byte Order:            Little Endian
# CPU(s):                  72
#   On-line CPU(s) list:   0-39,41-71
#   Off-line CPU(s) list:  40
# Vendor ID:               GenuineIntel
#   BIOS Vendor ID:        Intel(R) Corporation
#   Model name:            Intel(R) Xeon(R) Gold 6154 CPU @ 3.00GHz
#     BIOS Model name:     Intel(R) Xeon(R) Gold 6154 CPU @ 3.00GHz
#     CPU family:          6
#     Model:               85
#     Thread(s) per core:  2
#     Core(s) per socket:  18
#     Socket(s):           2
#     Stepping:            4
#     CPU max MHz:         3700.0000
#     CPU min MHz:         1200.0000
#     BogoMIPS:            6000.00
#     Flags:               fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr p
#                          dcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l3 cdp_l3 invpcid_single pti intel_ppin ssbd mba ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm cqm mpx rd
#                          t_a avx512f avx512dq rdseed adx smap clflushopt clwb intel_pt avx512cd avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local dtherm ida arat pln pts hwp hwp_act_window hwp_epp hwp_pkg_req pku ospke md_clear flush_l1d
# Virtualization features: 
#   Virtualization:        VT-x
# Caches (sum of all):     
#   L1d:                   1.1 MiB (36 instances)
#   L1i:                   1.1 MiB (36 instances)
#   L2:                    36 MiB (36 instances)
#   L3:                    49.5 MiB (2 instances)
# NUMA:                    
#   NUMA node(s):          2
#   NUMA node0 CPU(s):     0-17,36-39,41-53
#   NUMA node1 CPU(s):     18-35,54-71
# Vulnerabilities:        

###############################################################################
# The benchmarks below assume the setup described in the 'Benchmark commands' 
# section in the README.md. Instructions are reproduced here for convenience.
###############################################################################
# ################################################################
# # Prepare to run on CPU 4 only
# ################################################################
# # Disable address space randomization.
# echo 0 > /proc/sys/kernel/randomize_va_space

# # Disable the sibling of CPU 4.
# cat /sys/devices/system/cpu/cpu4/topology/thread_siblings_list 
# # E.g. this may return 4,40
# echo 0 > /sys/devices/system/cpu/cpu40/online

# ################################################################
# Perform cpuset manipulation.
# ################################################################
# # For reference, cset shield does not seem to run as expected on at least 2 systems.
# # cset shield -c 4 --user=${RUN_AS_USER} -k on --userset=${RUN_AS_USER}
# # Instead, reproduce the follwing: 
# # https://documentation.suse.com/sle-rt/15-SP2/html/SLE-RT-all/cha-shielding-cpuset.html
# #
# cset set -c 0-3,5-39,41-71 -s system -s system
# cset set -s sandbox -c 4 -m 0 --cpu_exclusive
# cset proc -m -f root -t system

# ################################################################
# # Freq control (note, cloud VM instances do not allow).
# ################################################################

# echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
# echo performance > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
###############################################################################

export IREE_LLVM_SANDBOX_BUILD_DIR=$(dirname $0)/build 
export MLIR_RUNNER_UTILS_LIB=${IREE_LLVM_SANDBOX_BUILD_DIR}/lib/libmlir_runner_utils.so 
export MLIR_C_RUNNER_UTILS_LIB=${IREE_LLVM_SANDBOX_BUILD_DIR}/lib/libmlir_c_runner_utils.so 
export PYTHONPATH=${PYTHONPATH}:${IREE_LLVM_SANDBOX_BUILD_DIR}/tools/sandbox/python_package 
export PATH=$PATH:$(dirname ~ntv)/.venv/mlirdev/bin/

function prepare_data_collection() {
  DUMP_DATA_FLAG=""
  PLOT_COMMAND_LINE=""
  if !(test -z "$1" ) 
  then
    DUMP_DATA_FLAG="--dump_data $1"
  fi
}

function plot() {
  if (test -z "$1" ) || (test -z "$2" ) || (test -z "$3" ) 
  then
    return
  fi
  echo "Start plotting: python ./tools/plot_benchmark.py -i $1 -o $2 -n \"$3\""
  python ./tools/plot_benchmark.py -i $1 -o $2 -n "$3"
}

###############################################################################
# Copy benchmarks.
###############################################################################
# On my machine (theoretical peak 384 GB/s L1 BW) I see:
# [100,  32],    # sweet spot for prefetchers, seems to maximize L1 BW @ 281GB/s
#
# [ 50, 272],    # 10% L2 load, L2 BW @ 71.6GB/s
# [100, 272],    # 20% L2 load, L2 BW @ 80.8GB/s
# [150, 272],    # 30% L2 load, L2 BW @ 69.3GB/s
# [200, 272],    # 40% L2 load, L2 BW @ 82GB/s
# [250, 272],    # 50% L2 load, L2 BW @ 81GB/s
# [300, 272],    # 60% L2 load, L2 BW @ 76GB/s
# [350, 272],    # 70% L2 load, L2 BW @ 65.3GB/s
# [400, 272],    # 80% L2 load, L2 BW @ 56.5GB/s
# [450, 272],    # 90% L2 load, L2 BW @ 54.8GB/s
# [500, 272],    # 100% L2 load, L2 BW @ 47.7GB/s
#
# [5000, 272],   # 40% L3 load, L3 BW @ 25.7GB/s
# [10000, 272],  # 80% L3 load, L3 BW @ 17.2GB/s
# [15000, 272],  # 120% L3 load, L3 BW @ 10.8GB/s
#
# [300000, 272], # DRAM (24x L3 load), L3 BW @ 12GB/s
function copy_bandwidth_benchmark() {
  cset proc -s sandbox -e python -- -m python.examples.copy.custom_copy_2d_bench
}

###############################################################################
# Static 1D copy benchmarks.
###############################################################################
# Careful here, static problem size smaller than the tile sizes completely folds
# away since the result tensor is not used.
# TODO: add a fake noop use after the timer in the timing loop to avoid this.
function copy_1d_static_small() {
  prepare_data_collection $1 $2
  #  GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.copy.copy_1d_bench --problem_sizes_list 32 ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Copy  Performance (Small Static Sizes)"
}

###############################################################################
# Static 2D copy benchmarks.
###############################################################################
# Careful here, static problem size smaller than the tile sizes completely folds
# away since the result tensor is not used.
# TODO: add a fake noop use after the timer in the timing loop to avoid this.
function copy_2d_static_small() {
  prepare_data_collection $1 $2
  #  GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.copy.copy_2d_bench --problem_sizes_list 16,16 ${DUMP_DATA_FLAG}
  plot $1 $2 "2D Copy  Performance (Small Static Sizes)"
}

###############################################################################
# Static 2D transpose benchmarks.
###############################################################################
function transpose_2d_static_small() {
  prepare_data_collection $1 $2
  #  GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.transpose.transpose_2d_bench --expert_list SingleTiling2DPeel --problem_sizes_list 8,8 ${DUMP_DATA_FLAG}
  plot $1 $2 "2D Transpose Performance (Small Static Sizes)"
}

###############################################################################
# Static 1D reduction benchmarks.
###############################################################################
function reduction_1d_static_small() {
  prepare_data_collection $1 $2
  #  GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.reduction.reduction_1d_bench --problem_sizes_list 100 ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Reduction Performance (Small Static Sizes)"
}

###############################################################################
# Static 2D row reduction benchmarks.
###############################################################################
#       "200,512",
#       "500,512",
#       "500,1024",
#       "1000,1024",
#       "4000,6144",
#       "8000,6144"
function row_reduction_2d_static_small() {
  prepare_data_collection $1 $2
  #  GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.reduction.row_reduction_2d_bench --problem_sizes_list 100,256 ${DUMP_DATA_FLAG}
  plot $1 $2 "2D Row Reduction Performance (Small Static Sizes)"
}

###############################################################################
# Static 2D column reduction benchmarks.
###############################################################################
#       "200,512",
#       "500,512",
#       "500,1024",
#       "1000,1024",
#       "4000,6144",
#       "8000,6144"
function column_reduction_2d_static_small() {
  prepare_data_collection $1 $2
  #  GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.reduction.column_reduction_2d_bench --problem_sizes_list 100,256 ${DUMP_DATA_FLAG}
  plot $1 $2 "2D Column Reduction Performance (Small Static Sizes)"
}

###############################################################################
# Static matmul mk,kn benchmarks.
###############################################################################
function matmul_static_small() {
  prepare_data_collection $1 $2
  # 179 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling2DPeel --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list 18,32,96 ${DUMP_DATA_FLAG}
  # 170 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling2DPeel --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list 24,64,96 ${DUMP_DATA_FLAG}
  # 172 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list 48,64,128 ${DUMP_DATA_FLAG}
  plot $1 $2 "Matrix Multiplication Performance (Small Static Sizes)"
}

function matmul_static_small_reduction_dimension() {
  prepare_data_collection $1 $2
  # 93 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling2DPeel --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list 480,512,16 ${DUMP_DATA_FLAG}
  plot $1 $2 "Matrix Multiplication Performance (Small Reduction Static Sizes)"
}

function matmul_static_medium() {
  prepare_data_collection $1 $2
  # 151 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling3DPad --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list  384,256,256 ${DUMP_DATA_FLAG}
  # 145 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling3DPad --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list  480,512,256 ${DUMP_DATA_FLAG}
  # 157 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list SingleTiling2DPeel --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list  784,128,512 ${DUMP_DATA_FLAG}
  plot $1 $2 "Matrix Multiplication Performance (Medium Static Sizes)"
}

function matmul_static_large() {
  prepare_data_collection $1 $2
  # 158 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list DoubleTile2DPadAndHoist --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list  1020,1152,1152 ${DUMP_DATA_FLAG}
  # 148 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list DoubleTile2DPadAndHoist --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list  1920,2304,2304 ${DUMP_DATA_FLAG}
  # 151 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.matmul.bench --expert_list DoubleTile2DPadAndHoist --dynamic_at_compile_time_list [] --spec_list mk,kn --problem_sizes_list  2304,2304,2560 ${DUMP_DATA_FLAG}
  plot $1 $2 "Matrix Multiplication Performance (Large Static Sizes)"
}

###############################################################################
# Static conv1d nwc benchmarks.
###############################################################################
# Batch size 1, 32 -> 64 channels, stride 1, dilation 1.
function conv_1d_static_small_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  # 166 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,32,3,64,[1],[1] ${DUMP_DATA_FLAG}
  # 167 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,32,3,64,[1],[1] ${DUMP_DATA_FLAG} 
  # 150 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,32,3,64,[1],[1] ${DUMP_DATA_FLAG} 
  # 142 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,32,3,64,[1],[1] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 128 -> 256 channels, stride 1, dilation 1.
function conv_1d_static_medium_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  # 166 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,128,3,256,[1],[1] ${DUMP_DATA_FLAG}
  # 152 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,128,3,256,[1],[1] ${DUMP_DATA_FLAG} 
  # 141 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,128,3,256,[1],[1] ${DUMP_DATA_FLAG} 
  # 150 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,128,3,256,[1],[1] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Medium Static Sizes)"
}

# Batch size 1, 512 -> 1024 channels, stride 1, dilation 1.
function conv_1d_static_large_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  # 101 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list DoubleTile3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,512,3,1024,[1],[1] ${DUMP_DATA_FLAG}
  # 98 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench  --expert_list DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,512,3,1024,[1],[1] ${DUMP_DATA_FLAG} 
  # 97 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,512,3,1024,[1],[1] ${DUMP_DATA_FLAG} 
  # 95 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,512,3,1024,[1],[1] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Large Static Sizes)"
}

# Batch size 1, 32 -> 64 channels, stride 2, dilation 1.
function conv_1d_static_small_stride_2_dilation_1() {
  prepare_data_collection $1 $2
  # 136 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,32,3,64,[2],[1] ${DUMP_DATA_FLAG}
  # 136 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,32,3,64,[2],[1] ${DUMP_DATA_FLAG} 
  # 120 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,32,3,64,[2],[1] ${DUMP_DATA_FLAG} 
  # 118 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,32,3,64,[2],[1] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 128 -> 256 channels, stride 2, dilation 1.
function conv_1d_static_medium_stride_2_dilation_1() {
  prepare_data_collection $1 $2
  # 125 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,128,3,256,[2],[1] ${DUMP_DATA_FLAG}
  # 118 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,128,3,256,[2],[1] ${DUMP_DATA_FLAG} 
  # 125 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,128,3,256,[2],[1] ${DUMP_DATA_FLAG} 
  # 123 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,128,3,256,[2],[1] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 512 -> 1024 channels, stride 2, dilation 1.
function conv_1d_static_large_stride_2_dilation_1() {
  prepare_data_collection $1 $2
  # 80 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list DoubleTile3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,512,3,1024,[2],[1] ${DUMP_DATA_FLAG}
  # 81 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench  --expert_list  DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,512,3,1024,[2],[1] ${DUMP_DATA_FLAG} 
  # 80 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list  DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,512,3,1024,[2],[1] ${DUMP_DATA_FLAG} 
  # 80 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list  DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,512,3,1024,[2],[1] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 32 -> 64 channels, stride 1, dilation 2.
function conv_1d_static_small_stride_1_dilation_2() {
  prepare_data_collection $1 $2
  # 168 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,32,3,64,[1],[2] ${DUMP_DATA_FLAG}
  # 167 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,32,3,64,[1],[2] ${DUMP_DATA_FLAG} 
  # 149 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,32,3,64,[1],[2] ${DUMP_DATA_FLAG} 
  # 145 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,32,3,64,[1],[2] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 128 -> 256 channels, stride 1, dilation 2.
function conv_1d_static_medium_stride_1_dilation_2() {
  prepare_data_collection $1 $2
  # 156 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,128,3,256,[1],[2] ${DUMP_DATA_FLAG}
  # 154 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,128,3,256,[1],[2] ${DUMP_DATA_FLAG} 
  # 151 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,128,3,256,[1],[2] ${DUMP_DATA_FLAG} 
  # 150 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,128,3,256,[1],[2] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 512 -> 1024 channels, stride 1, dilation 2.
function conv_1d_static_large_stride_1_dilation_2() {
  prepare_data_collection $1 $2
  # 103 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list DoubleTile3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,512,3,1024,[1],[2] ${DUMP_DATA_FLAG}
  # 99 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench  --expert_list  DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,512,3,1024,[1],[2] ${DUMP_DATA_FLAG} 
  # 101 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list  DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,512,3,1024,[1],[2] ${DUMP_DATA_FLAG} 
  # 97 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_1d_bench --expert_list  DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,512,3,1024,[1],[2] ${DUMP_DATA_FLAG} 
  plot $1 $2 "1D Convolution Performance (Small Static Sizes)"
}

###############################################################################
# Static conv2d nhwc benchmarks.
###############################################################################
# Batch size 1, 32 -> 64 channels, stride [1, 1], dilation [1, 1].
function conv_2d_static_small_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  # 180 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_2d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,16,16,32,3,3,64,[1,1],[1,1] ${DUMP_DATA_FLAG}
  # 173 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_2d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,26,38,32,3,3,64,[1,1],[1,1] ${DUMP_DATA_FLAG}
  # 163 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_2d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,56,74,32,3,3,64,[1,1],[1,1] ${DUMP_DATA_FLAG}
  # 165 GFlop/s
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_2d_bench --expert_list SingleTiling3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,100,113,32,3,3,64,[1,1],[1,1] ${DUMP_DATA_FLAG}
  plot $1 $2 "2D Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 128 -> 256 channels, stride [1, 1], dilation [1, 1].
function conv_2d_static_medium_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  # 75 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_2d_bench --expert_list DoubleTile3DPeel --dynamic_at_compile_time_list [] --problem_sizes_list 1,16,16,128,3,3,256,[1,1],[1,1] ${DUMP_DATA_FLAG}
  # 74 GFlop/s -> NYI perf bug
  cset proc -s sandbox -e python -- -m python.examples.conv.conv_2d_bench --expert_list DoubleTile3DPad --dynamic_at_compile_time_list [] --problem_sizes_list 1,26,38,128,3,3,256,[1,1],[1,1] ${DUMP_DATA_FLAG}
  plot $1 $2 "2D Convolution Performance (Medium Static Sizes)"
}

###############################################################################
# Static depthwise_conv_1d nwc benchmarks.
###############################################################################
# Batch size 1, 32 channels, stride 1, dilation 1.
function depthwise_conv_1d_static_small_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  # 53 GFlop/s 107 GB/s
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,32,3,[1],[1] ${DUMP_DATA_FLAG}
  # 59 GFlop/s 118 GB/s
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,32,3,[1],[1] ${DUMP_DATA_FLAG}
  # 37 GFlop/s 75 GB/s
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,32,3,[1],[1] ${DUMP_DATA_FLAG}
  # 19 GFlop/s 38 GB/s
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,32,3,[1],[1] ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Depthwise Convolution Performance (Small Static Sizes)"
}
# Batch size 1, 32 channels, stride 2, dilation 1.
function depthwise_conv_1d_static_small_stride_2_dilation_1() {
  prepare_data_collection $1 $2
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,32,3,[2],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,32,3,[2],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,32,3,[2],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,32,3,[2],[1] ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Depthwise Convolution Performance (Small Static Sizes)"
}
# Batch size 1, 32 channels, stride 1, dilation 2.
function depthwise_conv_1d_static_small_stride_1_dilation_2() {
  prepare_data_collection $1 $2
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,32,3,[1],[2] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,32,3,[1],[2] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,32,3,[1],[2] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,32,3,[1],[2] ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Depthwise Convolution Performance (Small Static Sizes)"
}

# Batch size 1, 128 channels, stride 1, dilation 1.
function depthwise_conv_1d_static_medium_stride_1_dilation_1() {
  prepare_data_collection $1 $2
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,128,3,[1],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,128,3,[1],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,128,3,[1],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,128,3,[1],[1] ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Depthwise Convolution Performance (Medium Static Sizes)"
}
# Batch size 1, 128 channels, stride 2, dilation 1.
function depthwise_conv_1d_static_medium_stride_2_dilation_1() {
  prepare_data_collection $1 $2
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,128,3,[2],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,128,3,[2],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,128,3,[2],[1] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,128,3,[2],[1] ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Depthwise Convolution Performance (Medium Static Sizes)"
}
# Batch size 1, 128 channels, stride 1, dilation 2.
function depthwise_conv_1d_static_medium_stride_1_dilation_2() {
  prepare_data_collection $1 $2
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,256,128,3,[1],[2] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,988,128,3,[1],[2] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,4144,128,3,[1],[2] ${DUMP_DATA_FLAG}
  cset proc -s sandbox -e python -- -m python.examples.depthwise_conv.depthwise_conv_1d_bench --dynamic_at_compile_time_list [] --problem_sizes_list 1,11300,128,3,[1],[2] ${DUMP_DATA_FLAG}
  plot $1 $2 "1D Depthwise Convolution Performance (Medium Static Sizes)"
}

###############################################################################
# Static depthwise_conv_2d nhwc benchmarks.
###############################################################################
  # "depthwise_conv_2d" : {
  #   "module" : "python.examples.depthwise_conv.depthwise_conv_2d_bench",
  #   "arguments" : {
  #     "n_iters" : 100,
  #     "problem_sizes_list" : [
  #       "8,16,16,32,3,3,[1,1],[1,1]", "8,16,16,32,3,3,[2,2],[2,2]",
  #       "8,26,38,32,3,3,[1,1],[1,1]", "8,26,38,32,3,3,[2,2],[2,2]",
  #       "8,56,74,32,3,3,[1,1],[1,1]", "8,56,74,32,3,3,[2,2],[2,2]",
  #       "8,100,113,32,3,3,[1,1],[1,1]", "8,100,113,32,3,3,[2,2],[2,2]"
  #     ],
  #   }
  # },

###############################################################################
# Entry points.
###############################################################################
function run_all() {
  BENCH_ROOT_DIR=$(dirname $0)/benchmarks
  BENCH_DIR=${BENCH_ROOT_DIR}/results_$(ls -l ${BENCH_ROOT_DIR} | wc -l)
  mkdir -p ${BENCH_DIR}

  copy_1d_static_small ${BENCH_DIR}/copy_1d_static_small.data ${BENCH_DIR}/copy_1d_static_small.pdf
  copy_2d_static_small ${BENCH_DIR}/copy_2d_static_small.data ${BENCH_DIR}/copy_2d_static_small.pdf

  transpose_2d_static_small ${BENCH_DIR}/transpose_2d_static_small.data ${BENCH_DIR}/transpose_2d_static_small.pdf

  reduction_1d_static_small ${BENCH_DIR}/reduction_1d_static_small.data ${BENCH_DIR}/reduction_1d_static_small.pdf
  row_reduction_2d_static_small ${BENCH_DIR}/row_reduction_2d_static_small.data ${BENCH_DIR}/row_reduction_2d_static_small.pdf
  column_reduction_2d_static_small ${BENCH_DIR}/column_reduction_2d_static_small.data ${BENCH_DIR}/column_reduction_2d_static_small.pdf

  matmul_static_small ${BENCH_DIR}/matmul_static_small.data ${BENCH_DIR}/matmul_static_small.pdf
  matmul_static_small_reduction_dimension ${BENCH_DIR}/matmul_static_small_reduction_dimension.data ${BENCH_DIR}/matmul_static_small_reduction_dimension.pdf
  matmul_static_medium ${BENCH_DIR}/matmul_static_medium.data ${BENCH_DIR}/matmul_static_medium.pdf
  matmul_static_large ${BENCH_DIR}/matmul_static_large.data ${BENCH_DIR}/matmul_static_large.pdf
  
  conv_1d_static_small_stride_1_dilation_1 ${BENCH_DIR}/conv_1d_static_small_stride_1_dilation_1.data ${BENCH_DIR}/conv_1d_static_small_stride_1_dilation_1.pdf
  conv_1d_static_medium_stride_1_dilation_1 ${BENCH_DIR}/conv_1d_static_medium_stride_1_dilation_1.data ${BENCH_DIR}/conv_1d_static_medium_stride_1_dilation_1.pdf
  conv_1d_static_large_stride_1_dilation_1 ${BENCH_DIR}/conv_1d_static_large_stride_1_dilation_1.data ${BENCH_DIR}/conv_1d_static_large_stride_1_dilation_1.pdf

  conv_1d_static_small_stride_2_dilation_1 ${BENCH_DIR}/conv_1d_static_small_stride_2_dilation_1.data ${BENCH_DIR}/conv_1d_static_small_stride_2_dilation_1.pdf
  conv_1d_static_medium_stride_2_dilation_1 ${BENCH_DIR}/conv_1d_static_medium_stride_2_dilation_1.data ${BENCH_DIR}/conv_1d_static_medium_stride_2_dilation_1.pdf
  conv_1d_static_large_stride_2_dilation_1 ${BENCH_DIR}/conv_1d_static_large_stride_2_dilation_1.data ${BENCH_DIR}/conv_1d_static_large_stride_2_dilation_1.pdf

  conv_1d_static_small_stride_1_dilation_2 ${BENCH_DIR}/conv_1d_static_small_stride_1_dilation_2.data ${BENCH_DIR}/conv_1d_static_small_stride_1_dilation_2.pdf
  conv_1d_static_medium_stride_1_dilation_2 ${BENCH_DIR}/conv_1d_static_medium_stride_1_dilation_2.data ${BENCH_DIR}/conv_1d_static_medium_stride_1_dilation_2.pdf
  conv_1d_static_large_stride_1_dilation_2 ${BENCH_DIR}/conv_1d_static_large_stride_1_dilation_2.data ${BENCH_DIR}/conv_1d_static_large_stride_1_dilation_2.pdf

  conv_2d_static_small_stride_1_dilation_1 ${BENCH_DIR}/conv_2d_static_small_stride_1_dilation_1.data ${BENCH_DIR}/conv_2d_static_small_stride_1_dilation_1.pdf
  conv_2d_static_medium_stride_1_dilation_1 ${BENCH_DIR}/conv_2d_static_medium_stride_1_dilation_1.data ${BENCH_DIR}/conv_2d_static_medium_stride_1_dilation_1.pdf

  depthwise_conv_1d_static_small_stride_1_dilation_1 ${BENCH_DIR}/depthwise_conv_1d_static_small_stride_1_dilation_1.data ${BENCH_DIR}/depthwise_conv_1d_static_small_stride_1_dilation_1.pdf
  depthwise_conv_1d_static_small_stride_2_dilation_1 ${BENCH_DIR}/depthwise_conv_1d_static_small_stride_2_dilation_1.data ${BENCH_DIR}/depthwise_conv_1d_static_small_stride_2_dilation_1.pdf
  depthwise_conv_1d_static_small_stride_1_dilation_2 ${BENCH_DIR}/depthwise_conv_1d_static_small_stride_1_dilation_2.data ${BENCH_DIR}/depthwise_conv_1d_static_small_stride_1_dilation_2.pdf

  depthwise_conv_1d_static_medium_stride_1_dilation_1 ${BENCH_DIR}/depthwise_conv_1d_static_medium_stride_1_dilation_1.data ${BENCH_DIR}/depthwise_conv_1d_static_medium_stride_1_dilation_1.pdf
  depthwise_conv_1d_static_medium_stride_2_dilation_1 ${BENCH_DIR}/depthwise_conv_1d_static_medium_stride_2_dilation_1.data ${BENCH_DIR}/depthwise_conv_1d_static_medium_stride_2_dilation_1.pdf
  depthwise_conv_1d_static_medium_stride_1_dilation_2 ${BENCH_DIR}/depthwise_conv_1d_static_medium_stride_1_dilation_2.data ${BENCH_DIR}/depthwise_conv_1d_static_medium_stride_1_dilation_2.pdf
}


function run_one_off() {
  matmul_static_small
}