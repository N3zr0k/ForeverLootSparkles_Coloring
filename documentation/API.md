# API

Das Addon hat keine globale API. Alle Funktionen hängen an der Addon-Tabelle `ns` und sind nur innerhalb des Addons erreichbar.

## SavedVariables `ForeverLootSparklesColoringDB` (accountweit)

| Feld | Typ | Bedeutung |
|---|---|---|
| `enabled` | boolean | Einfärben an/aus |
| `colors[category]` | `{ r, g, b }` | Farbe je Kategorie (`herb`, `ore`, `quest`, `corpseLoot`, `footlocker`) |
| `sparkleOre`, `sparkleHerbs`, `sparkleQuest`, `sparkleCorpseLoot`, `sparkleFootlocker` | boolean | Funkeln je Kategorie (nur mit FLS 2.x) |
| `safeSelfCast` | boolean | Sicheres Selbstzaubern |
| `hidePlate` | boolean | Namensplakette unter dem Funkeln ausblenden |
| `savedCVars` | table | CVar-Werte vor dem ersten Eingriff, für das Zurücksetzen |
| `pausedInteract` | number/nil | `SoftTargetInteract` während einer Pause |

## Interne Funktionen (`ns`)

| Funktion | Datei | Zweck |
|---|---|---|
| `ns.InitDB()` | Coloring.lua | SavedVariables anlegen und mit Standardwerten füllen |
| `ns.ResetColors()` | Coloring.lua | Farben auf Standard zurücksetzen |
| `ns.ColorsChanged()` | Coloring.lua | Nach einer Farbänderung neu zeichnen |
| `ns.StartColoring()` | Coloring.lua | Hook auf das Funkeln von FLS 1.x starten |
| `ns.KindOfUnit(unit)` | Coloring.lua | Kategorie einer Einheit bestimmen |
| `ns.SafeCall(func, ...)` / `ns.IsSecret(value)` | Coloring.lua | Gemeinsame Helfer |
| `ns.SparkleInit(sv)` | Sparkles.lua | Eigenes Funkeln (FLS 2.x) starten |
| `ns.SparkleOptionChanged(value)` | Sparkles.lua | Nach Änderung eines Funkel-Schalters |
| `ns.SafeSelfCastChanged()` / `ns.HidePlateChanged()` | Sparkles.lua | Nach Änderung der jeweiligen Option |
| `ns.DebugTarget()` | Sparkles.lua | `/flscolor target` |
| `ns.IconOptionsChanged()` / `ns.DebugIcons()` | IconHider.lua | Symbol-Optionen anwenden / `/flscolor icons` |
| `ns.TranslateFLS()`, `ns.HookRows()`, `ns.RefreshRows()` | Translate.lua | Optionsseite von FLS übersetzen |
