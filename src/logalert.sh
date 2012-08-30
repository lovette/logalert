#!/bin/bash
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/logalert

CMDPATH=$(readlink -f "$0")
CMDNAME=$(basename "$CMDPATH")
CMDDIR=$(dirname "$CMDPATH")
CMDARGS=$@

LOGALERT_VER="1.0.0"
EVALONEXIT=( )
TEMPFILES=( )
TERMWIDTH=25
GETOPTS="ac:C:e:E:f:g:hH:m:oOr:Rs:S:tTuvV"
HOSTNAME=$(hostname)
SYSADMIN=$(id -un)
CONFFILE=""

# Command line options
GETOPT_VERBOSE=0
GETOPT_REBOOT=0
GETOPT_LOGTAILTEST=0
GETOPT_OUTPUT=0
GETOPT_KEEPTEMP=0
GETOPT_RESET=0
GETOPT_DELETESTATE=0
GETOPT_GROUPS=( )

# Config file options
CONFDIR="/etc/logalert"
STATEDIR="/var/logalert"
LOGGROUPDIR=
FORMATAWKPATH=
RULESAWKPATH=
STYLESPATH=
INTROPATH=
FOOTERPATH=
SUBJECTHOSTNAME="$HOSTNAME"
SUBJECTPREPEND=
SUBJECTAPPEND=
SYSADMINFROM="$SYSADMIN@$HOSTNAME"
SYSADMINTO="$SYSADMIN@$HOSTNAME"
LOGTAILCMD="logtail2"
GREPCMD="egrep"
MAILCMD="sendmail -ti"
AWKCMD="awk --re-interval -f"
FORMATCMD=

##########################################################################
# Functions

# Called when script exits if any traps have been set
function on_exit()
{
	local i=

    for i in "${EVALONEXIT[@]}"
    do
        eval $i
    done
}

# set_exit_trap(eval)
# Sets a command that should be executed when script exits
function set_exit_trap()
{
    local n=${#EVALONEXIT[@]}
    EVALONEXIT[$n]="$*"
    if [[ $n -eq 0 ]]; then
        trap on_exit EXIT
    fi
}

# deletefile(path)
# Deletes a file and confirms that it is indeed deleted
# No-op if path is empty
function deletefile()
{
	local filepath=$1

	[ -z "$filepath" ] && return
	[ -f "$filepath" ] && /bin/rm -f "$filepath" && echo_verbose 3 "...deleted $filepath"
	[ -e "$filepath" ] && logalert_die "$filepath cannot be deleted!"
}

# deletefiles(array of paths)
# Deletes an array of files
function deletefiles()
{
	local -ar filepaths='("$@")'
	local filepath=

	for filepath in "${filepaths[@]}"
	do
		deletefile "$filepath"
	done
}

# tempfiles_add(array of paths)
# Adds a set of files that should be deleted when script exits
function tempfiles_add()
{
	local -ar filepaths='("$@")'
    local n=
	local filepath=

	for filepath in "${filepaths[@]}"
	do
	    n=${#TEMPFILES[@]}
		TEMPFILES[$n]="$filepath"
	done
}

# Deletes set of files tracked with tempfiles_add
function tempfiles_delete()
{
	if [ $GETOPT_KEEPTEMP -eq 0 ] && [ ${#TEMPFILES[@]} -gt 0 ]; then
		deletefiles "${TEMPFILES[@]}"
		unset TEMPFILES
		TEMPFILES=( )
	fi
}

# logalert_die(string)
function logalert_die()
{
	[ -n "$1" ] && echo "$@"
	echo "Logalert scan aborted!"
	exit 1
}

# echo_verbose([min verbose level,] string)
function echo_verbose()
{
	local minlevel=1

	# If there are multiple arguments, the first must be a minimum verbose level
	if [ $# -gt 1 ]; then
		minlevel=$1
		shift
	fi

	[ $GETOPT_VERBOSE -ge $minlevel ] && echo "$@"
}

# emailreport(type, log group name, directory, reportsubject, logoutpath)
# Emails the results of a log scan to a sysadmin
function emailreport()
{
	local reporttype=$1
	local loggroupname=$2
	local loggroupdir=$3
	local reportsubject=$4
	local logoutpath=$5
	local logvardir="$STATEDIR/$loggroupname"
	local mailout="$logvardir/$loggroupname.mail.$reporttype.$$.tmp"
	local awkformatpath="$loggroupdir/format.awk"
	local stylespath="$loggroupdir/format.styles"
	local subject=

	# Use log group specific formatting if available
	[ -s "$awkformatpath" ] || awkformatpath="$FORMATAWKPATH"
	[ -s "$stylespath" ] || stylespath="$STYLESPATH"

	# Build subject
	[ -n "$SUBJECTPREPEND" ] && subject="${SUBJECTPREPEND}${subject} "
	[ $GETOPT_REBOOT -eq 1 ] && subject="${subject}[REBOOT] "
	subject="${subject}${reportsubject} for $loggroupname @ $SUBJECTHOSTNAME"
	[ -n "$SUBJECTAPPEND" ] && subject="${subject} ${SUBJECTAPPEND}"

	echo_verbose 2 "...formatting $reporttype email with $awkformatpath"

	deletefile "$mailout"
	tempfiles_add "$mailout"

	# Generate email message
	(
	echo "From: Logalert <$SYSADMINFROM>"
	echo "To: $SYSADMINTO"
	echo "Subject: $subject"
	echo "X-Logalert-Ver: $LOGALERT_VER"
	echo "X-Logalert-Date: $(date -R)"
	echo "Content-Type: text/html"
	echo
	echo "<html>"
	echo "<head>"
	echo "<style type=\"text/css\">"
	cat $stylespath
	echo "</style>"
	echo "</head>"
	echo "<body>"
	[ -s "$INTROPATH" ] && cat "$INTROPATH"
	$FORMATCMD $awkformatpath $logoutpath
	[ -s "$FOOTERPATH" ] && cat "$FOOTERPATH"
	echo "</body>"
	echo "</html>"
	) > $mailout

	# Act on message
	case $GETOPT_OUTPUT in
	0)	cat $mailout | $MAILCMD
		[ $? -ne 0 ] && logalert_die
		echo_verbose "...$reporttype email sent to $SYSADMINTO"
		;;
	1)	cat $mailout
		;;
	2)
		;;
	esac
}

# scangroup(name, directory)
# Scans the logs in a log group and emails results to a sysadmin
function scangroup()
{
	local loggroupname=$1
	local loggroupdir=$2
	local logvardir="$STATEDIR/$loggroupname"
	local logfilespath="$logvardir/$loggroupname.logfiles"
	local ignorepath="$logvardir/$loggroupname.ignore"
	local alertspath="$logvardir/$loggroupname.alert"
	local logtailout="$logvardir/$loggroupname.logtail.$$.tmp"
	local unexpectedout="$logvardir/$loggroupname.unexpected.$$.tmp"
	local alertsout="$logvardir/$loggroupname.alerts.$$.tmp"
	local noticesout="$logvardir/$loggroupname.notices.$$.tmp"
	local tempfiles=( "$logtailout" "$alertsout" "$noticesout" "$unexpectedout" )
	local logfilepath=
	local logfilename=
	local offsetfile=
	local logtailargs=

	# Tell logtail not to save its offset file
	[ $GETOPT_LOGTAILTEST -eq 1 ] && logtailargs="-t"

	# Make sure output isn't spoofed
	deletefiles "${tempfiles[@]}"

	echo_verbose "Scanning $loggroupname logs..."

	tempfiles_add "$logtailout"

	# Tail all the logs in this group for changes
	while read logfilepath
	do
		echo_verbose "...tailing $logfilepath"

		logfilename=$(basename "$logfilepath")
		offsetfile="$logvardir/$logfilename.offset"

		# We can skip empty logs that have never been checked
		[ ! -f "$offsetfile" ] && [ ! -s "$logfilepath" ] && continue

		# Nothing we can do with unreadable files
		[ ! -r "$logfilepath" ] && echo "$logfilepath cannot be read and was not scanned!" && continue

		# Search for new log messages
		$LOGTAILCMD $logtailargs -o $offsetfile -f $logfilepath >> $logtailout
		[ $? -ne 0 ] && logalert_die

	done < $logfilespath

	# If no files have changed then we're done
	if [ ! -s "$logtailout" ]; then
		echo_verbose "...no changes found"
		tempfiles_delete
		return
	fi

	# See what we're supposed to ignore
	if [ -s "$ignorepath" ]; then
		tempfiles_add "$unexpectedout"
		$GREPCMD -v -f "$ignorepath" $logtailout > $unexpectedout
		[ $? -gt 1 ] && logalert_die "Error scanning log group: $loggroupname"
	else
		unexpectedout="$logtailout"
	fi

	# Search for alert patterns
	# Everything that's not an alert is a notice
	if [ -s "$alertspath" ]; then
		tempfiles_add "$alertsout"
		$GREPCMD -f "$alertspath" "$unexpectedout" > $alertsout
		[ $? -gt 1 ] && logalert_die "Error scanning log group: $loggroupname"

		tempfiles_add "$noticesout"
		$GREPCMD -v -f "$alertspath" "$unexpectedout" > $noticesout
		[ $? -gt 1 ] && logalert_die "Error scanning log group: $loggroupname"
	else
		noticesout="$unexpectedout"
	fi

	# Be verbose if requested
	if [ $GETOPT_VERBOSE -gt 1 ]; then
		if [ -s "$alertsout" ]; then
			echo_verbose "...ALERTS  found:"
			sed -e "s/^/....../" $alertsout
		fi

		if [ -s "$noticesout" ]; then
			echo_verbose "...NOTICES found:"
			sed -e "s/^/....../" $noticesout
		fi
	fi

	# Be really verbose if requested
	if [ $GETOPT_VERBOSE -gt 2 ]; then
		if [ -s "$ignorepath" ]; then
			echo_verbose "...IGNORED:"
			$GREPCMD -f "$ignorepath" $logtailout | sed -e "s/^/....../"
		fi
	fi

	# Act on results
	[ -s "$alertsout" ] && emailreport "alerts" "$loggroupname" "$loggroupdir" "ALERTS" $alertsout
	[ -s "$noticesout" ] && emailreport "notices" "$loggroupname" "$loggroupdir" "Unusual activity" $noticesout

	tempfiles_delete
}

# buildstatefile(path, directory, pattern)
# Combines a set of files to create an individual state file
function buildstatefile()
{
	local statefilepath=$1
	local loggroupdir=$2
	local fileglob=$3
	local awkrulespath="$loggroupdir/rules.awk"
	local filepath=

	[ -s "$awkrulespath" ] || awkrulespath="$RULESAWKPATH"

	echo_verbose "...building $statefilepath"

	deletefile "$statefilepath"

	# At least create an empty file so we know it was built
	touch "$statefilepath"

	# Combine log group files
	for filepath in $loggroupdir/$fileglob
	do
		$AWKCMD $awkrulespath $filepath >> $statefilepath
	done
}

# buildgroupstate(name, directory)
# Scans a log group directory and creates state files if necessary
function buildgroupstate()
{
	local loggroupname=$1
	local loggroupdir=$2
	local logvardir="$STATEDIR/$loggroupname"
	local logfilespath="$logvardir/$loggroupname.logfiles"
	local ignorepath="$logvardir/$loggroupname.ignore"
	local alertspath="$logvardir/$loggroupname.alert"
	local filepath=
	local built=0

	echo_verbose "Building state for $loggroupname logs..."

	# Reset group state directory
	if [ $GETOPT_RESET -eq 1 ]; then
		echo_verbose 2 "...deleting $logvardir/"
		/bin/rm -rf "$logvardir" || logalert_die "Cannot reset $loggroupname group state directory!"
	fi

	# Create group state directory
	if [ ! -d "$logvardir" ]; then
		echo_verbose 2 "...creating $logvardir/"
		mkdir -p $logvardir || logalert_die "$loggroupname group state directory cannot be created!"
	fi

	# Build the combined logfiles file if it's out of date
	for filepath in $loggroupdir/*.logfiles
	do
		if [ "$filepath" -nt "$logfilespath" ]; then
			buildstatefile "$logfilespath" "$loggroupdir" "*.logfiles"
			built=1
			break
		fi
	done

	[ -s "$logfilespath" ] || logalert_die "$loggroupdir: no log files to scan (no *.logfiles?)"

	# Build the combined ignore file if it's out of date
	for filepath in $loggroupdir/*.ignore
	do
		if [ "$filepath" -nt "$ignorepath" ]; then
			buildstatefile "$ignorepath" "$loggroupdir" "*.ignore"
			built=1
			break
		fi
	done

	# Build the combined alerts file if it's out of date
	for filepath in $loggroupdir/*.alert
	do
		if [ "$filepath" -nt "$alertspath" ]; then
			buildstatefile "$alertspath" "$loggroupdir" "*.alert"
			built=1
			break
		fi
	done

	[ $built -eq 0 ] && echo_verbose "...nothing to do"
}

# Print version and exit
function version()
{
	echo "logalert $LOGALERT_VER"
	echo
	echo "Copyright (C) 2011 Lance Lovette"
	echo "Licensed under the BSD License."
	echo "See the distribution file LICENSE.txt for the full license text."
	echo
	echo "Written by Lance Lovette <https://github.com/lovette>"

	exit 0
}

# Print usage and exit
function usage()
{
	echo "Scans log files and sends unexpected activity and alerts to a sysadmin via email."
	echo
	echo "Usage: logalert [OPTION]..."
	echo
	echo "Options:"
	echo "  -a             Reset state and scan logs from their beginning;"
	echo "                 If -g is used, only specified groups are reset"
	echo "  -c FILE        Override default configuration file"
	echo "  -C DIR         Override default directory of configuration files"
	echo "  -e TEXT        Override default subject prepend text"
	echo "  -E TEXT        Override default subject append text"
	echo "  -f FILE        Override default format awk script"
	echo "  -g NAME        Scan only this log group or directory (specify -g for each group)"
	echo "  -h, --help     Show this help and exit"
	echo "  -H HOST        Override hostname in email subject"
	echo "  -m EMAIL       Override email recipient"
	echo "  -o             Print email messages to stdout; no email will be sent"
	echo "  -O             Suppress all output; no email will be sent"
	echo "  -r DIR         Override log group directory"
	echo "  -R             Prepend email subject with \"[REBOOT]\""
	echo "  -s FILE        Override default format styles file"
	echo "  -S DIR         Override state directory"
	echo "  -t             Debug: Do not update logtail offset"
	echo "  -T             Debug: Do not delete temporary files (run again with -a to reset)"
	echo "  -u             Delete state directory and exit; see also -a"
	echo "  -v             Increase verbosity (can specify more than once)"
	echo "  -V, --version  Print version and exit"
	echo
	echo "Report bugs to <https://github.com/lovette/logalert/issues>"

	exit 0
}

##########################################################################
# Main

# Check for usage longopts
case "$1" in
	"--help"    ) usage;;
	"--version" ) version;;
esac

# Check for config file/dir override and usage
while getopts "$GETOPTS" opt
do
	case $opt in
	c  ) CONFFILE=$(readlink -f "$OPTARG");;
	C  ) CONFDIR=$(readlink -f "$OPTARG");;
	h  ) usage;;
	v  ) (( GETOPT_VERBOSE++ ));;
	V  ) version;;
	\? ) echo "Try '$CMDNAME --help' for more information."; exit 1;;
	esac
done

# Use a default configuration file if it exists
if [ -z "$CONFFILE" ] && [ -n "$CONFDIR" ]; then
	testconffile="$CONFDIR/logalert.conf"
	[ -f "$testconffile" ] && [ -r "$testconffile" ] && CONFFILE="$testconffile"
fi

# Import configuration file if available
if [ -n "$CONFFILE" ]; then
	if [ -f "$CONFFILE" ] && [ -r "$CONFFILE" ]; then
		echo_verbose 2 "Using configuration file $CONFFILE"
		source $CONFFILE || logalert_die
	else
		logalert_die "$CONFFILE: Configuration file not found or not readable"
	fi
fi

# Verify the configuration directory
CONFDIR=${CONFDIR%%/}
[ -n "$CONFDIR" ] || logalert_die "Configuration directory must be specified (CONFDIR or -C)"
[ -d "$CONFDIR" ] || logalert_die "$CONFDIR: configuration directory does not exist"
[ -r "$CONFDIR" ] || logalert_die "$CONFDIR: configuration directory is not readable"

# Set default config variables based on CONFDIR
[ -n "$LOGGROUPDIR" ] || LOGGROUPDIR="$CONFDIR/logs.d"
[ -n "$FORMATAWKPATH" ] || FORMATAWKPATH="$CONFDIR/default.format.awk"
[ -n "$RULESAWKPATH" ] || RULESAWKPATH="$CONFDIR/default.rules.awk"
[ -n "$STYLESPATH" ] || STYLESPATH="$CONFDIR/default.format.styles"
[ -n "$INTROPATH" ] || INTROPATH="$CONFDIR/intro.html"
[ -n "$FOOTERPATH" ] || FOOTERPATH="$CONFDIR/footer.html"

# Set default config variables based on AWKCMD
[ -n "$FORMATCMD" ] || FORMATCMD="$AWKCMD"

OPTIND=1

# Override options set in config file
while getopts "$GETOPTS" opt
do
	case $opt in
	a  ) GETOPT_RESET=1;;
	e  ) SUBJECTPREPEND="$OPTARG";;
	E  ) SUBJECTAPPEND="$OPTARG";;
	f  ) FORMATAWKPATH=$(readlink -f "$OPTARG");;
	g  ) GETOPT_GROUPS=( "${GETOPT_GROUPS[@]}" "$OPTARG" );;
	H  ) SUBJECTHOSTNAME="$OPTARG";;
	m  ) SYSADMINTO="$OPTARG";;
	o  ) GETOPT_OUTPUT=1;;
	O  ) GETOPT_OUTPUT=2;;
	r  ) LOGGROUPDIR=$(readlink -f "$OPTARG");;
	R  ) GETOPT_REBOOT=1;;
	s  ) STYLESPATH=$(readlink -f "$OPTARG");;
	S  ) STATEDIR=$(readlink -f "$OPTARG");;
	t  ) GETOPT_LOGTAILTEST=1;;
	T  ) GETOPT_KEEPTEMP=1;;
	u  ) GETOPT_DELETESTATE=1;;
	\? ) echo "Try '$CMDNAME --help' for more information."; exit 1;;
	esac
done

# Shift past recognized options
shift $(($OPTIND - 1))

# Capture console width if we're being verbose to a terminal
[ $GETOPT_VERBOSE -gt 0 ] && [ "$(tty)" != "not a tty" ] && TERMWIDTH=$(tput cols)

# All files we create should have limited visibility
umask 077

# Expand glob patterns which match no files to a null string
shopt -s nullglob

# Verify the log group directory
LOGGROUPDIR=${LOGGROUPDIR%%/}
[ -n "$LOGGROUPDIR" ] || logalert_die "Log group directory must be specified (LOGGROUPDIR or -r)"
[ -d "$LOGGROUPDIR" ] || logalert_die "$LOGGROUPDIR: log group directory does not exist"
[ -r "$LOGGROUPDIR" ] || logalert_die "$LOGGROUPDIR: log group directory is not readable"

# Verify the state directory where we keep persistent files
STATEDIR=${STATEDIR%%/}
[ -n "$STATEDIR" ] || logalert_die "State directory must be specified (STATEDIR or -S)"
[ "$STATEDIR" == "/" ] && logalert_die "State directory cannot be /"

# Verify email addresses
[ -n "$SYSADMINFROM" ] || logalert_die "Sysadmin sender must be specified (SYSADMINFROM)"
[ -n "$SYSADMINTO" ] || logalert_die "Sysadmin recipient must be specified (SYSADMINTO or -m)"

# Verify subject hostname
[ -n "$SUBJECTHOSTNAME" ] || logalert_die "Hostname must be specified (SUBJECTHOSTNAME or -H)"

# Verify script and files
[ -s "$FORMATAWKPATH" ] || logalert_die "$FORMATAWKPATH: default format awk script does not exist or is empty"
[ -s "$RULESAWKPATH" ] || logalert_die "$RULESAWKPATH: default rules awk script does not exist or is empty"
[ -s "$STYLESPATH" ] || logalert_die "$STYLESPATH: default styles file does not exist or is empty"

# Delete state directory if requested
if [ $GETOPT_DELETESTATE -eq 1 ]; then
	/bin/rm -rf "$STATEDIR" || logalert_die "Cannot delete state directory!"
	echo_verbose "$STATEDIR/ deleted"
	exit 0
fi

scangroupdirs=( )

# Set or search for directories defining logs to scan
if [ "${#GETOPT_GROUPS[@]}" -ne 0 ]; then
	for dirpathorname in "${GETOPT_GROUPS[@]}"
	do
		[[ "$dirpathorname" == /* ]] || dirpathorname="$LOGGROUPDIR/$dirpathorname"
		[ -d "$dirpathorname" ] || logalert_die "$dirpathorname: log group directory does not exist"
		scangroupdirs=( "${scangroupdirs[@]}" "$dirpathorname" )
	done
else
	# Delete all state directories at once
	if [ $GETOPT_RESET -eq 1 ]; then
		echo_verbose 2 "Deleting $STATEDIR/"
		/bin/rm -rf "$STATEDIR" || logalert_die "Cannot reset state directory!"
		GETOPT_RESET=0
	fi

	scangroupdirs=( $(find $LOGGROUPDIR -mindepth 1 -maxdepth 1 -type d) )
fi

[ "${#scangroupdirs[@]}" -gt 0 ] || logalert_die "No logs defined to scan ($LOGGROUPDIR is empty?)"

# Create state directory root
if [ ! -d "$STATEDIR" ]; then
	mkdir -p "$STATEDIR" || logalert_die "State directory cannot be created!"
fi

# Delete temporary files on exit
set_exit_trap tempfiles_delete

# First build the cached config files then scan the logs and email reports
for loggroupdir in "${scangroupdirs[@]}"
do
	loggroupname=$(basename "$loggroupdir")

	[ $GETOPT_VERBOSE -gt 0 ] && eval printf '%.0s=' {1.."$TERMWIDTH"} && echo

	buildgroupstate "$loggroupname" "$loggroupdir"
	scangroup "$loggroupname" "$loggroupdir"
done
