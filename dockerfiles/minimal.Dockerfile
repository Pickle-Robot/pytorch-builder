FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu22.04

ARG PYTORCH_VERSION_TAG=v2.8.0
ARG TORCH_URL=https://github.com/pytorch/pytorch.git
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
# Install git 
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl \
    && rm -rf /var/lib/apt/lists/*


RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks
RUN ln -s /usr/bin/python3.11 /usr/bin/python 

# Minimize downloads by only cloning shallow branches and not the full `git` history.
# Use at most 8 jobs for cloning the repository and its submodules.
RUN git clone --jobs $(( 8 < $(nproc) ? 8: $(nproc) )) --depth 1 \
        --single-branch --shallow-submodules --recurse-submodules \
        --branch ${PYTORCH_VERSION_TAG} ${TORCH_URL} /opt/pytorch
        

WORKDIR /opt/pytorch
ARG TORCH_CUDA_ARCH_LIST="11.0" # +PTX?
# ARG BUILD_LIBTORCH_WHL=1
RUN  python -X faulthandler setup.py bdist_wheel -d /tmp/dist

