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

def fname(word):
    return hashlib.md5(word.encode("utf-8")).hexdigest()[:12] + ".mp3"

missing = [w for w in words() if not os.path.exists(os.path.join(OUT, fname(w)))]
print(len(words()), "Wörter,", len(missing), "fehlen")
if "--check" in sys.argv:
    sys.exit(1 if missing else 0)
if not missing:
    sys.exit(0)

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
