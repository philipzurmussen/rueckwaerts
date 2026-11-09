"""Erzeugt Hörproben deutscher Piper-Stimmen für piper-test/index.html (läuft in GitHub Actions)."""
import json, os, urllib.request, wave

HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE"
VOICES = [  # (name, Qualität, Beschreibung, Tempo: length_scale > 1 = langsamer)
    ("thorsten", "medium", "männlich · normales Tempo", 1.0),
    ("thorsten", "medium", "männlich · etwas langsamer", 1.25),
    ("thorsten", "medium", "männlich · langsam", 1.5),
    ("thorsten", "medium", "männlich · sehr langsam", 1.8),
]
WORDS = ["Giraffe", "Schmetterling", "Eichhörnchen", "Kölner Dom", "Gummibärchen",
         "Sternschnuppe", "Donaudampfschiff", "Ich verstehe nur Bahnhof"]

here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "audio")
import shutil; shutil.rmtree(out_dir, ignore_errors=True); os.makedirs(out_dir)   # alte Proben entfernen
models = os.path.join(os.path.expanduser("~"), "piper-models"); os.makedirs(models, exist_ok=True)

def slug(t):
    return "".join(c if c.isalnum() else "_" for c in t.lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss"))

def synth(model, text, path, scale):
    # Python-API von piper-tts ≥ 1.3 (SynthesisConfig), sonst ältere API
    from piper import PiperVoice
    v = PiperVoice.load(model)
    with wave.open(path, "wb") as w:
        if hasattr(v, "synthesize_wav"):
            from piper import SynthesisConfig
            v.synthesize_wav(text, w, syn_config=SynthesisConfig(length_scale=scale))
        else:
            v.synthesize(text, w, length_scale=scale)

manifest = {"words": WORDS, "voices": []}
for name, q, desc, scale in VOICES:
    vid = f"de_DE-{name}-{q}"
    tag = f"{vid}-x{scale}"
    model = os.path.join(models, vid + ".onnx")
    try:
        for ext in (".onnx", ".onnx.json"):
            dest = os.path.join(models, vid + ext)
            if not os.path.exists(dest):
                urllib.request.urlretrieve(f"{HF}/{name}/{q}/{vid}{ext}", dest)
        files = {}
        for wd in WORDS:
            fn = f"{tag}__{slug(wd)}.wav"
            synth(model, wd, os.path.join(out_dir, fn), scale)
            files[wd] = "audio/" + fn
        manifest["voices"].append({"id": tag, "name": name, "quality": q, "desc": desc, "files": files})
        print("OK", tag)
    except Exception as e:
        print("FEHLER", tag, e)

with open(os.path.join(here, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1)
print(len(manifest["voices"]), "Stimmen erzeugt")
