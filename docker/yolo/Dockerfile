# Fixed Dockerfile with working YOLO-NAS model download
FROM python:3.9

WORKDIR /models

# Install system dependencies including build tools and OpenCV dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set pip configuration for better network handling
RUN pip config set global.timeout 300 && \
    pip config set global.retries 5

# Upgrade pip
RUN python -m pip install --upgrade pip setuptools wheel

# Install PyTorch CPU version first
RUN pip install torch==1.13.1+cpu torchvision==0.14.1+cpu \
    -f https://download.pytorch.org/whl/torch_stable.html

# Install super_gradients
RUN pip install super_gradients==3.7.1

# Pre-download the model weights from the correct URL
RUN mkdir -p /root/.cache/torch/hub/checkpoints && \
    wget -O /root/.cache/torch/hub/checkpoints/yolo_nas_s_coco.pth \
    https://sg-hub-nv.s3.amazonaws.com/models/yolo_nas_s_coco.pth

# Create the COCO-80 labelmap file
# Chopped as hell
RUN cat > coco-80.txt << 'EOF'
person
bicycle
car
motorcycle
airplane
bus
train
truck
boat
traffic light
fire hydrant
stop sign
parking meter
bench
bird
cat
dog
horse
sheep
cow
elephant
bear
zebra
giraffe
backpack
umbrella
handbag
tie
suitcase
frisbee
skis
snowboard
sports ball
kite
baseball bat
baseball glove
skateboard
surfboard
tennis racket
bottle
wine glass
cup
fork
knife
spoon
bowl
banana
apple
sandwich
orange
broccoli
carrot
hot dog
pizza
donut
cake
chair
couch
potted plant
bed
dining table
toilet
tv
laptop
mouse
remote
keyboard
cell phone
microwave
oven
toaster
sink
refrigerator
book
clock
vase
scissors
teddy bear
hair drier
toothbrush
EOF

# Create and run the model generation script
RUN cat > generate_model.py << 'EOF'
import os
from super_gradients.common.object_names import Models
from super_gradients.conversion import DetectionOutputFormatMode
from super_gradients.training import models

print("=" * 60)
print("YOLO-NAS Model Generator for Frigate")
print("=" * 60)

print("\n[1/2] Loading YOLO-NAS-S model...")
# The model will use the pre-downloaded weights from the cache
model = models.get(Models.YOLO_NAS_S, pretrained_weights="coco")

print("[2/2] Exporting model to ONNX format...")
model.export("yolo_nas_s.onnx",
    output_predictions_format=DetectionOutputFormatMode.FLAT_FORMAT,
    max_predictions_per_image=20,
    confidence_threshold=0.4,
    input_image_shape=(320,320),
)

print("\n" + "=" * 60)
print("✓ Model generation complete!")
print("=" * 60)
print(f"Generated files:")
print(f"  - yolo_nas_s.onnx ({os.path.getsize('yolo_nas_s.onnx') / 1024 / 1024:.2f} MB)")
print(f"  - coco-80.txt ({os.path.getsize('coco-80.txt')} bytes)")
EOF

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