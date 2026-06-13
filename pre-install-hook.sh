#!/bin/sh
# Runs after entrypoint rsync, before Nextcloud install attempt.
# Fixes config dir ownership for www-data (uid 82 on Alpine) and
# pre-creates config.php to disable the data dir permission check
# (macOS bind mounts do not support chmod from inside containers).
chown -R 82:82 /var/www/html/config
chmod 750 /var/www/html/config

cat > /var/www/html/config/config.php <<'EOF'
<?php
$CONFIG = [
  'check_data_directory_permissions' => false,
];
EOF
chown 82:82 /var/www/html/config/config.php
chmod 640 /var/www/html/config/config.php
