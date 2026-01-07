#!/bin/bash

#############################################################################
# ZFS HDD Pool Setup Script with NVMe Cache Integration
# 
# This script automates the creation of a ZFS HDD pool optimized for
# long-term storage of large files (backups, images, videos) with optional
# NVMe cache integration for improved performance.
#
# Features:
# - Creates ZFS pool only if it doesn't already exist
# - Optimizes settings for large files
# - Adds NVMe as L2ARC (read cache)
# - Optional ZIL (write log) support
# - Comprehensive logging and error handling
# - Support for dynamic drive addition
#############################################################################

set -euo pipefail

# Script configuration
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-/var/log/zfs-automation}"
LOG_FILE="${LOG_DIR}/zfs-pool-setup-$(date +%Y%m%d-%H%M%S).log"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/zfs-pool.conf}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration values
POOL_NAME="${POOL_NAME:-tank}"
POOL_TYPE="${POOL_TYPE:-raidz1}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/${POOL_NAME}}"
ENABLE_ZIL="${ENABLE_ZIL:-false}"
ENABLE_COMPRESSION="${ENABLE_COMPRESSION:-true}"
COMPRESSION_ALGORITHM="${COMPRESSION_ALGORITHM:-lz4}"
ENABLE_DEDUP="${ENABLE_DEDUP:-false}"
RECORDSIZE="${RECORDSIZE:-1M}"
ATIME="${ATIME:-off}"

#############################################################################
# Logging Functions
#############################################################################

setup_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}" || {
            echo -e "${RED}Error: Cannot create log directory ${LOG_DIR}${NC}" >&2
            exit 1
        }
    fi
    
    # Start logging
    exec 1> >(tee -a "${LOG_FILE}")
    exec 2>&1
    
    log_info "=== ZFS Pool Setup Started at $(date) ==="
    log_info "Log file: ${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

#############################################################################
# Utility Functions
#############################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_zfs_installed() {
    if ! command -v zpool &> /dev/null; then
        log_error "ZFS is not installed. Please install ZFS utilities first."
        log_info "On Debian/Ubuntu: apt-get install zfsutils-linux"
        exit 1
    fi
    log_success "ZFS utilities are installed"
}

load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_info "Loading configuration from ${CONFIG_FILE}"
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
        log_success "Configuration loaded successfully"
    else
        log_warning "No configuration file found at ${CONFIG_FILE}"
        log_info "Using default configuration values"
    fi
}

validate_device() {
    local device="$1"
    
    if [[ ! -b "${device}" ]]; then
        log_error "Device ${device} is not a valid block device"
        return 1
    fi
    
    # Check if device is already in use
    if zpool status 2>/dev/null | grep -q "${device}"; then
        log_error "Device ${device} is already in use by a ZFS pool"
        return 1
    fi
    
    return 0
}

#############################################################################
# ZFS Pool Functions
#############################################################################

pool_exists() {
    local pool_name="$1"
    zpool list "${pool_name}" &> /dev/null
}

create_zfs_pool() {
    local pool_name="$1"
    shift
    local devices=("$@")
    
    log_info "Creating ZFS pool '${pool_name}' with ${POOL_TYPE} configuration"
    log_info "Devices: ${devices[*]}"
    
    # Validate all devices
    for device in "${devices[@]}"; do
        if ! validate_device "${device}"; then
            log_error "Device validation failed for ${device}"
            return 1
        fi
    done
    
    # Create the pool
    if zpool create -f -m "${MOUNT_POINT}" "${pool_name}" "${POOL_TYPE}" "${devices[@]}"; then
        log_success "ZFS pool '${pool_name}' created successfully"
        return 0
    else
        log_error "Failed to create ZFS pool '${pool_name}'"
        return 1
    fi
}

optimize_pool_for_large_files() {
    local pool_name="$1"
    
    log_info "Optimizing pool '${pool_name}' for large files"
    
    # Set recordsize for large files (1M is optimal for videos, backups, images)
    if zfs set recordsize="${RECORDSIZE}" "${pool_name}"; then
        log_success "Set recordsize to ${RECORDSIZE}"
    else
        log_error "Failed to set recordsize"
        return 1
    fi
    
    # Disable atime for better performance
    if zfs set atime="${ATIME}" "${pool_name}"; then
        log_success "Set atime to ${ATIME}"
    else
        log_warning "Failed to set atime"
    fi
    
    # Enable compression if configured
    if [[ "${ENABLE_COMPRESSION}" == "true" ]]; then
        if zfs set compression="${COMPRESSION_ALGORITHM}" "${pool_name}"; then
            log_success "Enabled compression (${COMPRESSION_ALGORITHM})"
        else
            log_warning "Failed to enable compression"
        fi
    fi
    
    # Handle deduplication (usually not recommended for large files)
    if [[ "${ENABLE_DEDUP}" == "true" ]]; then
        log_warning "Deduplication is enabled - this requires significant RAM"
        if zfs set dedup=on "${pool_name}"; then
            log_success "Enabled deduplication"
        else
            log_error "Failed to enable deduplication"
        fi
    else
        log_info "Deduplication is disabled (recommended for large files)"
    fi
    
    log_success "Pool optimization completed"
    return 0
}

#############################################################################
# NVMe Cache Functions
#############################################################################

add_l2arc_cache() {
    local pool_name="$1"
    local cache_device="$2"
    
    log_info "Adding L2ARC read cache from ${cache_device} to pool '${pool_name}'"
    
    if ! validate_device "${cache_device}"; then
        log_error "Invalid cache device: ${cache_device}"
        return 1
    fi
    
    if zpool add "${pool_name}" cache "${cache_device}"; then
        log_success "L2ARC cache added successfully"
        return 0
    else
        log_error "Failed to add L2ARC cache"
        return 1
    fi
}

add_zil_log() {
    local pool_name="$1"
    local log_device="$2"
    
    log_info "Adding ZIL write log from ${log_device} to pool '${pool_name}'"
    
    if ! validate_device "${log_device}"; then
        log_error "Invalid log device: ${log_device}"
        return 1
    fi
    
    if zpool add "${pool_name}" log "${log_device}"; then
        log_success "ZIL write log added successfully"
        return 0
    else
        log_error "Failed to add ZIL write log"
        return 1
    fi
}

#############################################################################
# Dynamic Drive Management
#############################################################################

add_drives_to_pool() {
    local pool_name="$1"
    shift
    local new_devices=("$@")
    
    log_info "Adding drives to existing pool '${pool_name}'"
    log_info "New devices: ${new_devices[*]}"
    
    # Validate all new devices
    for device in "${new_devices[@]}"; do
        if ! validate_device "${device}"; then
            log_error "Device validation failed for ${device}"
            return 1
        fi
    done
    
    # Add devices to the pool
    if zpool add -f "${pool_name}" "${POOL_TYPE}" "${new_devices[@]}"; then
        log_success "Drives added successfully to pool '${pool_name}'"
        return 0
    else
        log_error "Failed to add drives to pool '${pool_name}'"
        return 1
    fi
}

#############################################################################
# Status and Information Functions
#############################################################################

show_pool_status() {
    local pool_name="$1"
    
    log_info "=== Pool Status for '${pool_name}' ==="
    zpool status "${pool_name}"
    echo ""
    
    log_info "=== Pool Properties ==="
    zfs get all "${pool_name}" | grep -E "(recordsize|compression|atime|dedup|available|used)"
    echo ""
    
    log_info "=== Pool I/O Statistics ==="
    zpool iostat "${pool_name}"
}

#############################################################################
# Main Script Functions
#############################################################################

show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

ZFS HDD Pool Setup Script with NVMe Cache Integration

OPTIONS:
    -h, --help              Show this help message
    -p, --pool NAME         Pool name (default: tank)
    -t, --type TYPE         Pool type: raidz1, raidz2, raidz3, mirror (default: raidz1)
    -d, --devices DEV1,DEV2 Comma-separated list of HDD devices for the pool
    -c, --cache DEVICE      NVMe device for L2ARC read cache
    -l, --log DEVICE        NVMe device for ZIL write log (optional)
    -m, --mount PATH        Mount point (default: /mnt/POOLNAME)
    -a, --add DEV1,DEV2     Add drives to existing pool
    -s, --status            Show pool status and exit
    --config FILE           Configuration file path

EXAMPLES:
    # Create a new pool with 4 HDDs and NVMe cache
    ${SCRIPT_NAME} -p tank -t raidz1 -d /dev/sdb,/dev/sdc,/dev/sdd,/dev/sde -c /dev/nvme0n1

    # Create pool with both L2ARC cache and ZIL log
    ${SCRIPT_NAME} -p tank -d /dev/sdb,/dev/sdc -c /dev/nvme0n1p1 -l /dev/nvme0n1p2

    # Add drives to existing pool
    ${SCRIPT_NAME} -p tank -a /dev/sdf,/dev/sdg

    # Show pool status
    ${SCRIPT_NAME} -p tank -s

CONFIGURATION:
    You can also use a configuration file (zfs-pool.conf) to set options.
    See zfs-pool.conf.example for details.

EOF
}

parse_arguments() {
    local devices_str=""
    local cache_device=""
    local log_device=""
    local add_devices_str=""
    local show_status=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--pool)
                POOL_NAME="$2"
                shift 2
                ;;
            -t|--type)
                POOL_TYPE="$2"
                shift 2
                ;;
            -d|--devices)
                devices_str="$2"
                shift 2
                ;;
            -c|--cache)
                cache_device="$2"
                shift 2
                ;;
            -l|--log)
                log_device="$2"
                ENABLE_ZIL="true"
                shift 2
                ;;
            -m|--mount)
                MOUNT_POINT="$2"
                shift 2
                ;;
            -a|--add)
                add_devices_str="$2"
                shift 2
                ;;
            -s|--status)
                show_status=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Export parsed values
    export PARSED_DEVICES="${devices_str}"
    export PARSED_CACHE_DEVICE="${cache_device}"
    export PARSED_LOG_DEVICE="${log_device}"
    export PARSED_ADD_DEVICES="${add_devices_str}"
    export PARSED_SHOW_STATUS="${show_status}"
}

main() {
    # Initialize
    check_root
    setup_logging
    check_zfs_installed
    load_config
    parse_arguments "$@"
    
    # Show status if requested
    if [[ "${PARSED_SHOW_STATUS}" == "true" ]]; then
        if pool_exists "${POOL_NAME}"; then
            show_pool_status "${POOL_NAME}"
            exit 0
        else
            log_error "Pool '${POOL_NAME}' does not exist"
            exit 1
        fi
    fi
    
    # Handle adding drives to existing pool
    if [[ -n "${PARSED_ADD_DEVICES}" ]]; then
        if ! pool_exists "${POOL_NAME}"; then
            log_error "Pool '${POOL_NAME}' does not exist. Create it first."
            exit 1
        fi
        
        IFS=',' read -ra add_devs <<< "${PARSED_ADD_DEVICES}"
        if add_drives_to_pool "${POOL_NAME}" "${add_devs[@]}"; then
            show_pool_status "${POOL_NAME}"
            log_success "=== Drive addition completed successfully ==="
            exit 0
        else
            log_error "Failed to add drives to pool"
            exit 1
        fi
    fi
    
    # Create new pool if it doesn't exist
    if pool_exists "${POOL_NAME}"; then
        log_warning "Pool '${POOL_NAME}' already exists"
        show_pool_status "${POOL_NAME}"
        
        # Still allow adding cache/log to existing pool
        if [[ -n "${PARSED_CACHE_DEVICE}" ]]; then
            log_info "Attempting to add cache to existing pool"
            add_l2arc_cache "${POOL_NAME}" "${PARSED_CACHE_DEVICE}" || log_warning "Cache addition failed"
        fi
        
        if [[ "${ENABLE_ZIL}" == "true" ]] && [[ -n "${PARSED_LOG_DEVICE}" ]]; then
            log_info "Attempting to add ZIL log to existing pool"
            add_zil_log "${POOL_NAME}" "${PARSED_LOG_DEVICE}" || log_warning "ZIL log addition failed"
        fi
        
        log_info "=== Script completed ==="
        exit 0
    fi
    
    # Validate devices for new pool
    if [[ -z "${PARSED_DEVICES}" ]]; then
        log_error "No devices specified for pool creation"
        log_info "Use -d option to specify devices"
        show_usage
        exit 1
    fi
    
    # Parse device list
    IFS=',' read -ra pool_devs <<< "${PARSED_DEVICES}"
    
    if [[ ${#pool_devs[@]} -eq 0 ]]; then
        log_error "No valid devices provided"
        exit 1
    fi
    
    log_info "Starting ZFS pool creation process"
    log_info "Pool name: ${POOL_NAME}"
    log_info "Pool type: ${POOL_TYPE}"
    log_info "Devices: ${pool_devs[*]}"
    
    # Create the pool
    if ! create_zfs_pool "${POOL_NAME}" "${pool_devs[@]}"; then
        log_error "Pool creation failed"
        exit 1
    fi
    
    # Optimize the pool
    if ! optimize_pool_for_large_files "${POOL_NAME}"; then
        log_warning "Pool optimization had some issues, but pool is created"
    fi
    
    # Add L2ARC cache if specified
    if [[ -n "${PARSED_CACHE_DEVICE}" ]]; then
        if ! add_l2arc_cache "${POOL_NAME}" "${PARSED_CACHE_DEVICE}"; then
            log_warning "Failed to add L2ARC cache, but pool is operational"
        fi
    else
        log_info "No cache device specified, skipping L2ARC setup"
    fi
    
    # Add ZIL log if specified and enabled
    if [[ "${ENABLE_ZIL}" == "true" ]] && [[ -n "${PARSED_LOG_DEVICE}" ]]; then
        if ! add_zil_log "${POOL_NAME}" "${PARSED_LOG_DEVICE}"; then
            log_warning "Failed to add ZIL log, but pool is operational"
        fi
    else
        log_info "ZIL write log not requested, skipping ZIL setup"
    fi
    
    # Show final status
    show_pool_status "${POOL_NAME}"
    
    log_success "=== ZFS pool setup completed successfully ==="
    log_info "Pool '${POOL_NAME}' is ready for use at ${MOUNT_POINT}"
    log_info "Log file: ${LOG_FILE}"
}

# Error handler
handle_error() {
    local line_no=$1
    log_error "Script failed at line ${line_no}"
    log_error "Check log file for details: ${LOG_FILE}"
    exit 1
}

trap 'handle_error ${LINENO}' ERR

# Run main function
main "$@"
