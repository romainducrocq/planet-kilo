#!/usr/bin/env bash

KERNEL_NAME="$(uname -s)"
OS_MACRO="__linux__"
if [[ "${KERNEL_NAME}" == "Darwin"* ]]; then
    OS_MACRO="__APPLE__"
elif [[ "${KERNEL_NAME}" == "FreeBSD"* ]]; then
    OS_MACRO="__FreeBSD__"
fi

planet -v -O3 -E -D${OS_MACRO} -latexit -lsignal kilo.plx
exit ${?}
