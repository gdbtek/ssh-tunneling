#!/bin/bash

function displayUsage()
{
    local scriptName="$(basename ${0})"

    echo -e "\033[1;33m"
    echo    "SYNOPSIS :"
    echo    "    ${scriptName}"
    echo    "        --help"
    echo    "        --configure"
    echo    "        --local-port <LOCAL_PORT>"
    echo    "        --remote-user <REMOTE_USER>"
    echo    "        --remote-host <REMOTE_HOST>"
    echo    "        --remote-port <REMOTE_PORT>"
    echo -e "\033[1;35m"
    echo    "DESCRIPTION :"
    echo    "    --help           Help page"
    echo    "    --configure      Config remote server to support forwarding (optional)"
    echo    "                     This option will require arguments '--remote-user' and '--remote-host'"
    echo    "    --local-port     Local port number (require)"
    echo    "    --remote-user    Remote user (require)"
    echo    "    --remote-host    Remote host (require)"
    echo    "    --remote-port    Remote port number (require)"
    echo -e "\033[1;36m"
    echo    "EXAMPLES :"
    echo    "    ./${scriptName} --help"
    echo    "    ./${scriptName}"
    echo    "        --configure"
    echo    "        --remote-user 'root'"
    echo    "        --remote-host 'my-server.com'"
    echo    "    ./${scriptName}"
    echo    "        --local-port 8080"
    echo    "        --remote-user 'root'"
    echo    "        --remote-host 'my-server.com'"
    echo    "        --remote-port 9090"
    echo -e "\033[0m"

    exit ${1}
}

function configure()
{
    local remoteUser="${1}"
    local remoteHost="${2}"

    local sshdConfigFile='/etc/ssh/sshd_config'
    local commands="$(cat "${utilPath}")
                    appendToFileIfNotFound "${sshdConfigFile}" '^\s*AllowTcpForwarding\s+yes\s*$' '\nAllowTcpForwarding yes'
                    appendToFileIfNotFound "${sshdConfigFile}" '^\s*GatewayPorts\s+yes\s*$' 'GatewayPorts yes'
                    service ssh restart"

    ssh -n "${remoteUser}@${remoteHost}" "${commands}"
}

function tunnel()
{
    local localPort="${1}"
    local remoteUser="${2}"
    local remoteHost="${3}"
    local remotePort="${4}"

    echo -e "\033[1;35m${remoteHost}:${remotePort} \033[1;36mforwards to \033[1;32mlocalhost:${localPort}\033[0m\n"

    ssh -C -N -g -v \
        -p 22 \
        -c '3des-cbc' \
        -R "${remotePort}:localhost:${localPort}" \
        "${remoteUser}@${remoteHost}"
}

function main()
{
    local appPath="$(cd "$(dirname "${0}")" && pwd)"
    local optCount=${#}
    utilPath="${appPath}/lib/util.bash"

    source "${utilPath}" || exit 1

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --help)
                displayUsage 0
                ;;
            --configure)
                shift

                local configure='true'
                ;;
            --local-port)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local localPort="$(trimString "${1}")"
                fi

                ;;
            --remote-user)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local remoteUser="$(trimString "${1}")"
                fi

                ;;
            --remote-host)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local remoteHost="$(trimString "${1}")"
                fi

                ;;
            --remote-port)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local remotePort="$(trimString "${1}")"
                fi

                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "${configure}" = 'true' ]]
    then
        if [[ "$(isEmptyString "${remoteUser}")" = 'true' || "$(isEmptyString "${remoteHost}")" = 'true' ]]
        then
            error '\nERROR: remoteUser or remoteHost argument not found!'
            displayUsage 1
        fi

        configure "${remoteUser}" "${remoteHost}"
    else
        if [[ "$(isEmptyString "${localPort}")" = 'true' || "$(isEmptyString "${remoteUser}")" = 'true' ||
              "$(isEmptyString "${remoteHost}")" = 'true' || "$(isEmptyString "${remotePort}")" = 'true' ]]
        then
            if [[ ${optCount} -gt 0 ]]
            then
                error '\nERROR: localPort, remoteUser, remoteHost, or remotePort argument not found!'
                displayUsage 1
            fi

            displayUsage 0
        fi

        tunnel "${localPort}" "${remoteUser}" "${remoteHost}" "${remotePort}"
    fi
}

main "${@}"
