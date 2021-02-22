#!/usr/bin/env sh

MAILTO=shawn.mulford@philips.com
echo "[$(date)]; Update GeoIP databases"
/usr/bin/geoipupdate -v
