# proxmox-automation
Automatisiertes ZFS-Setup für HDD-Pools und NVMe-Cache in Proxmox.

## Überblick

Dieses Repository enthält ein Bash-Skript zur Automatisierung der Einrichtung von ZFS-HDD-Pools mit NVMe-Cache-Integration in Proxmox-Umgebungen. Das Skript ist optimiert für die langfristige Speicherung großer Dateien wie Backups, Bilder und Videos.

## Features

- ✅ **Automatische Pool-Erstellung**: Erstellt ZFS-Pools mit Überprüfung auf Existenz
- ✅ **NVMe-Cache-Integration**: Unterstützt L2ARC (Lese-Cache) und optionales ZIL (Schreib-Log)
- ✅ **Optimierung für große Dateien**: Vorkonfigurierte Einstellungen für Backups, Videos und Bilder
- ✅ **Umfassendes Logging**: Detaillierte Protokollierung aller Operationen
- ✅ **Robuste Fehlerbehandlung**: Validierung und Fehlerbehandlung in jedem Schritt
- ✅ **Dynamische Laufwerksverwaltung**: Einfaches Hinzufügen neuer Laufwerke und Workloads
- ✅ **Flexible Konfiguration**: Unterstützung für Konfigurationsdateien und Kommandozeilenparameter

## Systemanforderungen

- Proxmox VE oder Linux-System mit ZFS-Unterstützung
- Root-Berechtigung
- ZFS-Utilities (`zfsutils-linux` auf Debian/Ubuntu)
- Bash 4.0 oder höher

## Installation

1. Repository klonen:
```bash
git clone https://github.com/gunnar-enke/proxmox-automation.git
cd proxmox-automation
```

2. Skript ausführbar machen:
```bash
chmod +x setup-zfs-pool.sh
```

3. (Optional) Konfigurationsdatei erstellen:
```bash
cp zfs-pool.conf.example zfs-pool.conf
# Konfigurationsdatei nach Bedarf anpassen
nano zfs-pool.conf
```

## Verwendung

### Grundlegende Syntax

```bash
./setup-zfs-pool.sh [OPTIONEN]
```

### Optionen

- `-h, --help` - Hilfe anzeigen
- `-p, --pool NAME` - Pool-Name (Standard: tank)
- `-t, --type TYPE` - Pool-Typ: raidz1, raidz2, raidz3, mirror (Standard: raidz1)
- `-d, --devices DEV1,DEV2` - Komma-getrennte Liste der HDD-Geräte
- `-c, --cache DEVICE` - NVMe-Gerät für L2ARC-Lese-Cache
- `-l, --log DEVICE` - NVMe-Gerät für ZIL-Schreib-Log (optional)
- `-m, --mount PATH` - Mount-Point (Standard: /mnt/POOLNAME)
- `-a, --add DEV1,DEV2` - Laufwerke zu bestehendem Pool hinzufügen
- `-s, --status` - Pool-Status anzeigen und beenden
- `--config FILE` - Pfad zur Konfigurationsdatei

### Beispiele

#### Beispiel 1: Neuen Pool mit 4 HDDs und NVMe-Cache erstellen

```bash
sudo ./setup-zfs-pool.sh \
  -p tank \
  -t raidz1 \
  -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde \
  -c /dev/nvme0n1
```

#### Beispiel 2: Pool mit L2ARC-Cache und ZIL-Log

```bash
sudo ./setup-zfs-pool.sh \
  -p storage \
  -t raidz2 \
  -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf,/dev/sdg \
  -c /dev/nvme0n1p1 \
  -l /dev/nvme0n1p2
```

#### Beispiel 3: Mirror-Pool mit zwei Laufwerken

```bash
sudo ./setup-zfs-pool.sh \
  -p mirror-tank \
  -t mirror \
  -d /dev/sdb,/dev/sdc \
  -c /dev/nvme0n1
```

#### Beispiel 4: Laufwerke zu bestehendem Pool hinzufügen

```bash
sudo ./setup-zfs-pool.sh \
  -p tank \
  -a /dev/sdf,/dev/sdg
```

#### Beispiel 5: Pool-Status anzeigen

```bash
sudo ./setup-zfs-pool.sh -p tank -s
```

## Pool-Typen

### RAID-Z1 (Standard)
- **Redundanz**: 1 Laufwerk kann ausfallen
- **Mindestanzahl**: 3 Laufwerke
- **Empfohlen für**: Allgemeine Verwendung, gute Balance zwischen Kapazität und Sicherheit

### RAID-Z2
- **Redundanz**: 2 Laufwerke können ausfallen
- **Mindestanzahl**: 4 Laufwerke
- **Empfohlen für**: Wichtige Daten, größere Arrays

### RAID-Z3
- **Redundanz**: 3 Laufwerke können ausfallen
- **Mindestanzahl**: 5 Laufwerke
- **Empfohlen für**: Kritische Daten, sehr große Arrays

### Mirror
- **Redundanz**: Halbe Kapazität nutzbar
- **Mindestanzahl**: 2 Laufwerke (paarweise)
- **Empfohlen für**: Beste Performance, kleinere Pools

## NVMe-Cache

### L2ARC (Lese-Cache)
Der L2ARC erweitert den ARC (Adaptive Replacement Cache) im RAM und speichert häufig gelesene Daten auf dem schnellen NVMe-Laufwerk.

**Vorteile:**
- Verbessert Lese-Performance bei wiederholten Zugriffen
- Reduziert Latenz für häufig genutzte Dateien
- Keine Datenintegritätsprobleme bei Ausfall

### ZIL (Write Log)
Das ZFS Intent Log (ZIL) beschleunigt synchrone Schreibvorgänge.

**Vorteile:**
- Verbessert synchrone Schreib-Performance
- Wichtig für NFS-Server und Datenbanken
- Schützt Daten bei Stromausfall

**Hinweis:** ZIL sollte nur aktiviert werden, wenn:
- Sie synchrone Schreibvorgänge verwenden
- Ein dediziertes NVMe-Gerät verfügbar ist
- Hohe Schreib-Performance erforderlich ist

## Konfigurationsdatei

Die Konfigurationsdatei `zfs-pool.conf` ermöglicht die dauerhafte Speicherung von Einstellungen:

```bash
# Kopieren Sie die Beispieldatei
cp zfs-pool.conf.example zfs-pool.conf

# Bearbeiten Sie die Einstellungen
nano zfs-pool.conf
```

Wichtige Konfigurationsparameter:

- `POOL_NAME`: Name des Pools
- `POOL_TYPE`: RAID-Typ (raidz1, raidz2, raidz3, mirror)
- `RECORDSIZE`: Blockgröße (1M für große Dateien empfohlen)
- `ENABLE_COMPRESSION`: Kompression aktivieren (empfohlen: true)
- `COMPRESSION_ALGORITHM`: Kompressionsalgorithmus (lz4 empfohlen)
- `ENABLE_DEDUP`: Deduplizierung (normalerweise false)
- `ENABLE_ZIL`: ZIL Write-Log aktivieren

## Optimierungen für große Dateien

Das Skript optimiert den Pool automatisch für große Dateien:

1. **Recordsize: 1M** - Optimal für Videos, Backups und Bilder
2. **Atime: off** - Verbessert Performance durch Deaktivierung der Access-Time-Updates
3. **Compression: lz4** - Schnelle Kompression mit geringem CPU-Overhead
4. **Dedup: off** - Deduplizierung deaktiviert (spart RAM)

## Logging

Alle Operationen werden protokolliert in:
```
/var/log/zfs-automation/zfs-pool-setup-YYYYMMDD-HHMMSS.log
```

Das Log enthält:
- Zeitstempel für jede Operation
- Erfolgs- und Fehlermeldungen
- Detaillierte Informationen über Pool-Konfiguration
- Warnungen und Hinweise

## Fehlerbehandlung

Das Skript implementiert robuste Fehlerbehandlung:

- ✅ Validierung aller Geräte vor Verwendung
- ✅ Überprüfung auf existierende Pools
- ✅ Prüfung ob Geräte bereits in Verwendung sind
- ✅ Detaillierte Fehlermeldungen mit Zeilennummern
- ✅ Fortsetzung bei nicht-kritischen Fehlern
- ✅ Automatisches Logging aller Fehler

## Best Practices

### Pool-Erstellung
1. Verwenden Sie gleich große Laufwerke für beste Effizienz
2. Nutzen Sie RAID-Z2 für wichtige Daten
3. Aktivieren Sie Kompression (lz4)
4. Deaktivieren Sie Deduplizierung (außer bei bekannt duplizierten Daten)

### NVMe-Cache
1. Verwenden Sie mindestens 10% der Pool-Größe für L2ARC
2. Partitionieren Sie NVMe für separate L2ARC und ZIL
3. Verwenden Sie ZIL nur wenn nötig
4. Überwachen Sie Cache-Statistiken regelmäßig

### Wartung
1. Führen Sie regelmäßige Scrubs durch (monatlich)
2. Überwachen Sie Pool-Status und -Kapazität
3. Sichern Sie wichtige Daten extern
4. Testen Sie die Wiederherstellung

## Fehlerbehebung

### "Device is not a valid block device"
**Problem:** Das angegebene Gerät existiert nicht oder ist kein Blockgerät.

**Lösung:**
```bash
# Liste verfügbare Geräte
lsblk

# Überprüfen Sie die Gerätepfade
ls -l /dev/sd* /dev/nvme*
```

### "Device is already in use by a ZFS pool"
**Problem:** Das Gerät wird bereits von einem ZFS-Pool verwendet.

**Lösung:**
```bash
# Überprüfen Sie den Pool-Status
zpool status

# Falls nötig, entfernen Sie das Gerät vom alten Pool
zpool remove <pool-name> <device>
```

### "Pool already exists"
**Problem:** Ein Pool mit diesem Namen existiert bereits.

**Lösung:**
- Verwenden Sie einen anderen Pool-Namen mit `-p`
- Fügen Sie Laufwerke zum bestehenden Pool hinzu mit `-a`
- Zeigen Sie den Status des bestehenden Pools mit `-s`

### "ZFS is not installed"
**Problem:** ZFS-Utilities sind nicht installiert.

**Lösung:**
```bash
# Auf Debian/Ubuntu
apt-get update
apt-get install zfsutils-linux

# Auf Proxmox (normalerweise bereits installiert)
apt-get install zfsutils-linux
```

## Performance-Überwachung

### Pool-Status prüfen
```bash
zpool status tank
```

### I/O-Statistiken anzeigen
```bash
zpool iostat -v tank 5
```

### Cache-Statistiken
```bash
# L2ARC-Statistiken
cat /proc/spl/kstat/zfs/arcstats | grep l2

# ARC-Zusammenfassung
arc_summary
```

### Pool-Eigenschaften anzeigen
```bash
zfs get all tank
```

## Sicherheit

Das Skript implementiert mehrere Sicherheitsmaßnahmen:

- ✅ Root-Berechtigung erforderlich
- ✅ Validierung aller Eingaben
- ✅ Überprüfung von Geräteverfügbarkeit
- ✅ Fehlerbehandlung mit trap
- ✅ Logging aller Operationen
- ✅ Keine automatische Löschung von Daten

## Lizenz

Dieses Projekt ist als Open Source verfügbar. Weitere Informationen finden Sie in der LICENSE-Datei.

## Beiträge

Beiträge sind willkommen! Bitte erstellen Sie einen Pull Request oder öffnen Sie ein Issue für Verbesserungsvorschläge.

## Support

Bei Fragen oder Problemen:
1. Überprüfen Sie die Dokumentation
2. Prüfen Sie die Log-Dateien unter `/var/log/zfs-automation/`
3. Öffnen Sie ein Issue auf GitHub

## Weitere Ressourcen

- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Proxmox ZFS Documentation](https://pve.proxmox.com/wiki/ZFS_on_Linux)
- [ZFS Best Practices](https://pthree.org/2012/12/04/zfs-administration-part-i-vdevs/)
