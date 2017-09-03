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
	echo "Usage: $0 <distribution> [variant] [--help] [--clean] [--distclean]"
	echo " <distribution>: the distribution to generate the DKMS for"
	echo "                 Currently supported:"
	echo "                   Debian"
	echo "                   Ubuntu"
	echo " <variant>: distribution variant"
	echo "            Debian: not used"
	echo "            Ubuntu: trusty, xenial, ..."
	echo "                    Note: This string is used for the changelog file."
	echo " Options:"
	echo "   --clean: Remove all created directories"
	echo "   --distclean: do --clean and also remove the TGZ file"
	echo "   --help: This text"
	exit_print "" 1
}

function opt_check_clean {
	if [ "${1}" = "--clean" ] ; then
		opt_clean=1
	fi
}

function opt_check_dclean {
	if [ "${1}" = "--distclean" ] ; then
		opt_clean=1
		opt_distclean=1
	fi
}

function opt_check_help {
	if [ "${1}" = "--help" ] ; then
		usage
	fi
}

function opt_check {
	opt_check_clean "${1}"
	opt_check_dclean "${1}"
	opt_check_help "${1}"
}

function clean {
	rm -rf debian
    rm -rf ${1}
    rm -f *-stamp
}

# $1 .. template file name
# $2 .. target path
function copy_file {
	target=${2}$(basename ${1})
	rm -f ${target}
	sed -e "s&@DKMS_VERSION@&${DKMS_VERSION}&g" \
		-e "s&@DKMS_VARIANT@&${DKMS_VARIANT}&g" \
		-e "s&@DKMS_URGENCY@&${DKMS_URGENCY}&g" \
		${1} > ${target}
}

# $1 .. template file name
# $2 .. template directory
# $3 .. target directory
function copy_template {
	if [ -f ${1} ] ; then
		src_dir="$(dirname ${1})"
		dest_dir="${src_dir#${2}}/"
		copy_file ${1} ${3}${dest_dir}
	elif [ -d ${1} ] ; then
		dest_dir="${1#${2}}"
		mkdir -p ${3}${dest_dir}
	else
		err_exit "Unsupported file type '${1}'!" 4
	fi
}

# used for Debian and Ubuntu
function create_debian_dir {
	mkdir debian
    for f in $(find template_common) ; do
		copy_template ${f} template_common debian
	done
}

function exec_debian_dir {
	chmod a+x debian/postinst debian/prerm debian/rules
}

# main

if [ $# -lt 1 ] ; then
	usage
fi

opt_check "${1}"

distribution="${1}"
shift

opt_check "${1}"

variant="${1}"
shift

opt_check "${1}"

for f in $(ls ${DKMS_TAR_NAME} 2> /dev/null ) __dummy__ ; do
	[ "${f}" = "__dummy__" ] && break
	[ -n "${DKMS_TAR_FOUND}" ] && err_exit "Found second TGZ file '${f}'!" 2
	DKMS_TAR_FOUND=${f}
done

[ -z "${DKMS_TAR_FOUND}" ] && err_exit "No TGZ file found!" 3

if [[ ${DKMS_TAR_FOUND} =~ ${DKMS_REGEX_VER} ]] ; then
   DKMS_VERSION="${BASH_REMATCH[1]}"
else
   err_exit "Can't determine TGZ version!" 4
fi

TAR_DIR="media-build-${DKMS_VERSION}"

clean ${TAR_DIR}

if [ -n "${opt_distclean}" ] ; then
    rm -rf ${DKMS_TAR_FOUND}
fi

if [ -n "${opt_clean}" ] ; then
    exit 0
fi

case "${distribution}" in
	Debian) variant="stable"; urgency="low";;
	Ubuntu) [ -z "${variant}" ] && err_exit "No variant defined!"
			urgency="medium"
			;;
	*) err_exit "Unsupported distribution '${distribution}'!" 2
esac

DKMS_DIST="${distribution}"
DKMS_VARIANT="${variant}"
DKMS_URGENCY="${urgency}"

echo "Found ${DKMS_TAR_FOUND}"
echo "Preparing for ${DKMS_DIST} ${DKMS_VARIANT} (urgency=${DKMS_URGENCY})"
echo "DKMS version ${DKMS_VERSION}"

case "${distribution}" in
	Debian) create_debian_dir
			for f in template_debian/* ; do
				copy_template ${f} template_debian debian
			done
			exec_debian_dir
			;;
	Ubuntu) create_debian_dir
			for f in template_ubuntu/* ; do
				copy_template ${f} template_ubuntu debian
			done
			exec_debian_dir
			;;
esac

echo "Extracting TGZ to ${TAR_DIR}"
mkdir ${TAR_DIR}
tar -xzf ${DKMS_TAR_FOUND} -C ${TAR_DIR}

echo "Now build your package."

exit 0

