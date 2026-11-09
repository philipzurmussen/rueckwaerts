"""Erzeugt Hörproben deutscher Piper-Stimmen für piper-test/index.html (läuft in GitHub Actions)."""
import json, os, subprocess, urllib.request, wave

HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE"
VOICES = [  # (name, Qualität, Beschreibung)
    ("thorsten", "medium", "männlich"),
    ("thorsten", "high", "männlich, beste Qualität"),
    ("karlsson", "low", "männlich"),
    ("pavoque", "low", "männlich"),
    ("eva_k", "x_low", "weiblich"),
    ("kerstin", "low", "weiblich"),
    ("ramona", "low", "weiblich"),
    ("mls", "medium", "gemischt (Sprecher 0)"),
]
WORDS = ["Giraffe", "Schmetterling", "Eichhörnchen", "Kölner Dom", "Gummibärchen",
         "Sternschnuppe", "Donaudampfschiff", "Ich verstehe nur Bahnhof"]

here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "audio"); os.makedirs(out_dir, exist_ok=True)
models = os.path.join(os.path.expanduser("~"), "piper-models"); os.makedirs(models, exist_ok=True)

def slug(t):
    return "".join(c if c.isalnum() else "_" for c in t.lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss"))

def synth(model, text, path):
    # zuerst Python-API (piper-tts ≥ 1.3, dann ältere), sonst Kommandozeile
    try:
        from piper import PiperVoice
        v = PiperVoice.load(model)
        with wave.open(path, "wb") as w:
            if hasattr(v, "synthesize_wav"): v.synthesize_wav(text, w)
            else: v.synthesize(text, w)
        return
    except Exception as e:
        print("  API fehlgeschlagen, versuche CLI:", e)
    subprocess.run(["piper", "--model", model, "--output_file", path], input=text.encode(), check=True)

manifest = {"words": WORDS, "voices": []}
for name, q, desc in VOICES:
    vid = f"de_DE-{name}-{q}"
    model = os.path.join(models, vid + ".onnx")
    try:
        for ext in (".onnx", ".onnx.json"):
            dest = os.path.join(models, vid + ext)
            if not os.path.exists(dest):
                urllib.request.urlretrieve(f"{HF}/{name}/{q}/{vid}{ext}", dest)
        files = {}
        for wd in WORDS:
            fn = f"{vid}__{slug(wd)}.wav"
            synth(model, wd, os.path.join(out_dir, fn))
            files[wd] = "audio/" + fn
        manifest["voices"].append({"id": vid, "name": name, "quality": q, "desc": desc, "files": files})
        print("OK", vid)
    except Exception as e:
        print("FEHLER", vid, e)

with open(os.path.join(here, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1)
print(len(manifest["voices"]), "Stimmen erzeugt")
