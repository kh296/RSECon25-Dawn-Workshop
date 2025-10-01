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
set -e

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
if [[ -z "${SLURM_CPUS_ON_NODE}" ]]; then
    SLURM_CPUS_ON_NODE=1
fi
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

# Ensure that data needed are downloaded before running application.
echo ""
echo "Downloading/checking dataset"
T3=${SECONDS}
python -c "import torchvision as tv; tv.datasets.MNIST('data', download=True)"
echo "Time downloading/checking dataset: $((${SECONDS}-${T3})) seconds"

# Generate file of host names.
if command -v scontrol 1>/dev/null 2>&1; then
    HOSTS="$(echo $(scontrol show hostnames ${SLURM_JOB_NODELIST})\
        | sed 's/ /,/g')"
    DIST_URL="${HOSTS%%,*}"
else
    HOSTS="${SLURM_JOB_NODELIST}"
    DIST_URL="127.0.0.1"
    DIST_URL="localhost"
fi
echo ""
echo "Node(s) used:"
echo "${HOSTS}"

# Exclamation mark used to avoid forced exit (with set -e)
# when read reaches end of stream (non-zero return code).
PYTHON_LAUNCH="python mnist_classify_ddp.py"
if command -v mpiexec 1>/dev/null 2>&1; then
    MPI_LAUNCH="mpiexec -n ${SLURM_NTASKS} "
    if [[ $(mpiexec --version) == *"Open MPI"* ]]; then
        MPI_LAUNCH+="-N ${SLURM_NTASKS_PER_NODE} --host ${HOSTS}"
    else
        MPI_LAUNCH+="-ppn ${SLURM_NTASKS_PER_NODE} --hosts ${HOSTS}"
    fi
    LAUNCH="${MPI_LAUNCH} ${PYTHON_LAUNCH}"
else
    LAUNCH=${PYTHON_LAUNCH}
fi
LAUNCH=${PYTHON_LAUNCH}
! read -r -d "" PYTHON_OPTS << EOS
 --ntasks-per-node ${SLURM_NTASKS_PER_NODE}\
 --dist-url ${DIST_URL}\
 --dist-port $(( (SLURM_JOB_ID % 10000) + 50000 ))\
 --cpus-per-task ${SLURM_CPUS_PER_TASK}\
 --epochs 1\
 --no-mps
EOS
CMD="${LAUNCH} ${PYTHON_OPTS}"
echo
echo "${CMD}"
echo
${CMD}
