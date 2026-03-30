#!/bin/bash
# Snapshot: Common helpers

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

step() { echo -e "\n${BLUE}[SCAN]${NC} ${BOLD}$1${NC}"; }
ok() { echo -e "${GREEN}  [OK]${NC} $1"; }
warn() { echo -e "${YELLOW}  [SKIP]${NC} $1"; }
info() { echo -e "${CYAN}  ->  ${NC} $1"; }
