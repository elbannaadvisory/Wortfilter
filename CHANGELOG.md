# Changelog

## 0.3.0 – Attacken- und Zaubertexte (Feature-Branch)

- Das Regel-Editor-Fenster zeigt als oberste Titelzeile exakt „Jemand könnte sagen “; zusätzlicher UI-Regressionstest.

- Moderne TooltipDataProcessor.AddTooltipPostCall-Hooks für Zauber, Auren und unterstützte Tooltip-Typen.
- Sichtbare Inhalte von Zauberbuch, Aktionsleisten, Pet-Leisten und Zauberbalken werden über die bestehenden Regeln gefiltert.
- Wiederverwendete Tooltip-Zeilen erkennen neue Originaltexte.
- Keine Änderung an Zauber-IDs, Makros, Casting oder Serverdaten.
- Acht neue getrennte Regressionstests. Prüfung im echten Client steht noch aus.


## 0.2.0 – 2026-11-18

- Projekt und AddOn von OttFilter in **Wortfilter** umbenannt.
- Ingame-Regel-Editor (/wf, /wort, /wortfilter) mit Anlegen, Bearbeiten, Löschen, Aktivieren und Sortieren.
- Wörtliche Suche und Lua-Pattern-Modus inklusive Capture-Ersetzungen.
- Live-Vorschau, Validierung, Default-Wiederherstellung und persistente SavedVariables.
- UI-Hooks merken ursprüngliche Texte und können bei Regeländerungen neu filtern.
- Weiterhin lokales FontString-/Chat-Filtering ohne Dateipatches.
- Standalone-Smoke-Tests und GitHub-Actions-Workflow hinzugefügt.

## 0.1.0 – 2026-11-18

- Ursprünglicher OttFilter mit den fest definierten Gott-/Gött-Regeln.
