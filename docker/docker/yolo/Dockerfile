# Fixed Dockerfile with working YOLO-NAS model download
FROM python:3.9

WORKDIR /models

# Install system dependencies including build tools and OpenCV dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    build-essential \
    cmake \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set pip configuration for better network handling
RUN pip config set global.timeout 300 && \
    pip config set global.retries 5

# Upgrade pip
RUN python -m pip install --upgrade pip setuptools wheel

# Install PyTorch CPU version first
RUN pip install torch==1.13.1 torchvision==0.14.1 --index-url https://download.pytorch.org/whl/cpu

# Install super_gradients
RUN pip install super_gradients==3.7.1

# Pre-download the model weights
RUN mkdir -p /root/.cache/torch/hub/checkpoints && \
    wget -O /root/.cache/torch/hub/checkpoints/yolo_nas_s_coco.pth \
    https://sg-hub-nv.s3.amazonaws.com/models/yolo_nas_s_coco.pth

# Copy local files
COPY coco-80.txt .
COPY generate_model.py .

# Run the model generation script
RUN python generate_model.py

# Copy generated files to output directory for easier access
RUN mkdir -p /output && \
    cp yolo_nas_s.onnx /output/ && \
    cp coco-80.txt /output/

# Display final information
RUN echo "===========================================" && \
    echo "Files are available in /output directory:" && \
    echo "  - /output/yolo_nas_s.onnx" && \
    echo "  - /output/coco-80.txt" && \
    echo "==========================================="

# Default command - just list the files
CMD ["ls", "-la", "/output/"]