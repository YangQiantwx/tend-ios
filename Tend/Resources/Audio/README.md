# Spoken guides

These recordings were synthesized from the `audioScript` fields in `study-config.json` with **Kyutai Pocket TTS 3.3.0**, the **English September 2026** stock-voice model and the **Alba** preset. They are generated speech, not recordings of a study team member. No private voice recording was supplied to the model.

The app plays the files offline with `AVAudioPlayer`. Pause, resume, app backgrounding, audio interruptions and headphone disconnection preserve the practice timer's foreground-only behavior. The spoken introduction ends before the practice timer; the remaining time is quiet practice. The guide does not automatically repeat. If a recording is absent, cannot be decoded, or no longer matches the text's SHA-256, the app uses the iOS device voice.

## Attribution and licensing

- Model: [Kyutai Pocket TTS](https://huggingface.co/kyutai/pocket-tts-without-voice-cloning), **CC BY 4.0**.
- Stock voice: **Alba MacKenna**, `alba-mackenna/casual.wav`, distributed by [Kyutai TTS voices](https://huggingface.co/kyutai/tts-voices/tree/main/alba-mackenna), **CC BY 4.0**. The upstream [voice catalog](https://huggingface.co/kyutai/tts-voices/blob/main/README.md) identifies this license.
- Engine: [Kyutai Pocket TTS](https://github.com/kyutai-labs/pocket-tts), **MIT**.
- The generated `.m4a` assets are distributed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/). Preserve this attribution when redistributing the audio. The stock voice and model were used to synthesize new text; gain was limited, short leading/trailing silence was added, and the result was encoded as mono AAC. This use does not imply endorsement by Kyutai or Alba MacKenna.

`narration-manifest.json` records pinned model/voice/code revisions, dependency versions, seeds, text and audio SHA-256 values, duration, and decode checks. Model weights and the generation environment are not included in the app or repository.

## Regeneration

Use a Python 3.11 environment outside the repository:

```sh
python3.11 -m venv ../tend-audio-env
../tend-audio-env/bin/python -m pip install -r scripts/audio-requirements.txt
../tend-audio-env/bin/python scripts/generate_audio.py --cache-dir ../tend-audio-cache
```

Generation runs locally on the CPU and downloads the pinned public stock-only model (about 219 MB). On macOS, the script uses the built-in `afconvert` utility for AAC encoding and round-trip decoding. Every practice must have valid, non-silent audio shorter than its timer; generation fails otherwise. Run `../tend-audio-env/bin/python scripts/verify_audio.py` to recheck every committed asset against its script and decode it again. Rebuilding the Xcode project bundles the new recordings and manifest.

The current narration follows the prototype scripts. Improved voice quality does not establish clinical review or approval of those scripts.
