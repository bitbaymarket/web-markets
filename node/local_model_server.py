"""
Local AI Moderation RPC Server using Qwen3-VL.
Listens on port 10000 for JSON-RPC requests to moderate images and text.
"""

import sys
import os
import json
import base64
import io
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

# Attempt imports; will fail gracefully if not installed yet
try:
    import torch
    from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
    from PIL import Image
except ImportError:
    print("ERROR: Required packages not installed. Run install.bat first.")
    sys.exit(1)

RPC_PORT = 10000
MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai-model", "model")
MAX_IMAGE_DIM = 150
REQUEST_TIMEOUT = 60  # seconds

# Prompts
IMAGE_PROMPT = (
    "Look at this image. Does it contain any of the following: nudity, bare skin, "
    "sexual content, violence, gore, illegal activity, drugs, weapons, or anything "
    "that would be considered inappropriate or illegal? "
    "Respond with only a single word: true if the image is safe and legal, "
    "or false if it is not. Do not elaborate."
)

TEXT_PROMPT = (
    "Read the following text. Does it solicit or promote illegal activity, violence, "
    "drugs, weapons, hate speech, or any inappropriate content? "
    "Respond with only a single word: true if the text is safe and legal, "
    "or false if it is not. Do not elaborate.\n\nText: "
)

model = None
processor = None
device = None


def detect_device():
    """Detect best available device (CUDA GPU or CPU)."""
    if torch.cuda.is_available():
        vram_bytes = torch.cuda.get_device_properties(0).total_mem
        vram_gb = vram_bytes / (1024 ** 3)
        gpu_name = torch.cuda.get_device_properties(0).name
        print(f"Detected GPU: {gpu_name} with {vram_gb:.1f} GB VRAM")
        if vram_gb < 6:
            print("WARNING: Low VRAM detected. Model may run slowly or fail.")
        return "cuda"
    else:
        print("No NVIDIA GPU detected. Using CPU (will be slower).")
        return "cpu"


def load_model():
    """Load the Qwen3-VL model and processor."""
    global model, processor, device

    device = detect_device()

    if not os.path.exists(MODEL_DIR):
        print(f"ERROR: Model directory not found at {MODEL_DIR}")
        print("Please run install.bat first to download the model.")
        sys.exit(1)

    print(f"Loading model from {MODEL_DIR} ...")
    dtype = torch.float16 if device == "cuda" else torch.float32

    model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
        MODEL_DIR,
        torch_dtype=dtype,
        device_map="auto" if device == "cuda" else None,
        low_cpu_mem_usage=True,
    )
    if device == "cpu":
        model = model.to("cpu")

    processor = AutoProcessor.from_pretrained(MODEL_DIR)
    print("Model loaded successfully.")


def resize_image(image_bytes):
    """Resize image so max dimension is MAX_IMAGE_DIM to reduce tokens."""
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")
    w, h = img.size
    if max(w, h) > MAX_IMAGE_DIM:
        scale = MAX_IMAGE_DIM / max(w, h)
        new_w = int(w * scale)
        new_h = int(h * scale)
        img = img.resize((new_w, new_h), Image.LANCZOS)
    return img


def run_inference(messages, timeout=REQUEST_TIMEOUT):
    """Run model inference with a timeout. Returns the generated text."""
    result = [None]
    error = [None]

    def _infer():
        try:
            text = processor.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
            inputs = processor(
                text=[text],
                images=messages[0].get("_images"),
                padding=True,
                return_tensors="pt",
            )
            inputs = {k: v.to(model.device) if hasattr(v, "to") else v for k, v in inputs.items()}

            with torch.no_grad():
                output_ids = model.generate(
                    **inputs,
                    max_new_tokens=10,
                    do_sample=False,
                )
            # Decode only the newly generated tokens
            generated_ids = output_ids[:, inputs["input_ids"].shape[1]:]
            result[0] = processor.batch_decode(
                generated_ids, skip_special_tokens=True
            )[0]
        except Exception as e:
            error[0] = str(e)

    thread = threading.Thread(target=_infer)
    thread.start()
    thread.join(timeout=timeout)

    if thread.is_alive():
        return None, "Inference timed out"
    if error[0]:
        return None, error[0]
    return result[0], None


def parse_bool_response(text):
    """Extract the first occurrence of 'true' or 'false' from model output."""
    if text is None:
        return None
    lower = text.lower().strip()
    true_pos = lower.find("true")
    false_pos = lower.find("false")
    if true_pos == -1 and false_pos == -1:
        return None
    if true_pos == -1:
        return False
    if false_pos == -1:
        return True
    return true_pos < false_pos


def moderate_image(b64_data):
    """Moderate an image given as base64 string. Returns True if safe."""
    # Strip data URL prefix if present
    if "," in b64_data:
        b64_data = b64_data.split(",", 1)[1]

    try:
        image_bytes = base64.b64decode(b64_data)
    except Exception:
        return None, "Invalid base64 data"

    img = resize_image(image_bytes)

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image", "image": img},
                {"type": "text", "text": IMAGE_PROMPT},
            ],
            "_images": [img],
        }
    ]

    text, err = run_inference(messages)
    if err:
        return None, err

    result = parse_bool_response(text)
    if result is None:
        return None, f"Could not parse model response: {text}"
    return result, None


def moderate_text(text_content):
    """Moderate text content. Returns True if safe."""
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": TEXT_PROMPT + text_content},
            ],
        }
    ]

    text, err = run_inference(messages)
    if err:
        return None, err

    result = parse_bool_response(text)
    if result is None:
        return None, f"Could not parse model response: {text}"
    return result, None


class RPCHandler(BaseHTTPRequestHandler):
    """Simple JSON-RPC handler for moderation requests."""

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > 50 * 1024 * 1024:  # 50MB limit
                self._send_error(-32600, "Request too large")
                return

            body = self.rfile.read(content_length)
            request = json.loads(body.decode("utf-8"))

            method = request.get("method", "")
            params = request.get("params", {})
            req_id = request.get("id", 1)

            if method == "moderate_image":
                b64 = params.get("image", "")
                if not b64:
                    self._send_error(-32602, "Missing 'image' parameter", req_id)
                    return
                result, err = moderate_image(b64)
                if err:
                    self._send_error(-32000, err, req_id)
                    return
                self._send_result({"safe": result}, req_id)

            elif method == "moderate_text":
                text = params.get("text", "")
                if not text:
                    self._send_error(-32602, "Missing 'text' parameter", req_id)
                    return
                result, err = moderate_text(text)
                if err:
                    self._send_error(-32000, err, req_id)
                    return
                self._send_result({"safe": result}, req_id)

            elif method == "health":
                self._send_result({"status": "ok"}, req_id)

            else:
                self._send_error(-32601, f"Unknown method: {method}", req_id)

        except json.JSONDecodeError:
            self._send_error(-32700, "Parse error")
        except Exception as e:
            self._send_error(-32603, str(e))

    def _send_result(self, result, req_id=1):
        response = json.dumps({"jsonrpc": "2.0", "result": result, "id": req_id})
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(response.encode("utf-8"))

    def _send_error(self, code, message, req_id=None):
        response = json.dumps({
            "jsonrpc": "2.0",
            "error": {"code": code, "message": message},
            "id": req_id,
        })
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(response.encode("utf-8"))

    def log_message(self, format, *args):
        print(f"[RPC] {args[0]}")


def main():
    print("=" * 60)
    print("  Local AI Moderation Server (Qwen3-VL)")
    print("=" * 60)

    load_model()

    server = HTTPServer(("127.0.0.1", RPC_PORT), RPCHandler)
    print(f"\nRPC server listening on http://127.0.0.1:{RPC_PORT}")
    print("Waiting for moderation requests...")
    print("Press Ctrl+C to stop.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()


if __name__ == "__main__":
    main()
