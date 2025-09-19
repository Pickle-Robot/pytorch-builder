FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu22.04

ARG PYTORCH_VERSION_TAG=2.8.0
ARG TORCH_URL=https://github.com/pytorch/pytorch.git
# Minimize downloads by only cloning shallow branches and not the full `git` history.
# Use at most 8 jobs for cloning the repository and its submodules.
RUN git clone --jobs $(( 8 < $(nproc) ? 8: $(nproc) )) --depth 1 \
        --single-branch --shallow-submodules --recurse-submodules \
        --branch ${PYTORCH_VERSION_TAG} ${TORCH_URL} /opt/pytorch

WORKDIR /opt/pytorch
RUN python -X faulthandler setup.py bdist_wheel -d /tmp/dist

