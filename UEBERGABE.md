# Ollah! – Übergabe für neue Chats

Smartphone-Wortspiel: Wort aufnehmen → rückwärts anhören → rückwärts nachsprechen → der Versuch wird wieder umgedreht und mit dem Original verglichen (bis zu 3 Sterne). Ziel: App Store.

- Live: **https://ollah.app** (GitHub Pages, Repo `philipzurmussen/rueckwaerts`, Branch `main`, Domain über `CNAME`, DNS bei Strato)
- Sprache der App und der Gespräche: Deutsch

## Aufbau

| Datei | Inhalt |
|---|---|
| `index.html` | Die ganze App (HTML/CSS/JS in einer Datei) |
| `supabase/setup.sql` | Komplettes Datenbank-Setup, beliebig oft ausführbar |
| `sw.js` | Service Worker (network-first, Cache-Version `ollah-vNN` bei jeder Änderung erhöhen) |
| `manifest.webmanifest`, `icon-*.png`, `apple-touch-icon.png` | PWA |

**Tabs:** Solo · Duelle · Rangliste (Live-Modus per PeerJS existiert noch, ist aber ausgeblendet: `#tabDuel hidden`).

- **Solo:** Schritt 1 Wort aufnehmen, dann Schritt 2 nachsprechen (nacheinander), Satzmodus darunter, Verlauf der letzten 5, Season-Karte.
- **Duelle:** rundenbasiert (5 Runden), gegen Freunde (Einladungslink `#D` + 6 Zeichen) oder zufällige Gegner; Themenlisten, eigene Wörter nur unter Freunden; Reaktionen/Sprüche, Revanche, Aufgeben, 48 h Zeitlimit.
- **Rangliste:** Level (0/30/80/150/300 Punkte schalten Themen frei), Wochen-Season, Gesamtrangliste.
- **Seasons:** eine Woche, 6 vorgegebene Begriffe, alle sprechen mit eigener Stimme. Planung im Admin-**Studio** (`#STUDIO`).
- **Konto:** anonym starten, später E-Mail-Code (OTP) verknüpfen; Login auf anderem Gerät per Code.
- Sonstiges: Feedback-Knopf, geführte erste Runde (Tour), „?“-Hilfe, Links-/Rechtshänder-Umschalter.

## Technik

- Audio: MediaRecorder → Stille wegschneiden (RMS) → normalisieren → umdrehen; Wiedergabe über ein `<audio>`-Element (iOS).
- Vergleich: MFCC + DTW; Sterne-Schwellen `STAR_STEPS = [0.35, 0.5, 0.65]`, unter 0.10 kein Abhören.
- Backend: Supabase (Auth, Postgres mit RLS + RPC-Funktionen, Storage-Bucket `audio`, Realtime auf `games`). E-Mail-Versand über Brevo-SMTP.
- `SB_URL` / `SB_KEY` (publishable key) stehen in `index.html`. **Nie** den service_role/secret key verwenden oder anfragen; DB-Passwort und Brevo-Key bleiben bei Philip.

## Ablauf bei Änderungen

1. `index.html` bzw. `setup.sql` ändern, `sw.js`-Cache-Version erhöhen.
2. Lokal testen (Postgres + Mock-Server + Playwright mit Fake-Mikro) – Testumgebung muss im neuen Chat neu aufgesetzt werden.
3. Commit + Push auf `main` → nach ~1 Min. live.
4. Wenn `setup.sql` geändert wurde: Philip führt das **komplette** Skript im Supabase SQL Editor aus (Warnung „destructive operations“ ist harmlos).

## Wöchentlicher Agent

Samstags läuft eine geplante Aufgabe, die Ereignisse und Gedenktage der kommenden Woche sucht und Season-Themen vorschlägt (auch fortlaufende Themen; gerne auch Themen wie Feminismus, CSD).

## Offen

- Nach dem Domainwechsel: HTTPS-Zertifikat prüfen, Tester auf ollah.app umstellen (neu einloggen; Gast-Konten wandern nicht mit).
- Später auf Wunsch: Brevo-Domain-Authentifizierung für Absender `@ollah.app`.
- Sterne-Schwellen anhand echter Daten nachjustieren (bei 3 Sternen bleiben).
- Tester-Feedback auswerten, u. a. ob 3 Wörter pro Runde spannender wären.

## Zurückgestellte Ideen (nicht ohne Auftrag bauen)

- KI-/TTS-generierte Vorgabewörter gegen Schummeln (API-Key nur auf dem Admin-Gerät, nie in der App).
- Season als Pop-up bzw. im Hauptmenü (App-Store-Version).
- App-Store-Build: Capacitor, Push-Benachrichtigungen, Login mit Apple/Google.
