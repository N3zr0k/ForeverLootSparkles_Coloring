# Bugfixes

Details zu behobenen Fehlern. `CHANGELOG.md` nennt nur eine Zeile pro Änderung.

## 2.2.5

### Interaktionstaste am Auktionshaus aus, Interaktionssymbol flackert, Auctionator-Fehler
- **Dateien:** `ForeverLootSparkles_Coloring/Sparkles.lua`, `ForeverLootSparkles_Coloring/IconHider.lua`
- **Ursache:** „Sicheres Selbstzaubern“ schaltete `SoftTargetInteract` auf 0, sobald das Soft-Ziel eine lebende Einheit war, also auch beim Auktionator oder bei Spielern im AH. Ohne Spielerposition wurde nach 3 Sekunden fortgesetzt und sofort wieder pausiert. Jeder dieser CVar-Schreibvorgänge löst `CVAR_UPDATE` mit dem Taint des Addons aus, auch während das AH offen ist.
- **Folge:** Die Interaktionstaste ging am Auktionator nicht oder nur zeitweise, das Interaktionssymbol flackerte, und Addons im AH-Fenster (Auctionator) liefen in Fehler.
- **Fix:** Drei Modi (Aus / Nur im Kampf / Im Kampf und bei Einheiten). Hatte der Spieler die Interaktionstaste selbst an, gilt automatisch „Nur im Kampf“, bis er einen Modus wählt. NPCs mit Dienst-Cursor werden nicht mehr pausiert. Keine CVar-Schreibvorgänge, solange ein NPC-, AH- oder Postfenster offen ist. Wird dieselbe Einheit direkt nach dem Fortsetzen erneut gewählt, verdoppelt sich die Wartezeit (bis 16-fach). IconHider: nur noch die Icon-Textur wird ausgeblendet, der von Blizzard zuletzt gesetzte Alpha-Wert wird wiederhergestellt, die Prüfung läuft ereignisgesteuert (Poller nur noch 1 s), und die NPC-Icon-CVar wird nicht gesetzt, wenn sie nicht lesbar ist.
- **Status:** gegen eine Mock-API getestet, im Spiel ungetestet.

## 2.2.2

### Pausenstatus der Soft-Zielerfassung wurde nicht zurückgesetzt
- **Datei:** `ForeverLootSparkles_Coloring/Sparkles.lua`
- **Ursache:** `local paused` war erst nach `ApplyCVars` und `RestoreCVars` deklariert. Beide Funktionen schrieben deshalb eine globale Variable `paused` statt der lokalen; der lokale Pausenstatus blieb nach dem Zurücksetzen erhalten.
- **Folge:** Nach dem Aus-/Einschalten des Funkelns oder „Sicheres Selbstzaubern“ konnte eine alte Pause (z. B. „unit“) hängen bleiben, sodass `Pause()` früh zurückkehrte. Zusätzlich landete `paused` im globalen Namensraum.
- **Fix:** Deklaration vor `ApplyCVars` verschoben. Gefunden durch luacheck.
- **Status:** nur per luacheck geprüft, im Spiel ungetestet.
