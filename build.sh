#!/usr/bin/env bash

KERNEL_NAME="$(uname -s)"
if [[ "${KERNEL_NAME}" == "Darwin"* ]]; then
    KERNEL_NAME="__APPLE__"
elif [[ "${KERNEL_NAME}" == "FreeBSD"* ]]; then
    KERNEL_NAME="__FreeBSD__"
else
    KERNEL_NAME="__linux__"
fi

planet -v -O3 -E -D${KERNEL_NAME} -latexit -lsignal kilo.plx
exit ${?}
