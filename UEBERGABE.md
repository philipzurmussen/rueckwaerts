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
- **Aufbau (weniger scrollen):** Tabs als feste Leiste unten (`.bnav`, Duelle mit roter Zahl über `data-n`). Solo-Start `#soloHome` = Season-Karte + Kacheln „Freies Spiel“ (`#tFree` → `openFree()`) und „Satz-Modus“ (`#zStart`) + Leiste „Letzte Runden“ (`#tHist`), die die Liste als Ausklapp-Fenster `#histSheet` öffnet. Freies Spiel `#soloFree` ist eigene Ansicht mit Zurück-Knopf; Solo-Tab nochmal tippen → zurück zum Start (`showSoloHome`). „?“ sitzt im Mini-Profil, der Duelle-Chip ist dort ausgeblendet.
- **Spiel-Ansicht:** In Freies Spiel, Season und Satz-Modus bekommt `body` die Klasse `ingame` → Mini-Profil und Tab-Leiste sind ausgeblendet. Freies Spiel: Fortschritt `#fSteps` (1 Aufnehmen · 2 Nachsprechen · 3 Ergebnis, `syncSteps()` beobachtet Karten + `#score`), großer Aufnahmeknopf mit Beschriftung „Aufnehmen/Stopp“, Titel statt Erklärtext. Im Ergebnis-Schritt (`#cardB.scored`) stehen Wappen und Banner oben, Wellenform/Aufnahme sind ausgeblendet, „Nochmal versuchen“ (`#againB`) geht zurück zu Schritt 2.
- **Duell-Ansicht:** `#aGame` ist ebenfalls Spiel-Ansicht (`ingame`): oben Zurück-Knopf + kompakter Spielstand (`.dhead`/`.dboard`), in der Mitte die Aufgabe (`.dstage`, große Aufnahmeknöpfe), unten Leiste „Rundenverlauf“ (`#aRoundsBtn`), die `#aRounds` samt „Duell aufgeben“ im Ausklapp-Fenster `#roundsSheet` öffnet.
- **Season + Satz-Modus:** gleicher Aufbau wie Freies Spiel/Duell (`.gamehead` mit Titel, `.dstage`, große Aufnahmeknöpfe). Wochen-Rangliste der Season steckt im Ausklapp-Fenster `#boardSheet` (Knopf `#sBoardBtn`).
- **Statistik:** Jede fertige Runde ruft `logPlay(modus, sterne)` → RPC `log_play` schreibt anonym in `public.plays` (Modus frei/satz/season/duell, Sterne, Zeit, anonyme Nutzer-ID; kein Audio, kein Name; max. 300/Stunde pro Nutzer). Im Studio (`#studio`) zeigt die Karte „📊 Statistik“ über `admin_stats()` Runden/Spieler heute, 7 Tage, gesamt, 14-Tage-Balken und Modi – Admin-Konten herausgerechnet. Zählt erst ab dem Einrichten (setup.sql ausführen).
- **Profil-Fenster:** Tipp auf den Avatar oben öffnet `#profSheet` (Ausklapp-Fenster) mit `#profBox` (Nickname, Avatar, Farbe, Konto sichern/Anmelden) und dem Level-Block `#aLevel`. Im Duelle-Tab gibt es keinen Profil-Bereich mehr; bei Einladungslinks öffnet sich das Profil-Fenster für neue Spieler automatisch. Live-Lobby nutzt weiter `#lProfSlot`.
- **Kopfzeile:** Logo oben entfällt (steht im Ladescreen). Stattdessen Mini-Profil `#pbar` (Avatar + Level-Abzeichen, Name, Level-Titel, XP-Leiste bis zum nächsten Level; Chips „Platz N“ → Rangliste und „N dran“ → Duelle, roter Punkt auch am Duelle-Tab), `renderPbar()`. Tipp auf den Avatar öffnet die Avatar-Auswahl im Duelle-Tab. Der „?“-Knopf sitzt rechts neben den Tabs.
- **Stil:** Karten und Knöpfe mit dunkler Kontur `#0e0722` und 3D-Schatten wie die Ergebnistafel; Season-Karte lila mit gelbem Rand und Lichtstrahlen.
- **Zwischen-Slides:** `interstitial(titel, untertitel)` – lila Vollbild mit Lichtstrahlen und dem O aus dem Logo (`o.png`), das sich einmal rückwärts dreht (~1,2 s, Tippen überspringt). Solo „Passt so“ → „Jetzt du!“ (Vorlage spielt direkt im Tipp, wegen iOS), Duell „Weiter“ → „Runde N“, Duell aus der Liste öffnen, wenn man dran ist → „Du bist dran!“, Season „Nächster Begriff“ → „Begriff N“. Danach gleitet die Karte weich rein (`enter()`).
- **Look:** Ladescreen beim Start (`#splash`: Streifen, Maskottchen-Sprechblase, Logo, ~1,3 s, Tippen überspringt); Solo-Ergebnis als „Wappen“ mit hochzählender Prozentzahl, ploppenden Sternen, Banner und Konfetti ab 2 Sternen (`showScore`, `confetti()`; Konfetti auch bei Season und Satz-Modus). Duell-Runde nach dem eigenen Versuch: Wappen „Du VS Gegner“ mit hochzählenden Zahlen, Sterne-Pop, Krone für den Rundensieger, Konfetti bei Sieg, große Reaktions-Knöpfe (`renderReveal`, einmal pro Runde animiert über `A.shownReveal`). Entwurf auf dem Design-Canvas „Ollah! – Ergebnis-Screen“.
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

## Reward-System (Plan für später, nach ersten Tester-Erfahrungen)

Inspiration: Duolingo, Wordle, Clash Royale, GeoGuessr – Mechaniken übernehmen, eigener Look und Witz.

1. **Tageswort** (Favorit für den Einstieg): ein Wort pro Tag für alle, ein Versuch, Tagesrangliste, **Teilen-Grafik** ohne das Wort zu verraten (z. B. „Ollah! #42 ⭐⭐☆“) – auch Werbung in WhatsApp-Gruppen und spätere Gratis-Grenze.
2. **Serie** 🔥 für tägliches Spielen, mit **Streak-Freeze** gegen Frust.
3. **Wochen-Ligen** statt einer großen Rangliste: kleine Gruppen (~20) ähnlich aktiver Spieler, Auf- und Abstieg pro Woche – passt zu den Seasons.
4. **Belohnungspfad** für Level: vorher sichtbar, was als Nächstes freigeschaltet wird (Themen, Avatare, Waveform-Farben, Jubel-Sounds).
5. **Abzeichen** Bronze/Silber/Gold (z. B. erstes 3★, 10 Duell-Siege, Zungenbrecher, Season-Podest) – nur sinnvoll, wenn sie im Profil/Duell sichtbar sind.
6. Später **Duell-Rang (ELO)** getrennt vom Level, für faire Zufallsgegner.

Grundsatz: Belohnungen nie auf Sterne/Vergleich auswirken lassen; Kosmetik ist der naheliegende Weg für spätere Einnahmen.
