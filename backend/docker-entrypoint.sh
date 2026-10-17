#!/bin/sh
set -eu
# Initialize only the configured mounted directory, then drop JVM privileges.
storage_root="$(realpath -m "${DOCUMENTS_STORAGE_ROOT:?DOCUMENTS_STORAGE_ROOT is required}")"
mountpoint -q /var/data || { echo '/var/data must be a persistent mounted volume' >&2; exit 1; }
case "$storage_root" in
  /var/data/*) ;;
  *) echo 'Production storage must be mounted under /var/data' >&2; exit 1 ;;
esac
mkdir -p "$storage_root"
chown blistra:blistra "$storage_root"
chmod 700 "$storage_root"
exec gosu blistra java -jar /app/app.jar
