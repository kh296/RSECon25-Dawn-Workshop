#!/bin/bash
#SBATCH --job-name=ml-install        # create a short name for your job
#SBATCH --output=%x.log              # job output file
#SBATCH --partition=pvc9             # cluster partition to be used
#SBATCH --nodes=1                    # number of nodes
#SBATCH --gres=gpu:1                 # number of allocated gpus per node
#SBATCH --time=01:00:00              # total run time limit (HH:MM:SS)

# Script for installing MLvenv environment for practical-ml-with-pytorch
# on Dawn supercomputer, and on other systems.

# On Dawn, this script may be run interactively on a compute node
# (not on a login node):
# bash ./practical-ml-with-pytorch_install.sh
# or it may be submitted from a login node to the Slurm batch system:
# sbatch --acount=<project account> ./practical-ml-with-pytorch_install.sh

# Exit at first failure.
set -e
#
# Determine system being used.
ENV_NAME="practical-ml-with-pytorch"
if [[ "$(hostname)" == "pvc-s"* ]]; then
    SYSTEM="Dawn"
elif [[ "${OSTYPE}" == "darwin"* ]]; then
    SYSTEM="macOS"
else
    echo "Installation of ${ENV_NAME} for ${OSTYPE} on $(hostname) not handled"
    echo "Exiting: $(date)"
    exit 1
fi

# Perform installation.
echo "Installation of ${ENV_NAME} for ${OSTYPE} on $(hostname) started: $(date)"
T0=${SECONDS}

# Create script for environment setup.
ENVS_DIR=$(realpath ..)/envs
mkdir -p ${ENVS_DIR}
SETUP=${ENVS_DIR}/${ENV_NAME}-setup.sh
if [[ "Dawn" == "${SYSTEM}" ]]; then
    DAWN_SETUP="${SETUP}"
else
    DAWN_SETUP="/dev/null"
fi

cat <<EOF >${SETUP}
# Setup script for activating ${ENV_NAME} on ${SYSTEM}.
# Generated: $(date)

EOF

cat <<EOF >>${DAWN_SETUP}
# Load modules.
module purge
module load rhel9/default-dawn

EOF

cat <<EOF >>${SETUP}
# Activate environment.
EOF

# Set up installation environment.
source ${SETUP}
if [[ "Dawn" == ${SYSTEM} ]]; then
    module load intelpython-conda/2025.0
fi

# Initialise the virtual enviroment.
VENV_DIR=$(realpath ..)/venvs/${ENV_NAME}
mkdir -p ${VENV_DIR}
rm -rf ${VENV_DIR}
python -m venv ${VENV_DIR}
#sed -i "s@${HOME}@\${HOME}@g" ${VENV_DIR}/bin/activate
source "${VENV_DIR}/bin/activate"
echo "source ${VENV_DIR}/bin/activate" >> ${SETUP}
python -m pip install --upgrade pip

# Clone project, and install packages in virtual environment.
PROJECTS_DIR=$(realpath ..)/projects
rm -rf ${PROJECTS_DIR}
mkdir -p ${PROJECTS_DIR}
cd ${PROJECTS_DIR}
git clone https://github.com/kh296/${ENV_NAME}
cd ${ENV_NAME}
git checkout xpu
pip install --index-url https://download.pytorch.org/whl/xpu --extra-index-url https://pypi.org/simple . ipywidgets

# Perform initial import.
python -c "import ml_workshop"

# Create Jupyter kernel.
python -m ipykernel install --user --name=${ENV_NAME}

echo ""
echo "Installation of ${ENV_NAME} for ${OSTYPE} on $(hostname) completed : $(date)"
echo "Installation time: $((${SECONDS}-${T0})) seconds"

echo ""
echo "Set up environment for ${ENV_NAME} with:"
echo "source ${SETUP}"
echo ""
echo "To use ${ENV_NAME} from Jupyter notebook, choose kernel: ${ENV_NAME}"
