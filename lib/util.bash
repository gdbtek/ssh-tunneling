#!/bin/bash -e

########################
# FILE LOCAL UTILITIES #
########################

function appendToFileIfNotFound()
{
    local file="${1}"
    local pattern="${2}"
    local string="${3}"
    local patternAsRegex="${4}"
    local stringAsRegex="${5}"

    if [[ -f "${file}" ]]
    then
        local grepOption='-o -F'

        if [[ "${patternAsRegex}" = 'true' ]]
        then
            grepOption='-o -E'
        fi

        local found="$(grep ${grepOption} "${pattern}" "${file}")"

        if [[ "$(isEmptyString "${found}")" = 'true' ]]
        then
            if [[ "${stringAsRegex}" = 'true' ]]
            then
                echo -e "${string}" >> "${file}"
            else
                echo >> "${file}"
                echo "${string}" >> "${file}"
            fi
        fi
    else
        fatal "FATAL: file '${file}' not found!"
    fi
}

####################
# STRING UTILITIES #
####################

function error()
{
    echo -e "\033[1;31m${1}\033[0m" 1>&2
}

function fatal()
{
    error "${1}"
    exit 1
}

function formatPath()
{
    local string="${1}"

    while [[ "$(echo "${string}" | grep -F '//')" != '' ]]
    do
        string="$(echo "${string}" | sed -e 's/\/\/*/\//g')"
    done

    echo "${string}" | sed -e 's/\/$//g'
}

function isEmptyString()
{
    if [[ "$(trimString ${1})" = '' ]]
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function trimString()
{
    echo "${1}" | sed -e 's/^ *//g' -e 's/ *$//g'
}

####################
# SYSTEM UTILITIES #
####################

function checkRequireRootUser()
{
    checkRequireUser 'root'
}

function checkRequireUser()
{
    local user="${1}"

    if [[ "$(whoami)" != "${user}" ]]
    then
        fatal "\nFATAL: please run this program as '${user}' user!"
    fi
}

function isLinuxOperatingSystem()
{
    isOperatingSystem 'Linux'
}

function isMacOperatingSystem()
{
    isOperatingSystem 'Darwin'
}

function isOperatingSystem()
{
    local operatingSystem="${1}"

    local found="$(uname -s | grep -i -o -E "^${operatingSystem}$")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isPortOpen()
{
    local port="${1}"

    if [[ "$(isEmptyString "${port}")" = 'true' ]]
    then
        fatal "\nFATAL: port undefined"
    fi

    if [[ "$(isLinuxOperatingSystem)" = 'true' ]]
    then
        local process="$(netstat -l -n -t -u | grep -E ":${port}\s+" | head -1)"
    elif [[ "$(isMacOperatingSystem)" = 'true' ]]
    then
        local process="$(lsof -i -n -P | grep -i -E ":${port}\s+\(LISTEN\)$" | head -1)"
    else
        fatal "\nFATAL: operating system not supported"
    fi

    if [[ "$(isEmptyString "${process}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}
