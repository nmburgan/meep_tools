#! /bin/bash

#set -x
set -e

while getopts d:m:c:p opt; do
  case "$opt" in
    d)
      pe_dir="${OPTARG?}"
      ;;
    m)
      pe_modules="${OPTARG?}"
      ;;
    c)
      _pe_conf_path="${OPTARG?}"
      ;; 
    p)
      prep_arg='-p'
      ;;
  esac
done

pe_conf_path=${_pe_conf_path:-/root/pe.conf}

if [ -z "${pe_dir}" ]; then
  echo "Usage: rerun-pe-install-with-module-links.sh -d <pe-tarball-directory> -m <module-list>"
  echo " -d - path to the exploded pe tarball directory to re-install from"
  echo " -m - comma separated list of modules to link into the base and enterprise modulepaths from /jpartlow-src before final installation configure"
  echo " -c - path to a pe.conf file, if there isn't one already in the /root directory"
  echo " -p - just run a prep install (setup package repo and install puppet-agent pe-modules)"
  echo
  echo "This script will uninstall PE, prep an install, then link the requested modules before calling the final configure so you can test an install with updated module code without rebuilding a tarball."
  exit 1
fi

pushd "${pe_dir}"
  # unlink modules (particularly a problem on ubuntu)
  for m in $pe_modules; do
    if [ -L "/opt/puppetlabs/puppet/modules/${m}" ]; then
      rm "/opt/puppetlabs/puppet/modules/${m}"
    fi
    if [ -L "/opt/puppetlabs/server/data/environments/enterprise/modules/${m}" ]; then
      rm "/opt/puppetlabs/server/data/environments/enterprise/modules/${m}"
    fi
  done
  # clear up existing installation
  ./puppet-enterprise-uninstaller -y -p -d
  # prep install to get puppet-agent and pe-modules back into place
  ./puppet-enterprise-installer -p -c "${pe_conf_path}"
  if [ -n "${pe_modules}" ]; then
    # link in src overrides for the module code I'm testing
    # shellcheck disable=SC2086
    /jpartlow-src/integration-tools/scripts/link-in-src-modules.rb -a ${pe_modules//,/ }
  fi
  # run the actual installation (this assumes that /root/pe.conf has
  # whatever parameters we need to test already.
  ./puppet-enterprise-installer -c "${pe_conf_path}" "${prep_arg}"
popd
