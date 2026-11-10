"""Machbarkeitstest: Bewertung per Spracherkennung (Whisper) statt Klangvergleich.

Für jede beurteilte Runde wird das Ergebnis (Versuch umgedreht) gegen alle Kandidaten-Wörter
abgeglichen: Wie wahrscheinlich ist es laut Whisper, dass dort genau dieses Wort gesagt wurde?
Daraus: Rang des richtigen Worts, Abstand zum besten falschen Wort, und wie gut das gut/schlecht trennt.
"""
import base64, io, json, os, sys, time, wave
import numpy as np, torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
runs = json.load(open(os.path.join(ROOT, "eval", "runs.json"), encoding="utf-8"))["rounds"]
words = [w for w in json.load(open(os.path.join(ROOT, "tts", "index.json"), encoding="utf-8")) if w not in ("Hallo", "Olla")]

def wav(b64):
    with wave.open(io.BytesIO(base64.b64decode(b64))) as w:
        sr = w.getframerate(); x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    return x, sr

def to16k(x, sr):
    n = int(len(x) * 16000 / sr); return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)

def auc(pos, neg):
    c = sum((p > n) + 0.5 * (p == n) for p in pos for n in neg); return c / (len(pos) * len(neg)) if pos and neg else float("nan")

POS, NEG = {"gut", "okay"}, {"falsch", "genuschelt"}
report = {}
for name in sys.argv[1:] or ["openai/whisper-tiny", "openai/whisper-base", "openai/whisper-small"]:
    t0 = time.time()
    proc = WhisperProcessor.from_pretrained(name); model = WhisperForConditionalGeneration.from_pretrained(name).eval()
    tok = proc.tokenizer
    prefix = tok.convert_tokens_to_ids(["<|startoftranscript|>", "<|de|>", "<|transcribe|>", "<|notimestamps|>"])
    eot = tok.eos_token_id
    cand = [tok.encode(" " + w, add_special_tokens=False) for w in words]
    L = max(len(c) for c in cand) + 1
    ids = torch.full((len(words), len(prefix) + L), eot); mask = torch.zeros_like(ids, dtype=torch.bool)
    for i, c in enumerate(cand):
        seq = prefix + c + [eot]; ids[i, :len(seq)] = torch.tensor(seq); mask[i, len(prefix):len(seq)] = True
    rows = []
    for r in runs:
        if not r["word"] or r["word"] not in words: continue
        x, sr = wav(r["b"]); res = to16k(x[::-1].copy(), sr)            # Ergebnis = Versuch umgedreht
        o, _ = wav(r["a"]); orig = to16k(o, sr)
        out = {}
        for key, audio in (("res", res), ("orig", orig)):
            feats = proc(audio, sampling_rate=16000, return_tensors="pt").input_features
            with torch.no_grad():
                enc = model.model.encoder(feats).last_hidden_state
                logits = model(encoder_outputs=(enc.expand(len(words), -1, -1),), decoder_input_ids=ids[:, :-1]).logits
            lp = torch.log_softmax(logits, -1).gather(-1, ids[:, 1:].unsqueeze(-1)).squeeze(-1)
            m = mask[:, 1:]
            s_sum = (lp * m).sum(1).numpy(); s_mean = s_sum / m.sum(1).numpy()
            ti = words.index(r["word"])
            for sk, s in (("sum", s_sum), ("mean", s_mean)):
                others = np.delete(s, ti)
                out[key + "_" + sk] = {"rank": int((others > s[ti]).sum()) + 1, "margin": float(s[ti] - others.max()),
                                       "z": float((s[ti] - others.mean()) / (others.std() + 1e-9)), "top": [words[i] for i in np.argsort(-s)[:3]]}
            if key == "res":
                with torch.no_grad():
                    gen = model.generate(feats, language="de", task="transcribe", max_new_tokens=20)
                out["heard"] = tok.decode(gen[0], skip_special_tokens=True).strip()
        rows.append({"label": r["label"], "word": r["word"], "d": r["d"], **out})
    print(f"\n===== {name}  ({time.time()-t0:.0f} s, {len(rows)} Runden, {len(words)} Kandidaten) =====")
    for sk in ("sum", "mean"):
        k = "res_" + sk
        pos = [x for x in rows if x["label"] in POS]; neg = [x for x in rows if x["label"] in NEG]
        print(f"[{sk}] AUC margin {auc([x[k]['margin'] for x in pos],[x[k]['margin'] for x in neg]):.3f} | z {auc([x[k]['z'] for x in pos],[x[k]['z'] for x in neg]):.3f} | -rank {auc([-x[k]['rank'] for x in pos],[-x[k]['rank'] for x in neg]):.3f}"
              f" | Vorlage selbst auf Rang 1: {sum(x['orig_'+sk]['rank']==1 for x in rows)}/{len(rows)}")
    print(f"zum Vergleich jetzige Messung (-d): AUC {auc([-x['d'] for x in rows if x['label'] in POS],[-x['d'] for x in rows if x['label'] in NEG]):.3f}")
    for x in sorted(rows, key=lambda x: -x["res_sum"]["z"]):
        print(f"{x['label']:10} {x['word']:15} d {x['d']:.2f} | Rang {x['res_sum']['rank']:3} z {x['res_sum']['z']:5.2f} m {x['res_sum']['margin']:6.2f} | Top {', '.join(x['res_sum']['top'])} | gehört: {x['heard']}")
    report[name] = rows
json.dump(report, open(os.path.join(ROOT, "eval", "results.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
