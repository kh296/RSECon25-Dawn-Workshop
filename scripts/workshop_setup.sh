#/bin/bash
# Script for copying workshop setup scripts and kernels.
WORKSHOP_HOME=$(cd $(dirname "${BASH_SOURCE[0]}")/..; pwd)
WORKSHOP_RDS="${HOME}/rds/rds-rsecon/rsecon25-dawn-workshop"

# Copy setup scripts.
mkdir -p ${WORKSHOP_HOME}/envs
cp ${WORKSHOP_RDS}/envs/*setup.sh ${WORKSHOP_HOME}/envs

# Link to shared miniforge3 directory.
rm -rf ~/miniforge3
ln -s ${WORKSHOP_RDS}/miniforge3 ~/miniforge3

# Copy kernel files, and update to current home directory.
JUPYTER_KERNELS_HOME="${HOME}/.local/share/jupyter/kernels"
JUPYTER_KERNELS_RDS="${WORKSHOP_RDS}/jupyter/kernels"
cp -r ${JUPYTER_KERNELS_RDS}/* ${JUPYTER_KERNELS_HOME}
for VENV in $(ls ${JUPYTER_KERNELS_HOME}); do
    sed -i "s@/.*/rds/@${HOME}/rds/@g" ${JUPYTER_KERNELS_HOME}/${VENV}/kernel.json
done
