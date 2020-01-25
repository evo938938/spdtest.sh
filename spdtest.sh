#!/usr/bin/env bash
# shellcheck disable=SC1090  #can't follow non constant source
# shellcheck disable=SC2034  #unused variables
# shellcheck disable=SC2001 #sed
# shellcheck disable=SC2207 # read -a, mapfile warning
# shellcheck disable=SC2119 # function warnings
# shellcheck disable=SC2086 # double quoute warning
# shellcheck disable=SC2120 # function argument warnings

aa_TODOs() { echo -n;

# TODO Fix argument parsing and error messages
# TODO Change slowtest to multiple servers and compare results
# TODO fix wrong keypress in inputwait, esc codes etc
# TODO fix up README.md
# TODO extern config and save to config?
# TODO ssh controlmaster, server, client
# TODO grc function in bash function?
# TODO grc, grc.conf, speedtest and speedtest-cli to /dev/shm ?
# TODO buffer logview
# TODO route test menu, choose host to test
# TODO windows: help, options, route, timer   <----------------------
# TODO plot speedgraphs overtime in UI
# TODO stat file

}
#?> Start variables ------------------------------------------------------------------------------------------------------------------>
aa_variables() { echo -n; }
net_device="auto"		#* Network interface to get current speed from, set to "auto" to get default interface from "ip route" command
unit="mbit"				#* Valid values are "mbit" and "mbyte"
slowspeed="30"			#* Download speed in unit defined above that triggers more tests, recommended set to 10%-40% of your max speed
numservers="30"			#* How many of the closest servers to get from speedtest.net, used as random pool of servers to test against
slowretry="1"			#* When speed is below slowspeed, how many retries of random servers before running full tests
numslowservers="8"		#* How many of the closest servers from list to test if slow speed has been detected, tests all if not set
precheck="true"			#* Check current bandwidth usage before slowcheck, blocks if speed is higher then values set below
precheck_samplet="5"	#* Time in seconds to sample bandwidth usage, defaults to 5 if not set
precheck_down="50"		#* Download speed in unit defined above that blocks slowcheck
precheck_up="50"		#* Upload speed in unit defined above that blocks slowcheck
precheck_ssh_host="192.168.1.1" #* If set, precheck will fetch data from /proc/net/dev over SSH, for example from a router running linux
						#* remote machine needs to have: "/proc/net/dev" and be able to run commands "ip route" and "grep"
						#* copy SSH keys to remote machine if you don't want to be asked for password at start, guide: https://www.ssh.com/ssh/copy-id
precheck_ssh_user="admin" #* Username for ssh connection
precheck_ssh_nd="auto"  #* Net device on remote machine to get speeds from, set to auto if unsure
waittime="00:15:00"		#* Default wait timer between slow checks, format: "HH:MM:SS"
slowwait="00:05:00"		#* Time between tests when slow speed has been detected, uses wait timer if unset, format: "HH:MM:SS"
idle="false"			#* If "true", resets timer if keyboard or mouse activity is detected in XServer
# idletimer="00:30:00"	#* If set and idle="true", the script uses this timer until first test, then uses standard wait time,
						#* any X Server activity resets back to idletimer, format: "HH:MM:SS"
displaypause="false"	#* If "true" automatically pauses timer when display is on, unpauses when off, overrides idle="true" if set, needs xset to work
main_menu_start="shown" #* The status of the main menu at start, possible values: "shown", "hidden"
loglevel=2				#* 0 : No logging
						#* 1 : Log only when slow speed has been detected
						#* 2 : Also log slow speed check
						#* 3 : Also log server updates
						#* 4 : Log all including forced tests
quiet_start="true"		#* If "true", don't print serverlist and routelist at startup
maxlogsize="1024"		#* Max logsize (in kilobytes) before log is rotated
# logcompress="gzip"	#* Command for compressing rotated logs, disabled if not set
# logname=""			#* Custom logfile (full path), if a custom logname is set, log rotation is disabled
max_buffer="1000"		#* Max number of lines to buffer in internal scroll buffer, set to 0 to disable, disabled if use_shm="false"
buffer_save="true"		#* Save buffer to disk on exit and restore on start
mtr="true"				#* Set "false" to disable route testing with mtr, automatically set to "false" if mtr is not found in PATH
mtr_internal="true"		#* Use hosts from full test in mtr test
mtr_internal_ok="false"	#* Use hosts from full test with speeds above $slowspeed, set to false to only test hosts with speed below $slowspeed
# mtr_internal_max=""	#* Set max hosts to add from internal list
mtr_external="false"	#* Use hosts from route.cfg.sh, see route.cfg.sh.sample for formatting
mtrpings="25"			#* Number of pings sent with mtr
paused="false"			#* If "true", the timer is paused at startup, ignored if displaypause="true"
startuptest="false"		#* If "true" and paused="false", tests speed at startup before timer starts
testonly="false" 		#* If "true", never enter UI mode, always run full tests and quit
testnum=1				#* Number of times to loop full tests in testonly mode

trace_errors="true" #? Remove!

ookla_speedtest="speedtest"						#* Command or full path to official speedtest client 
spdtest_grcconf="./grc/grc.conf"				#* Path to grc color config

#! Variables below are for internal function, don't change unless you know what you are doing
if [[ -w /dev/shm ]]; then temp="/dev/shm"; else temp="/tmp" ; fi
secfile="${temp}/spdtest-sec.$$"
speedfile="${temp}/spdtest-speed.$$"
routefile="${temp}/spdtest-route.$$"
tmpout="${temp}/spdtest-tmpout.$$"

bufferfile="${temp}/spdtest-buffer.$$"
declare -x colorize_input
grc_err=0
getIdle_err=0
if [[ -z $DISPLAY ]]; then declare -x DISPLAY=":0"; fi
ulimit -s 65536
startup=1
forcetest=0
detects=0
slowgoing=0
startupdetect=0
idledone=0
updatesec=0
idlebreak=0
broken=0
updateservers=0
times_tested=0
pausetoggled=0
slowerror=0
stype=""
speedstring=""
chars="/-\|"
escape_char=$(printf "\u1b")
charx=0
animx=1
animout=""
bufflen=0
scrolled=0
logfile=""
buffsize=0
buffpos=0
buffpid=""
trace_msg=""
scroll_symbol=""
drawm_ltitle="" 
drawm_lcolor=""
declare -a trace_array
err=""
menuypos=1
main_menu=""
main_menu_len=0
menu_status=0
proc_nd=""
timer_menu=0
#? Menu format "Text".<underline position>."color"
menu_array=(
	"Quit.1.red"
	"Menu.1.yellow"
	"Help.1.blue"
	"Timer.4.green"
	"Idle.1.magenta"
	"Pause.1.yellow"
	"Test.1.green"
	"Force test.1.cyan"
	"Update servers.1.magenta"
	"Clear buffer.1.yellow"
	)
if command -v less >/dev/null 2>&1; then less="true"; menu_array+=("View log.1.cyan"); else less="false"; fi
timer_array=(
	"← Exit.3.yellow"
	"Add Hour.5.green"
	"Rem hour.5.red"
	"Add Minute.5.green"
	"Rem minute.5.red"
	"Add Second.5.green"
	"Rem second.5.red"
	"Save.2.yellow"
	"Reset.1.cyan"
	)
width=$(tput cols)
height=$(tput lines)
precheck_status=""
precheck_samplet=${precheck_samplet:-5}
mtr_internal_max=${mtr_internal_max:-$numslowservers}
declare -a routelista; declare -a routelistb; declare -a routelistc
declare -A routelistdesc; declare -A routelistport
declare -a testlista; declare -A testlistdesc
declare -a rndbkp
declare -a errorlist
declare -A was_list
declare -A old_list
cd "$(dirname "$(readlink -f "$0")")" || { echo "Failed to set working directory"; exit 1; }
if [[ -e server.cfg.sh ]]; then servercfg="server.cfg.sh"; else servercfg="/dev/null"; fi
if [[ -e /dev/urandom ]]; then rnd_src="--random-source=/dev/urandom"; else rnd_src=""; fi
if (( max_buffer>0 & max_buffer<(height*2) )); then max_buffer=$((height*2)); fi
if [[ $main_menu_start == "shown" ]]; then menu_status=1; fi

#? Colors
reset="\e[0m"
bold="\e[1m"
ul="\e[4m"
blink="\e[5m"
reverse="\e[7m"
dark="\e[2m"
italic="\e[3m"

black="\e[30m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cyan="\e[36m"
white="\e[37m"

bgr="${reset}${dark}├${reset}${bold}"
bgl="${reset}${dark}┤${reset}${bold}"
bgls="${reset}${dark}─┤${reset}${bold}"
bgs="${reset}${dark}─${reset}${bold}"

declare -x colorize_config #? Settings for colorize function, standard grc config formatting
read -r -d '' colorize_config <<'EOF'
# Color settings for colorize
#mtr
# 0 Full Line | 1 Loss | 2 Snt | 3 Last | 4 Avg | 5 Best | 6 Worst | 7 stDev
regexp=(\d+\.\d%)\s+(\d+)\s+(\d+\.\d)\s+(\d+\.\d)\s+(\d+\.\d)\s+(\d+\.\d)\s+(\d+\.\d)$
colours=unchanged,yellow,unchanged,unchanged,blue,green,red,unchanged
=======
# unknow host
regexp=\?\?\?
colours=red
=======
# Packets/Pings
regexp=(Packets|Pings)
colours=bold green
=======
# spdtest.sh
# error text
regexp=(ERROR:).*($)
colours=bold white
count=more
======
# error red
regexp=(ERROR:)
colours=bold red
count=more
======
# warning text
regexp=(WARNING:).*($)
colours=bold white
count=more
======
# warning yellow
regexp=(WARNING:)
colours=bold yellow
count=more
======
# info text
regexp=(INFO:).*($)
colours=bold white
count=more
======
# info green
regexp=(INFO:)
colours=bold green
count=more
======
# everything in parentheses
regexp=\(.+?\)
colours=bold green
count=more
======
# everything in < >
regexp=\<.+?\>
colours=bold yellow
count=more
======
# slow speed arrows
regexp=(<-*)Slow speed detected!(-*>)
colours=bold red
count=more
======
# slow speed text
regexp=(Slow speed detected!)
colours=bold white
count=more
======
# normal speed arrows
regexp=(<-*)Speeds normal!(-*>)
colours=bold green
count=more
======
# normal speed text
regexp=(Speeds normal!)
colours=bold white
count=more
======
# ip number
regexp=\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}
colours=bold green
count=more
======
# ok green
regexp=(OK!)
colours=bold green
count=more
======
# fail red
regexp=(FAIL!)
colours=bold red
count=more
======
# mbps mb/s
regexp=(\d*\s+)(Mbps|MB\/s)
colours=bold white
count=more
======
# progress start
regexp=(\[=*)
colours=bold white
count=more
======
# progress end
regexp=(=*\])
colours=bold white
count=more
======
# column titles
regexp=(Down).*(Server)
colours=bold white
count=more
======
# Arrow and text
regexp=(<--).*(\d)
colours=bold white
count=more
======
# DOWN=
regexp=(DOWN=)
colours=bold green
count=more
======
# UP=
regexp=(UP=)
colours=bold red
count=more
======
# Less title
regexp=(Viewing).*(= Help)
colours=bold white
count=more
EOF

#? End variables -------------------------------------------------------------------------------------------------------------------->

if [[ -z $ookla_speedtest ]]; then ookla_speedtest="speedtest"; fi
if [[ ! $(speedtest -V | head -n1) =~ "Speedtest by Ookla" ]]; then
	echo "ERROR: Ookla speedtest client not found!"; exit 1
fi

if [[ $mtr == "true" ]] && ! command -v mtr >/dev/null 2>&1; then mtr="false"; fi

#? Start argument parsing ------------------------------------------------------------------------------------------------------------------>
argumenterror() { #? Handles argument errors
	echo -n "ERROR: "
	case $1 in
		general) echo -e "$2 not a valid option" ;;
		server-config) echo "Can't find server config, use with flag -gs to create a new file" ;;
		missing) echo -e "$2 missing argument" ;;
		wrong) echo -e "$3 not a valid modifier for $2" ;;
	esac
	echo -e "$0 -h, --help \tShows help information"
	exit 0
}

# re='^[0-9]+$'
while [[ $# -gt 0 ]]; do #? @note Parse arguments
	case $1 in
		-t|--test)
			testonly="true"
			if [[ -n $2 && ${2::1} != "-" ]]; then testnum="$2"; shift; fi
			testnum=${testnum:-1}
		;;
		-u|--unit)
			if [[ $2 == "mbyte" || $2 == "mbit" ]]; then unit="$2"; shift
			else argumenterror "wrong" "$1" "$2"; fi	
		;;
		-s|--slow-speed)
			if [[ -n $2 && ${2::1} != "-" ]]; then slowspeed="$2"; shift
			else argumenterror "missing" "$1"; fi
		;;
		-l|--loglevel)
			if [[ -n $2 && ${2::1} != "-" ]]; then loglevel="$2"; shift
			else argumenterror "missing" "$1"; fi
		;;
		-lf|--log-file)
			if [[ -n $2 && ${2::1} != "-" ]]; then logname="$2"; shift
			else argumenterror "missing" "$1"; fi
		;;
		-i|--interface)
			if [[ -n $2 && ${2::1} != "-" ]]; then net_device="$2"; shift
			else argumenterror "missing" "$1"; fi
		;;
		-p|--paused)
			paused="true"
		;;
		-n|--num-servers)
			if [[ -n $2 && ${2::1} != "-" ]]; then numservers="$2"; shift
			else argumenterror "missing" "$1"; fi
		;;
		-gs|--gen-server-cfg)
			updateservers=3
			genservers="true"
			servercfg=server.cfg.sh
			shift
		;;
		-sc|--server-config)
			if [[ -e $2 ]] || [[ $updateservers == 3 ]]; then servercfg="$2"; shift
			else argumenterror "server-config"; fi
		;;
		-wt|--wait-time)
			waittime="$2"
			shift
		;;
		-st|--slow-time)
			slowwait="$2"
			shift
		;;
		-x|--x-reset)
			idle="true"
			if [[ -n $2 && ${2::1} != "-" ]]; then idletimer="$2"; shift; fi
		;;
		-d|--display-pause)
			displaypause="true"
		;;
		--debug)
			debug=true
		;;
		--trace)
			trace_errors="true"
		;;
		-h|--help)
			echo -e "USAGE: $0 [OPTIONS]"
			echo ""
			echo -e "OPTIONS:"
			echo -e "\t-t, --test num              Runs full test 1 or <x> number of times and quits"
			echo -e "\t-u, --unit mbit/mbyte       Which unit to show speed in, valid units are mbit or mbyte [default: mbit]"
			echo -e "\t-s, --slow-speed speed      Defines what speed in defined unit that will trigger more tests"
			echo -e "\t-n, --num-servers num       How many of the closest servers to get from speedtest.net"
			echo -e "\t-i, --interface name        Network interface being used [default: auto]"
			echo -e "\t-l, --loglevel 0-3          0 No logging"
			echo -e "\t                            1 Log only when slow speed has been detected"
			echo -e "\t                            2 Also log slow speed check and server update"
			echo -e "\t                            3 Log all including forced tests"
			echo -e "\t-lf, --log-file file        Full path to custom logfile, no log rotation is done on custom logfiles"
			echo -e "\t-p, --paused                Sets timer to paused state at startup"
			echo -e "\t-wt, --wait-time HH:MM:SS   Time between tests when NO slowdown is detected [default: 00:10:00]"
			echo -e "\t-st, --slow-time HH:MM:SS   Time between tests when slowdown has been detected, uses wait timer if unset"
			echo -e "\t-x, --x-reset [HH:MM:SS]    Reset timer if keyboard or mouse activity is detected in X Server"
			echo -e "\t                            If HH:MM:SS is included, the script uses this timer until first test, then uses"
			echo -e "\t                            standard wait time, any activity resets to idle timer [default: unset]"
			echo -e "\t-d, --display-pause         Automatically pauses timer when display is on, unpauses when off"
			echo -e "\t-gs, --gen-server-cfg num   Writes <x> number of the closest servers to \"server.cfg.sh\" and quits"
			echo -e "\t                            Servers aren't updated automatically at start if \"server.cfg.sh\" exists"
			echo -e "\t-sc, --server-config file   Reads server config from <file> [default: server.cfg.sh]"
			echo -e "\t                            If used in combination with -gs a new file is created"
			echo -e "\t-h, --help                  Shows help information"
			echo -e "CONFIG:"
			echo -e "\t                            Note: All config files should be stored in same folder as main script"
			echo -e "\tspdtest.sh                  Options can be permanently set in the Variables section of main script"
			echo -e "\t[server.cfg.sh]             Stores server id's to use with speedtest, delete to refresh servers on start"
			echo -e "\t[route.cfg.sh]              Additional hosts to test with mtr"
			echo -e "LOG:"
			echo -e "\t                            Logs are named spdtest<date>.log and saved in ./log folder of main script"
			exit 0
		;;
		*)
			argumenterror "general" "$1"
		;;
	esac
	shift
done


if ((loglevel>4)); then loglevel=4; fi
if [[ $unit = "mbyte" ]]; then unit="MB/s"; unitop="1"; else unit="Mbps"; unitop="8"; fi
if [[ $displaypause == "true" ]]; then idle="false"; fi


#? End argument parsing ------------------------------------------------------------------------------------------------------------------>

#? Start functions ------------------------------------------------------------------------------------------------------------------>

network_init() { #? Open SSH control master and get network devices if set to "auto", otherwise check that devices are valid
if [[ $net_device == "auto" ]]; then
	net_device=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
else
	# shellcheck disable=SC2013
	for good_device in $(grep ":" /proc/net/dev | awk '{print $1}' | sed "s/:.*//"); do
		if [[ "$net_device" = "$good_device" ]]; then is_good=1; break; fi
	done
	if not is_good; then
			echo "Net device \"$net_device\" not found. Should be one of these:"
			grep ":" /proc/net/dev | awk '{print $1}' | sed "s/:.*//"
			exit 1
	fi
	unset is_good good_device
fi

if [[ -n $precheck_ssh_host && -n $precheck_ssh_user ]]; then
	precheck_ssh="${precheck_ssh_user}@${precheck_ssh_host}"
	if ! ping -qc1 -w5 "$precheck_ssh_host" > /dev/null 2>&1; then echo "Could not reach remote machine \"$precheck_ssh\""; exit 1; fi
	ssh_socket="$temp/spdtest.ssh_socket.$$"
	ssh -fN -o 'ControlMaster=yes' -o 'ControlPersist=1h' -S "$ssh_socket" "$precheck_ssh"
	if ! ssh -S "$ssh_socket" -O check "$precheck_ssh" >/dev/null 2>&1; then echo "Could not connect to remote machine \"$precheck_ssh\""; exit 1; fi
	if [[ $precheck_ssh_nd == "auto" || -z $precheck_ssh_nd ]]; then
		precheck_ssh_nd=$(ssh -S "$ssh_socket" "$precheck_ssh" 'ip route')
		precheck_ssh_nd=$(echo "$precheck_ssh_nd" | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
	else
		is_good=0; ssh_grep=$(ssh -S "$ssh_socket" "$precheck_ssh" 'grep ":" /proc/net/dev')
		for good_device in $(echo "$ssh_grep" | awk '{print $1}' | sed "s/:.*//"); do
			if [[ "$precheck_ssh_nd" = "$good_device" ]]; then is_good=1; break; fi
		done
		if not is_good; then
			echo "Remote machine net device \"$precheck_ssh_nd\" not found. Should be one of these:"
			echo "$ssh_grep" | awk '{print $1}' | sed "s/:.*//"
			exit 1
		fi
	fi
	proc_nd="$precheck_ssh_nd"
else
	proc_nd="$net_device"
fi
}

assasinate() { #? Silently kill running process if not already dead
	local i
	for i in "$@"; do
	if kill -0 "$i" >/dev/null 2>&1; then kill "$i" >/dev/null 2>&1; fi 
	done
}


ax_anim() { #? Gives a character for printing loading animation, arguments: <x> ;Only prints if "x" equals counter
			if ((animx==$1)); then
				if ((charx>=${#chars})); then charx=0; fi
				animout="${chars:$charx:1}"; ((++charx)); animx=0
			fi
			((++animx))
}

buffer() { #? Buffer control, arguments: add/up/down/pageup/pagedown/redraw/clear ["text to add to buffer"][scroll position], no argument returns exit codes for buffer availability
	if [[ -z $1 ]] && ((max_buffer<=buffsize)); then return 1
	elif [[ -z $1 ]] && ((max_buffer>buffsize)); then return 0
	elif ((max_buffer<=buffsize)); then return; fi

	local buffout scrtext y x
	bufflen=$(wc -l <"$bufferfile")

	old scrolled save

	if [[ $1 == "add" && -n $2 ]]; then
		local addlen addline buffer
		scrolled=0
		addline="$2"
		addlen=$(echo -en "$addline" | wc -l)
		if ((addlen>=max_buffer)); then echo -e "$(echo -e "$addline" | tail -n"$max_buffer")\n" > "$bufferfile"
		elif (( bufflen+addlen>max_buffer )); then buffer="$(tail -n$(((max_buffer-addlen)-(max_buffer/10))) <"$bufferfile")\n$addline"; echo -e "$buffer" > "$bufferfile"
		else echo -e "${buffer}${addline}" >> "$bufferfile"
		fi
		bufflen=$(wc -l <"$bufferfile")
		drawscroll
		return

	elif [[ $1 == "up" ]] && ((bufflen>buffsize & scrolled<bufflen-buffsize-1)); then ((++scrolled))

	elif [[ $1 == "down" ]] && ((scrolled>0)); then ((scrolled--))
	
	elif [[ $1 == "pageup" ]] && ((bufflen>buffsize & scrolled<bufflen-buffsize-1)); then scrolled=$((scrolled+buffsize))
		if ((scrolled>=bufflen-buffsize-1)); then scrolled=$((bufflen-buffsize-1)); fi
	
	elif [[ $1 == "pagedown" ]] && ((scrolled>0)); then scrolled=$((scrolled-buffsize))
		if ((scrolled<0)); then scrolled=0; fi

	elif [[ $1 == "home" ]] && ((bufflen>buffsize & scrolled<bufflen-buffsize-1)); then scrolled=$((bufflen-buffsize-1))

	elif [[ $1 == "end" ]] && ((scrolled>0)); then scrolled=0

	elif [[ $1 == "redraw" ]]; then scrolled=${2:-$scrolled}
		if ((scrolled>=bufflen-buffsize-1)); then scrolled=$((bufflen-buffsize-1)); fi
		
	elif [[ $1 == "clear" ]]; then
		true > "$bufferfile"
		scrolled=0
		tput cup $buffpos 0; tput ed
		drawscroll
		return
	fi

	if old scrolled same && [[ $1 != "redraw" ]]; then return; fi

	buffout="$(buffline)"
	tput cup $buffpos 0; tput ed
	echo -e "$buffout"
	if now testing; then echo; fi
	drawscroll

	#sleep 0.001
}

buffline() { #? Get current buffer from scroll position and window height, cut off text wider than window width
	echo -e "$(<$bufferfile)" | tail -n$((buffsize+scrolled)) | head -n "$buffsize" | cut -c -"$((width-1))" | colorize
}

bury() { #? Silently remove files
	local i
	for i in "$@"; do
	rm "$i" >/dev/null 2>&1
	done
}

colorize() { #? Make the text pretty using a slightly modified version of grc, usage colorize "text" ["<file"]
	declare -x colorize_input=${1:-$(</dev/stdin)}
	if [[ -z $colorize_input ]]; then return; fi
	if [[ $2 == "<file" ]]; then 
		fileline="open(inputvar, 'r')"
	else
		fileline="io.StringIO(inputvar)"
	fi
	if ((grc_err>=10)); then echo -e "$input"; return; fi
python3 - << EOF #? Unmodified source for grc at https://github.com/garabik/grc
from __future__ import print_function
import sys, os, string, re, signal, errno, io
colours = {'none':"", 'default':"\033[0m", 'bold':"\033[1m", 'underline':"\033[4m", 'blink':"\033[5m", 'reverse':"\033[7m", 'concealed':"\033[8m",
			'black':"\033[30m",  'red':"\033[31m", 'green':"\033[32m", 'yellow':"\033[33m", 'blue':"\033[34m", 'magenta':"\033[35m", 'cyan':"\033[36m", 'white':"\033[37m",
			'previous':"prev", 'unchanged':"unchanged", 'dark':"\033[2m", 'italic':"\033[3m", 'rapidblink':"\033[6m", 'strikethrough':"\033[9m",}
signal.signal(signal.SIGINT, signal.SIG_IGN)
def add2list(clist, m, patterncolour):
	for group in range(0, len(m.groups()) +1):
		if group < len(patterncolour):
			clist.append((m.start(group), m.end(group), patterncolour[group]))
		else:
			clist.append((m.start(group), m.end(group), patterncolour[0]))
def get_colour(x):
	if x in colours:
		return colours[x]
	elif len(x)>=2 and x[0]=='"' and x[-1]=='"':
		return eval(x)
	else:
		raise ValueError('Bad colour specified: '+x)
regexplist = []
conffile = os.environ.get('colorize_config')
f = io.StringIO(conffile)
is_last = 0
split = str.split
lower = str.lower
letters = string.ascii_letters
while not is_last:
	ll = {'count':"more"}
	while 1:
		l = f.readline()
		if l == "": 
			is_last = 1
			break
		if l[0] == "#" or l[0] == '\012':
			continue
		if not l[0] in letters:
			break
		fields = split(l.rstrip('\r\n'), "=", 1)
		if len(fields) != 2:
			sys.stderr.write('Error in grc config\n')
			sys.exit(1)
		keyword, value = fields
		keyword = lower(keyword)
		if keyword in  ('colors', 'colour', 'color'):
			keyword = 'colours'
		if not keyword in ["regexp", "colours", "count", "command", "skip", "replace", "concat"]:
			raise ValueError("Invalid keyword")
		ll[keyword] = value
	if 'colours' in ll:
		colstrings = list([''.join([get_colour(x) for x in split(colgroup)]) for colgroup in split(ll['colours'], ',')])
		ll['colours'] = colstrings
	cs = ll['count']
	if 'regexp' in ll:
		ll['regexp'] = re.compile(ll['regexp']).search
		regexplist.append(ll)
prevcolour = colours['default']
prevcount = "more"
blockflag = 0
inputvar = os.environ.get('colorize_input')
# inputstring = io.StringIO(inputvar)
inputstring = $fileline
while 1:
	line = inputstring.readline()
	if line == "" :
		break
	if line[-1] in '\r\n':
		line = line[:-1]
	clist = []
	skip = 0
	for pattern in regexplist:
		pos = 0
		currcount = pattern['count']
		while 1:
			m = pattern['regexp'](line, pos)
			if m:
				if 'replace' in pattern:
					line = re.sub(m.re, pattern['replace'], line)
				if 'colours' in pattern:
					if currcount == "block":
						blockflag = 1
						blockcolour = pattern['colours'][0]
						currcount = "stop"
						break
					elif currcount == "unblock":
						blockflag = 0
						blockcolour = colours['default']
						currcount = "stop"
					add2list(clist, m, pattern['colours'])
					if currcount == "previous":
						currcount = prevcount
					if currcount == "stop":
						break
					if currcount == "more":
						prevcount = "more"
						newpos = m.end(0)
						if newpos == pos:
							pos += 1
						else:
							pos = newpos
					else:
						prevcount = "once"
						pos = len(line)
				if 'concat' in pattern:
					with open(pattern['concat'], 'a') as f :
						f.write(line + '\n')
					if 'colours' not in pattern:
						break
				if 'command' in pattern:
					os.system(pattern['command'])
					if 'colours' not in pattern:
						break
				if 'skip' in pattern:
					skip = pattern['skip'] in ("yes", "1", "true")
					if 'colours' not in pattern:
						break
			else: break
		if m and currcount == "stop":
			prevcount = "stop"
			break
	if len(clist) == 0:
		prevcolour = colours['default']
	first_char = 0
	last_char = 0
	length_line = len(line)
	if blockflag == 0:
		cline = (length_line+1)*[colours['default']]
		for i in clist:
			if i[2] == "prev":
				cline[i[0]:i[1]] = [colours['default']+prevcolour]*(i[1]-i[0])
			elif i[2] != "unchanged":
				cline[i[0]:i[1]] = [colours['default']+i[2]]*(i[1]-i[0])
			if i[0] == 0:
				first_char = 1
				if i[2] != "prev":
					prevcolour = i[2]
			if i[1] == length_line:
				last_char = 1
		if first_char == 0 or last_char == 0:
			prevcolour = colours['default']
	else:
		cline = (length_line+1)*[blockcolour]
	nline = ""
	clineprev = ""
	if not skip:
		for i in range(len(line)):
			if cline[i] == clineprev: 
				nline = nline + line[i]
			else:
				nline = nline + cline[i] + line[i]
				clineprev = cline[i]
		nline = nline + colours['default']
		try:
			print(nline)
		except IOError as e:
			if e.errno == errno.EPIPE:
				break
			else:
				raise
EOF
	grc_err=$((grc_err+$?))
	if [[ $grc_err -ne 0 ]]; then echo -e "$input"; fi
}

contains() { #? Function for checking if a value is contained in an array, arguments: <"${array[@]}"> <"value">
	local i n value
	n=$#
	value=${!n}
	for ((i=1;i < $#;i++)) {
		if [[ "${!i}" == "${value}" ]]; then
			return 0
		fi
	}
	return 1
}

ctrl_c() { #? Catch ctrl-c and general exit function, abort if currently testing otherwise cleanup and exit
	if now testing; then
		assasinate "$speedpid" "$routepid"
		reset broken
		broken=1
		return
	else
		assasinate "$secpid" "$routepid" "$speedpid"
		bury "$secfile" "$speedfile" "$routefile" "$tmpout"
		if now buffer_save && [[ -e "$bufferfile" ]]; then cp -f "$bufferfile" .buffer >/dev/null 2>&1; fi
		bury "$bufferfile"
		if [[ -n $precheck_ssh ]] && ssh -S "$ssh_socket" -O check "$precheck_ssh" >/dev/null 2>&1; then ssh -S "$ssh_socket" -O exit "$precheck_ssh" >/dev/null 2>&1; fi
		tput clear; tput cvvis; stty echo; tput rmcup
		exit 0
	fi
}

deliver() {  #? Create file(s) if not created and set r/w for user only	
	local i
	for i in "$@"; do
	touch "$i"; chmod 600 "$i"; 
	done
}

drawm() { #? Draw menu and title, arguments: <"title text"> <bracket color> <sleep time>
	local curline tlength mline i il da
	if now testonly; then return; fi
	tput sc
	if now trace_errors; then tput cup 0 55; echo -en "$trace_msg"; fi

	if menu && wasnt testing && now testing; then gen_menu darken
	elif menu && was testing && not testing; then gen_menu
	fi
	#printf "${bold}${dark}%0$(tput cols)d" 0 | tr '0' '≡'
	
	echo -en "${dark}"
	for ((il=0;il<=titleypos;il++)); do
		tput cup $il 0
		for ((i=0;i<width;i++)) ; do echo -n "─"; done
	done
	echo -en "${reset}"
	tput cup 0 0
	if menu; then
		echo -en "$main_menu"
		tput cup "$titleypos" 0
	elif ! now testing; then
		echo -en "\e[1C$bgl${ul}${red}Q${reset}$bgr$bgl${ul}${yellow}M$bgr\e[1C"
	fi
	
	if now testing; then echo -en "${bold}\e[1C$bgl${ul}${yellow}C${reset}${bold}trl+${ul}${yellow}C$bgr\e[1C"; fi
	if ((detects>0)); then echo -en "\e[1C${bgl}${red}!${white}=$detects${bgr}"; fi
	
	if [[ -n $scroll_symbol ]]; then drawscroll_symbol; fi
	
	if [[ -n $1 ]]; then
		drawm_ltitle="$1"; drawm_lcolor="$2"
		tput cup "$titleypos" $(( (width / 2)-(${#1} / 2) ))
		echo -en "${reset}${2:-$dark}┤${reset}${bold}${white}${1}${reset}${2:-$dark}├${reset}"
		sleep "${3:-0}"
	fi
	tput rc
	# drawscroll
}

drawscroll() { #? Draw scrollbar
	tput sc
	if ((scrolled>0 & scrolled<bufflen-buffsize-1)); then scroll_symbol="↕"
	elif ((scrolled>0 & scrolled==bufflen-buffsize-1)); then scroll_symbol="↓"
	elif ((scrolled==0 & bufflen>buffsize)); then scroll_symbol="↑"
	else return; fi

	drawscroll_symbol

	if ((scrolled>0 & scrolled<=bufflen-buffsize-1)); then 
		y=$(echo "scale=2; $scrolled / ($bufflen-$buffsize) * ($buffsize+1)" | bc); y=${y%.*}; y=$(( (buffsize-y)+buffpos ))
		tput cup "$y" $((width-1)); echo -en "${bold}▒${reset}"
	fi
	tput rc
}

drawscroll_symbol() { #? Draw scroll direction arrow in titlebar
	local da
	if now testing; then da="$dark"; fi
	tput cup $titleypos $((width-4)); echo -en "${dark}┤${reset}${da}$scroll_symbol${dark}├${reset}"
}

gen_menu() { #? Generate main menu and adapt for window width
	local i menuconv underpos color mend nline nlinex tmp_array no_color darken ult="$ul"
	if now paused; then paustate="${yellow}On"; else paustate="${dark}Off"; fi
	if now idle; then idlstate="${magenta}On"; else idlstate="${dark}Off"; fi

	tmp_array=("${menu_array[@]}")

	
	if now timer_menu; then no_color=1; exp_menu="Timer"; tmp_array+=( "\n" "${timer_array[@]}" ); fi
	
	main_menu="\e[1C${bold}"; menuconv=1; nlinex=1

	for i in "${tmp_array[@]}"; do
		if [[ $i == "\n" ]]; then 
			menuconv=$(( (width*nlinex) +1 )); ((++nlinex))
			main_menu="${main_menu}\n\e[1C"
			no_color=0
		else	
			if [[ $1 == "darken" ]] || now no_color && [[ ! ${i%%.*} == "Quit" ]]; then darken="$dark"; color="dark"; ult=""

			else darken=""; color=${i##*.*.}; fi

			i=${i%.*}
			underpos=$((${i##*.}-1)); i=${i%.*}

			if ([[ $i == "Pause" ]] && now paused) || ([[ $i == "Idle" ]] && now idle); then menuconv=$((menuconv+3))
			elif ([[ $i == "Pause" ]] && not paused) || ([[ $i == "Idle" ]] && not idle); then menuconv=$((menuconv+4)); fi

			menuconv=$((menuconv+${#i}+2)); if ((menuconv>=width*nlinex)); then nline="\n\e[1C"; menuconv=$(( (width*nlinex) +1 )); ((++nlinex)); else nline=""; fi

			if [[ $i == "Pause" ]]; then i="$i ${!color}$paustate"; elif [[ $i == "Idle" ]]; then i="$i ${!color}$idlstate"; fi

			if ((underpos>0)); then i="${darken}${i:0:$((underpos))}${ult}${!color}${i:$underpos:1}${reset}${darken}${bold}${i:$((underpos+1))}"
			else i="${ult}${!color}${i:0:1}${reset}${darken}${bold}${i:$((underpos+1))}"; fi

			main_menu="${main_menu}${nline}${bgl}${i}${bgr}"
		fi
	done

	if ((main_menu_len<menuconv)); then main_menu_len=$menuconv; redraw calc
	elif ((main_menu_len>menuconv)); then main_menu_len=$menuconv; redraw calc; buffer redraw; fi
}

getcspeed() { #? Get current $net_device bandwith usage, arguments: <"down"/"up"> <sample time in seconds> <["get"][value from previous get]>
	local line svalue speed total awkline slp=${2:-3} sdir=${1:-down}
	# shellcheck disable=SC2016
	if [[ $sdir == "down" ]]; then awkline='{print $1}'
	elif [[ $sdir == "up" ]]; then awkline='{print $9}'
	else return; fi
	svalue=$(getproc | sed "s/.*://" | awk "$awkline")
	if [[ $3 == "get" ]]; then echo "$svalue"; return; fi
	if [[ -n $3 && $3 != "get" ]]; then speed=$(echo "($svalue - $3) / $slp" | bc); echo $(((speed*unitop)>>20)); return; fi
	total=$((svalue))
	sleep "$slp"
	svalue=$(getproc | sed "s/.*://" | awk "$awkline")
	speed=$(echo "($svalue - $total) / $slp" | bc)
	echo $(((speed*unitop)>>20))
}

getIdle() { #? Returns current XServer idle time in seconds
if ((getIdle_err>=10)); then return; fi
python3 - << EOF
import ctypes, os
class XScreenSaverInfo(ctypes.Structure):
    _fields_ = [('window',      ctypes.c_ulong), ('state',       ctypes.c_int), ('kind',        ctypes.c_int), ('since',       ctypes.c_ulong), ('idle',        ctypes.c_ulong), ('event_mask',  ctypes.c_ulong)]
xlib = ctypes.cdll.LoadLibrary( 'libX11.so')
xlib.XOpenDisplay.argtypes = [ctypes.c_char_p]
xlib.XOpenDisplay.restype = ctypes.c_void_p
xlib.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
xlib.XDefaultRootWindow.restype = ctypes.c_uint32
dpy = xlib.XOpenDisplay(None)
root = xlib.XDefaultRootWindow(dpy)
xss = ctypes.cdll.LoadLibrary( 'libXss.so')
xss.XScreenSaverQueryInfo.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.POINTER(XScreenSaverInfo)]
xss.XScreenSaverQueryInfo.restype = ctypes.c_int
xss.XScreenSaverAllocInfo.restype = ctypes.POINTER(XScreenSaverInfo)
xss_info = xss.XScreenSaverAllocInfo()
xss.XScreenSaverQueryInfo( dpy, root, xss_info)
print( "%d" %(xss_info.contents.idle / 1000) )
EOF
getIdle_err=$((getIdle_err+$?))
}

getproc() { #? Get /proc/dev/net 
	if [[ -n $precheck_ssh ]]; then
		ssh -S "$ssh_socket" "$precheck_ssh" "grep $proc_nd /proc/net/dev"
	else
		grep "$proc_nd" /proc/net/dev
	fi	
}

getservers() { #? Gets servers from speedtest-cli and optionally saves to file
	unset 'testlista[@]'
	unset 'testlistdesc[@]'
	unset 'routelista[@]'
	unset 'routelistadesc[@]'
	local num IFS=$'\n'
	num=1

	if [[ $quiet_start = "true" && $loglevel -ge 3 ]]; then bkploglevel=$loglevel; loglevel=103
	elif [[ $quiet_start = "true" && $loglevel -lt 3 ]]; then bkploglevel=$loglevel; loglevel=1000; fi

	if [[ -e $servercfg && $servercfg != "/dev/null" && $updateservers = 0 ]]; then
		source "$servercfg"
		writelog 3 "\nUsing servers from $servercfg"
		for tl in "${testlista[@]}"; do
			writelog 3 "$num. ${testlistdesc["$tl"]}"
			((++num))
		done
	else
		echo "#? Automatically generated server list, servers won't be refreshed at start if this file exists" >> "$servercfg"
		getservers_cli "$numservers" > $tmpout &
		waiting $! "Fetching servers"; tput el
		speedlist=$(<"$tmpout")
		true > "$tmpout"
		writelog 3 "Using servers:         "
		for line in $speedlist; do
			servnum=${line:0:5}
			servnum=${servnum%)}
			servnum=${servnum# }
			testlista+=("$servnum")
			servlen=$((${#line} - 6))
			servdesc=${line:(-servlen)}
			servdesc=${servdesc# }
			testlistdesc["$servnum"]="$servdesc"
			echo -e "testlista+=(\"$servnum\");\t\ttestlistdesc[\"$servnum\"]=\"$servdesc\"" >> "$servercfg"
			writelog 3 "$num. $servdesc"
			((++num))
		done
	fi
	if [[ $numslowservers -ge $num ]]; then numslowservers=$((num-1)); fi
	numslowservers=${numslowservers:-$((num-1))}
	writelog 3 "\n "
	if [[ -e route.cfg.sh && $startup == 1 && $genservers != "true" && $mtr == "true" && $mtr_external == "true" ]]; then
		# shellcheck disable=SC1091
		source route.cfg.sh
		writelog 3 "Hosts in route.cfg.sh:"
		
		for i in "${routelista[@]}"; do
			writelog 3 "(${routelistdesc["$i"]}): $i"
		done
		writelog 3 "\n"
	fi

	if [[ $quiet_start = "true" ]]; then loglevel=$bkploglevel; fi
}

getservers_cli() { #? Modified and heavly compacted version of speedtest-cli, unmodified source at https://github.com/sivel/speedtest-cli
						#? Only used to fetch serverlist in order of closest server, usage: getserver_cli [number of servers]
						#? APACHE LICENSE v2.0 https://www.apache.org/licenses/LICENSE-2.0
local num="${1:-0}"
python3 - << EOF
# -*- coding: utf-8 -*-
import os, re, sys, math, errno, signal, socket, timeit, datetime, platform, threading, gzip
GZIP_BASE = gzip.GzipFile
__version__ = '2.1.2'
class FakeShutdownEvent(object):
	@staticmethod
	def isSet():
		return False
DEBUG = False
_GLOBAL_DEFAULT_TIMEOUT = object()
import xml.etree.ElementTree as ET
from urllib.request import urlopen, Request, HTTPError, URLError, AbstractHTTPHandler, ProxyHandler, HTTPDefaultErrorHandler, HTTPRedirectHandler, HTTPErrorProcessor, OpenerDirector
from http.client import HTTPConnection, BadStatusLine, HTTPSConnection
FakeSocket = None
from queue import Queue
from urllib.parse import parse_qs, urlparse
from hashlib import md5
from optparse import OptionParser as ArgParser, SUPPRESS_HELP as ARG_SUPPRESS
PARSER_TYPE_INT = 'int'
PARSER_TYPE_STR = 'string'
PARSER_TYPE_FLOAT = 'float'
from io import StringIO, BytesIO
from xml.dom import minidom as DOM
from xml.parsers.expat import ExpatError
etree_iter = ET.Element.iter
import ssl
CERT_ERROR = (ssl.CertificateError,)
HTTP_ERRORS = ((HTTPError, URLError, socket.error, ssl.SSLError, BadStatusLine) + CERT_ERROR)
class SpeedtestException(Exception):
	"""Base exception for this module"""
class SpeedtestHTTPError(SpeedtestException):
	"""Base HTTP exception for this module"""
class SpeedtestConfigError(SpeedtestException):
	"""Configuration XML is invalid"""
class SpeedtestServersError(SpeedtestException):
	"""Servers XML is invalid"""
class ConfigRetrievalError(SpeedtestHTTPError):
	"""Could not retrieve config.php"""
class ServersRetrievalError(SpeedtestHTTPError):
	"""Could not retrieve speedtest-servers.php"""
class InvalidServerIDType(SpeedtestException):
	"""Server ID used for filtering was not an integer"""
class NoMatchedServers(SpeedtestException):
	"""No servers matched when filtering"""
class SpeedtestHTTPConnection(HTTPConnection):
	def __init__(self, *args, **kwargs):
		source_address = kwargs.pop('source_address', None)
		timeout = kwargs.pop('timeout', 10)
		HTTPConnection.__init__(self, *args, **kwargs)
		self.source_address = source_address
		self.timeout = timeout
	def connect(self):
		self.sock = socket.create_connection((self.host, self.port), self.timeout, self.source_address)
if HTTPSConnection:
	class SpeedtestHTTPSConnection(HTTPSConnection):
		default_port = 443
		def __init__(self, *args, **kwargs):
			source_address = kwargs.pop('source_address', None)
			timeout = kwargs.pop('timeout', 10)
			self._tunnel_host = None
			HTTPSConnection.__init__(self, *args, **kwargs)
			self.timeout = timeout
			self.source_address = source_address
		def connect(self):
			"Connect to a host on a given (SSL) port."
			self.sock = socket.create_connection((self.host, self.port), self.timeout, self.source_address)
			if ssl:
				try:
					kwargs = {}
					if hasattr(ssl, 'SSLContext'):
						if self._tunnel_host:
							kwargs['server_hostname'] = self._tunnel_host
						else:
							kwargs['server_hostname'] = self.host
					self.sock = self._context.wrap_socket(self.sock, **kwargs)
				except AttributeError:
					self.sock = ssl.wrap_socket(self.sock)
					try:
						self.sock.server_hostname = self.host
					except AttributeError:
						pass
def _build_connection(connection, source_address, timeout, context=None):
	def inner(host, **kwargs):
		kwargs.update({'source_address': source_address, 'timeout': timeout})
		if context:
			kwargs['context'] = context
		return connection(host, **kwargs)
	return inner
class SpeedtestHTTPHandler(AbstractHTTPHandler):
	def __init__(self, debuglevel=0, source_address=None, timeout=10):
		AbstractHTTPHandler.__init__(self, debuglevel)
		self.source_address = source_address
		self.timeout = timeout
	def http_open(self, req):
		return self.do_open(
			_build_connection(SpeedtestHTTPConnection, self.source_address, self.timeout), req)
	http_request = AbstractHTTPHandler.do_request_
class SpeedtestHTTPSHandler(AbstractHTTPHandler):
	def __init__(self, debuglevel=0, context=None, source_address=None, timeout=10):
		AbstractHTTPHandler.__init__(self, debuglevel)
		self._context = context
		self.source_address = source_address
		self.timeout = timeout
	def https_open(self, req):
		return self.do_open(
			_build_connection(SpeedtestHTTPSConnection, self.source_address, self.timeout, context=self._context,), req)
	https_request = AbstractHTTPHandler.do_request_
def build_opener(source_address=None, timeout=10):
	if source_address:
		source_address_tuple = (source_address, 0)
	else:
		source_address_tuple = None
	handlers = [ProxyHandler(), SpeedtestHTTPHandler(source_address=source_address_tuple, timeout=timeout), SpeedtestHTTPSHandler(source_address=source_address_tuple, timeout=timeout), HTTPDefaultErrorHandler(), HTTPRedirectHandler(), HTTPErrorProcessor()]
	opener = OpenerDirector()
	opener.addheaders = [('User-agent', build_user_agent())]
	for handler in handlers:
		opener.add_handler(handler)
	return opener
class GzipDecodedResponse(GZIP_BASE):
	def __init__(self, response):
		IO = BytesIO or StringIO
		self.io = IO()
		while 1:
			chunk = response.read(1024)
			if len(chunk) == 0:
				break
			self.io.write(chunk)
		self.io.seek(0)
		gzip.GzipFile.__init__(self, mode='rb', fileobj=self.io)
	def close(self):
		try:
			gzip.GzipFile.close(self)
		finally:
			self.io.close()
def get_exception():
	return sys.exc_info()[1]
def distance(origin, destination):
	lat1, lon1 = origin
	lat2, lon2 = destination
	radius = 6371  # km
	dlat = math.radians(lat2 - lat1)
	dlon = math.radians(lon2 - lon1)
	a = (math.sin(dlat / 2) * math.sin(dlat / 2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) * math.sin(dlon / 2))
	c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
	d = radius * c
	return d
def build_user_agent():
	ua_tuple = ('Mozilla/5.0', '(%s; U; %s; en-us)' % (platform.platform(), platform.architecture()[0]), 'Python/%s' % platform.python_version(), '(KHTML, like Gecko)', 'speedtest-cli/%s' % __version__)
	user_agent = ' '.join(ua_tuple)
	return user_agent
def build_request(url, data=None, headers=None, bump='0', secure=False):
	if not headers:
		headers = {}
	if url[0] == ':':
		scheme = ('http', 'https')[bool(secure)]
		schemed_url = '%s%s' % (scheme, url)
	else:
		schemed_url = url
	if '?' in url:
		delim = '&'
	else:
		delim = '?'
	final_url = '%s%sx=%s.%s' % (schemed_url, delim, int(timeit.time.time() * 1000), bump)
	headers.update({'Cache-Control': 'no-cache',})
	return Request(final_url, data=data, headers=headers)
def catch_request(request, opener=None):
	if opener:
		_open = opener.open
	else:
		_open = urlopen
	try:
		uh = _open(request)
		return uh, False
	except HTTP_ERRORS:
		e = get_exception()
		return None, e
def get_response_stream(response):
	try:
		getheader = response.headers.getheader
	except AttributeError:
		getheader = response.getheader
	if getheader('content-encoding') == 'gzip':
		return GzipDecodedResponse(response)
	return response
class Speedtest(object):
	def __init__(self, config=None, source_address=None, timeout=10, secure=False, shutdown_event=None):
		self.config = {}
		self._source_address = source_address
		self._timeout = timeout
		self._opener = build_opener(source_address, timeout)
		self._secure = secure
		if shutdown_event:
			self._shutdown_event = shutdown_event
		else:
			self._shutdown_event = FakeShutdownEvent()
		self.get_config()
		if config is not None:
			self.config.update(config)
		self.servers = {}
		self.closest = []
		self._best = {}
	def get_config(self):
		headers = {}
		if gzip:
			headers['Accept-Encoding'] = 'gzip'
		request = build_request('://www.speedtest.net/speedtest-config.php', headers=headers, secure=self._secure)
		uh, e = catch_request(request, opener=self._opener)
		if e:
			raise ConfigRetrievalError(e)
		configxml_list = []
		stream = get_response_stream(uh)
		while 1:
			try:
				configxml_list.append(stream.read(1024))
			except (OSError, EOFError):
				raise ConfigRetrievalError(get_exception())
			if len(configxml_list[-1]) == 0:
				break
		stream.close()
		uh.close()
		if int(uh.code) != 200:
			return None
		configxml = ''.encode().join(configxml_list)
		try:
			root = ET.fromstring(configxml)
		except ET.ParseError:
			e = get_exception()
			raise SpeedtestConfigError(
				'Malformed speedtest.net configuration: %s' % e)
		server_config = root.find('server-config').attrib
		download = root.find('download').attrib
		upload = root.find('upload').attrib
		# times = root.find('times').attrib
		client = root.find('client').attrib
		ignore_servers = list(map(int, server_config['ignoreids'].split(',')))
		ratio = int(upload['ratio'])
		upload_max = int(upload['maxchunkcount'])
		up_sizes = [32768, 65536, 131072, 262144, 524288, 1048576, 7340032]
		sizes = {'upload': up_sizes[ratio - 1:], 'download': [350, 500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000]}
		size_count = len(sizes['upload'])
		upload_count = int(math.ceil(upload_max / size_count))
		counts = {'upload': upload_count, 'download': int(download['threadsperurl'])}
		threads = {'upload': int(upload['threads']), 'download': int(server_config['threadcount']) * 2}
		length = {'upload': int(upload['testlength']), 'download': int(download['testlength'])}
		self.config.update({'client': client, 'ignore_servers': ignore_servers, 'sizes': sizes, 'counts': counts, 'threads': threads, 'length': length, 'upload_max': upload_count * size_count})
		try:
			self.lat_lon = (float(client['lat']), float(client['lon']))
		except ValueError:
			raise SpeedtestConfigError('Unknown location: lat=%r lon=%r' % (client.get('lat'), client.get('lon')))
		return self.config
	def get_servers(self, servers=None, exclude=None):
		if servers is None:
			servers = []
		if exclude is None:
			exclude = []
		self.servers.clear()
		for server_list in (servers, exclude):
			for i, s in enumerate(server_list):
				try:
					server_list[i] = int(s)
				except ValueError:
					raise InvalidServerIDType('%s is an invalid server type, must be int' % s)
		urls = ['://www.speedtest.net/speedtest-servers-static.php', 'http://c.speedtest.net/speedtest-servers-static.php', '://www.speedtest.net/speedtest-servers.php', 'http://c.speedtest.net/speedtest-servers.php',]
		headers = {}
		if gzip:
			headers['Accept-Encoding'] = 'gzip'
		errors = []
		for url in urls:
			try:
				request = build_request(
					'%s?threads=%s' % (url, self.config['threads']['download']), headers=headers, secure=self._secure)
				uh, e = catch_request(request, opener=self._opener)
				if e:
					errors.append('%s' % e)
					raise ServersRetrievalError()
				stream = get_response_stream(uh)
				serversxml_list = []
				while 1:
					try:
						serversxml_list.append(stream.read(1024))
					except (OSError, EOFError):
						raise ServersRetrievalError(get_exception())
					if len(serversxml_list[-1]) == 0:
						break
				stream.close()
				uh.close()
				if int(uh.code) != 200:
					raise ServersRetrievalError()
				serversxml = ''.encode().join(serversxml_list)
				try:
					root = ET.fromstring(serversxml)
				except ET.ParseError:
					e = get_exception()
					raise SpeedtestServersError('Malformed speedtest.net server list: %s' % e)
				elements = etree_iter(root, 'server')
				for server in elements:
					try:
						attrib = server.attrib
					except AttributeError:
						attrib = dict(list(server.attributes.items()))
					if servers and int(attrib.get('id')) not in servers:
						continue
					if (int(attrib.get('id')) in self.config['ignore_servers']
							or int(attrib.get('id')) in exclude):
						continue
					try:
						d = distance(self.lat_lon, (float(attrib.get('lat')), float(attrib.get('lon'))))
					except Exception:
						continue
					attrib['d'] = d
					try:
						self.servers[d].append(attrib)
					except KeyError:
						self.servers[d] = [attrib]
				break
			except ServersRetrievalError:
				continue
		if (servers or exclude) and not self.servers:
			raise NoMatchedServers()
		return self.servers
speedtest = Speedtest()
try:
	speedtest.get_servers()
except (ServersRetrievalError,) + HTTP_ERRORS:
	print('Cannot retrieve speedtest server list')
	sys.exit(1)
count = 1
for _, servers in sorted(speedtest.servers.items()):
	for server in servers:
		line = ('%(id)5s) %(sponsor)s (%(name)s, %(country)s) ''[%(d)0.2f km]' % server)
		try:
			print(line)
		except IOError:
			e = get_exception()
			if e.errno != errno.EPIPE:
				raise
		if count == $num :
			break
		count += 1
	else:
		continue
	break
EOF
}

inputwait() { #? Timer and input loop
	gen_menu
	drawm
	local bl
	local IFS=:
	# shellcheck disable=SC2048
	# shellcheck disable=SC2086
	set -- $*
	if [[ -n $waitsaved ]] && not idle; then
		secs=$waitsaved
	elif [[ -n $idlesaved ]] && now idle; then
		secs=$idlesaved
	else
		secs=$(( ${1#0} * 3600 + ${2#0} * 60 + ${3#0} ))
	fi
	stsecs=$secs
	if not paused; then
		tcount $secs &
		secpid="$!"
	fi
	unset IFS


	while [[ $secs -gt 0 ]]; do
		tput sc; tput cup $titleypos $(( (width / 2)-4 ))
		if now paused && not timer_menu; then bl="$dark"; else bl=""; fi
		if [[ $secs -le 10 ]]; then
			printf "${bgl}${bl}%02d:%02d:${red}%02d${reset}${bgr}" $((secs/3600)) $(( (secs/60) %60 )) $((secs%60))
		else
			printf "${bgl}${bl}%02d:%02d:%02d${reset}${bgr}" $((secs/3600)) $(( (secs/60) %60 )) $((secs%60))
		fi
		tput rc
		
		read -srd '' -t 0.0001 -n 10000 || true
		# shellcheck disable=SC2162
		read -srn 1 -t 0.9999 keyp || true
		if [[ $keyp == "$escape_char" ]]; then read -rsn3 -t 0.0001 keyp || true ; fi

		case "$keyp" in #* Buffer and quit keys ------------------------------------
			'[A') buffer "up" ;;
			'[B') buffer "down" ;;
			'[5~') buffer "pageup" ;;
			'[6~') buffer "pagedown" ;;
			'[H') buffer "home" ;;
			'[F') buffer "end" ;;
				q) ctrl_c ;;
		esac

		if now timer_menu; then #* Timer menu keys ------------------------------------
			case "$keyp" in
				H) secs=$(( secs + 3600 )); updatesec=1;;
				h) if [[ $secs -gt 3600 ]]; then secs=$(( secs - 3600 )) ; updatesec=1; fi ;;
				M) secs=$(( secs + 60 )); updatesec=1 ;;
				m) if [[ $secs -gt 60 ]]; then secs=$(( secs - 60 )); updatesec=1 ; fi ;;
				S) secs=$(( secs + 1 )); updatesec=1 ;;
				s) if [[ $secs -gt 1 ]]; then secs=$(( secs - 1 )); updatesec=1 ; fi ;;
				a|A)
					if [[ -n $idletimer ]] && [[ $idle == "true" ]]; then idlesaved=$secs
					else waitsaved=$secs; fi
					updatesec=1
					drawm "Timer saved!" "$green" 2; drawm
					;;
				r|R) unset waitsaved ; secs=$stsecs; updatesec=1 ;;
				e|E)
					toggle timer_menu
					if old pausetoggled notsame; then toggle pausetoggled; else gen_menu; fi
					if old menu_status notsame; then menu toggle; else drawm; fi
					 ;;
			esac
		
		else #* Regular main menu keys -------------------------------------------------------
			case "$keyp" in
				p|P) toggle pausetoggled ;;
				t|T) break ;;
				i|I)
					if now idle && [[ -n $idletimer ]]; then idlebreak=1; idledone=0; idle="false"; break
					elif not idle && [[ -n $idletimer ]]; then idlebreak=1; idledone=0; idle="true"; break
					fi
					toggle idle
					secs=$stsecs; updatesec=1; gen_menu; drawm
					;;
				e|E) 
					toggle timer_menu
					old pausetoggled save; old menu_status save
					if not paused; then toggle pausetoggled; else gen_menu; fi
					if not menu; then menu toggle; else drawm; fi
					;;
				m|M) menu toggle ;;
				f|F) forcetest=1; break ;;
				v|V)
					if now less; then
						if [[ -s $logfile ]]; then tput clear; colorize "$logfile" "<file" | less -rMXx1 +Gg; redraw full
						else drawm "Log empty!" "$red" 2; drawm
						fi
					fi
					;;
				c|C) if ! buffer ; then tput clear; tput cup 3 0; drawm
					else buffer "clear"
					fi ;;
				u|U) drawm "Getting servers..." "$yellow"; updateservers=1; getservers; drawm ;;
			esac
		fi

		if  ( not paused && now pausetoggled) || (not paused pausetoggled && now displaypause && monitor_on); then
			paused="true"
			assasinate "$secpid"
			gen_menu
			drawm
		elif (now paused && not pausetoggled) || (now paused displaypause && not pausetoggled && not monitor_on); then
			paused="false"
			tcount $secs &
			secpid="$!"
			gen_menu
			drawm
		fi
		if now paused updatesec && not idledone; then
			updatesec=0;
		elif now updatesec && not idledone paused; then
			assasinate "$secpid"
			tcount $secs &
			secpid="$!"
			updatesec=0
		elif not paused; then
			oldsecs=$secs
			secs=$(<"$secfile")
		fi
		if ([[ $secs -gt $oldsecs && -n $idletimer ]] && now idle idledone && not idlebreak paused); then idlebreak=1; idledone=0; break; fi
	done
	if [[ $scrolled -gt 0 ]]; then buffer "redraw" 0; fi
	if [[ -n $idletimer ]] && now idle && not slowgoing idlebreak; then idledone=1; fi
	assasinate "$secpid"
}

internet() {
	if ping -qc1 -w5 1.1.1.1 > /dev/null 2>&1 || ping -qc1 -w5 8.8.8.8 > /dev/null 2>&1; then
		if [[ $1 == "down" ]]; then return 1; fi
		return 0
	else
		if [[ $1 == "down" ]]; then return 0; fi
		return 1
	fi
}

logrotate() { #? Rename logfile, compress and create new if size is over $logsize
	if [[ -n $logname ]]; then
		logfile="$logname"
	else
		logfile="log/spdtest.log"
		if ((loglevel==0)); then return; fi
		if [[ ! -d log ]]; then mkdir log; fi
		touch $logfile
		logsize=$(du $logfile | tr -s '\t' ' ' | cut -d' ' -f1)
		if ((logsize>maxlogsize)); then
			ts=$(date +%y-%m-%d-T:%H:%M)
			mv $logfile "log/spdtest.$ts.log"
			touch $logfile
			# shellcheck disable=SC2154
			if [[ -n $logcompress ]]; then $logcompress "log/spdtest.$ts.log"; fi
		fi
	fi
}

menu() { #? Menu handler, no arguments returns 0 for shown menu, arguments: toggle toggle_keep
	if [[ -z $1 && $menu_status -eq 1 ]]; then return 0
	elif [[ -z $1 ]]; then return 1; fi

	if [[ $1 == "toggle" ]]; then toggle menu_status; fi
	redraw calc
	buffer redraw
	drawm
}

monitor_on() { if [[ $(xset -q) =~ "Monitor is On" ]]; then return 0; else return 1; fi; } #? Check if display is on with xset

myip() { curl -s ipinfo.io/ip; } #? Get public IP

not() { #? Multi function: Invert of now(), usage: not "var1" ["var2"] ...
		#? can also be used to reverse return of function or program if first argument isn't a variable, usage: not "command" ["arg1"] ["arg2"] ...
	if [[ -z $1 ]]; then return; fi

	if [[ -z ${!1+x} ]]; then
		if "$@" 2> /dev/null; then return 1; else return 0; fi
	fi

	if [[ "$#" -gt 1 ]]; then
		local i x=0
		for i in "$@"; do
			if not "$i"; then ((++x)); fi
		done
		if [[ x -eq "$#" ]]; then return 0; else return 1; fi
	fi

	if now "$1"; then return 1; else return 0; fi
}

now() { #? Returns true or false for one or multiple variables, usage: now "var1" ["var2"] ...
	if [[ -z $1 ]]; then return; fi
	if [[ "$#" -gt 1 ]]; then
		local i x=0
		for i in "$@"; do
			if now "$i"; then ((++x)); fi
		done
		if [[ x -eq "$#" ]]; then return 0; else return 1; fi
	fi

	local var="$1"
	if [[ -z ${!var} || ${!var} =~ 0|false|False|FALSE ]]; then
		if [[ -n ${!var} ]] && wasnt "$var"; then reset "$var"; fi
		return 1
	elif [[ ${!var} =~ 1|true|True|TRUE ]]; then
		if wasnt "$var"; then reset "$var"; fi
		return 0
	fi
}

old() {
	if [[ -z $1 ]]; then return; fi
	local out var="$1"
	if [[ $2 == "save" ]]; then old_list[$var]="${!var}"; return
	elif [[ $2 == "get" ]]; then echo -n "${old_list[$var]}"
	elif [[ $2 == "same" ]]; then
		if [[ ${old_list[$var]} == "${!var}" ]]; then return 0
		else return 1
		fi
	elif [[ $2 == "notsame" ]]; then
		if [[ ${old_list[$var]} == "${!var}" ]]; then return 1
		else return 0
		fi
	fi
	
	if [[ -z ${old_list[$var]} || ${old_list[$var]} =~ 0|false|False|FALSE ]]; then
		return 1
	elif [[ ${old_list[$var]} =~ 1|true|True|TRUE ]]; then
		return 0
	fi	
}

precheck_speed() { #? Check current bandwidth usage before slowcheck
	testing=1
	local sndvald sndvalu i skip=1
	local dspeed=0
	local uspeed=0
	local ib=10
	local t=$((precheck_samplet*10))
	drawm "Checking bandwidth usage" "$yellow"
	if [[ -n $precheck_ssh ]] && ! ssh -S "$ssh_socket" -O check "$precheck_ssh" >/dev/null 2>&1; then
		writelog 8 "Disconnected from $precheck_ssh_host, reconnecting..."
		ssh -fN -o 'ControlMaster=yes' -o 'ControlPersist=1h' -S "$ssh_socket" "$precheck_ssh"
	fi
	echo -en "Checking bandwidth usage: ${bold}$(progress 0)${reset}\r"
	sndvald="$(getcspeed "down" 0 "get")"
	sndvalu="$(getcspeed "up" 0 "get")"
	for((i=1;i<=t;i++)); do
		prc=$(echo "scale=2; $i / $t * 100" | bc | cut -d . -f 1)
		if [[ $i -eq $ib ]]; then ib=$((ib+10)); dspeed=$(getcspeed "down" $((i/10)) "$sndvald"); uspeed=$(getcspeed "up" $((i/10)) "$sndvalu"); fi
		echo -en "Checking bandwidth usage: ${bold}$(progress "$prc") ${green}DOWN=${white}$dspeed $unit ${red}UP=${white}$uspeed $unit${reset}         \r"
		sleep 0.1
		if now broken; then precheck_status="fail"; testing=0; tput el; tput el1; writelog 2 "\nWARNING: Precheck aborted!\n"; return; fi
	done
	tput el
	dspeed="$(getcspeed "down" $precheck_samplet "$sndvald")"
	uspeed="$(getcspeed "up" $precheck_samplet "$sndvalu")"
	if [[ $dspeed -lt $precheck_down && $uspeed -lt $precheck_up ]]; then
		precheck_status="ok"
		writelog 9 "Checking bandwidth usage: $(progress 100 "OK!") DOWN=$dspeed $unit UP=$uspeed $unit\r"
		drawm "Checking bandwidth usage" "$green" 1
		tput cuu1; tput el
	else
		precheck_status="fail"
		writelog 9 "Checking bandwidth usage: $(progress 100 "FAIL!") DOWN=$dspeed $unit UP=$uspeed $unit\r"
		drawm "Checking bandwidth usage" "$red" 1
		tput cuu1
		writelog 2 "WARNING: Testing blocked, current bandwidth usage: DOWN=$dspeed $unit UP=$uspeed $unit ($(date +%Y-%m-%d\ %T))"
	fi
	testing=0
	#drawm
}

printhelp() { #? Prints help information in UI
	echo ""
	echo -e "Key:              Descripton:                           Key:              Description:"
	echo -e "q                 Quit                                  e                 Show help information"
	echo -e "c                 Clear screen                          v                 View current logfile with less"
	echo -e "H                 Add 1 hour to timer                   h                 Remove 1 hour from timer"
	echo -e "M                 Add 1 minute to timer                 m                 Remove 1 minute from timer"
	echo -e "S                 Add 1 second to timer                 s                 Remove 1 second from timer"
	echo -e "a                 Save wait timer                       r                 Reset wait timer"
	echo -e "i                 Reset timer on X Server activity      p                 Pause timer"
	echo -e "t                 Test if speed is slow                 f                 Run full tests without slow check"
	echo -e "u                 Update serverlist\n"
}

progress() { #? Print progress bar, arguments: <percent> [<"text">] [<text color>] [<reset color>]
	local text cs ce x i xp=0
	local percent=${1:-0}
	local text=${2:-$percent}
	if [[ -n $3 ]]; then cs="$3"; ce="${4:-$white}"
	else cs=""; ce=""
	fi
	
	if [[ ${#text} -gt 10 ]]; then text=${text::10}; fi
	
	echo -n "["

	if [[ ! $((${#text}%2)) -eq 0 ]]; then 
		if [[ $percent -ge 10 ]]; then 
			echo -n "="
		else 
			echo -n " "
		fi
		((++xp))
	fi

	for((x=1;x<=2;x++)); do
		for((i=0;i<((10-${#text})/2);i++)); do
			((++xp))
			if [[ $xp -le $((percent/10)) ]]; then echo -n "="
			else echo -n " "
			fi
		done
		if [[ $x -eq 1 ]]; then echo -en "${cs}${text}${ce}"; xp=$((xp+${#text})); fi
	done

	echo -n "]"
}

random() { #? Random/shuffle (number[s]) or (number[s] in array) or (value[s] in array) generator
	local x=${3:-1}

	if [[ $1 == int && -n $2 ]]; then #? Random number[s], usage: random int "start-end" ["amount"]
		if [[ ! $2 =~ "-" ]]; then return; fi
		if ((${2%-*}>=${2#*-})); then return; fi
		if ((x>${2#*-}-${2%-*})); then x=$((${2#*-}-${2%-*})); fi
		echo -n "$(shuf -i "$2" -n "$x" $rnd_src)"

	elif [[ $1 == array_int && -n $2 ]]; then #? Random number[s] between 0 and array size, usage: random array_int "arrayname" ["amount"] ; use "*" as amount for all in random order
		#shellcheck disable=SC2016
		local arr_int='${#'"$2"'[@]}'; eval arr_int="$arr_int"
		if [[ $x == "*" ]] || ((x>arr_int)); then x=$arr_int; fi
		echo -n "$(shuf -i 0-$((arr_int-1)) -n "$x" $rnd_src)"

	elif [[ $1 == array_value && -n $2 ]]; then  #? Random value[s] from array, usage: random array_value "arrayname" ["amount"] ; use "*" as amount for all in random order
		local i rnd; rnd=($(random array_int "$2" "$3"))
		for i in "${rnd[@]}"; do
		local arr_value="${2}[$i]"
		echo "${!arr_value}"
		done
	fi
}

redraw() { #? Redraw menu and reprint buffer if window is resized
	width=$(tput cols)
	height=$(tput lines)
	if menu; then menuypos=$((main_menu_len/width)); titleypos=$((menuypos+1)); else menuypos=0; titleypos=0; fi
	#if [[ $width -lt 106 ]]; then menuypos=2; else menuypos=1; fi
	buffpos=$((titleypos+1))
	buffsize=$((height-buffpos-1))
	if [[ $1 == "calc" ]]; then return; fi
	if ! buffer; then tput sc; tput cup $buffpos 0; tput el; tput rc
	else buffer "redraw"; fi
	gen_menu
	drawm
	sleep 0.1
}

reset() { #? Set variable was() state to current value, usage: reset "variable name"
	if [[ -z $1 ]]; then return 1; fi
	was "$1" add
}

routetest() { #? Test routes with mtr
	if not mtr || now broken || internet down; then return; fi
	testing=1
	unset 'routelistc[@]'
	local i ttime tcount pcount prc secs dtext port

	if [[ -n ${routelistb[0]} ]]; then	routelistc+=("${routelistb[@]}"); fi
	if [[ -n ${routelista[0]} ]]; then routelistc+=("${routelista[@]}"); fi
	if [[ -z ${routelistc[0]} ]]; then testing=0; return; fi

	for i in "${routelistc[@]}"; do
		echo "Routetest: ${routelistdesc[$i]} $i ($(date +%T))" | writelog 1
		if ping -qc1 -w5 "$i" > /dev/null 2>&1; then
			drawm "Running route test..." "$green"
			
			if [[ ${routelistport[$i]} == "auto" || ${routelistport[$i]} == "null" || -z ${routelistport[$i]} ]]; then port=""
			else port="-P ${routelistport[$i]}"; fi
			# shellcheck disable=SC2086
			mtr -wbc "$mtrpings" -I "$net_device" $port "$i" > "$routefile" &
			routepid="$!"
			
			ttime=$((mtrpings+5))
			tcount=1; pcount=1; dtext=""
			
			printf "\r%s${bold}%s${reset}%s" "Running mtr  " "$(progress "$prc" "$dtext" "${green}")" "  Time left: "
			printf "${bold}${yellow}<%02d:%02d>${reset}" $(((ttime/60)%60)) $((ttime%60))
			while kill -0 "$routepid" >/dev/null 2>&1; do
				prc=$(echo "scale=2; $pcount / ($ttime * 5) * 100" | bc | cut -d . -f 1)
				if [[ $pcount -gt $((ttime*5)) ]]; then ax_anim 1; prc=100; dtext=" $animout "; tcount=$((tcount-1)); fi
				printf "\r%s${bold}%s${reset}%s" "Running mtr  " "$(progress "$prc" "$dtext" "${green}")" "  Time left: "
				if [[ $tcount -eq 5 ]]; then
					secs=$((ttime-(pcount/5)))
					printf "${bold}${yellow}<%02d:%02d>${reset}" $((secs/60%60)) $((secs%60))
					tcount=0
				fi
				sleep 0.2
				((++tcount)); ((++pcount))
			done

			echo -en "\r"; tput el

			if now broken; then break; fi
			writelog 1 "$(tail -n+2 <$routefile)\n"

		else
			echo "ERROR: Host not reachable!" | writelog 1

		fi
		done
		writelog 1 " "
	if now broken; then tput el; tput el1; writelog 1 "\nWARNING: Route tests aborted!\n"; fi
	testing=0
}

running() { if kill -0 "$1" >/dev/null 2>&1; then return 0; else return 1; fi; } #? Returns true if process is running, usage: running "process pid"

not_running() { if running "$1"; then return 1; else return 0; fi; } #? Returns true if process is NOT running, usage: not_running "process pid"

tcount() { #? Run timer count and write to shared memory, meant to be run in background
	local rsec lsec="$1"
	echo "$lsec" > "$secfile"
	local secbkp=$((lsec+1))
	while ((lsec>0)); do
		rsec=$(date +%s || sleep 1)
		while (( rsec==$(date +%s) )); do sleep 0.25; done
		if now idle && (($(getIdle)<1)); then lsec=$secbkp; fi
		((lsec--))
		echo "$lsec" > "$secfile"
	done
}

test_type_checker() { #? Check current type of test being run by speedtest
		speedstring=$(tail -n1 < $speedfile)
		stype=$(echo "$speedstring" | jq -r '.type' 2> /dev/null)
		if now broken; then stype="broken"; fi
		if [[ $stype == "log" ]]; then slowerror=1; return; fi
		if [[ $mode == "full" ]] && not_running "$speedpid" && [[ $stype != "result" ]]; then slowerror=1; stype="ended"; fi
}

testspeed() { #? Using official Ookla speedtest client
	local mode=${1:-down}
	local max_tests cs ce cb warnings
	local tests=0
	local err_retry=0
	local xl=1
	local routetemp routeadd
	unset 'errorlist[@]'
	unset 'routelistb[@]'
	testing=1

	if [[ $mode == "full" ]] && ((numslowservers>=${#testlista[@]})); then max_tests=$((${#testlista[@]}-1))
	elif [[ $mode == "full" ]] && ((numslowservers<${#testlista[@]})); then max_tests=$((numslowservers-1))
	elif [[ $mode == "down" ]]; then

		max_tests=$slowretry
		if ((${#testlista[@]}>1)) && not slowgoing; then
			tl=$(random array_value testlista)
		elif ((${#testlista[@]}>1)) && now slowgoing; then
			rnum=${rndbkp[$xl]}
			tl=${testlista[$rnum]}
		else
			tl=${testlista[0]}
			rnum=0
		fi
	fi

	while ((tests<=max_tests)); do #? Test loop start ------------------------------------------------------------------------------------>
		if [[ $mode == "full" ]]; then
			if not slowgoing forcetest testonly; then
				writelog 1 "\n<---------------------------------------Slow speed detected!---------------------------------------->"
				slowgoing=1
			fi
			if ((tests==0)); then
				writelog 1 "Speedtest start: ($(date +%Y-%m-%d\ %T)), IP: $(myip)"
				printf "%-12s%-12s%-10s%-14s%-10s%-10s\n" "Down $unit" "Up $unit" "Ping" "Progress" "Time /s" "Server" | writelog 1
			fi
			tl=${testlista[$tests]}
			printf "%-58s%s" "" "${testlistdesc["$tl"]}" | writelog 9
			tput cuu1; drawm "Running full test" "$red"
			routetemp=""
			routeadd=0

		elif [[ $mode == "down" ]]; then
			if ((tests>=1)); then numstat="<-- Attempt $((tests+1))"; else numstat=""; fi
			printf "\r%5s%-4s%14s\t%s" "$down_speed " "$unit" "$(progress 0 "Init")" " ${testlistdesc["$tl"]} $numstat"| writelog 9
			tput cuu1; drawm "Testing speed" "$green"
		fi

		stype=""; speedstring=""; true > "$speedfile"

		$ookla_speedtest -s "$tl" -p yes -f json -I "$net_device" &>"$speedfile" &         #? <----------------  speedtest start
		speedpid="$!"

		x=1
		while [[ $stype == ""  || $stype =~ null|testStart|ping ]]; do
			test_type_checker
			if [[ $stype == "ping" ]]; then server_ping=$(echo "$speedstring" | jq '.ping.latency'); server_ping=${server_ping%.*}; fi
			if ((x==10)); then
				ax_anim 1
				if [[ $mode == "full" ]]; then printf "\r${bold}%-12s${reset}%-12s%-8s${bold}%16s${reset}" "     " "" "  " "$(progress 0 "Init $animout")    "
				elif [[ $mode == "down" ]]; then printf "\r${bold}%5s%-4s%14s\t${reset}" "$down_speed " "$unit" "$(progress 0 "Init $animout")"
				fi
				x=0
			fi
			sleep 0.01
			((++x))
		done

		while [[ ! $stype =~ download|log|ended ]]; do
			sleep 0.1
			if now broken; then break 2; fi
		done

		while [[ $stype == "download" ]]; do
			down_speed=$(echo "$speedstring" | jq '.download.bandwidth'); down_speed=$(( (down_speed*unitop)>>20 ))
			down_progress=$(echo "$speedstring" | jq '.download.progress'); down_progress=$(echo "$down_progress*100" | bc -l 2> /dev/null)
			down_progress=${down_progress%.*}
			if [[ $mode == "full" ]]; then
				down_progress=$((down_progress/2))
				elapsed=$(echo "$speedstring" | jq '.download.elapsed'); elapsed=$(echo "scale=2; $elapsed / 1000" | bc 2> /dev/null)
				printf "\r${bold}%-12s${reset}%-12s%-8s${bold}%16s%-5s${reset}" "   $down_speed  " "" " $server_ping " "$(progress "$down_progress")    " " $elapsed  "
			elif [[ $mode == "down" ]]; then
				printf "\r${bold}%5s%-4s%14s\t${reset}" "$down_speed " "$unit" "$(progress "$down_progress")"
			fi
			sleep 0.1
			test_type_checker
		done
		
		if [[ $mode == "down" ]]; then assasinate "$speedpid"; fi

		if now broken; then break; fi
		
		while [[ $stype == "upload" && $mode == "full" ]]; do
			up_speed=$(echo "$speedstring" | jq '.upload.bandwidth'); up_speed=$(( (up_speed*unitop)>>20 ))
			elapsed2=$(echo "$speedstring" | jq '.upload.elapsed'); elapsed2=$(echo "scale=2; $elapsed2 / 1000" | bc 2> /dev/null)
			elapsedt=$(echo "scale=2; $elapsed + $elapsed2" | bc 2> /dev/null)
			up_progress=$(echo "$speedstring" | jq '.upload.progress'); up_progress=$(echo "$up_progress*100" | bc -l 2> /dev/null)
			up_progress=${up_progress%.*}; up_progress=$(( (up_progress/2)+50 ))
			if ((up_progress==100)); then ax_anim 1; up_progresst=" $animout "; cs="${bold}${green}"; ce="${white}"; cb=""; else up_progresst=""; cs=""; ce=""; cb="${bold}"; fi
			printf "\r%-12s$cb%-12s${reset}%-8s${bold}%-16s${reset}$cb%-5s${reset}" "   $down_speed  " "  $up_speed" " $server_ping " "$(progress "$up_progress" "$up_progresst" "$cs" "$ce")    " " $elapsedt  "
			sleep 0.1
			test_type_checker
		done
		
		#? ------------------------------------Checks--------------------------------------------------------------
		if now broken; then break; fi
		if [[ $mode == "full" ]]; then wait $speedpid || true; fi

		if [[ $mode == "full" && $stype == "result" ]] && not slowerror; then
			speedstring=$(jq -c 'select(.type=="result")' $speedfile)
			down_speed=$(echo "$speedstring" | jq '.download.bandwidth')
			down_speed=$(( (down_speed*unitop)>>20 ))
			up_speed=$(echo "$speedstring" | jq '.upload.bandwidth')
			up_speed=$(( (up_speed*unitop)>>20 ))
			server_ping=$(echo "$speedstring" | jq '.ping.latency'); server_ping=${server_ping%.*}
			packetloss=$(echo "$speedstring" | jq '.packetLoss')
			routetemp="$(echo "$speedstring" | jq -r '.server.host')"
			if ((down_speed<=slowspeed)); then
				downst="FAIL!"
				if [[ $mtr_internal == "true" && -n $routetemp ]] && ((${#routelistb[@]}<mtr_internal_max)); then routeadd=1; fi
			else 
				downst="OK!"
				if [[ $mtr_internal_ok == "true" && -n $routetemp ]] && ((${#routelistb[@]}<mtr_internal_max)); then routeadd=1; fi
			fi

			if now routeadd; then
				routelistb+=("$routetemp")
				if [[ -z ${routelistdesc["$routetemp"]} ]]; then
				routelistdesc["$routetemp"]="$(echo "$speedstring" | jq -r '.server.name') ($(echo "$speedstring" | jq -r '.server.location'), $(echo "$speedstring" | jq -r '.server.country'))"
				routelistport["$routetemp"]="$(echo "$speedstring" | jq '.server.port')"
				fi
			fi
			
			if [[ -n $packetloss && ! $packetloss =~ null|0 ]]; then warnings="WARNING: ${packetloss%%.*}% packet loss!"; fi
			printf "\r"; tput el
			printf "%-12s%-12s%-8s%-16s%-10s%s%s" "   $down_speed  " "  $up_speed" " $server_ping " "$(progress "$up_progress" "$downst")    " " $elapsedt  " "${testlistdesc["$tl"]}" "  $warnings" | writelog 1
			((++tests))
		
		elif [[ $mode == "full" ]] && now slowerror; then
			warnings="ERROR: Couldn't test server!"
			printf "\r"; tput el
			printf "%-12s%-12s%-8s%-16s%-10s%s%s" "   $down_speed  " "  $up_speed" " $server_ping " "$(progress "$up_progress" "FAIL!")    " " $elapsedt  " "${testlistdesc["$tl"]}" "  $warnings" | writelog 1
			if internet down; then writelog 1 "ERROR: Can't reach the internet, aborting tests!\n"; testing=0; return; fi
			((++tests))
		
		elif [[ $mode == "down" ]] && not slowerror; then
			if not slowgoing; then rndbkp[$xl]="$tl"; ((++xl)); fi
			if ((down_speed<=slowspeed)); then downst="FAIL!"; else downst="OK!"; fi
			if (( tdate!=$(date +%d) )) || ((times_tested==10)); then tdate="$(date +%d)"; times_tested=0; timestamp="$(date +%H:%M\ \(%y-%m-%d))"; else timestamp="$(date +%H:%M)"; fi
			printf "\r"; tput el; printf "%5s%-4s%14s\t%s" "$down_speed " "$unit" "$(progress $down_progress "$downst")" " ${testlistdesc["$tl"]} <Ping: $server_ping> $timestamp $numstat"| writelog 2
			lastspeed=$down_speed
			((++times_tested))
			if ((down_speed<=slowspeed & ${#testlista[@]}>1 & tests<max_tests)) && not slowgoing; then
				tl2=$tl
				while [[ $tl2 == "$tl" ]]; do
					tl2=$(random array_value testlista)
				done
				tl=$tl2
				((++tests))
			elif ((down_speed<=slowspeed & ${#testlista[@]}>1 & tests<max_tests)) && now slowgoing; then
				((++xl))
				tl=${rndbkp[$xl]}
				((++tests))
			else
				tests=$((max_tests+1))
			fi
		
		elif [[ $mode == "down" ]] && now slowerror; then
			((++err_retry))
			errorlist+=("$tl")
			timestamp="$(date +%H:%M\ \(%y-%m-%d))"
			printf "\r"; tput el; printf "%5s%-4s%14s\t%s" "$down_speed " "$unit" "$(progress $down_progress "FAIL!")" " ${testlistdesc["$tl"]} $timestamp  ERROR: Couldn't test server!" | writelog 2
			if internet down; then writelog 2 "ERROR: Can't reach the internet, aborting tests!\n"; testing=0; return; fi
			if ((${#testlista[@]}>1 & err_retry<${#testlista[@]})); then
				tl2=$tl
				while contains "${errorlist[@]}" "$tl2"; do
					tl2=$(random array_value testlista)
				done
				tl=$tl2
			else
				writelog 2 "\nERROR: Couldn't get current speed from servers!"
				testing=0
				return
			fi
		fi

		warnings=""
	done #? Test loop end ----------------------------------------------------------------------------------------------------------------------->
	
	assasinate "$speedpid"
	if now broken && [[ $mode == "full" ]]; then tput el; tput el1; writelog 1 "\nWARNING: Full test aborted!\n"; 
	elif now broken && [[ $mode == "down" ]]; then tput el; tput el1; writelog 2 "\nWARNING: Slow test aborted!\n"; 
	elif [[ $mode == "full" ]]; then writelog 1 " "; fi
	testing=0
}

toggle() { #? Toggle a variables true or false state
	if [[ -z $1 || -z ${!1} ]]; then return; fi

	if [[ "$#" -gt 1 ]]; then
		local i
		for i in "$@"; do
			toggle "$i"
		done
		return
	fi

	if [[ ${!1} == "0" ]]; then 
		eval "$1=1"
		was "$var" add "0"
	elif [[ ${!1} =~ false|False|FALSE ]]; then
		eval "$1=true"
		was "$var" add "false"
	elif [[ ${!1} == "1" ]]; then
		eval "$1=0"
		was "$var" add "1"
	elif [[ ${!1} =~ true|True|TRUE ]]; then
		eval "$1=false"
		was "$var" add "true"
	fi
}

traperr() {
	local match len trap_muted err="${BASH_LINENO[0]}"

	if [[ -z ${trace_array[0]} ]]; then echo -e "INFO: Starting error trace $(date +\(%x\))" >> misc/errors; fi
	len=$((${#trace_array[@]}))
	if ((len-->=1)); then
		while ((len>=${#trace_array[@]}-2)); do		
			if [[ $err == "${trace_array[$((len--))]}" ]]; then ((++match)) ; fi
		done
		if ((match==2 & len != -2)); then return
		elif ((match>=1)); then trap_muted="(MUTED!)"
		fi
	fi
	trace_array+=("$err")
	echo "$(date +%X)  ERROR: On line $err $trap_muted" >> "misc/errors"
	
}

waiting() { #? Show animation and text while waiting for background job, arguments: <pid> <"text">
			local i text=${2:-Waiting...}
			while running "$1"; do
				for ((i=0; i<${#chars}; i++)); do
					sleep 0.2
					if now broken; then return; fi
					echo -en "${bold}${white}$text ${red}${chars:$i:1} ${reset}" "\r"
				done
			done

}

was() { #? Returns state or sets previous true or false state of a variable, usage: was "variable name" [add] [value]
	if [[ -z $1 ]]; then return; fi
	local out var="$1"
	if [[ $2 == "add" ]]; then
		out=${3:-${!var}}
		was_list[$var]="$out"
	elif [[ -z ${was_list[$var]} || ${was_list[$var]} =~ 0|false|False|FALSE ]]; then
		return 1
	elif [[ ${was_list[$var]} =~ 1|true|True|TRUE ]]; then
		return 0
	fi
}

wasnt() { #? Returns true if previous variable state is NOT true, usage: wasnt "variable name"
	if [[ -z $1 ]]; then return; fi
	if was "$1"; then return 1; else return 0; fi
}

writelog() { #? Write to logfile, buffer and send to colorize()
	if ((loglevel==1000)); then return; fi
	declare input=${2:-$(</dev/stdin)}

	if (($1<=loglevel | loglevel==103)); then file="$logfile"; else file="/dev/null"; fi
	if ((loglevel==103)); then echo -en "$input\n" > "$file"; return; fi

	echo -en "$input\n" | tee -a "$file" | cut -c -"$width" | colorize
	if not startup; then drawm "$drawm_ltitle" "$drawm_lcolor"; fi

	if not testonly && (($1<=8 & loglevel!=103)); then buffer add "$input"; fi
}

x_debug1() { #* Remove
	drawm
	startup=0
	loglevel=0
	#quiet_start="true"
	numservers="30"
	numslowservers="5"
	slowspeed="30"
	mtrpings="10"
	max_buffer="1000"
	mtr_external="false"
	mtr_internal="true"
	mtr_internal_ok="true"
	# mtr_internal_max=""
	getservers
	while true; do
		key=""
		while [[ -z $key ]]; do
		#drawm "Debug Mode" "$magenta"
		tput sc; tput cup 0 0
		echo -en "${bold} T = Test  F = Full test  P = Precheck  G = grctest  R = routetest  Q = Quit  A = Add line  C = Clear  Ö = Custom  V = Clear  B = Buffer:$scrolled"
		tput rc
		read -srd '' -t 0.0001 -n 10000 || true
		read -rsn 1 key || true
		done
		if [[ $key == "$escape_char" ]]; then read -rsn3 -t 0.0001 key || true ; fi
		tput el
		case "$key" in
		'[A') buffer "up" ;;
		'[B') buffer "down" ;;
		'[C') echo "right" ;;
		'[D') echo "left" ;;
		'[5~') buffer "pageup" ;;
		'[6~') buffer "pagedown" ;;
		q|Q) break ;;
		t|T) testspeed "down" ;;
		f|F) testspeed "full" ;;
		p|P) precheck_speed; echo "" ;;
		g|G) if [[ -s $logfile ]]; then writelog 8 "${logfile}:\n$(tail -n500 "$logfile")"; fi; drawm ;;
		b|B) echo -e "$(<$bufferfile)" | colorize; drawm ;;
		r|R) routetest ;;
		a|A) echo "Korv" | writelog 5  ;;
		v|V) redraw full 
		;;
		c|C) tput clear; tput cup 3 0; drawm; echo -n "" > "$bufferfile" ;;
		ö|Ö) 
		echo $menuypos
		echo $(((main_menu_len/width)+1))
		echo "$main_menu_len"
		echo "$width"


		 ;;
		*) echo "$key" ;;
		esac
		broken=0
		testing=0
		
	done
		broken=0
		testing=0
	ctrl_c
}

#?> End functions -------------------------------------------------------------------------------------------------------------------->

z__pre_main() { echo -n; }

trap ctrl_c INT

network_init

if not mtr; then mtr_internal="false"; mtr_internal_ok="false"; fi

deliver "$tmpout"

if now genservers; then #? Gets servers, write to file and quit if -gs or --gen-server-cfg was passed
	echo -e "\nCreating server.cfg.sh"
	loglevel=0
	getservers
	exit 0
fi

logrotate
if [[ ! -w $logfile ]] && ((loglevel!=0)); then echo "ERROR: Couldn't write to logfile: $logfile"; exit 1; fi

deliver "$speedfile" "$routefile"

if now testonly; then #? Run tests and quit if variable test="true" or arguments -t or --test was passed to script
	getservers
	for i in $testnum; do
		testspeed "full"
		if now broken; then stat=1; break; fi
		routetest
		if now broken; then stat=1; break; fi
		stat=0
	done
	assasinate "$routepid" "$speedpid"
	bury "$speedfile" "$routefile" "$tmpout"
	exit $stat
fi

deliver "$bufferfile" "$secfile"
tput smcup; tput clear; tput civis; tput cup 3 0; stty -echo

trap 'redraw full' WINCH
gen_menu
redraw calc
drawm "Getting servers..." "$green"

if now trace_errors || now debug; then
	# exec 19>misc/logfile
	# BASH_XTRACEFD=19
	# set -x
	trace_errors="true"
	set -o errtrace
	trap traperr ERR
fi

if now buffer_save && [[ -s .buffer ]]; then cp -f .buffer "$bufferfile" >/dev/null 2>&1; buffer "redraw" 0; fi
if now debug; then x_debug1; fi #* Remove

#writelog 1 "\nINFO: Script started! ($(date +%Y-%m-%d\ %T))\n"

getservers

if  now displaypause && monitor_on; then paused="true"
elif now displaypause && ! monitor_on; then paused="false"
fi

if not paused && now startuptest && internet up; then
	testspeed "down"
	if ((lastspeed<=slowspeed)) && not slowerror; then startupdetect=1; fi
fi

drawm
startup=0




#? Main loop function ------------------------------------------------------------------------------------------------------------------>
z_main_loop() {
	if [[ -n $idletimer ]] && now idle && not slowgoing idledone startupdetect; then
		inputwait "$idletimer"
	elif not startupdetect; then
		inputwait "$waittime"
	fi

	if internet down; then writelog 1 "ERROR: Can't reach the internet, aborting tests! ($(date +%H:%M))"; return; fi	

	if not idlebreak; then
		logrotate

		if not forcetest startupdetect; then
			if now precheck; then
				precheck_speed
				if [[ $precheck_status = "fail" ]]; then return; fi
			fi
			testspeed "down"
		fi

		if now broken; then return; fi

		if now forcetest; then
			if ((loglevel<4)); then bkploglevel=$loglevel; loglevel=0; fi
			writelog 9 "\n INFO: Running forced test!"
			testspeed "full"
			routetest
			if [[ -n $bkploglevel ]] && ((bkploglevel<4)); then loglevel=$bkploglevel; fi
			forcetest=0
		elif ((lastspeed<=slowspeed)) && not slowerror; then
			testspeed "full"
			routetest
			detects=$((detects + 1))
			if [[ -n $slowwait ]]; then waitbkp=$waittime; waittime=$slowwait; fi
		elif [[ $slowgoing == 1 ]]; then
			if [[ -n $slowwait ]]; then waittime=$waitbkp; fi
			if not slowerror; then
				slowgoing=0
				writelog 1 "\n<------------------------------------------Speeds normal!------------------------------------------>"
			fi
		fi
	fi

	
}

#? Start infinite loop ------------------------------------------------------------------------------------------------------------------>
while true; do
	z_main_loop
	idlebreak=0
	precheck_status=""
	broken=0
	reset broken
	reset testing
	startupdetect=0
	slowerror=0
done
ctrl_c
zz_end() { echo -n; }