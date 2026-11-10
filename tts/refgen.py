"""Versuch: dieselben Wörter mit weiteren Piper-Stimmen erzeugen (Referenzen für die Bewertung).
Aufruf: python tts/refgen.py  – schreibt tts-ref/<stimme>/<md5[:12]>.mp3 für alle Wörter aus tts/index.json."""
import hashlib, json, os, subprocess, sys, tempfile, urllib.request, wave
from piper import PiperVoice
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE"
VOICES = [("thorsten", "medium", 1.0), ("thorsten", "high", 1.4), ("karlsson", "low", 1.4), ("pavoque", "low", 1.4), ("kerstin", "low", 1.6), ("eva_k", "x_low", 1.3)]
words = list(json.load(open(os.path.join(ROOT, "tts", "index.json"), encoding="utf-8")).keys())
only = [w for w in sys.argv[1:]]
if only: words = [w for w in words if w in only]
models = os.path.join(os.path.expanduser("~"), "piper-models"); os.makedirs(models, exist_ok=True)
for name, q, scale in VOICES:
    vid = f"de_DE-{name}-{q}"; tag = f"{name}-{q}"
    out = os.path.join(ROOT, "tts-ref", tag); os.makedirs(out, exist_ok=True)
    try:
        for ext in (".onnx", ".onnx.json"):
            dest = os.path.join(models, vid + ext)
            if not os.path.exists(dest): urllib.request.urlretrieve(f"{HF}/{name}/{q}/{vid}{ext}", dest)
        voice = PiperVoice.load(os.path.join(models, vid + ".onnx"))
        n = 0
        for w in words:
            f = os.path.join(out, hashlib.md5(w.encode("utf-8")).hexdigest()[:12] + ".mp3")
            if os.path.exists(f): continue
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp: path = tmp.name
            with wave.open(path, "wb") as wf:
                from piper import SynthesisConfig
                voice.synthesize_wav(w, wf, syn_config=SynthesisConfig(length_scale=scale))
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-ac", "1", "-ar", "22050", "-b:a", "40k", f], check=True)
            os.remove(path); n += 1
        print("OK", tag, n)
    except Exception as e:
        print("FEHLER", tag, e)
