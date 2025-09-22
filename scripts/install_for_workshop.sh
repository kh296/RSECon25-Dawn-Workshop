#!/bin/bash -l
# Script to set up directories for software installation for this workshop.
#SBATCH --job-name=install_for_workshop  # short name for job
#SBATCH --output=%x.log                  # job output file
#SBATCH --partition=pvc9                 # cluster partition to be used
#SBATCH --nodes=1                        # number of nodes
#SBATCH --gres=gpu:1                     # number of allocated gpus per node
#SBATCH --time=02:00:00                  # total run time limit (HH:MM:SS)

# Exit at first failure.
set -e

# See: https://tldp.org/LDP/abs/html/comparison-ops.html
WORKSHOP_HOME=$(cd $(dirname "$0")/..; pwd)
if [[ ${WORKSHOP_HOME} == /var/spool/* ]]; then
    WORKSHOP_HOME=$(dirname $(pwd))
fi
USER_RDS=${HOME}/rds/rds-rsecon/$(whoami)
rm -rf ${USER_RDS}
mkdir -p ${USER_RDS}
chmod g-w ${USER_RDS}

SCRIPTS_HOME=${WORKSHOP_HOME}/scripts
INSTALL_RDS=${USER_RDS}/install
mkdir -p ${INSTALL_RDS}
INSTALL_SCRIPTS="miniforge3_install.sh mlvenv_dawn.sh ai_install.sh"
for INSTALL_SCRIPT in ${INSTALL_SCRIPTS}; do
    cp ${SCRIPTS_HOME}/${INSTALL_SCRIPT} ${INSTALL_RDS}
done

# Link default user directory for Jupyter kernels
# to user sub-directory of rds-rsecon,
# deleting any pre-existing kernels.
JUPYTER_KERNELS_HOME="${HOME}/.local/share/jupyter/kernels"
JUPYTER_KERNELS_RDS="${USER_RDS}/jupyter/kernels"

rm -rf ${JUPYTER_KERNELS_HOME}
mkdir -p $( dirname ${JUPYTER_KERNELS_HOME})
rm -rf ${JUPYTER_KERNELS_RDS}

mkdir -p ${JUPYTER_KERNELS_RDS}
ln -s ${JUPYTER_KERNELS_RDS} ${JUPYTER_KERNELS_HOME}

cd ${INSTALL_RDS}
for INSTALL_SCRIPT in ${INSTALL_SCRIPTS}; do
    echo ""
    ./${INSTALL_SCRIPT}
done
