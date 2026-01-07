# ZFS Pool Setup - Schnellreferenz

## Schnellstart

### 1. Einfacher Pool mit Cache
```bash
sudo ./setup-zfs-pool.sh -p tank -d /dev/sdb,/dev/sdc,/dev/sdd -c /dev/nvme0n1
```

### 2. Pool mit hoher Redundanz
```bash
sudo ./setup-zfs-pool.sh -p storage -t raidz2 -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf -c /dev/nvme0n1p1
```

### 3. Pool-Status anzeigen
```bash
sudo ./setup-zfs-pool.sh -p tank -s
```

## Wichtige Befehle

### Pool-Management
```bash
# Status anzeigen
zpool status tank

# I/O-Statistiken
zpool iostat tank 5

# Eigenschaften anzeigen
zpool get all tank

# Scrub starten
zpool scrub tank
```

### Filesystem-Management
```bash
# Eigenschaften anzeigen
zfs get all tank

# Snapshot erstellen
zfs snapshot tank@backup-$(date +%Y%m%d)

# Snapshots auflisten
zfs list -t snapshot

# Kompression prüfen
zfs get compression,compressratio tank
```

### Monitoring
```bash
# Verfügbarer Speicher
zfs list

# Detaillierte Informationen
zpool list -v tank

# Cache-Statistiken
cat /proc/spl/kstat/zfs/arcstats
```

## Geräte finden

### Verfügbare Laufwerke anzeigen
```bash
# Alle Blockgeräte
lsblk

# Nach Größe sortiert
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | sort -k2 -h

# NVMe-Laufwerke
ls -l /dev/nvme*

# SATA/SAS-Laufwerke
ls -l /dev/sd*

# Geräte-IDs (empfohlen für Produktion)
ls -l /dev/disk/by-id/
```

### Laufwerk-Informationen
```bash
# SMART-Status
smartctl -a /dev/sdb

# Laufwerksmodell
hdparm -I /dev/sdb | grep "Model Number"

# Seriennummer
lsblk -o NAME,SERIAL
```

## Häufige Szenarien

### NVMe partitionieren für Cache + ZIL
```bash
# Partition für L2ARC (z.B. 100GB)
parted /dev/nvme0n1 mklabel gpt
parted /dev/nvme0n1 mkpart primary 0% 100GB
parted /dev/nvme0n1 mkpart primary 100GB 120GB

# Cache hinzufügen
./setup-zfs-pool.sh -p tank -c /dev/nvme0n1p1 -l /dev/nvme0n1p2
```

### Laufwerk zu Pool hinzufügen
```bash
# Neue Laufwerke hinzufügen
./setup-zfs-pool.sh -p tank -a /dev/sdf,/dev/sdg
```

### Pool erweitern
```bash
# Für RAID-Z: Neue vdev-Gruppe hinzufügen
zpool add tank raidz1 /dev/sdh /dev/sdi /dev/sdj
```

### Defektes Laufwerk ersetzen
```bash
# Laufwerk offline schalten
zpool offline tank /dev/sdb

# Physisch ersetzen, dann:
zpool replace tank /dev/sdb /dev/sdh

# Status überwachen
zpool status -v tank
```

## Performance-Tuning

### Optimierungen für große Dateien
```bash
zfs set recordsize=1M tank
zfs set atime=off tank
zfs set compression=lz4 tank
```

### Optimierungen für viele kleine Dateien
```bash
zfs set recordsize=128K tank
zfs set compression=lz4 tank
zfs set atime=off tank
```

### Optimierungen für Datenbanken
```bash
zfs set recordsize=8K tank/database
zfs set logbias=throughput tank/database
zfs set compression=lz4 tank/database
```

## Snapshot-Management

### Automatische Snapshots
```bash
# Snapshot erstellen
zfs snapshot tank@backup-$(date +%Y%m%d-%H%M)

# Wiederherstellen
zfs rollback tank@backup-20260107-1200

# Snapshot löschen
zfs destroy tank@backup-20260107-1200

# Alle Snapshots anzeigen
zfs list -t snapshot -o name,used,creation
```

### Snapshot-Automatisierung (Cron)
```bash
# /etc/cron.d/zfs-snapshots
0 */6 * * * root zfs snapshot tank@auto-$(date +\%Y\%m\%d-\%H\%M)
0 2 * * 0 root zfs list -t snapshot | grep "tank@auto-" | head -n -10 | awk '{print $1}' | xargs -n1 zfs destroy
```

## Wartung

### Regelmäßige Scrubs
```bash
# Scrub starten
zpool scrub tank

# Scrub-Status
zpool status tank

# Automatischer Scrub (Cron)
# /etc/cron.d/zfs-scrub
0 2 1 * * root zpool scrub tank
```

### Kapazitätsüberwachung
```bash
# Warnung bei 80% Kapazität
zpool list -H -o capacity tank | sed 's/%//' | awk '{if ($1 > 80) print "WARNUNG: Pool ist zu " $1 "% voll"}'
```

## Troubleshooting

### Pool Import/Export
```bash
# Pool exportieren
zpool export tank

# Pools finden
zpool import

# Pool importieren
zpool import tank

# Pool mit anderem Namen importieren
zpool import tank newtank
```

### Fehlerhafte Geräte prüfen
```bash
# Fehler anzeigen
zpool status -v

# Fehler zurücksetzen (nach Behebung)
zpool clear tank

# Detaillierte Fehlerinfo
zpool events -v
```

### Performance-Probleme
```bash
# I/O-Latenz prüfen
zpool iostat -v -l tank 5

# Fragmentierung prüfen
zpool list -o fragmentation tank

# ARC-Statistiken
arc_summary | grep "Hit Rate"

# L2ARC-Statistiken
cat /proc/spl/kstat/zfs/arcstats | grep l2_
```

## Wichtige Hinweise

⚠️ **Vorsicht:**
- Immer Backups haben, bevor Sie Änderungen vornehmen
- Testen Sie Wiederherstellungen regelmäßig
- Überwachen Sie die Pool-Gesundheit
- Halten Sie Reserve-Laufwerke bereit

✅ **Best Practices:**
- Verwenden Sie Geräte-IDs statt /dev/sdX (z.B. /dev/disk/by-id/)
- Aktivieren Sie E-Mail-Benachrichtigungen für ZFS-Events
- Dokumentieren Sie Ihre Pool-Konfiguration
- Führen Sie monatliche Scrubs durch
- Halten Sie 20% freien Speicher für optimale Performance

## Nützliche Aliase

Fügen Sie zu `~/.bashrc` hinzu:
```bash
alias zfs-status='zpool status && zfs list'
alias zfs-io='zpool iostat -v 5'
alias zfs-space='zfs list -o name,used,avail,refer,mountpoint'
alias zfs-snap='zfs list -t snapshot'
alias zfs-scrub='zpool scrub tank && watch -n 60 zpool status'
```

## Performance-Referenzwerte

### Typische Werte für HDD-Pool mit NVMe-Cache:
- **Sequentielles Lesen (ohne Cache):** 200-600 MB/s
- **Sequentielles Lesen (mit L2ARC Cache):** 1000-3000 MB/s
- **Sequentielles Schreiben:** 150-500 MB/s
- **Sequentielles Schreiben (mit ZIL):** 300-1000 MB/s
- **IOPS (mit Cache):** 10K-50K+

### Faktoren für Performance:
- Anzahl der Laufwerke
- RAID-Level
- Laufwerksgeschwindigkeit
- NVMe-Geschwindigkeit
- Recordsize-Einstellung
- Kompression
