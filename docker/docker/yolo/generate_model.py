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
