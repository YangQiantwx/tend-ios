#!/usr/bin/env python3
"""Generate offline guides with the official Pocket TTS stock voice.

Requires Python 3.11 and scripts/audio-requirements.txt. On macOS,
afconvert encodes and then decodes every AAC asset to verify it is playable.
The cache must be outside the repository; no model weights are shipped in the app.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request

CODE_REVISION = "a11539ee73ad4659624b2540c8b050cd1ecb9525"
MODEL_REVISION = "e7205b6ee50e654a5ea19f0e9df2b0813b05e921"
VOICE_REVISION = "069025daa1d6a8a9640bd52581e2a2252f8bede4"
TOKENIZER_REVISION = "00eac05ed3d16bdc3f6b5d598874019c34a89214"
LANGUAGE = "english_2026-09"
REPOSITORY = "kyutai/pocket-tts-without-voice-cloning"
ASSETS = {
    "model.safetensors": f"https://huggingface.co/{REPOSITORY}/resolve/{MODEL_REVISION}/languages/{LANGUAGE}/model.safetensors",
    "alba.safetensors": f"https://huggingface.co/{REPOSITORY}/resolve/{VOICE_REVISION}/languages/{LANGUAGE}/embeddings/alba.safetensors",
    "tokenizer.json": f"https://huggingface.co/{REPOSITORY}/resolve/{TOKENIZER_REVISION}/languages/{LANGUAGE}/tokenizer.json",
    "english_2026-09.yaml": f"https://raw.githubusercontent.com/kyutai-labs/pocket-tts/{CODE_REVISION}/pocket_tts/config/{LANGUAGE}.yaml",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def download(url: str, path: Path) -> None:
    if path.exists():
        return
    temporary = path.with_suffix(path.suffix + ".download")
    with urllib.request.urlopen(url, timeout=60) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, required=True)
    parser.add_argument("--config", type=Path, default=Path("Tend/Resources/study-config.json"))
    parser.add_argument("--output", type=Path, default=Path("Tend/Resources/Audio"))
    parser.add_argument("--only", help="Generate one practice; intended for reviewing a sample.")
    args = parser.parse_args()
    cache = args.cache_dir.resolve()
    project = Path(__file__).resolve().parent.parent
    if cache == project or project in cache.parents:
        parser.error("Use a model cache outside the repository.")
    cache.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    for filename, url in ASSETS.items():
        print("Preparing", filename, flush=True)
        download(url, cache / filename)

    # Use the public stock-only checkpoint directly, without Hugging Face account access.
    config = (cache / "english_2026-09.yaml").read_text()
    config = re.sub(r"^weights_path: .*$", f"weights_path: {cache / 'model.safetensors'}", config, flags=re.M)
    config = re.sub(r"^(\s*)tokenizer_path: .*$", rf"\1tokenizer_path: {cache / 'tokenizer.json'}", config, flags=re.M)
    local_config = cache / "stock-only.yaml"
    local_config.write_text(config)
    os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
    import numpy as np
    import soundfile as sf
    import torch
    from pocket_tts import TTSModel

    torch.set_num_threads(2)
    torch.manual_seed(20260928)
    model = TTSModel.load_model(config=local_config, temp=0.3)
    model.has_voice_cloning = False
    voice = model.get_state_for_audio_prompt(cache / "alba.safetensors")
    study = json.loads(args.config.read_text())
    entries = []
    for index, practice in enumerate(study["practices"]):
        if args.only and practice["id"] != args.only:
            continue
        script = practice["audioScript"]
        if not re.fullmatch(r"[a-z0-9-]+", practice["id"]):
            raise ValueError("Practice IDs must be safe filenames.")
        torch.manual_seed(20260928 + index)
        print("Generating", practice["id"], flush=True)
        speech = model.generate_audio(voice, script).detach().cpu().numpy().astype(np.float32)
        if not np.isfinite(speech).all() or np.max(np.abs(speech)) < 0.01:
            raise RuntimeError(f"Invalid audio for {practice['id']}")
        # No time stretching, background music, extra words, or change to the practice script.
        speech *= min(1.0, 0.92 / float(np.max(np.abs(speech))))
        speech = np.concatenate([np.zeros(int(0.3 * model.sample_rate), dtype=np.float32), speech,
                                 np.zeros(int(0.7 * model.sample_rate), dtype=np.float32)])
        duration = len(speech) / model.sample_rate
        if duration >= practice["durationSeconds"]:
            raise RuntimeError(f"Narration exceeds practice timer: {practice['id']}")
        filename = practice["id"] + ".m4a"
        target = args.output / filename
        with tempfile.TemporaryDirectory(prefix="tend-narration-") as folder:
            wav = Path(folder) / "source.wav"
            decoded = Path(folder) / "decoded.wav"
            sf.write(wav, speech, model.sample_rate, subtype="PCM_16")
            subprocess.run(["/usr/bin/afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", "-q", "127", str(wav), str(target)], check=True)
            subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16", str(target), str(decoded)], check=True)
            data, sample_rate = sf.read(decoded)
            assert sample_rate == model.sample_rate and np.isfinite(data).all()
            assert abs(len(data) / sample_rate - duration) < 0.2
            peak = float(np.max(np.abs(data)))
            rms = float(np.sqrt(np.mean(data**2)))
            assert 0.01 < peak < 1.0 and rms > 0.001
        entries.append({"practiceID": practice["id"], "filename": filename,
                        "scriptSHA256": sha256(script.encode()), "audioSHA256": sha256(target.read_bytes()),
                        "durationSeconds": round(duration, 3), "sampleRate": model.sample_rate,
                        "channels": 1, "decodedPeak": round(peak, 6), "decodedRMS": round(rms, 6),
                        "bytes": target.stat().st_size, "seed": 20260928 + index})
        print(f"Verified {filename}: {duration:.2f} s, {target.stat().st_size} bytes", flush=True)
    manifest = {"schemaVersion": 1, "engine": "Pocket TTS", "engineVersion": "3.3.0",
                "model": LANGUAGE, "modelRepository": REPOSITORY, "modelRevision": MODEL_REVISION,
                "codeRevision": CODE_REVISION, "voice": "alba", "voiceRevision": VOICE_REVISION,
                "temperature": 0.3, "modelLicense": "CC-BY-4.0", "voiceLicense": "CC-BY-4.0",
                "codeLicense": "MIT", "generatedSpeech": True,
                "voiceAttribution": "Alba MacKenna, casual voice, via Kyutai TTS voices (CC BY 4.0)",
                "voiceSource": "https://huggingface.co/kyutai/tts-voices/tree/main/alba-mackenna",
                "licenseURL": "https://creativecommons.org/licenses/by/4.0/",
                "assets": entries,
                "generationDependencies": {name: importlib.metadata.version(name) for name in ("pocket-tts", "torch", "numpy", "soundfile")},
                "generationInputHashes": {name: sha256((cache / name).read_bytes()) for name in ASSETS}}
    manifest_name = "narration-sample.json" if args.only else "narration-manifest.json"
    (args.output / manifest_name).write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
