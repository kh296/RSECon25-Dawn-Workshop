#!/bin/bash -l
# Script to set up directories for software installation for workshop.
#SBATCH --job-name=install_for_workshop  # short name for job
#SBATCH --output=%x.log                  # job output file
#SBATCH --partition=pvc9                 # cluster partition to be used
#SBATCH --nodes=1                        # number of nodes
#SBATCH --gres=gpu:1                     # number of allocated gpus per node
#SBATCH --time=04:00:00                  # total run time limit (HH:MM:SS)

# Script for installing software for Dawn workshop.
#
#

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
WORKSHOP_RDS=${HOME}/rds/rds-rsecon/rsecon25-dawn-workshop
rm -rf ${WORKSHOP_RDS}
mkdir -p ${WORKSHOP_RDS}

SCRIPTS_HOME=${WORKSHOP_HOME}/scripts
SCRIPTS_RDS=${WORKSHOP_RDS}/scripts
mkdir -p ${SCRIPTS_RDS}
INSTALL_SCRIPTS="practical-ml-with-pytorch_install.sh ai_install.sh"
for INSTALL_SCRIPT in ${INSTALL_SCRIPTS}; do
    cp ${SCRIPTS_HOME}/${INSTALL_SCRIPT} ${SCRIPTS_RDS}
done

# Link default user directory for Jupyter kernels
# to user sub-directory of rds-rsecon,
# deleting any pre-existing kernels.
JUPYTER_KERNELS_HOME="${HOME}/.local/share/jupyter/kernels"
JUPYTER_KERNELS_RDS="${WORKSHOP_RDS}/jupyter/kernels"

rm -rf ${JUPYTER_KERNELS_HOME}
mkdir -p $( dirname ${JUPYTER_KERNELS_HOME})
rm -rf ${JUPYTER_KERNELS_RDS}

mkdir -p ${JUPYTER_KERNELS_RDS}
ln -s ${JUPYTER_KERNELS_RDS} ${JUPYTER_KERNELS_HOME}

cd ${SCRIPTS_RDS}
${SCRIPTS_HOME}/miniforge3_install.sh -i ${WORKSHOP_RDS}/miniforge3
for INSTALL_SCRIPT in ${INSTALL_SCRIPTS}; do
    echo ""
    ./${INSTALL_SCRIPT}
done

# Allow group access to installation.
CMD="chmod -R g=u-w ${WORKSHOP_RDS}"
echo ""
echo "Setting group permissions:"
echo "${CMD}"
eval "${CMD}"

# Signal completion.
echo ""
echo "Installation of software for Dawn workshop completed: $(date)"
echo "Installation time: $((${SECONDS}-${T0})) seconds"
