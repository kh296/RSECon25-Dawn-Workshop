# RSECon25-Dawn-Workshop

## 1. Dawn

[Dawn](https://docs.hpc.cam.ac.uk/hpc/user-guide/pvc.html#hardware)
is a supercomputer hosted at the University of Cambridge, and is part
of the [AI Resource Research (AIRR)](https://www.gov.uk/government/publications/ai-research-resource/airr-advanced-supercomputers-for-the-uk).  It has
256 nodes, in the form of [Dell PowerEdge XE9640](https://www.delltechnologies.com/asset/en-us/products/servers/technical-support/poweredge-xe9640-spec-sheet.pdf) servers.  Each node consists of:
2 CPUs ([Intel Xeon Platinum 8468](https://www.intel.com/content/www/us/en/products/sku/231735/intel-xeon-platinum-8468-processor-105m-cache-2-10-ghz/specifications.html)), each with 48 cores and 512 GiB RAM;
4GPUs ([Intel Data Centre GPU Max 1550](https://www.intel.com/content/www/us/en/products/sku/232873/intel-data-center-gpu-max-1550/specifications.html)),
each with two stacks, 1024 compute units, and 128 GiB RAM.

To install and run software from this workshop on Dawn, you
will need to have an account set up.  For further information, see:
[Access to Dawn](https://www.csd3.cam.ac.uk/index.php/access-dawn).

## 2. Software installation

If you're been allocated a training account for this workshop, you
don't need to perform any software installation.  Otherwise, follow
the linked instructions for one of the following:
- [software installation by an individual user](docs/individual_user.md);
- [software installation by a workshop organiser](docs/workshop_organiser.md).

## 3. Open Jupyter notebook on Dawn

Login at:
[https://login-web.hpc.cam.ac.uk/](https://login-web.hpc.cam.ac.uk/).  If
asked to enable multi-factor authentication, follow the instructions for
doing this.

At the top of the dashboard page presented after login, select:
```
Interactive Apps -> Jupyter Notebook
```

On the Jupyter Notebook form, enter as project account `training-dawn-gpu`
if you're using a training account, or otherwise the project name of
your Dawn allocation.  Enter other values as follows:
```
- Partition: pvc9
- Reservation: [leave blank]:
- Number of hours: 2
- Number of cores: 1
- Number of GPUs: 2
- Modules: rhel9/default-dawn intel-oneapi-mkl intel-oneapi-compilers jupyterlab
- Number of nodes: 1
```
The above request the resources needed for this workshop, for a period of
2 hours.  The number of hours may be decreased or increased as needed.

Click the __Launch__ button.

Your request for a Jupyter Notebook will progress through the states:
__Queued__, __Starting__, __Running__.  Once the __Running__ state is reached,
click the __Connect to Jupyter__ button.

Once connected to the Jupyter server, you will initially be shown the
__File Browser__, in the Jupyter Home tab.

Open a Terminal session and a JupyterLab session by selecting:
```
File -> New -> Terminal
View -> JupyterLab
```
The Terminal session is initially in the home directory of your
account on Dawn.  The JupyterLab session includes a file browser to the
left, initially shoing the home directory of your account on Dawn.

You can switch between Terminal and JupyterLab using the tabs of your
web browser.

## 4. Download examples and set up environment

If you're not using a training account, meaning that you performed your
own software installation, no further download or set up is needed.  Otherwise,
continue in the Terminal session, working from your home directory.

Clone the workshop repository to your home directory:
```
git clone https://github.com/RSE-Cambridge/RSECon25-Dawn-Workshop
```
Set up the environement:
```
source ~/RSECon25-Dawn-Workshop/scripts/workshop_setup.sh
```
The setup clones another repository with examples
(`practical-ml-with-pytorch`) to your home directory, creates
account-specific setup files in `~/RSECon25-Dawn-Workshop/envs`,
and create kernel-definition files in `~/.local/shared/jupyter/kernels`.

## 5. Submit batch jobs

As batch jobs may take a while to complete, it's suggested to submit
them now.  The code being run, and the job outputs, are considered in
section 7.

In the Terminal session, move to the workshop examples directory, and
submit the two job example jobs:
```
cd ~/RSECon25-Dawn-Workshop/examples
sbatch --account=training-dawn-gpu run_mnist_classify_ddp.sh
sbatch --account=training-dawn-gpu run_lightning_toy_example.sh
```

## 6. Run Jupyter notebooks

### 6.1 Check devices

In the JupyterLab session, in the left panel, navigate to
`RSECon25-Dawn-Workshop/examples`.  Open, and experiment with:
`check_devices.ipynb`.  Before running the notebook, check that the kernel,
indicated towards the top right of the session window, is set to `ai`.  If
it isn't, change the kernel as follows:
```
Kernel -> Change Kernel... -> ai
```

### 6.2 Practical ml with PyTorch

In the JupyterLab session, in the left panel, navigate to
`practical-ml-with-pytorch/worked-solutions`.  Open and experiment with
the four notebooks.  (Note that 01 and 02 use CPU only, while 03 and 04
each use a single GPU.)  Before running each notebook, check that the
kernel, indicated towards the top right of the session window, is set
to `practical-ml-with-pytorch`.  If it isn't, change the kernel as follows:
```
Kernel -> Change Kernel... -> practical-ml-with-pytorch
```

## 7. Examine completed batch jobs
