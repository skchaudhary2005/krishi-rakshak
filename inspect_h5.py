import h5py
import json

MODEL_PATH = r"public\models\final_deployed_model\best_model.h5"

print("=" * 70)
print("Inspecting saved H5 model configuration")
print("=" * 70)

with h5py.File(MODEL_PATH, "r") as f:

    print("\nH5 FILE CONTENTS:")
    print(list(f.keys()))

    if "model_config" not in f.attrs:
        print("\n❌ model_config not found")
        raise SystemExit

    raw_config = f.attrs["model_config"]

    if isinstance(raw_config, bytes):
        raw_config = raw_config.decode("utf-8")

    config = json.loads(raw_config)

    print("\nMODEL CLASS:")
    print(config.get("class_name"))

    model_config = config.get("config", {})

    layers = model_config.get("layers", [])

    print("\nNUMBER OF LAYERS:", len(layers))

    print("\n" + "=" * 70)
    print("LAYERS / POSSIBLE PREPROCESSING")
    print("=" * 70)

    for i, layer in enumerate(layers):

        class_name = layer.get("class_name")
        layer_config = layer.get("config", {})
        name = layer_config.get("name", "")

        print(f"\n[{i}] {class_name} -> {name}")

        text = json.dumps(layer)

        if (
            "127.5" in text
            or "TrueDivide" in text
            or "Lambda" in text
            or "TFOpLambda" in text
            or "Rescaling" in text
        ):
            print("   ⭐ RELEVANT PREPROCESSING LAYER")

            print(
                json.dumps(
                    layer,
                    indent=2,
                    ensure_ascii=False
                )[:5000]
            )

print("\n" + "=" * 70)
print("Inspection complete")
print("=" * 70)