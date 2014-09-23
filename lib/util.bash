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
    local addNewLine="${6}"

    # Validate Inputs

    checkExistFile "${file}"
    checkNonEmptyString "${pattern}" 'undefined pattern'
    checkNonEmptyString "${string}" 'undefined string'
    checkTrueFalseString "${patternAsRegex}"
    checkTrueFalseString "${stringAsRegex}"

    if [[ "${stringAsRegex}" = 'false' ]]
    then
        checkTrueFalseString "${addNewLine}"
    fi

    # Append String

    local grepOption='-F -o'

    if [[ "${patternAsRegex}" = 'true' ]]
    then
        grepOption='-E -o'
    fi

    local found="$(grep ${grepOption} "${pattern}" "${file}")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        if [[ "${stringAsRegex}" = 'true' ]]
        then
            echo -e "${string}" >> "${file}"
        else
            if [[ "${addNewLine}" = 'true' ]]
            then
                echo >> "${file}"
            fi

            echo "${string}" >> "${file}"
        fi
    fi
}

####################
# STRING UTILITIES #
####################

function checkNonEmptyString()
{
    local string="${1}"
    local errorMessage="${2}"

    if [[ "$(isEmptyString "${string}")" = 'true' ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal "\nFATAL : empty value detected"
        else
            fatal "\nFATAL : ${errorMessage}"
        fi
    fi
}

function checkTrueFalseString()
{
    local string="${1}"

    if [[ "${string}" != 'true' && "${string}" != 'false' ]]
    then
        fatal "\nFATAL : '${string}' is not 'true' or 'false'"
    fi
}

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
    local path="${1}"

    while [[ "$(echo "${path}" | grep -F '//')" != '' ]]
    do
        path="$(echo "${path}" | sed -e 's/\/\/*/\//g')"
    done

    echo "${path}" | sed -e 's/\/$//g'
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

function checkExistFile()
{
    local file="${1}"
    local errorMessage="${2}"

    if [[ "${file}" = '' || ! -f "${file}" ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal "\nFATAL : file '${file}' not found"
        else
            fatal "\nFATAL : ${errorMessage}"
        fi
    fi
}

function checkRequireRootUser()
{
    checkRequireUserLogin 'root'
}

function checkRequireUserLogin()
{
    local userLogin="${1}"

    if [[ "$(whoami)" != "${userLogin}" ]]
    then
        fatal "\nFATAL : user login '${userLogin}' required"
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

    local found="$(uname -s | grep -E -i -o "^${operatingSystem}$")"

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

    checkNonEmptyString "${port}" 'undefined port'

    if [[ "$(isLinuxOperatingSystem)" = 'true' ]]
    then
        local process="$(netstat -l -n -t -u | grep -E ":${port}\s+" | head -1)"
    elif [[ "$(isMacOperatingSystem)" = 'true' ]]
    then
        local process="$(lsof -i -n -P | grep -E -i ":${port}\s+\(LISTEN\)$" | head -1)"
    else
        fatal "\nFATAL : operating system not supported"
    fi

    if [[ "$(isEmptyString "${process}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}