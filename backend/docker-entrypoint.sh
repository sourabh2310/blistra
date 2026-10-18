#!/bin/sh
set -eu
# Database storage works on stateless/free hosts. Filesystem mode requires a disk.
case "${DOCUMENTS_STORAGE_BACKEND:-postgres}" in
  postgres) ;;
  filesystem)
    storage_root="$(realpath -m "${DOCUMENTS_STORAGE_ROOT:?DOCUMENTS_STORAGE_ROOT is required}")"
    mountpoint -q /var/data || { echo '/var/data must be a persistent mounted volume for filesystem storage' >&2; exit 1; }
    case "$storage_root" in
      /var/data/*) ;;
      *) echo 'Filesystem storage must be mounted under /var/data' >&2; exit 1 ;;
    esac
    mkdir -p "$storage_root"
    chown blistra:blistra "$storage_root"
    chmod 700 "$storage_root"
    ;;
  *) echo 'DOCUMENTS_STORAGE_BACKEND must be postgres or filesystem' >&2; exit 1 ;;
esac
exec gosu blistra java -jar /app/app.jar
