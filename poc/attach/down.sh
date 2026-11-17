#!/bin/sh
cd "$(dirname "$0")"
[ -f run/qemu.pid ] && kill "$(cat run/qemu.pid)" && rm -f run/qemu.pid
