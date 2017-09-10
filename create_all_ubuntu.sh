#!/bin/bash

prepare_script="./prepare_dkms_src.sh"

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

function do_prepare_Ubuntu {
   ${prepare_script} Ubuntu ${1}
   debuild -S || err_exit "Couldn't create source package for Ubuntu ${1}" 1

   if [ "${2}" = "binary" ]; then
       fakeroot debian/rules binary || err_exit "Couldn't create binary package for Ubuntu ${1}" 2
   fi
}

# main

do_prepare_Ubuntu precise
do_prepare_Ubuntu trusty binary
do_prepare_Ubuntu xenial

