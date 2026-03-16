"""Download and save a Qwen3-VL model for local moderation."""

import sys
import os


def main():
    if len(sys.argv) != 3:
        print("Usage: download_model.py <model_name> <ai_dir>")
        sys.exit(1)

    model_name = sys.argv[1]
    ai_dir = sys.argv[2]
    model_dir = os.path.join(ai_dir, "model")
    cache_dir = os.path.join(ai_dir, "cache")

    from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor

    print(f"Downloading model: {model_name}")
    print("This may take a while depending on your internet connection...")

    model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
        model_name, cache_dir=cache_dir
    )
    model.save_pretrained(model_dir)
    print(f"Model saved to {model_dir}")

    print("Downloading processor...")
    processor = AutoProcessor.from_pretrained(model_name, cache_dir=cache_dir)
    processor.save_pretrained(model_dir)
    print("Processor saved.")

    print("Download complete!")


if __name__ == "__main__":
    main()
