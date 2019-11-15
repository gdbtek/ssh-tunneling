#!/bin/bash -e

function displayUsage()
{
    local -r scriptName="$(basename "${BASH_SOURCE[0]}")"

    echo -e "\033[1;33m"
    echo    "SYNOPSIS :"
    echo    "    ${scriptName}"
    echo    "        --help"
    echo    "        --configure"
    echo    "        --local-port       <LOCAL_PORT>"
    echo    "        --remote-port      <REMOTE_PORT>"
    echo    "        --local-to-remote"
    echo    "        --remote-to-local"
    echo    "        --remote-user      <REMOTE_USER>"
    echo    "        --remote-host      <REMOTE_HOST>"
    echo    "        --identity-file    <IDENTITY_FILE>"
    echo -e "\033[1;35m"
    echo    "DESCRIPTION :"
    echo    "    --help               Help page"
    echo    "    --configure          Config remote server to support forwarding (optional)"
    echo    "                         This option will require arguments '--remote-user' and '--remote-host'"
    echo    "    --local-port         Local port number (require)"
    echo    "    --remote-port        Remote port number (require)"
    echo    "    --local-to-remote    Forward request from local machine to remote machine"
    echo    "                         Either '--local-to-remote' or '--remote-to-local' must be specified"
    echo    "    --remote-to-local    Forward request from remote machine to local machine (require)"
    echo    "                         Either '--local-to-remote' or '--remote-to-local' must be specified"
    echo    "    --remote-user        Remote user (require)"
    echo    "    --remote-host        Remote host (require)"
    echo    "    --identity-file      Path to private key (*.ppk, *.pem) to access remote server (optional)"
    echo -e "\033[1;36m"
    echo    "EXAMPLES :"
    echo    "    ./${scriptName} --help"
    echo
    echo    "    ./${scriptName} --configure --remote-user 'root' --remote-host 'my-server.com'"
    echo    "    ./${scriptName} --configure --remote-user 'root' --remote-host 'my-server.com' --identity-file '/keys/my-server/key.ppk'"
    echo
    echo    "    ./${scriptName} --local-port 8080 --remote-port 9090 --local-to-remote --remote-user 'root' --remote-host 'my-server.com'"
    echo    "    ./${scriptName} --local-port 8080 --remote-port 9090 --local-to-remote --remote-user 'root' --remote-host 'my-server.com' --identity-file '/keys/my-server/key.ppk'"
    echo
    echo    "    ./${scriptName} --local-port 8080 --remote-port 9090 --remote-to-local --remote-user 'root' --remote-host 'my-server.com'"
    echo    "    ./${scriptName} --local-port 8080 --remote-port 9090 --remote-to-local --remote-user 'root' --remote-host 'my-server.com' --identity-file '/keys/my-server/key.ppk'"
    echo -e "\033[0m"

    exit ${1}
}

function getIdentityFileOption()
{
    local identityFile="${1}"

    if [[ "$(isEmptyString "${identityFile}")" = 'false' && -f "${identityFile}" ]]
    then
        echo "-i "${identityFile}""
    else
        echo
    fi
}

function configure()
{
    local remoteUser="${1}"
    local remoteHost="${2}"
    local identityFile="${3}"

    local identityOption=''
    identityOption="$(getIdentityFileOption "${identityFile}")"

    local commands=''
    commands="$(cat "${utilPath}")
                checkRequireRootUser
                appendToFileIfNotFound '${sshdConfigFile}' '${tcpForwardConfigPattern}' '\nAllowTcpForwarding yes' 'true' 'true'
                appendToFileIfNotFound '${sshdConfigFile}' '${gatewayConfigPattern}' 'GatewayPorts yes' 'true' 'true'
                service ssh restart"

    ssh ${identityOption} -n "${remoteUser}@${remoteHost}" "${commands}"
}

function verifyPort()
{
    local port="${1}"
    local mustExist="${2}"
    local remoteUser="${3}"
    local remoteHost="${4}"
    local identityOption="${5}"

    if [[ "$(isEmptyString "${remoteUser}")" = 'true' || "$(isEmptyString "${remoteHost}")" = 'true' ]]
    then
        local isProcessRunning=''
        isProcessRunning="$(isPortOpen "${port}")"

        local machineLocation='local'
    else
        local commands=''
        commands="$(cat "${utilPath}")
                    isPortOpen '${port}'"

        local isProcessRunning=''
        isProcessRunning="$(ssh ${identityOption} -n "${remoteUser}@${remoteHost}" "${commands}")"

        local machineLocation="${remoteHost}"
    fi

    if [[ "${mustExist}" = 'true' && "${isProcessRunning}" = 'false' ]]
    then
        error "\nFATAL :"
        error "    - There is not a process listening to port ${port} on the '${machineLocation}' machine."
        fatal "    - Please make sure your process is listening to the port ${port} before trying to tunnel.\n"
    elif [[ "${mustExist}" = 'false' && "${isProcessRunning}" = 'true' ]]
    then
        error "\nFATAL :"
        error "    - There is a process listening to port ${port} on the '${machineLocation}' machine."
        fatal "    - Please make sure your process is not listening to the port ${port} before trying to tunnel.\n"
    fi
}

function tunnel()
{
    local localPort="${1}"
    local remotePort="${2}"
    local tunnelDirection="${3}"
    local remoteUser="${4}"
    local remoteHost="${5}"
    local identityFile="${6}"

    # Get Identity File Option

    local identityOption=''
    identityOption="$(getIdentityFileOption "${identityFile}")"

    # Verify Ports

    if [[ "${tunnelDirection}" = 'local-to-remote' ]]
    then
        verifyPort "${localPort}" 'false'
        verifyPort "${remotePort}" 'true' "${remoteUser}" "${remoteHost}" "${identityOption}"
    elif [[ "${tunnelDirection}" = 'remote-to-local' ]]
    then
        verifyPort "${localPort}" 'true'
        verifyPort "${remotePort}" 'false' "${remoteUser}" "${remoteHost}" "${identityOption}"
    else
        fatal "\nFATAL : invalid tunnel direction '${tunnelDirection}'"
    fi

    # Verify Remote Config

    local tcpForwardConfigFound=''
    tcpForwardConfigFound="$(ssh ${identityOption} -n "${remoteUser}@${remoteHost}" grep -E -o "'${tcpForwardConfigPattern}'" "'${sshdConfigFile}'")"

    local gatewayConfigFound=''
    gatewayConfigFound="$(ssh ${identityOption} -n "${remoteUser}@${remoteHost}" grep -E -o "'${gatewayConfigPattern}'" "'${sshdConfigFile}'")"

    if [[ "$(isEmptyString "${tcpForwardConfigFound}")" = 'true' || "$(isEmptyString "${gatewayConfigFound}")" = 'true' ]]
    then
       error   "\nWARNING :"
       error   "    - Your remote host '${remoteHost}' is NOT yet configured for tunneling."
       echo -e "    \033[1;31m- Run '\033[1;33m--configure\033[1;31m' to set it up!\033[0m"
       error   "    - Will continue tunneling but it might NOT work for you!"
       sleep 5
    fi

    # Start Forwarding

    if [[ "${tunnelDirection}" = 'local-to-remote' ]]
    then
        doTunnel 'localhost' "${localPort}" "${remoteHost}" "${remotePort}" '-L' "${remoteUser}" "${remoteHost}" "${identityOption}"
    else
        doTunnel "${remoteHost}" "${remotePort}" 'localhost' "${localPort}" '-R' "${remoteUser}" "${remoteHost}" "${identityOption}"
    fi
}

function doTunnel()
{
    local sourceHost="${1}"
    local sourcePort="${2}"
    local destinationHost="${3}"
    local destinationPort="${4}"
    local directionOption="${5}"
    local remoteUser="${6}"
    local remoteHost="${7}"
    local identityOption="${8}"

    echo -e "\n\033[1;35m${sourceHost}:${sourcePort} \033[1;36mforwards to \033[1;32m${destinationHost}:${destinationPort}\033[0m\n"

    ssh -c '3des-cbc' \
        -C \
        -g \
        -N \
        -p 22 \
        -v \
        ${identityOption} \
        "${directionOption}" "${sourcePort}:localhost:${destinationPort}" \
        "${remoteUser}@${remoteHost}"
}

function main()
{
    local appPath=''
    appPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local optCount=${#}
    utilPath="${appPath}/libraries/util.bash"

    source "${utilPath}"

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
                    local localPort=''
                    localPort="$(trimString "${1}")"
                fi

                ;;

            --remote-port)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local remotePort=''
                    remotePort="$(trimString "${1}")"
                fi

                ;;

            --local-to-remote)
                shift

                local tunnelDirection='local-to-remote'
                ;;

            --remote-to-local)
                shift

                local tunnelDirection='remote-to-local'
                ;;

            --remote-user)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local remoteUser=''
                    remoteUser="$(trimString "${1}")"
                fi

                ;;

            --remote-host)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local remoteHost=''
                    remoteHost="$(trimString "${1}")"
                fi

                ;;

            --identity-file)
                shift

                if [[ ${#} -gt 0 ]]
                then
                    local identityFile=''
                    identityFile="$(formatPath "${1}")"
                fi

                ;;

            *)
                shift
                ;;
        esac
    done

    # Global Config

    sshdConfigFile='/etc/ssh/sshd_config'
    tcpForwardConfigPattern='^\s*AllowTcpForwarding\s+yes\s*$'
    gatewayConfigPattern='^\s*GatewayPorts\s+yes\s*$'

    # Validate Identity File Input

    if [[ "$(isEmptyString "${identityFile}")" = 'false' && ! -f "${identityFile}" ]]
    then
        fatal "\nFATAL : identity file '${identityFile}' not found!"
    fi

    # Action

    if [[ "${configure}" = 'true' ]]
    then
        if [[ "$(isEmptyString "${remoteUser}")" = 'true' || "$(isEmptyString "${remoteHost}")" = 'true' ]]
        then
            error '\nERROR : remoteUser or remoteHost argument not found!'
            displayUsage 1
        fi

        configure "${remoteUser}" "${remoteHost}" "${identityFile}"
    else
        if [[ "$(isEmptyString "${localPort}")" = 'true' || "$(isEmptyString "${remotePort}")" = 'true' ||
              "$(isEmptyString "${tunnelDirection}")" = 'true' ||
              "$(isEmptyString "${remoteUser}")" = 'true' || "$(isEmptyString "${remoteHost}")" = 'true' ]]
        then
            if [[ ${optCount} -gt 0 ]]
            then
                error '\nERROR : localPort, remotePort, tunnelDirection, remoteUser, or remoteHost argument not found!'
                displayUsage 1
            fi

            displayUsage 0
        fi

        tunnel "${localPort}" "${remotePort}" "${tunnelDirection}" "${remoteUser}" "${remoteHost}" "${identityFile}"
    fi
}

main "${@}"