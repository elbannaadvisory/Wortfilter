# Wortfilter – WoW Forever

Wortfilter ist ein lokales Lua-AddOn für World of Warcraft: Forever 1.60.1 (AddOn-Interface 16001). Es ersetzt konfigurierbare Wörter und Lua-Textmuster in erreichbaren Quest-, Benutzeroberflächen- und Chattexten, ohne Spieldateien oder Serverdaten zu verändern.

**Projektstatus:** Version 0.2.0. Lua-Smoke-Tests mit simulierten WoW-APIs erfolgreich; ein Test im laufenden Spiel steht noch aus.

## Installation

1. WoW beenden. Einen bestehenden Ordner namens OttFilter deaktivieren oder entfernen, damit zwei Filter nicht parallel laufen.
2. Den Ordner Wortfilter aus dem Projekt in World of Warcraft\_forever_\Interface\AddOns\ kopieren.
3. Im AddOn-Menü Wortfilter aktivieren.
4. Das Spiel starten und /wf eingeben.

Der zu installierende Ordner ist: Wortfilter/ (mit den Dateien Wortfilter_Camelot.toc, Wortfilter_Defaults.lua, Wortfilter_Core.lua und Wortfilter_UI.lua).

## Einstellungen im Spiel

- /wf, /wort oder /wortfilter: Regel-Editor öffnen und schließen.
- Vorhandene Regel anklicken, Suchmuster und Ersetzung bearbeiten, anschließend Speichern wählen.
- Mit Neu, Löschen, Nach oben und Nach unten die Regeln verwalten.
- Regel aktiv deaktiviert eine einzelne Regel; Wortfilter aktiviert schaltet den gesamten Filter um.
- Lua-Pattern aktivieren für Muster mit Platzhaltern, sonst wird der Suchtext wörtlich interpretiert.
- Die Live-Vorschau zeigt Änderungen sofort, die Regeln werden als SavedVariables in WortfilterDB gespeichert.
- Bei sehr vielen Regeln kann die Darstellung langsamer werden (maximal 100 Regeln).

Die Reihenfolge der Regeln ist relevant. Muster können maximal 160 Byte und Ersetzungen maximal 320 Byte lang sein.

## Standardregeln

| Suchmuster | Ersetzung | Beispiel |
| --- | --- | --- |
| [Gg]([Oo][Tt][Tt]) | %1 | Gott → ott, GOTT → OTT |
| [Gg](ö[Tt][Tt]) | %1 | Göttin → öttin |
| [Gg](Ö[Tt][Tt]) | %1 | GÖTTLICH → ÖTTLICH |

Einige weitere Beispiele:
- Textmodus: König → Kaiser.
- Textmodus: Sturmwind → Sonnenstadt.
- Lua-Pattern: (%d+) Wölfe → %1 Füchse (10 Wölfe → 10 Füchse).

**Hinweis:** Lua-Patterns sind keine JavaScript-/PCRE-RegEx. UTF-8-Ersetzungen funktionieren, aber Zeichenklassen wie %a sind nicht generell Unicode-bewusst.

## Chatbefehle

| Befehl | Wirkung |
| --- | --- |
| /wf | Editor öffnen/schließen |
| /wf on und /wf off | Filter an-/ausschalten |
| /wf test Gott und Göttin | Text mit den Regeln testen |
| /wf scan | Bereits angezeigte UI-Texte neu prüfen |
| /wf reset | Standardregeln wiederherstellen (eigene Regeln gehen verloren) |

## Grenzen

Wortfilter verändert ausschließlich die lokale Anzeige. Andere Spieler und der Server sehen weiterhin den ursprünglichen Text. Der Filter erreicht FontStrings, sofern ein kompatibler Hook möglich ist, und bestimmte Chatnachrichten über die AddOn-API. Er kann keine Texturen, Bilder, nicht zugängliche Interface-Elemente, geschützte Werte oder alle clientinternen Texte ersetzen. Das Verhalten hängt von der tatsächlichen Forever-Client-API ab. Bei Problemen zunächst /wf scan oder /reload ausprobieren.

Kein Dateisystem-Patch, keine DLL, keine Prozessinjektion und keine Anti-Cheat-Manipulation.

## Tests

Das Projekt enthält tests/smoke.lua und einen GitHub-Actions-Workflow. Der Test prüft Regeln, Hook-Logik, Regeln zur Laufzeit, An/Aus, Pattern-Captures, ungültige Muster, Chatfilter und Editor-Abläufe mit WoW-API-Mocks.

Auf einem System mit Lua 5.4:
    lua tests/smoke.lua

## Entwicklung

Quellcode und Fortschritt: https://github.com/elbannaadvisory/Wortfilter

- Wortfilter/: installierbares AddOn
- tests/: lokale Lua-Tests
- .github/workflows/: CI
- CHANGELOG.md: Änderungen nach Version

Änderungen bevorzugt auf einem Feature-Branch entwickeln und über Pull Requests nach main integrieren. Ohne ausdrückliche Freigabe keine Spieldateien verändern.
