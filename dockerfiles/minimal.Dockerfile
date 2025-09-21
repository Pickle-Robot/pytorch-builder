FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu22.04 
# as wheel-builder


ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ARG CONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-py311_25.7.0-2-Linux-aarch64.sh
ARG CONDA_MANAGER=conda
WORKDIR /tmp/conda

# install git, wget, bzip2, and other dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget &&\
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG conda=/opt/conda/bin/${CONDA_MANAGER}
ARG PYTHON_VERSION=3.11.13
# install miniconda
RUN mkdir -p /miniconda3 && \
    wget ${CONDA_URL} -O /miniconda3/miniconda.sh && \
    chmod +x /miniconda3/miniconda.sh && \
    /miniconda3/miniconda.sh -b -u -p /miniconda3 && \
    rm /miniconda3/miniconda.sh

# /miniconda3/bin/activate in all future RUN commands
ENV PATH="/miniconda3/bin:$PATH"
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda install python=${PYTHON_VERSION} && \
    conda clean -fya && rm -rf /tmp/conda/miniconda.sh && \
    find /miniconda3 -type d -name '__pycache__' | xargs rm -rf

# Create a new conda environment with the same Python version as the system Python.
# Initialize conda
RUN /miniconda3/bin/conda init bash && \
    /miniconda3/bin/conda create -n py311 python=3.11 -y


# Minimize downloads by only cloning shallow branches and not the full `git` history.
# Use at most 8 jobs for cloning the repository and its submodules.
ARG PYTORCH_VERSION_TAG=v2.9.0-rc2
ARG TORCH_URL=https://github.com/pytorch/pytorch.git
RUN git clone --jobs $(( 8 < $(nproc) ? 8: $(nproc) )) --depth 1 \
        --single-branch --shallow-submodules --recurse-submodules \
        --branch ${PYTORCH_VERSION_TAG} ${TORCH_URL} /opt/pytorch


WORKDIR /opt/pytorch

RUN git submodule sync && \
    git submodule update --init --recursive

# Install PyTorch build dependencies via `conda`
# Run this command from the PyTorch directory after cloning the source code using the “Get the PyTorch Source“ section above
RUN cat pyproject.toml && pip install --group dev


ARG TORCH_CUDA_ARCH_LIST="11.0" # +PTX?
# ARG BUILD_LIBTORCH_WHL=1
ENV PYTHONUNBUFFERED=1

RUN VERBOSE_SCRIPT=true python setup.py bdist_wheel -d /tmp/dist


# Next build torch vision wheel
# https://github.com/pytorch/vision/blob/main/CONTRIBUTING.md#development-installation

#  conda install -c conda-forge libstdcxx-ng  is to resolve -- ImportError: /miniconda3/bin/../lib/libstdc++.so.6: version `GLIBCXX_3.4.30' not found (required by /miniconda3/lib/python3.11/site-packages/torch/lib/libtorch_python.so)

# Start by installing the nightly build of PyTorch (or in our case the wheel we just built)
RUN conda install -c conda-forge libstdcxx-ng && \
    python -m pip install /tmp/dist/torch-2.9.0a0+gitc31a818-cp311-cp311-linux_aarch64.whl


ENV FORCE_CUDA=1

WORKDIR /
ARG PYTORCH_VISION_URL=https://github.com/pytorch/vision.git
ARG PYTORCH_VISION_VERSION_TAG=v0.23.0
RUN git clone --jobs $(( 8 < $(nproc) ? 8: $(nproc) )) --depth 1 \
        --single-branch --shallow-submodules --recurse-submodules \
        --branch ${PYTORCH_VISION_VERSION_TAG} ${PYTORCH_VISION_URL} /opt/pytorch_vision && \
         cd /opt/pytorch_vision && \
         python setup.py bdist_wheel -d /tmp/dist


# install the wheel and verify torch imports and runs a basic op
# python -m pip install --no-build-isolation -v .
# RUN python -m pip install /tmp/dist/torch-2.9.0a0+gitc31a818-cp311-cp311-linux_aarch64.whl && \
#     python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); x = torch.rand(5, 3); print(x)"

COPY ./test-torch-vision-nms.py /test-torch-vision-nms.py
RUN ls /tmp/dist && python -m pip install /tmp/dist/torchvision-0.23.0a0+824e8c8-cp311-cp311-linux_aarch64.whl && \
    python /test-torch-vision-nms.py


# FROM wheel-builder AS export
# COPY --from=wheel-builder /tmp/dist /dist/wheels