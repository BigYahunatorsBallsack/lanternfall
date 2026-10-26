# Lanternfall

Koop-Survivors für Roblox. Design: [DESIGN.md](DESIGN.md), Arbeitsregeln: [CLAUDE.md](CLAUDE.md).

## Einmalige Einrichtung (Windows/Mac)

1. **Rokit installieren** (verwaltet alle Werkzeuge): Anleitung auf https://github.com/rojo-rbx/rokit – unter Windows in PowerShell, auf dem Mac im Terminal den dort angegebenen Einzeiler ausführen.
2. Terminal im Projektordner öffnen und `rokit install` eingeben. Fragt Rokit, ob es den Werkzeugen vertrauen soll: mit `y` bestätigen. Danach sind `rojo`, `wally`, `stylua` und `selene` installiert.
3. **Rojo-Plugin in Studio:** im Terminal `rojo plugin install` eingeben, danach Studio neu starten. In Studio erscheint unter „Plugins“ der Knopf **Rojo**.

## Jede Session

1. Im Projektordner `rojo serve` starten (Fenster offen lassen).
2. In Studio die Test-Place öffnen, Plugins → **Rojo** → **Connect**.
3. Studio zeigt jetzt den Code aus `src/`. Änderungen im Repo erscheinen sofort in Studio.

## Ordner

| Ordner | Landet in Studio unter | Inhalt |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage › Shared | Config (alle Spielwerte), Net (Netzwerk), Util |
| `src/server` | ServerScriptService › Server | Server-Start und Services |
| `src/client` | StarterPlayer › StarterPlayerScripts › Client | Client-Start und Controller |

## Für Entwickler

- Formatieren: `stylua src` · Prüfen: `selene src` (beim ersten Mal lädt Selene die Roblox-API herunter).
- Neue Remote nur in `src/shared/Net/Remotes.luau`, mit Rate-Limit und Validatoren.
- Spielwerte nur in `src/shared/Config`.
