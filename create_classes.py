#!/usr/bin/env python3
"""
Create class names mapping from test dataset
"""

from pathlib import Path
import json

TEST_DATA_PATH = Path("datasets/unified/test")

print("Creating class names mapping...")

# Get all class directories
class_dirs = sorted([d.name for d in TEST_DATA_PATH.iterdir() if d.is_dir()])

# Create index mapping
class_indices = {name: idx for idx, name in enumerate(class_dirs)}

print(f"\nFound {len(class_indices)} classes:")
for name, idx in sorted(class_indices.items(), key=lambda x: x[1]):
    print(f"   {idx:2d}: {name}")

# Save to models directory
output_path = Path("models/combined_best_models/crop_disease_real/classes.json")
output_path.parent.mkdir(parents=True, exist_ok=True)

with open(output_path, 'w') as f:
    json.dump(class_indices, f, indent=2)

print(f"\n✅ Saved to: {output_path}")

# Also save to deployed model
deploy_path = Path("public/models/final_deployed_model/classes.json")
with open(deploy_path, 'w') as f:
    json.dump(class_indices, f, indent=2)

print(f"✅ Saved to: {deploy_path}")