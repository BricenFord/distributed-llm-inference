"""
Minimal client for an OpenAI-compatible API (e.g., vllm/vllm-openai).

Sends text or image prompts to /v1/chat/completions
(default: http://127.0.0.1:8000/v1).

Examples:
    python inference.py --list-models
    python inference.py --prompt "Hello"

Note: Adjust temperature/max_tokens in the script as needed.
"""

#!/usr/bin/env python3

import argparse
import base64
import mimetypes
import os
import requests


def image_to_data_url(path):
    mime, _ = mimetypes.guess_type(path)
    if mime is None:
        mime = "application/octet-stream"
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")
    return f"data:{mime};base64,{b64}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8000/v1")
    parser.add_argument("--model", default="/model")
    parser.add_argument("--prompt")
    parser.add_argument("--image")
    parser.add_argument("--image-url")
    parser.add_argument("--list-models", action="store_true")
    args = parser.parse_args()

    if args.list_models:
        r = requests.get(f"{args.base_url}/models")
        print(r.json())
        return

    if not args.prompt:
        raise ValueError("Need --prompt")

    if args.image and args.image_url:
        raise ValueError("Use only one of --image or --image-url")

    if args.image:
        content = [
            {"type": "text", "text": args.prompt},
            {"type": "image_url", "image_url": {"url": image_to_data_url(args.image)}},
        ]
    elif args.image_url:
        content = [
            {"type": "text", "text": args.prompt},
            {"type": "image_url", "image_url": {"url": args.image_url}},
        ]
    else:
        content = args.prompt

    payload = {
        "model": args.model,
        "messages": [{"role": "user", "content": content}],
        "max_tokens": 256,
        "temperature": 0.0,
    }

    r = requests.post(f"{args.base_url}/chat/completions", json=payload)
    r.raise_for_status()
    print(r.json()["choices"][0]["message"]["content"])


if __name__ == "__main__":
    main()