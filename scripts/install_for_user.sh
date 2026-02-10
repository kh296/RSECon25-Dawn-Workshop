#!/bin/bash -l
# Script for installing software for Dawn workshop in user area.
#SBATCH --job-name=install_for_user      # short name for job
#SBATCH --output=%x.log                  # job output file
#SBATCH --partition=pvc9                 # cluster partition to be used
#SBATCH --nodes=1                        # number of nodes
#SBATCH --gres=gpu:1                     # number of allocated gpus per node
#SBATCH --time=04:00:00                  # total run time limit (HH:MM:SS)

# Exit at first failure.
set -e

# Perform installation.
echo "Installation of software for Dawn workshop started: $(date)"
echo ""
T0=${SECONDS}

# See: https://tldp.org/LDP/abs/html/comparison-ops.html
WORKSHOP_HOME=$(cd $(dirname "$0")/..; pwd)
if [[ ${WORKSHOP_HOME} == /var/spool/* ]]; then
    WORKSHOP_HOME=$(dirname $(pwd))
fi

cd ${WORKSHOP_HOME}/scripts

CONDA_HOME=${HOME}/miniforge3
if [ ! -d ${CONDA_HOME} ]; then
    ./miniforge3_install.sh 
fi
source ${CONDA_HOME}/bin/activate

INSTALL_SCRIPTS="practical-ml-with-pytorch_install.sh ai_install.sh"
for INSTALL_SCRIPT in ${INSTALL_SCRIPTS}; do
    echo ""
    ./${INSTALL_SCRIPT}
done

# Signal completion.
echo ""
echo "Installation of software for Dawn workshop completed: $(date)"
echo "Installation time: $((${SECONDS}-${T0})) seconds"
