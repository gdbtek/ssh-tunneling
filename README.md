ssh-tunneling
=============

```
SYNOPSIS :
    tunnel.bash
        --help
        --configure
        --local-port <LOCAL_PORT>
        --remote-user <REMOTE_USER>
        --remote-host <REMOTE_HOST>
        --remote-port <REMOTE_PORT>
        [ --remote-to-local | --local-to-remote ]

DESCRIPTION :
    --help               Help page
    --configure          Config remote server to support forwarding (optional)
                         This option will require arguments '--remote-user' and '--remote-host'
    --local-port         Local port number (require)
    --remote-user        Remote user (require)
    --remote-host        Remote host (require)
    --remote-port        Remote port number (require)
    --remote-to-local    Forward request from remote machine to local machine (require)
    --local-to-remote    Forward request from local machine to remote machine (require)

EXAMPLES :
    ./tunnel.bash --help
    ./tunnel.bash
        --configure
        --remote-user 'root'
        --remote-host 'my-server.com'
    ./tunnel.bash
        --local-port 8080
        --remote-user 'root'
        --remote-host 'my-server.com'
        --remote-port 9090
        --remote-to-local
    ./tunnel.bash
        --local-port 8080
        --remote-user 'root'
        --remote-host 'my-server.com'
        --remote-port 9090
        --local-to-remote
```
