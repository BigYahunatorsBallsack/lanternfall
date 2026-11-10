# Code-Graph (graphify)

Stand 10.11.2026. Ein Wissensgraph des ganzen Repos (Code, Tests, Tools, Docs): welche Datei oder Funktion ruft was auf, welche Teile gehören zusammen. Er hilft, schnell zu finden, **wo** etwas liegt. Er ersetzt weder `STATUS.md` noch `DESIGN.md` noch das Lesen des echten Codes.

## Wo liegt er

`graphify-out/` im Repo-Root (committet):

| Datei | Inhalt |
|---|---|
| `GRAPH_REPORT.md` | Kurzüberblick: Zahlen, wichtigste Knoten, Gruppen. Nur für den groben Überblick lesen. |
| `graph.json` | Rohdaten, aus denen die Befehle unten antworten. |
| `graph.html` | Interaktive Ansicht, im Browser öffnen (herunterladen, GitHub zeigt sie nicht an). |
| `manifest.json`, `.graphify_*` | Interne Hilfsdateien, nicht anfassen. |

`graphify-out/cache/` ist in `.gitignore` und wird bei Bedarf neu angelegt.

## Benutzen

Einmal installieren (Python 3.10+ und `uv`; das Paket heißt mit zwei „y"):

```bash
uv tool install graphifyy
```

Dann im Repo-Root fragen:

```bash
graphify query "How does SpawnDirector use EnemySim?"
graphify path "SpawnDirector/init.luau" "EnemySim/init.luau"
graphify explain "EnemySim/init.luau"
```

`query` zeigt standardmäßig nur etwa 2000 Token; bei „TRUNCATED" mit `--budget <Zahl>` mehr holen oder die Frage enger stellen. In Claude Code gibt es zusätzlich den Skill `/graphify` (liegt unter `.claude/skills/graphify/`), der auch Docs und Bilder mit einem Sprachmodell auswerten kann.

## Aktuell halten

Der Graph gehört zu **einem Commit** (steht in `GRAPH_REPORT.md` unter „Graph Freshness"). Danach ist er veraltet. Wer Code ändert und den Graphen mitnehmen will:

```bash
graphify update .
```

Das braucht kein Sprachmodell und keine Kosten. `graph.json` wird dabei komplett neu geschrieben, ein großer Diff in dieser Datei ist normal. Bei Konflikten in `graph.json` nicht von Hand mergen, sondern `graphify update .` neu laufen lassen und das Ergebnis committen.

Der Graph ist **keine Pflicht** in jedem Paket. Er darf auch eine Weile hinterherhinken; dann vor jeder Entscheidung den echten Code prüfen. Es sind bewusst **keine** automatischen Hooks (Git oder Claude Code) eingerichtet.

## Bekannte Grenzen

- **Luau wird nur teilweise gelesen.** Beim Bau meldete der Parser bei 240 Dateien Syntaxfehler (teilweise extrahiert) und bei 236 Dateien keine Symbole, zum Beispiel viele Waffen-Visuals unter `src/client/Controllers/WeaponRenderer/Visuals/`. Fehlt etwas im Graphen, heißt das nicht, dass es nicht existiert. Im Zweifel `grep` und den Code lesen.
- **Modelle und Binärdateien** (`.fbx`, `.blend`, `.glb`, 66 Dateien) sind nicht enthalten.
- **Docs nur grob.** `graphify update` ohne Sprachmodell erfasst Markdown nur oberflächlich.
- Mit „17 % INFERRED" markierte Verbindungen sind Schätzungen des Werkzeugs, nicht belegte Aufrufe.
- Quelle des Werkzeugs: https://github.com/Graphify-Labs/graphify (Paket `graphifyy`, beim Bau Version 0.9.105).
