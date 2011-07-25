#!/bin/sh
# This is a testsuite.
# estimated run-time on my PC; 1 hour

PBUILDER=/usr/sbin/pbuilder

# ideal value
DEBOOTSTRAPS="debootstrap cdebootstrap"
DISTRIBUTIONS="sid lenny squeeze"

# override
DEBOOTSTRAPS="debootstrap"
DISTRIBUTIONS="sid squeeze"

log_success () {
    CODE=$?
    if [ $CODE = 0 ]; then
	echo "[OK]   $1" >> ${RESULTFILE}
    else
	echo "[FAIL] $1" >> ${RESULTFILE}
    fi
}

[ -x ${PBUILDER} ] || exit 1
[ -x /usr/sbin/debootstrap ] || exit 1
[ -x /usr/bin/cdebootstrap ] || exit 1

case "`hostname --fqdn`" in
  *.dooz.org)
    mirror=http://ftp.de.debian.org/debian
  ;;
  *)
    mirror=http://localhost:9999/debian
  ;;
esac

testdir=$(TMPDIR=$(pwd) mktemp -d)
testimage=$testdir/testimage
testbuild=$testdir/dir1
testbuild2=$testdir/dir2
testbuild3=$testdir/dir3

export testdir

HOOKOPTION=" --hookdir /usr/share/doc/pbuilder/examples/workaround"

for DEBOOTSTRAP in $DEBOOTSTRAPS; do
    case $DEBOOTSTRAP in 
	debootstrap)
	    logdir=$(readlink -f normal/)
	    RESULTFILE="run-test.log"
	    unset DEBOOTSTRAPOPTS
	    DEBOOTSTRAPOPTS[0]="--debootstrapopts"
	    DEBOOTSTRAPOPTS[1]="--verbose"
	    ;;
	*)
	    logdir=$(readlink -f $DEBOOTSTRAP)
	    RESULTFILE="run-test-${DEBOOTSTRAP}.log"
	    unset DEBOOTSTRAPOPTS
	    DEBOOTSTRAPOPTS[0]="--debootstrapopts"
	    DEBOOTSTRAPOPTS[1]="--verbose"
	    ;;
    esac
    : > ${RESULTFILE}
    RESULTFILE=$(readlink -f ${RESULTFILE})
    
    for distribution in ${DISTRIBUTIONS}; do
	sudo ${PBUILDER} create $HOOKOPTION "${DEBOOTSTRAPOPTS[@]}" --mirror $mirror --debootstrap ${DEBOOTSTRAP} --distribution "${distribution}" --basetgz ${testimage} --logfile ${logdir}/pbuilder-create-${distribution}.log.orig 

	log_success create-${distribution}-${DEBOOTSTRAP}
	
	for PKG in dsh; do 
	    ( 
		mkdir ${testbuild}
		cd ${testbuild}
		apt-get source -d ${PKG}
	    )
	    sudo ${PBUILDER} build --debemail "Junichi Uekawa <dancer@debian.org>" --basetgz ${testimage} --buildplace ${testbuild}/ --logfile ${logdir}/pbuilder-build-${PKG}-${distribution}.log.orig ${testbuild}/${PKG}*.dsc
	    log_success build-${distribution}-${PKG}
	    
	    (
		mkdir ${testbuild2}
		mkdir ${testbuild3}
		cd ${testbuild2}
		apt-get source ${PKG}
		cd ${PKG}-*
		pdebuild --logfile ${logdir}/pdebuild-normal-${distribution}.log.orig -- --basetgz ${testimage} --buildplace ${testbuild3}
		log_success pdebuild-${distribution}-${PKG}
		
		pdebuild --use-pdebuild-internal --logfile ${logdir}/pdebuild-internal-${distribution}.log.orig -- --basetgz ${testimage} --buildplace ${testbuild3}
		log_success pdebuild-internal-${distribution}-${PKG}
	    )
	done
	sudo ${PBUILDER} execute --basetgz ${testimage} --logfile ${logdir}/pbuilder-execute-${distribution}.log.orig ../examples/execute_paramtest.sh test1 test2 test3
	
	# upgrading testing.
	case $distribution in 
	    lenny)
		sudo ${PBUILDER} update $HOOKOPTION --basetgz ${testimage} --distribution squeeze --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-squeeze.log.orig 
		log_success update-${distribution}-squeeze
		sudo ${PBUILDER} update $HOOKOPTION --basetgz ${testimage} --distribution sid --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-squeeze-sid.log.orig 
		log_success update-${distribution}-squeeze-sid
		sudo ${PBUILDER} update $HOOKOPTION --basetgz ${testimage} --distribution experimental --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-squeeze-sid-experimental.log.orig 
		log_success update-${distribution}-squeeze-sid-experimental
		;;
	    squeeze)
		sudo ${PBUILDER} update $HOOKOPTION --basetgz ${testimage} --distribution sid --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-sid.log.orig 
		log_success update-${distribution}-sid
		sudo ${PBUILDER} update $HOOKOPTION --basetgz ${testimage} --distribution experimental --mirror $mirror --override-config --logfile ${logdir}/pbuilder-update-${distribution}-sid-experimental.log.orig 
		log_success update-${distribution}-sid-experimental
		;;
	esac
	sudo rm -rf ${testbuild} ${testbuild2} ${testimage} ${testbuild3}
    done

    for A in ${logdir}/*.log.orig; do
	sed \
	    -e "s,${testdir},/TESTDIR,g" \
	    -e "s,^Current time:.*,Current time: TIME," \
	    -e "s,^pbuilder-time-stamp: .*,pbuilder-time-stamp: XXXX," \
	    -e "s,^Fetched .*B in .*s (.*B/s),Fetched XXXB in Xs (XXXXXB/s)," \
	    -e "s,/var/cache/pbuilder/build//[0-9]*,/var/cache/pbuilder/build//NUM,g" \
	    -e "s,\(/TESTDIR/dir[123]\)/[0-9]\+,\1/NUM,g" \
	    -e "s,Local time is now:.*,Local time is now: XXXX," \
	    -e "s,Universal Time is now:.*,Universal Time is now: XXXX," \
	    < $A > ${A/.orig} && \
	rm -f $A
    done

    echo '### RESULT: ###'
    cat "${RESULTFILE}"
done

rm -r ${testdir}
