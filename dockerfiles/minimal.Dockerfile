FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu22.04

ARG PYTORCH_VERSION_TAG=v2.8.0
ARG TORCH_URL=https://github.com/pytorch/pytorch.git

# Install git 
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and compile Python 3.11.13
RUN wget https://www.python.org/ftp/python/3.11.13/Python-3.11.13.tgz \
    && tar -xzf Python-3.11.13.tgz \
    && cd Python-3.11.13 \
    && ./configure --enable-optimizations \
    && make -j$(nproc) \
    && make altinstall \
    && cd .. \
    && rm -rf Python-3.11.13.tgz Python-3.11.13

# Create symlinks
RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python \
    && ln -s /usr/local/bin/pip3.11 /usr/local/bin/pip

# Minimize downloads by only cloning shallow branches and not the full `git` history.
# Use at most 8 jobs for cloning the repository and its submodules.
RUN git clone --jobs $(( 8 < $(nproc) ? 8: $(nproc) )) --depth 1 \
        --single-branch --shallow-submodules --recurse-submodules \
        --branch ${PYTORCH_VERSION_TAG} ${TORCH_URL} /opt/pytorch
        

WORKDIR /opt/pytorch
ARG TORCH_CUDA_ARCH_LIST="11.0" # +PTX?
# ARG BUILD_LIBTORCH_WHL=1
RUN  pyenv shell 3.11.13 && \
    python -X faulthandler setup.py bdist_wheel -d /tmp/dist

