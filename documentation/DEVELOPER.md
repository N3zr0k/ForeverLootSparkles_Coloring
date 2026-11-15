# Entwickler-Doku

## Aufbau des Addons

Alle Dateien teilen sich die Addon-Tabelle `ns` (zweiter Wert aus `...`). Ladereihenfolge laut TOC:

| Datei | Aufgabe |
|---|---|
| `LocalesMore.lua` | Zusätzliche Sprachen (esES/esMX, ptBR, itIT, ruRU, koKR, zhCN/zhTW) |
| `Locales.lua` | Englisch, Deutsch, Französisch; Auswahl über `GetLocale()`, Fallback enUS |
| `Coloring.lua` | SavedVariables, Kategorien, Standardfarben; färbt das Funkeln von Forever Loot Sparkles 1.x per Post-Hook auf dessen `OnUpdate` |
| `IconHider.lua` | Blendet Interaktionssymbole auf Namensplaketten aus (Alpha 0), NSC-Symbole über die CVar `SoftTargetIconInteract` |
| `Sparkles.lua` | Eigenes Funkeln für Forever Loot Sparkles 2.x, sicheres Selbstzaubern, Ausblenden der Namensplakette |
| `Translate.lua` | Übersetzt die Optionsseite von Forever Loot Sparkles |
| `Options.lua` | Hängt die eigenen Optionen in die Seite von Forever Loot Sparkles ein, Slash-Befehl `/flscolor` |

## Wichtige Abläufe

- **Erkennung FLS 1.x/2.x:** über die Version aus der TOC von Forever Loot Sparkles, Fallback über dessen SavedVariables (`IsFLSModern` in `Options.lua`).
- **Start verzögert:** `Sparkles.lua` greift erst 6 s nach dem Login in die CVars ein, damit Forever Loot Sparkles 2.x seine alten Soft-Target-Werte zuerst zurücksetzt.
- **Sicheres Selbstzaubern:** `SoftTargetInteract` wird im Kampf und bei lebenden Einheiten auf 0 gesetzt; der vorherige Wert liegt in `db.pausedInteract`, damit ein Logout während der Pause nichts verstellt. Fortsetzen nach 5 Yards Bewegung bzw. 3 s ohne Positionsdaten.
- **CVars nur außerhalb des Kampfs:** Änderungen im Kampf werden in `pendingCVars` vorgemerkt und nach `PLAYER_REGEN_ENABLED` nachgeholt.
- **Secret Values:** Werte aus Unit-APIs und Texturen werden mit `ns.IsSecret` geprüft und wie „fehlt“ behandelt.

## Erweitern

- **Neue Funkel-Kategorie:** Kategorie in `ns.DEFAULT_COLORS` (`Coloring.lua`), Erkennung und Schalter in `Sparkles.lua` (`DEFAULTS`, Zuordnung zur Option), Texte in allen Locale-Dateien.
- **Neue Texte:** in `Locales.lua` (enUS, deDE, frFR) und `LocalesMore.lua` eintragen.
- **Als eigenes Addon:** `## Dependencies: ForeverLootSparkles_Coloring` und die Funktionen aus [API.md](API.md) nutzen. Die Tabelle `ns` ist nicht global; ein externes Addon kommt nur über `ForeverLootSparklesColoringDB` und die Optionen heran.

## Lokal prüfen

```sh
luacheck ForeverLootSparkles_Coloring
```

In der Cloud gibt es keinen WoW-Client: alles ist erst nach dem Test im Spiel bestätigt.
