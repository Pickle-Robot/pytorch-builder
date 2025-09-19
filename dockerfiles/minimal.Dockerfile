FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu22.04

ARG PYTORCH_VERSION_TAG=v2.8.0
ARG TORCH_URL=https://github.com/pytorch/pytorch.git
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ARG CONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-py311_25.7.0-2-Linux-aarch64.sh
ARG CONDA_MANAGER=conda
WORKDIR /tmp/conda

ARG conda=/opt/conda/bin/${CONDA_MANAGER}
ARG PYTHON_VERSION=3.11.13
RUN /bin/bash /tmp/conda/miniconda.sh -b -p /opt/conda && \
    printf "channels:\n  - conda-forge\n  - nodefaults\nssl_verify: false\n" > /opt/conda/.condarc && \
    $conda install -y python=${PYTHON_VERSION} && $conda clean -fya && \
    find /opt/conda -type d -name '__pycache__' | xargs rm -rf

# Minimize downloads by only cloning shallow branches and not the full `git` history.
# Use at most 8 jobs for cloning the repository and its submodules.
RUN git clone --jobs $(( 8 < $(nproc) ? 8: $(nproc) )) --depth 1 \
        --single-branch --shallow-submodules --recurse-submodules \
        --branch ${PYTORCH_VERSION_TAG} ${TORCH_URL} /opt/pytorch
        

WORKDIR /opt/pytorch
ARG TORCH_CUDA_ARCH_LIST="11.0" # +PTX?
# ARG BUILD_LIBTORCH_WHL=1

RUN git submodule sync && \
    git submodule update --init --recursive

# Run this command from the PyTorch directory after cloning the source code using the “Get the PyTorch Source“ section above
RUN pip install --group dev
RUN  python -X faulthandler setup.py bdist_wheel -d /tmp/dist

