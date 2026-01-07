#!/bin/bash

#############################################################################
# Test-Szenarien für ZFS Pool Setup Script
#
# Dieses Skript demonstriert verschiedene Verwendungsszenarien des
# setup-zfs-pool.sh Skripts mit Mock-Geräten für Testzwecke.
#############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/../setup-zfs-pool.sh"

# Farben für Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_scenario() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Szenario: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_command() {
    echo -e "${YELLOW}Befehl:${NC}"
    echo "  $1"
    echo ""
}

print_note() {
    echo -e "${YELLOW}Hinweis:${NC} $1"
    echo ""
}

# Hauptmenü
cat << EOF
${GREEN}ZFS Pool Setup - Test-Szenarien${NC}

Dieses Skript zeigt verschiedene Verwendungsbeispiele.
Die Beispiele verwenden Platzhalter-Geräte - ersetzen Sie diese
mit Ihren tatsächlichen Gerätepfaden.

WICHTIG: Führen Sie diese Befehle NICHT direkt aus, ohne die
Gerätepfade anzupassen! Das könnte zu Datenverlust führen.

EOF

#############################################################################
# Szenario 1: Einfacher RAID-Z1 Pool mit 4 HDDs
#############################################################################
print_scenario "1: Einfacher RAID-Z1 Pool mit 4 HDDs und NVMe-Cache"
print_command "sudo ${MAIN_SCRIPT} \\
  -p tank \\
  -t raidz1 \\
  -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde \\
  -c /dev/nvme0n1"

print_note "Dies erstellt einen RAID-Z1 Pool mit 4 HDDs und nutzt ein komplettes NVMe-Laufwerk als L2ARC Cache."

#############################################################################
# Szenario 2: RAID-Z2 mit höherer Redundanz
#############################################################################
print_scenario "2: RAID-Z2 Pool für kritische Daten"
print_command "sudo ${MAIN_SCRIPT} \\
  -p storage \\
  -t raidz2 \\
  -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf,/dev/sdg \\
  -c /dev/nvme0n1p1 \\
  -m /mnt/storage"

print_note "RAID-Z2 toleriert den Ausfall von 2 Laufwerken gleichzeitig. Ideal für wichtige Daten."

#############################################################################
# Szenario 3: Pool mit L2ARC und ZIL
#############################################################################
print_scenario "3: Pool mit separatem L2ARC Cache und ZIL Write Log"
print_command "# Zuerst NVMe partitionieren:
sudo parted /dev/nvme0n1 mklabel gpt
sudo parted /dev/nvme0n1 mkpart primary 0% 200GB    # L2ARC
sudo parted /dev/nvme0n1 mkpart primary 200GB 100%  # ZIL

# Dann Pool erstellen:
sudo ${MAIN_SCRIPT} \\
  -p media \\
  -t raidz1 \\
  -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde \\
  -c /dev/nvme0n1p1 \\
  -l /dev/nvme0n1p2"

print_note "Separate Partitionen für Cache und Log verbessern Performance bei synchronen Schreibvorgängen."

#############################################################################
# Szenario 4: Mirror Pool für höchste Performance
#############################################################################
print_scenario "4: Mirror Pool für beste Lese-/Schreib-Performance"
print_command "sudo ${MAIN_SCRIPT} \\
  -p fast-storage \\
  -t mirror \\
  -d /dev/sdb,/dev/sdc \\
  -c /dev/nvme0n1"

print_note "Mirror bietet beste Performance, aber nur 50% der Kapazität ist nutzbar."

#############################################################################
# Szenario 5: Laufwerke zu bestehendem Pool hinzufügen
#############################################################################
print_scenario "5: Laufwerke zu bestehendem Pool hinzufügen"
print_command "# Neue vdev-Gruppe zum Pool hinzufügen:
sudo ${MAIN_SCRIPT} \\
  -p tank \\
  -a /dev/sdf,/dev/sdg,/dev/sdh"

print_note "Dies fügt eine neue RAID-Z1 Gruppe zum bestehenden Pool hinzu."

#############################################################################
# Szenario 6: Mit Konfigurationsdatei
#############################################################################
print_scenario "6: Pool-Erstellung mit Konfigurationsdatei"
print_command "# Erstelle Konfigurationsdatei:
cp ${SCRIPT_DIR}/../zfs-pool.conf.example ${SCRIPT_DIR}/../zfs-pool.conf

# Bearbeite die Konfiguration:
nano ${SCRIPT_DIR}/../zfs-pool.conf

# Erstelle Pool mit Konfiguration:
sudo ${MAIN_SCRIPT} \\
  --config ${SCRIPT_DIR}/../zfs-pool.conf \\
  -d /dev/sdb,/dev/sdc,/dev/sdd"

print_note "Konfigurationsdateien sind ideal für wiederholbare Setups."

#############################################################################
# Szenario 7: Pool-Status prüfen
#############################################################################
print_scenario "7: Pool-Status und Informationen anzeigen"
print_command "sudo ${MAIN_SCRIPT} -p tank -s"

print_note "Zeigt detaillierte Informationen über den Pool, inkl. Geräte, Kapazität und I/O-Statistiken."

#############################################################################
# Szenario 8: Geräte-IDs verwenden (Empfohlen für Produktion)
#############################################################################
print_scenario "8: Pool mit Geräte-IDs statt /dev/sdX (Best Practice)"
print_command "# Geräte-IDs finden:
ls -l /dev/disk/by-id/ | grep -v part

# Pool mit Geräte-IDs erstellen:
sudo ${MAIN_SCRIPT} \\
  -p tank \\
  -t raidz1 \\
  -d /dev/disk/by-id/ata-WDC_WD40EFRX-12345,/dev/disk/by-id/ata-WDC_WD40EFRX-67890,/dev/disk/by-id/ata-WDC_WD40EFRX-11111 \\
  -c /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB"

print_note "Geräte-IDs bleiben konstant, auch wenn sich /dev/sdX Namen ändern."

#############################################################################
# Praktische Tipps
#############################################################################
cat << EOF

${GREEN}Praktische Tipps:${NC}

1. ${YELLOW}Geräte identifizieren:${NC}
   lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
   ls -l /dev/disk/by-id/

2. ${YELLOW}Pool-Gesundheit überwachen:${NC}
   zpool status
   zpool iostat -v 5

3. ${YELLOW}Eigenschaften anpassen:${NC}
   zfs set compression=lz4 tank
   zfs set recordsize=1M tank
   zfs set atime=off tank

4. ${YELLOW}Snapshots erstellen:${NC}
   zfs snapshot tank@backup-\$(date +%Y%m%d)
   zfs list -t snapshot

5. ${YELLOW}Scrub durchführen:${NC}
   zpool scrub tank
   watch -n 60 zpool status

6. ${YELLOW}Cache-Statistiken:${NC}
   cat /proc/spl/kstat/zfs/arcstats | grep l2
   arc_summary

${YELLOW}WARNUNG:${NC}
- Ersetzen Sie alle Gerätepfade mit Ihren tatsächlichen Geräten
- Überprüfen Sie, dass die Geräte nicht bereits verwendet werden
- Stellen Sie sicher, dass alle Daten gesichert sind
- Testen Sie zuerst in einer Test-Umgebung

Weitere Informationen: ${SCRIPT_DIR}/../README.md

EOF
