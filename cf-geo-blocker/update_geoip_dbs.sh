#!/usr/bin/env sh

echo "[$(date)]; Update GeoIP databases"
/usr/bin/geoipupdate -v
