# Beiträge zum Projekt

Vielen Dank für Ihr Interesse am proxmox-automation Projekt! Wir freuen uns über Beiträge.

## Wie kann ich beitragen?

### Fehler melden

Wenn Sie einen Fehler gefunden haben:
1. Überprüfen Sie, ob der Fehler bereits gemeldet wurde
2. Erstellen Sie ein neues Issue mit:
   - Beschreibung des Problems
   - Schritte zur Reproduktion
   - Erwartetes vs. tatsächliches Verhalten
   - Log-Dateien aus `/var/log/zfs-automation/`
   - Systeminformationen (OS-Version, ZFS-Version)

### Feature-Vorschläge

Für neue Features:
1. Öffnen Sie ein Issue zur Diskussion
2. Beschreiben Sie den Anwendungsfall
3. Erklären Sie, wie das Feature helfen würde
4. Berücksichtigen Sie Rückwärtskompatibilität

### Code-Beiträge

1. **Fork das Repository**
2. **Erstellen Sie einen Feature-Branch**
   ```bash
   git checkout -b feature/mein-neues-feature
   ```

3. **Entwickeln Sie Ihr Feature**
   - Folgen Sie den Coding-Standards (siehe unten)
   - Fügen Sie Dokumentation hinzu
   - Testen Sie gründlich

4. **Commiten Sie Ihre Änderungen**
   ```bash
   git commit -m "Feature: Beschreibung des Features"
   ```

5. **Pushen Sie zum Branch**
   ```bash
   git push origin feature/mein-neues-feature
   ```

6. **Erstellen Sie einen Pull Request**

## Coding-Standards

### Bash-Skript-Standards

1. **Shebang und Set-Optionen**
   ```bash
   #!/bin/bash
   set -euo pipefail
   ```

2. **Variablen**
   - GROSS_BUCHSTABEN für Konstanten und Umgebungsvariablen
   - klein_buchstaben für lokale Variablen
   - Immer in Anführungszeichen setzen: `"${variable}"`

3. **Funktionen**
   ```bash
   function_name() {
       local param="$1"
       # Code hier
       return 0
   }
   ```

4. **Fehlerbehandlung**
   - Prüfen Sie Rückgabewerte
   - Verwenden Sie aussagekräftige Fehlermeldungen
   - Loggen Sie alle wichtigen Operationen

5. **Kommentare**
   - Kommentieren Sie komplexe Logik
   - Fügen Sie Funktionsheader hinzu
   - Erklären Sie das "Warum", nicht das "Was"

### ShellCheck

Alle Bash-Skripte müssen ShellCheck-konform sein:
```bash
shellcheck -x setup-zfs-pool.sh
```

### Dokumentation

- Dokumentieren Sie neue Funktionen in README.md
- Aktualisieren Sie QUICKSTART.md bei Bedarf
- Fügen Sie Beispiele zu examples/test-scenarios.sh hinzu
- Deutsche Sprache für Dokumentation

## Testing

### Manuelle Tests

Vor dem Einreichen eines PR:

1. **Syntax-Prüfung**
   ```bash
   bash -n setup-zfs-pool.sh
   ```

2. **ShellCheck**
   ```bash
   shellcheck -x setup-zfs-pool.sh
   ```

3. **Funktionale Tests**
   - Testen Sie in einer sicheren Umgebung
   - Testen Sie verschiedene Szenarien
   - Überprüfen Sie Log-Dateien

4. **Edge Cases**
   - Ungültige Eingaben
   - Fehlende Geräte
   - Existierende Pools
   - Fehlerhafte Konfiguration

### Test-Checkliste

- [ ] Skript läuft ohne Fehler
- [ ] Logging funktioniert korrekt
- [ ] Fehlerbehandlung funktioniert
- [ ] Dokumentation ist aktualisiert
- [ ] Beispiele sind hinzugefügt
- [ ] ShellCheck ist sauber
- [ ] Keine Breaking Changes (oder dokumentiert)

## Versionierung

Wir verwenden [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking Changes
- **MINOR**: Neue Features (rückwärtskompatibel)
- **PATCH**: Bugfixes

## Commit-Nachrichten

Gute Commit-Nachrichten folgen diesem Format:

```
Type: Kurze Beschreibung (max 50 Zeichen)

Längere Erklärung falls nötig (max 72 Zeichen pro Zeile).
Erklären Sie das Problem, das gelöst wird, nicht den Code.

- Bullet points sind okay
- Verwenden Sie Imperativ ("Add feature" nicht "Added feature")
```

**Types:**
- `Feature:` - Neues Feature
- `Fix:` - Bugfix
- `Docs:` - Dokumentationsänderungen
- `Style:` - Code-Formatierung
- `Refactor:` - Code-Umstrukturierung
- `Test:` - Test-Änderungen
- `Chore:` - Wartungsarbeiten

## Code Review

Alle Pull Requests werden überprüft auf:

1. **Funktionalität**: Löst der Code das Problem?
2. **Code-Qualität**: Ist der Code lesbar und wartbar?
3. **Tests**: Sind Tests vorhanden und bestehen sie?
4. **Dokumentation**: Ist die Dokumentation aktualisiert?
5. **Sicherheit**: Gibt es Sicherheitsprobleme?
6. **Performance**: Gibt es Performance-Probleme?

## Lizenz

Durch Ihre Beiträge stimmen Sie zu, dass Ihr Code unter der gleichen Lizenz wie das Projekt veröffentlicht wird.

## Fragen?

Bei Fragen:
- Öffnen Sie ein Issue
- Markieren Sie es mit dem Label "question"
- Wir helfen gerne weiter!

## Vielen Dank!

Jeder Beitrag, ob groß oder klein, wird geschätzt. Danke, dass Sie dieses Projekt besser machen!
