"""Erzeugt die Kunststimme (Piper, thorsten medium, langsam) für alle Listen-Wörter aus supabase/setup.sql.

Dateiname = erste 12 Zeichen von md5(Wort) + .mp3 – genauso berechnet der Server den Pfad (tts_round).
Nur fehlende Wörter werden erzeugt. Mit --check wird nur geprüft, ob etwas fehlt (Exit-Code 1 = ja).
"""
import hashlib, os, re, subprocess, sys, tempfile, urllib.request, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tts")
VOICE, SCALE = "de_DE-thorsten-medium", 1.5
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/medium/"

def words():
    sql = open(os.path.join(ROOT, "supabase", "setup.sql"), encoding="utf-8").read()
    block = re.search(r"insert into public\.words\(word\) values(.*?)on conflict do nothing;", sql, re.S).group(1)
    return [w.replace("''", "'") for w in re.findall(r"\('((?:[^']|'')*)'\)", block)]

# Zusatzwörter für das Einstiegs-Beispiel („Hallo“ rückwärts ≈ „Olla“)
EXTRA = ["Hallo", "Olla"]

def fname(word):
    return hashlib.md5(word.encode("utf-8")).hexdigest()[:12] + ".mp3"

import json
ALL = words() + [w for w in EXTRA if w not in words()]
INDEX = os.path.join(OUT, "index.json")
index = {w: fname(w) for w in ALL}
missing = [w for w in ALL if not os.path.exists(os.path.join(OUT, fname(w)))]
stale = not os.path.exists(INDEX) or json.load(open(INDEX, encoding="utf-8")) != index
print(len(ALL), "Wörter,", len(missing), "fehlen", "| Index veraltet" if stale else "")
if "--check" in sys.argv:
    sys.exit(1 if (missing or stale) else 0)

def write_index():
    with open(INDEX, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=0, sort_keys=True)

if not missing:
    write_index(); sys.exit(0)

from piper import PiperVoice
models = os.path.join(os.path.expanduser("~"), "piper-models"); os.makedirs(models, exist_ok=True)
for ext in (".onnx", ".onnx.json"):
    dest = os.path.join(models, VOICE + ext)
    if not os.path.exists(dest): urllib.request.urlretrieve(HF + VOICE + ext, dest)
voice = PiperVoice.load(os.path.join(models, VOICE + ".onnx"))

for w in missing:
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp: path = tmp.name
    with wave.open(path, "wb") as wf:
        if hasattr(voice, "synthesize_wav"):
            from piper import SynthesisConfig
            voice.synthesize_wav(w, wf, syn_config=SynthesisConfig(length_scale=SCALE))
        else:
            voice.synthesize(w, wf, length_scale=SCALE)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-ac", "1", "-ar", "22050", "-b:a", "64k",
                    os.path.join(OUT, fname(w))], check=True)
    os.remove(path)
    print("OK", w)
write_index()
