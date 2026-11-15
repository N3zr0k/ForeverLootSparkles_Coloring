# Forever Loot Sparkles - Herbs & Ores

Begleit-Addon zu **Forever Loot Sparkles** (WoW Forever). Das Original-Addon wird dabei nicht verändert.

## Was das Addon macht

### Funkeln für Kräuter, Erz, Questobjekte, Leichen und Schließkisten
Forever Loot Sparkles 2.0 hat das Funkeln an Kräutern, Erzvorkommen, Questobjekten und Leichen mit Beute entfernt. Dieses Addon bringt es zurück (übernommen aus Forever Loot Sparkles 1.3.1) und ergänzt Schließkisten, die Schurken knacken können.

- **Sicheres Selbstzaubern** (an): Zauber ohne Ziel konnten auf einem Spieler oder NSC landen, den die Soft-Zielerfassung neben dir ausgewählt hatte. Die Soft-Zielerfassung wird deshalb im Kampf und bei lebenden Einheiten pausiert und nach ein paar Metern Bewegung wieder eingeschaltet.
- **Namensplakette unter dem Funkeln ausblenden** (an): Leichen und Objekte zeigen keine leere Namensplakette oder Lebensleiste mehr, nur das Funkeln.
- Mit Forever Loot Sparkles 1.x färbt das Addon nur dessen Funkeln ein.

### Farben je Kategorie
Kräuter, Erzvorkommen, Questobjekte, Leichen mit Beute und Schließkisten bekommen jeweils eine eigene Farbe. Die Farbfelder sitzen direkt neben den Checkboxen auf der Optionsseite von Forever Loot Sparkles, darunter ein Schalter zum Ein-/Ausschalten und ein Knopf zum Zurücksetzen. Außer Reichweite wird das Funkeln gedimmt, bei gesperrten Objekten grau.

### Interaktionssymbole ausblenden
Optional lässt sich das Interaktionssymbol des Spiels (Zahnrad, Spitzhacke, Blatt, Hand …) über Objekten ausblenden: alle auf einmal oder einzeln für Kräuter, Erz, Questobjekte, Leichen mit Beute, sonstige Objekte und NSCs. Das Funkeln bleibt sichtbar.

### Übersetzung
Die Optionsseite von Forever Loot Sparkles wird in die Sprache des Clients übersetzt. Unterstützt: Englisch, Deutsch, Französisch, Spanisch (esES, esMX), Portugiesisch (ptBR), Italienisch, Russisch, Koreanisch und Chinesisch (zhCN, zhTW).

## Installation

1. [Forever Loot Sparkles](https://www.curseforge.com/wow/addons/forever-loot-sparkles) installieren (Pflicht-Abhängigkeit).
2. ZIP aus den [Releases](../../releases) oder von CurseForge herunterladen.
3. Den Ordner `ForeverLootSparkles_Coloring` nach `World of Warcraft\_retail_\Interface\AddOns` entpacken.

Der Ordnername bleibt `ForeverLootSparkles_Coloring`, damit die Einstellungen (`ForeverLootSparklesColoringDB`, accountweit) erhalten bleiben.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/flscolor` | Öffnet die Optionen auf der Seite von Forever Loot Sparkles |
| `/flscolor target` | Zeigt im Chat, was das Addon am aktuellen Interaktionsziel erkennt (Name, Objekt-ID, Symbol, Kategorie) – hilfreich für Fehlermeldungen |
| `/flscolor icons` | Listet, was das Addon auf den Namensplaketten in der Nähe sieht |

## Einschränkungen

- Eingefärbt werden nur die Funken, die Forever Loot Sparkles bzw. dieses Addon selbst zeichnet. Das Beute-Funkeln des Spiels an Questgegenständen zeichnet die Engine.
- Die Chatzeile „restart the game“ und die Beschreibung von Forever Loot Sparkles in der Addon-Liste bleiben englisch (dafür müssten dessen Dateien geändert werden).
- Die Übersetzungen passen zu den Texten von Forever Loot Sparkles 1.3.1; umformulierte Texte späterer Versionen bleiben englisch.

## Repository-Aufbau

| Pfad | Inhalt |
|---|---|
| `ForeverLootSparkles_Coloring/` | Der Spielordner, genau so wie er nach `Interface\AddOns` kommt |
| `.github/workflows/release.yml` | CI: Lint, ZIP-Build, Release und CurseForge-Upload |
| `.pkgmeta` / `.luacheckrc` | Packager- und Lint-Konfiguration |
| `CHANGELOG.md` / `BUGFIX.md` | Änderungen (englisch) / Fehlerbehebungen im Detail |
| `documentation/` | Entwickler- und API-Doku, CurseForge-Beschreibung, Assets |

## Release-Ablauf

Die Version steht ausschließlich in der TOC (`## Version:`). Bei einem Push auf `main` gilt:

1. **Lint** (luacheck) muss grün sein.
2. Das Addon wird mit dem BigWigs-Packager als `ForeverLootSparkles_HerbsOres-<version>.zip` gebaut und als Artefakt abgelegt (auch bei Pull Requests).
3. Gibt es zur TOC-Version noch keinen Tag, legt CI Tag und GitHub-Release an:

| TOC-Version | GitHub | CurseForge |
|---|---|---|
| `x.y.z-alpha.N` | Prerelease | kein Upload |
| `x.y.z-beta.N` | Release, Titel mit „(Beta)“ | Upload als Beta |
| `x.y.z` | Release | Upload als Release |

Die Release-Notes kommen aus dem Abschnitt `## <version>` in `CHANGELOG.md`.

### Einmalige Einrichtung

Unter *Settings → Secrets and variables → Actions*:

- **Secret** `CF_API_KEY`: API-Token von https://legacy.curseforge.com/account/api-tokens
- **Variable** `CURSEFORGE_PROJECT_ID`: numerische Projekt-ID (steht auf der CurseForge-Projektseite unter „About Project“)
- **Variable** `CF_GAME_VERSION` (optional): nur nötig, falls CurseForge die Interface-Version der TOC nicht zuordnen kann

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE). Der Klassifizierungscode ist aus Forever Loot Sparkles übernommen und angepasst.

## Danke

Ein großes Dankeschön an **conoar**, den Autor von Forever Loot Sparkles. Dieses Addon fügt nur etwas Farbe und ein paar Übersetzungen hinzu; die eigentliche Arbeit, Beute, Kräuter und Erz funkeln zu lassen, stammt von conoar.
