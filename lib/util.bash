#!/bin/bash

function error()
{
    echo -e "\033[1;31m${1}\033[0m" 1>&2
}

function fatal()
{
    error "${1}"
    exit 1
}

function trimString()
{
    echo "${1}" | sed -e 's/^ *//g' -e 's/ *$//g'
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

function checkRequireUser()
{
    local requireUser="${1}"

    if [[ "$(whoami)" != "${requireUser}" ]]
    then
        fatal "ERROR: please run this program as '${requireUser}' user!"
    fi
}

function checkRequireRootUser()
{
    checkRequireUser 'root'
}

function appendToFileIfNotFound()
{
    local file="${1}"
    local pattern="${2}"
    local string="${3}"
    local patternAsRegex="${4}"
    local stringAsRegex="${5}"

    if [[ -f "${file}" ]]
    then
        local grepOption='-Fo'

        if [[ "${patternAsRegex}" = 'true' ]]
        then
            grepOption='-Eo'
        fi

        local found="$(grep "${grepOption}" "${pattern}" "${file}")"

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
        fatal "ERROR: file '${file}' not found!"
    fi
}