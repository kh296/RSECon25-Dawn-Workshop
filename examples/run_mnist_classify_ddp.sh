#!/bin/bash -l
#SBATCH --job-name=ddp-torch   # create a short name for the job
#SBATCH --output=%x.log        # job output file
#SBATCH --partition=pvc9       # cluster partition to be used
#SBATCH --nodes=2              # number of nodes
#SBATCH --gres=gpu:4         # number of allocated gpus per node
#SBATCH --time=01:00:00        # total run time limit (HH:MM:SS)
#
# Script for running pytorch example,
# based around MNIST classification, with use of distributed data parallel.
#
# It's assumed that the environment for running pytorch applications
# can be set up with:
# source ../envs/ai-setup.sh
#
# This script can be run interactively:
#     ./run_mnist_classify_ddp.sh
# or can be submitted to a Slurm batch system, substituting
# valid project account for <project_account>:.
#     sbatch --acount=<project_account> run_mnist_classify_ddp.sh
T1=${SECONDS}
echo "Job start on $(hostname): $(date)"

# Exit at first failure.
#set -e

# Ensure that Slurm environment variables are set,
# also if outside of a Slurm environment.
#
# The variables specifying number of tasks per node (SLURM_NTASKS_PER_NODE),
# number of tasks (SLURM_NTASKS), and number of CPU cores per task
# (SLURM_CPUS_PER_TASK) are used in defining task parallelisation.
# These numbers depend on the number of nodes allocated, on the
# number of GPUs per node, and on how GPUs are configured.
#
# On Dawn, if a single node is allocated, then it may be allocated with
# 1, 2, 3, or 4 GPUs (but not with 0 GPUs).  If more than one node is
# allocated, all must be allocated with all (4) GPUs.  If GPUs are
# used in "FLAT" mode, the two stacks of each GPU are treated as two
# root devices.  If GPUs are used in "COMPOSITE" mode, the two stacks
# of each GPU are treated as a single root device.  For more information
# about modes for Intel GPUs, see:
# https://www.intel.com/content/www/us/en/docs/oneapi/optimization-guide-gpu/2024-1/exposing-device-hierarchy.html
# https://www.intel.com/content/www/us/en/developer/articles/technical/flattening-gpu-tile-hierarchy.html
#
# The variables specifying node(s) allocated (SLURM_JOB_NODELIST)
# and job id (SLURM_JOB_ID) are used to define the master address and
# port for task parallelisation.

# Default to 1 node allocated if running outside of Slurm.
if [[ -z "${SLURM_NNODES}" ]]; then
    SLURM_NNODES=1
fi

# Determine number of root devices per GPU on Dawn.
if [[ "COMPOSITE" == ${ZE_FLAT_DEVICE_HIERARCHY} ]]; then
    DEVICES_PER_GPU=1
else
    DEVICES_PER_GPU=2
fi

# Determine number of tasks per node, with one task per GPU root device,
# or defaulting to 1 if there are no GPUs.
if [[ -z "${SLURM_GPUS_ON_NODE}" ]]; then
    SLURM_NTASKS_PER_NODE=1
else
    SLURM_NTASKS_PER_NODE=$((${SLURM_GPUS_ON_NODE}*${DEVICES_PER_GPU}))
fi

# Determine total number of tasks.
SLURM_NTASKS=$((${SLURM_NNODES}*${SLURM_NTASKS_PER_NODE}))

# Determine number of CPU cores per task.
export SLURM_CPUS_PER_TASK=$((${SLURM_CPUS_ON_NODE}/${SLURM_NTASKS_PER_NODE}))

# Ensure that value assigned to SLURM_JOB_NODELIST.
if [[ -z "${SLURM_JOB_NODELIST}" ]]; then
    SLURM_JOB_NODELIST=$(hostname)
fi

# Ensure that value assigned to SLURM_JOB_ID.
if [[ -z "${SLURM_JOB_ID}" ]]; then
    SLURM_JOB_ID=5100
fi

# Unset and set Slurm variables for compatibility with srun.
unset SLURM_MEM_PER_CPU
unset SLURM_MEM_PER_NODE
SLURM_EXPORT_ENV=ALL

# Perform environment setup.
SETUP_SCRIPT="../envs/ai-setup.sh"
SETUP="source ${SETUP_SCRIPT}"
echo ""
echo ${SETUP}
${SETUP}

# Set Intel MPI/OFI related environment variables.

# export I_MPI_OFFLOAD=1
# export I_MPI_OFFLOAD_SYMMETRIC=0

# See: https://www.osc.edu/supercomputing/batch-processing-at-osc/slurm_migration/slurm_migration_issues
unset I_MPI_PMI_LIBRARY
export I_MPI_JOB_RESPECT_PROCESS_PLACEMENT=0

# Avoid CCL warning:
# [CCL_WARN] CCL_CONFIGURATION_PATH_modshare=:1 is unknown to and unused by
# oneCCL code but is present in the environment, check if it is not mistyped.
unset CCL_CONFIGURATION_PATH_modshare

# Avoid CCL warnings:
# |CCL_WARN| the number of workers (1) matches the number of available cores
# per process, this may lead to contention between workers and application
# threads
# |CCL_WARN| workers are disabled, to forcibly enable them
# set CCL_WORKER_OFFLOAD=1
#
# Note: setting CCL_WORKER_OFFLOAD=1 slows down processing.
export CCL_WORKER_OFFLOAD=1

# Use sockets instead of drmfd.
# See: https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-ze-ipc-exchange
#export CCL_ZE_IPC_EXCHANGE=sockets
export CCL_ZE_IPC_EXCHANGE=pidfd

# Ensure that data needed are downloaded before running application.
echo ""
echo "Checking/downloading dataset"
T3=${SECONDS}
python -c "import torchvision as tv; tv.datasets.MNIST('data', download=True)"
echo "Time checking/downloading dataset: $((${SECONDS}-${T3})) seconds"

# Generate file of host names.
scontrol show hostnames $SLURM_JOB_NODELIST > mpi_hostfile.txt
echo ""
echo "Node(s) used:"
cat mpi_hostfile.txt

# Exclamation mark used to avoid exiting
# because read reaching end of stream results in non-zero return code.
! read -r -d "" CMD << EOS
mpiexec -n ${SLURM_NTASKS} -ppn ${SLURM_NTASKS_PER_NODE} -f mpi_hostfile.txt\
 python mnist_classify_ddp.py\
 --ntasks-per-node ${SLURM_NTASKS_PER_NODE}\
 --dist-url $(head -n1 mpi_hostfile.txt)\
 --dist-port $(( (SLURM_JOB_ID % 10000) + 50000 ))\
 --cpus-per-task ${SLURM_CPUS_PER_TASK}\
 --epochs 1
EOS
echo
echo "${CMD}"
echo
${CMD}
