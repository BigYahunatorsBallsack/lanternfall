# AGENTS.md – Lanternfall (für ChatGPT / Codex und andere KI-Agenten)

## Verbindlicher Projektstand

- Das GitHub-Repository `BigYahunatorsBallsack/lanternfall` ist die Quelle fuer den aktuellen Projektstand. Vor jeder Arbeit den aktuellen `main` auf GitHub pruefen und Aenderungen von dort ableiten.
- Der lokale Ordner `C:\Users\jonas\Documents\Roblox\lanternfall\lanternfall` ist veraltet. Seinen Inhalt oder seinen lokalen `main` nicht als aktuellen Stand verwenden; vorhandene lokale Aenderungen unangetastet lassen.
- Studio kann fuer Laufzeittests genutzt werden. Vor einem Befund den dort geladenen Code mit GitHub `main` abgleichen, da Studio ebenfalls einen aelteren Stand enthalten kann.

Koop-Survivors für **Roblox** in **Luau** (kein Godot, kein Unity). 1–4 Spieler, 20 Wellen im Stil von Brotato, Shop zwischen den Wellen.

## Zuerst lesen (in dieser Reihenfolge)

1. **`CLAUDE.md`** – alle Regeln dort gelten für dich genauso (Owner-Kommunikation auf Deutsch, Architektur-Regeln, Definition of Done). Nur die Effort-Hinweise sind Claude-spezifisch: für Pakete mit „High"/„Extra high" die höchste Denkstufe deines Werkzeugs wählen.
2. **`STATUS.md`** – Stand, feste Entscheidungen des Owners, Werkzeug-Tricks, Code-Landkarte.
3. **`docs/PARALLEL.md`** – du bist **Strang B**. Dort steht, welche Pakete du baust, welche Dateien dir gehören, was geteilt ist und wie gemerged wird.
4. Aus `DESIGN.md` nur die Abschnitte deines Pakets (Abschnitt 20 = Paketliste).

## Das Wichtigste in Kürze

- **Parallel-Arbeit:** Claude baut gleichzeitig Strang A. Ändere **nur Dateien deines Strangs**; geteilte Dateien nur am Ende des passenden Blocks ergänzen. Nichts verschieben, umbenennen oder fremde Dateien umformatieren.
- **Brotato-Regel (verbindlich, Owner 06.11.2026):** Alles soll 1:1 wie in Brotato sein: Charaktere, Waffen, Items, Namen, Texte, Mechaniken, Formeln, Zahlen und Darstellung. Referenz: https://brotato.wiki.spellsandguns.com/. HP, Schaden und Heilung verwenden die originalen Einheiten mit Faktor 1; keine HP-x10-Skalierung und kein eigenes Ersatz-Balancing. Diese Vorgabe ersetzt aeltere Regeln zu eigenen Namen/Inhalten und bloss angenaeherten Werten. Bestehende technische oder spielerische Abweichungen sind offene Arbeit, keine erlaubten Ausnahmen; nicht als bereits 1:1 implementiert ausgeben. Ungeklaerte Wiki-Werte kennzeichnen und pruefen, nicht erfinden. Architektur, Server-Autoritaet und Dateibesitz bleiben verbindlich.
- **Server-Autorität:** Der Client schickt nur Absichten. Jede Remote steht in `src/shared/Net/Remotes.luau` mit Rate-Limit und Validierung.
- **Referenz und B10-Ausnahme (Owner 06.11.2026):** Stabile PC-Version **1.2.0.3 einschliesslich aller DLCs**, keine Beta (Owner-Aktualisierung 14.11.2026; ersetzt das vorherige Ziel1.2.0.2). Fuer diesen Charakterauftrag sind die notwendigen gezielten Ergaenzungen in Strang-A-Diensten freigegeben; Umfang und Schnittstellen siehe `docs/BROTATO-REQUIREMENTS.md`. Sprites liefert der andere Agent; sonstiger Dateibesitz bleibt geschuetzt.
- **Keine Balancing-Zahl im Code:** alle Werte in `src/shared/Config/*`.
- **Neue Waffe = Config-Datensatz in `Config/Weapons.luau` + Verhaltensmodul in `src/server/Services/WeaponService/Behaviors/` + Visual in `src/client/Controllers/WeaponRenderer/Visuals/`.** Vorbilder: `SparkBolt`, `BoomerangAxe`, `OrbitBlades`. Das Framework (`Arsenal`) bleibt unverändert.
- **Neues Item = Datensatz in `Config/Items.luau`**, Effekte als Daten nach `Config/Effects.luau` (Kopfkommentar listet Auslöser und Aktionen).
- Jedes Modul: `--!strict`, oben eine Kommentarzeile „Zweck und Aufrufer". Code, Kommentare und Spieltexte Englisch.

## Werkzeuge

- Formatieren: `stylua <deine geänderten Dateien>` (Einstellungen in `stylua.toml`).
- Lint: `selene src` (Roblox-Standard; geht der Download der Roblox-API nicht, siehe Trick in `STATUS.md` → Werkzeuge).
- Tests (Rust nötig): `cd tools/luau-test-runner && cargo build --release`, dann aus dem Repo-Ordner `tools/luau-test-runner/target/release/luau-test-runner . tests/<Name>.spec.luau` – **eine Datei pro Aufruf**.
- Roblox Studio hast du nicht. Der Owner testet in Studio nach deiner Testanleitung.
- Kannst du etwas nicht ausführen, schreib das ehrlich in den PR („Was ich nicht prüfen konnte").

## Abgabe

- Branch `wp-<nr>-<kurzname>` von aktuellem `main`, kleine Commits, Commit-Texte Englisch im Imperativ.
- PR nach `main`, Titel `[ChatGPT] <Paket> <Kurzname>`, Text nach der Vorlage in `.github/pull_request_template.md` (deutsche Zusammenfassung + Testanleitung für den Owner). Nicht selbst mergen.
- `STATUS.md`: nur deine Zeile in der Tabelle „Stränge" ändern, sonst nur unten anhängen.
- Ein Bug nach zwei Versuchen nicht gelöst: stoppen, Ursache und Optionen beschreiben.
