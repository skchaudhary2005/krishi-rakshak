import tensorflow as tf
from tensorflow.keras.layers import Layer


class TrueDivide(Layer):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def call(self, inputs):
        if isinstance(inputs, (list, tuple)):
            return inputs[0] / inputs[1]

        return inputs / 1.0


MODEL_PATH = r"public\models\final_deployed_model\best_model.h5"

print("=" * 60)
print("Loading Krishi Rakshak trained model...")
print("=" * 60)

try:
    model = tf.keras.models.load_model(
        MODEL_PATH,
        custom_objects={
            "TrueDivide": TrueDivide
        },
        compile=False
    )

    print("\n✅ MODEL LOADED SUCCESSFULLY")

    print("\nINPUT SHAPE:")
    print(model.input_shape)

    print("\nOUTPUT SHAPE:")
    print(model.output_shape)

    print("\nPARAMETERS:")
    print(model.count_params())

    print("\nMODEL SUMMARY:")
    model.summary()

except Exception as error:
    print("\n❌ MODEL LOAD FAILED")
    print("Error type:", type(error).__name__)
    print("Error:", error)