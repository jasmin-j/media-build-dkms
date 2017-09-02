#!/bin/bash

DKMS_TAR_NAME="media-build-*.dkms_src.tgz"
DKMS_REGEX_VER="media-build-(.*).dkms_src.tgz"

DKMS_TAR_FOUND=

function exit_print {
	if [ -z "${2}" ] ; then
		code=100
	else
		code=${2}
	fi

	echo "${1}"
	exit ${code}
}

function err_exit {
	exit_print "Error: ${1}" ${2}
}

function usage {
	echo "Usage: $0 <distribution> [variant] [--help]"
	echo " <distribution>: the distribution to generate the DKMS for"
	echo "                 Currently supported:"
	echo "                   Debian"
	echo "                   Ubuntu"
	echo " <variant>: distribution variant"
	echo "            Debian: not used"
	echo "            Ubuntu: trusty, xenial, ..."
	echo "                    Note: This string is used for the changelog file."
	echo " Options:"
	echo "   --help: This text"
	exit_print "" 1
}

function arg_check_help {
	if [ "${1}" = "--help" ] ; then
		usage
	fi
}

# $1 .. template file name
# $2 .. target path
function copy_template {
	target=${2}/$(basename ${1})
	rm -f ${target}
	sed -e "s&@DKMS_VERSION@&${DKMS_VERSION}&g" \
		-e "s&@DKMS_VARIANT@&${DKMS_VARIANT}&g" \
		-e "s&@DKMS_URGENCY@&${DKMS_URGENCY}&g" \
		${1} > ${target}
}

# used for Debian and Ubuntu
function create_debian_dir {
	rm -rf debian
	mkdir debian
	for f in template_common/* ; do
		copy_template ${f} debian
	done
}

# main

if [ $# -lt 1 ] ; then
	usage
fi

arg_check_help "${1}"

distribution="${1}"
shift

arg_check_help "${1}"

variant="${1}"
shift

arg_check_help "${1}"

case "${distribution}" in
	Debian) variant="stable"; urgency="low";;
	Ubuntu) [ -z "${variant}" ] && err_exit "No variant defined!"
			urgency="medium"
			;;
	*) err_exit "Unsupported distribution '${distribution}'!" 2
esac

for f in $(ls ${DKMS_TAR_NAME} 2> /dev/null ) __dummy__ ; do
	[ "${f}" = "__dummy__" ] && break
	[ -n "${DKMS_TAR_FOUND}" ] && err_exit "Found second TGZ file '${f}'!" 2
	DKMS_TAR_FOUND=${f}
done

DKMS_DIST="${distribution}"
DKMS_VARIANT="${variant}"
DKMS_URGENCY="${urgency}"

[ -z "${DKMS_TAR_FOUND}" ] && err_exit "No TGZ file found!" 3

echo "Found ${DKMS_TAR_FOUND}"

if [[ ${DKMS_TAR_FOUND} =~ ${DKMS_REGEX_VER} ]] ; then
   DKMS_VERSION="${BASH_REMATCH[1]}"
else
   err_exit "Can't determine TGZ version!" 4
fi

echo "Preparing for ${DKMS_DIST} ${DKMS_VARIANT} (urgency=${DKMS_URGENCY})"
echo "DKMS version ${DKMS_VERSION}"

case "${distribution}" in
	Debian) create_debian_dir
			for f in template_debian/* ; do
				copy_template ${f} debian
			done
			;;
	Ubuntu) create_debian_dir
			for f in template_ubuntu/* ; do
				copy_template ${f} debian
			done
			;;
esac

TAR_DIR="media-build-${DKMS_VERSION}"

echo "Extracting TGZ to ${TAR_DIR}"
rm -rf ${TAR_DIR}
mkdir ${TAR_DIR}
tar -xzf ${DKMS_TAR_FOUND} -C ${TAR_DIR}

echo "Now build your package."

exit 0

