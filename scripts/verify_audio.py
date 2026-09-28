#!/usr/bin/env python3
"""Check bundled narration coverage, script binding, file hashes, duration and AAC decoding."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import tempfile
import soundfile as sf

root = Path(__file__).resolve().parent.parent
folder = root / 'Tend/Resources/Audio'
config = json.loads((root / 'Tend/Resources/study-config.json').read_text())
manifest = json.loads((folder / 'narration-manifest.json').read_text())
practices = {p['id']: p for p in config['practices']}
assets = manifest['assets']
assert len(assets) == len(practices), 'Every practice must have exactly one narration asset'
assert {a['practiceID'] for a in assets} == practices.keys(), 'Narration/practice mismatch'
for asset in assets:
    practice = practices[asset['practiceID']]
    assert asset['scriptSHA256'] == hashlib.sha256(practice['audioScript'].encode()).hexdigest()
    path = folder / asset['filename']
    assert path.parent == folder and path.suffix == '.m4a'
    assert asset['audioSHA256'] == hashlib.sha256(path.read_bytes()).hexdigest()
    assert 1 < asset['durationSeconds'] < practice['durationSeconds']
    with tempfile.TemporaryDirectory(prefix='tend-audio-check-') as scratch:
        wav = Path(scratch) / 'decoded.wav'
        subprocess.run(['/usr/bin/afconvert', '-f', 'WAVE', '-d', 'LEI16', str(path), str(wav)], check=True)
        with sf.SoundFile(str(wav)) as decoded:
            assert decoded.channels == 1 and decoded.subtype == 'PCM_16'
            assert decoded.samplerate == asset['sampleRate']
            seconds = len(decoded) / decoded.samplerate
            assert math.isclose(seconds, asset['durationSeconds'], abs_tol=0.2)
    print(f"PASS {asset['practiceID']}: {asset['durationSeconds']:.2f} s, matching script and decoded AAC")
print(f'{len(assets)} bundled narration assets verified')
