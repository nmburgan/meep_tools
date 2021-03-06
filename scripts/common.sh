# Common setup used by several scripts to determine VER, PLATFORM, PLATFORM_VERSION, ARCH from
# current directory, potentially with local overrides.
if [ -e local ]; then
    source local
fi

if [[ $(pwd) =~ pe-[0-9]+\.[0-9]+ ]]; then
  VER=${VER:-$(pwd | grep -Eo 'pe-[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+')}
  FULL_VER=${FULL_VER:=${VER}.0}
  defaults=($(basename "$(pwd)" | grep -Eo '[^-]+'))
  PLATFORM=${PLATFORM:-${defaults[0]}}
  case "${PLATFORM?}" in
      redhat | centos | sles)
          PLATFORM=el
          default_arch=x86_64
          ;;
      debian | ubuntu)
          default_arch=amd64
          defaults[1]=$(echo "${defaults[1]}" | sed -re 's/([0-9]{2})(.+)/\1.\2/')
          ;;
  esac
  PLATFORM_VERSION=${PLATFORM_VERSION:-${defaults[1]}}
  ARCH=${ARCH:-$default_arch}
  PLATFORM_STRING="${PLATFORM?}-${PLATFORM_VERSION?}-${ARCH?}"
  # find release version
  BUILD=$(find -L pe_builds -type d -name "puppet-enterprise-${FULL_VER?}-${PLATFORM_STRING?}*" -printf "%f\n" | sort | tail -n1)
  # or dev version
  if [ -z "$BUILD" ]; then
    BUILD=$(find -L pe_builds -type d -name "puppet-enterprise-${FULL_VER?}-*-${PLATFORM_STRING?}*" -printf "%f\n" | sort | tail -n1)
  fi
  echo "VER: $VER"
  echo "FULL_VER: $FULL_VER"
  echo "PLATFORM_STRING: $PLATFORM_STRING"
  echo "BUILD: $BUILD"
fi
ensure_rsync() {
    _platform=${1?}
    _host=${2?}

    case "${_platform%%-*}" in
        el | redhat | centos)
            ssh_on "${_host?}" 'yum install -y rsync tree wget'
            ;;
        ubuntu | debian)
            ssh_on "${_host?}" 'apt-get install -y rsync tree wget'
            ;;
        *)
            echo 'no sles yet!'
            exit 1
    esac
}

_ssh_on() {
    local _host=${1?}
    local _command=${2?}

    if [[ "$_host" =~ .*\.puppetdebug\.vlan ]]; then
        _hostname=${_host%%.*}
        pwd
        vagrant ssh "$_hostname" -c "sudo $_command"
    else
        # accept master's host key since it's just a qa vm
        ssh -o StrictHostKeyChecking=no "root@${_host}" "$_command"
    fi
}

ssh_on() {
    local _host=${1?}
    local _command=${2?}

    echo "--> ($_host)# $_command"
    _ssh_on "$_host" "$_command"
}

ssh_get() {
    local _host=${1?}
    local _command=${2?}
    local _variable=${3?}

    echo "--> ($_host)# $_command"
    local value
    value=$(_ssh_on "$_host" "$_command")
    # An ugly and unsafe workaround for getting return values in BASH
    eval "${_variable}=${value}"
}

rsync_on() {
    _host=${1?}
    _source=${2?}
    _target=${3}
    _dryrun=${4}

    if [ "${_dryrun}" == '-d' ]; then
      dryrun='--dry-run'
    fi

    if [[ "$_host" =~ .*\.puppetdebug\.vlan ]]; then
        _port=$(vagrant ssh-config "${_host%%.*}" | grep Port | grep -oE '[0-9]+')
        rsync --progress "${dryrun}" -rLptgoD -e "ssh -o StrictHostKeyChecking=false -p $_port" "$_source" "root@localhost:${_target}"
    else
        rsync --progress ${dryrun} -rLptgOD "$_source" "root@${_host}:${_target}"
    fi
}

get_hostnames() {
  if [ -n "$master" ]; then
    return 0
  fi
  hosts=$(vagrant hosts list)

  master=$(grep -Eo 'pe-[0-9]+-master\.[a-z.]+' <<< "$hosts")
  db=$(grep -Eo 'pe-[0-9]+-db\.[a-z.]+' <<< "$hosts")
  console=$(grep -Eo 'pe-[0-9]+-console\.[a-z.]+' <<< "$hosts")
  agent=$(grep -Eo 'pe-[0-9]+-agent\.[a-z.]+' <<< "$hosts")

  echo "master: $master"
  echo "db: $db"
  echo "console: $console"
  echo "agent: $agent"
}

