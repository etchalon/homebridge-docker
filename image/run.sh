#!/bin/bash

cd /root/.homebridge

env_file="/root/.homebridge/.env"
install_file="/root/.homebridge/install.sh"
package_file="/root/.homebridge/package.json"
plugin_folder="/root/.homebridge/plugins"

# Include environment variables
# -------------------------------------------------------------------------
# See https://github.com/marcoraddatz/homebridge-docker#env-options
if [ -f "$env_file" ]
then
    echo "Including environment variables from $env_file."

    source $env_file

    echo "Environment is set to '$HOMEBRIDGE_ENV'."
else
    echo "$env_file not found."
    echo "Default env variables will be used."
fi

# (Re-) Install specific Homebridge version to avoid incompatible updates
# with either Homebridge or iOS.
# -------------------------------------------------------------------------
# See https://github.com/marcoraddatz/homebridge-docker#homebridge_version
if [ "$HOMEBRIDGE_VERSION" ]
then
    echo "Force the installation of Homebridge version '$HOMEBRIDGE_VERSION'."

    yarn global add "homebridge@${HOMEBRIDGE_VERSION}"
fi

# Install plugins via package.json
if [ -f "$package_file" ]
then
    echo "Installing plugins from $package_file."

    npm install
else
    echo "$package_file not found."
fi

# Install plugins via install.sh
if [ -f "$install_file" ]
then
    echo "Installing plugins from $install_file."

    /bin/bash $install_file
else
    echo "$install_file not found."
fi

# Manually set timezone
if [ "$HOMEBRIDGE_TIMEZONE" ]
then
    rm /etc/localtime
    ln -s /usr/share/zoneinfo/${HOMEBRIDGE_TIMEZONE} /etc/localtime
    date

    echo "Updated timezone to '$HOMEBRIDGE_TIMEZONE'.".
fi

# Fix for Synology DSM
# See https://github.com/oznu/docker-homebridge/commit/8e5ef5e7b3480b50f59dc3717f493d27f4070df1
# See https://github.com/oznu/docker-homebridge/issues/35
if [ "$DS_HOSTNAME" ]
then
    sed -i "s/.*host-name.*/host-name=${DS_HOSTNAME}/" /etc/avahi/avahi-daemon.conf

    echo "Avahi hostname set to '$DS_HOSTNAME'."
fi

rm -f /var/run/dbus/pid /var/run/avahi-daemon/pid

dbus-daemon --system
avahi-daemon -D

# Start Homebridge
if [ "$HOMEBRIDGE_ENV" ]
then
    case "$HOMEBRIDGE_ENV" in
        "debug-insecure" )
            DEBUG=* homebridge -I -D -P $plugin_folder ;;
        "development-insecure" )
            homebridge -I -P $plugin_folder ;;
        "production-insecure" )
            homebridge -I ;;
        "debug" )
            DEBUG=* homebridge -D -P $plugin_folder ;;
        "development" )
            homebridge -P $plugin_folder ;;
        "production" )
            homebridge ;;
    esac
else
    homebridge
fi
