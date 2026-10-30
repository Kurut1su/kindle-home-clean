#!/bin/sh
# kpm launch home-clean [on|off|toggle|status]
exec sh /var/local/homeclean/homeclean.sh "${1:-toggle}"
