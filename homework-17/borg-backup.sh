#!/bin/sh

# the repo and it's passphrase
export BORG_REPO=ssh://borg@server/var/backup/client
export BORG_PASSPHRASE='verylongandsecure'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup"

# backup the directories
borg create \
  --verbose --filter AME \
  --list --stats --show-rc \
  --compression zlib,5 --exclude-caches \
  ::'{hostname}-daily-{now}' \
  /etc 2>&1

backup_exit=$?

info "Pruning repository"

# prune the repo
borg prune \
    --list \
    --prefix '{hostname}-daily-' \
    --show-rc \
    --keep-daily 90 \
    --keep-monthly 12 2>&1

prune_exit=$?

# use highest exit code as exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 1 ];
then
    info "Backup and/or Prune finished with a warning"
fi

if [ ${global_exit} -gt 1 ];
then
    info "Backup and/or Prune finished with an error"
fi

exit ${global_exit}
