# batt_opt.sh
# Version 1.0
# 2021-05-16 @ 15:29 (UTC)
# ID: 1b14d2
# Written by jpzex@XDA
# Use at your own risk, Busybox is required.

which busybox > /dev/null || $(echo "No busybox found." && exit 0)

alias_list="
mountpoint
awk
echo
grep
chmod
fstrim
cat
mount"

for x in $alias_list; do
alias $x="busybox $x"; done

scriptname=batt_opt
dumpE=0

# Specific optimizations for economy,
# focused on extended battery time.

specific_opt(){
M2 # sysctl
M3 # LMK
M5 # kernel modules
M6 # interactive governor
M7 # adreno gpu
}

#===================================================#
#===================================================#
#===================================================#

# Module 2: Sysctl Tweaks

M2(){

sys=/proc/sys

kernel_batt(){
wr $sys/kernel/random/read_wakeup_threshold 256
wr $sys/kernel/random/write_wakeup_threshold 256
}

vm_batt(){
wr $sys/vm/dirty_ratio 90
wr $sys/vm/dirty_background_ratio 50
wr $sys/vm/dirty_expire_centisecs 3000
wr $sys/vm/dirty_writeback_centisecs 1000
wr $sys/vm/min_free_order_shift 5
wr $sys/vm/swappiness 40
wr $sys/vm/user_reserve_kbytes 256
wr $sys/vm/vfs_cache_pressure 300
}

kernel_batt
vm_batt

unset sys kernel_batt vm_batt
}

#===================================================#
#===================================================#
#===================================================#

# Module 3: LMK Tweaks

M3(){

params=/sys/module/lowmemorykiller/parameters
extramb=$(($msize/4096))
tend=$(($msize/102400))

t(){
echo $((($1*$tend*16)+32*$extramb))
}

lmk(){
echo "$(t $1),$(t $2),$(t $3),$(t $4),$(t $5),$(t $6)"
}

limits=$(lmk 10 19 30 38 54 98)

#wr $params/adj 
wrl $params/minfree $limits
wrl $params/cost 32

unset params extramb tend t lmk limits

}

#===================================================#
#===================================================#
#===================================================#

# Module 5: Kernel modules toggles

M5(){

a="/sys/module/workqueue/parameters"

wrl $a/power_efficient N
wrl $a/disable_numa Y

a="/sys/module/msm_thermal"

wrl $a/core_control/enabled 0
wrl $a/parameters/enabled N
wrl $a/vdd_restriction/enabled N

a="/sys/module/msm_performance/parameters"

count="$kernel_max"

while [ "$count" -ge "0" ]; do
cpulist="$count $cpulist";
count=$((count-1)); done

for x in $cpulist; do
list="$list $x:0"; done

wrl $a/cpu_min_freq "$list"
wrl $a/io_enter_cycles 100
wrl $a/io_exit_cycles 100
wrl $a/ip_evt_trig_thr 1

unset a list cpulist count cpu

}

#===================================================#
#===================================================#
#===================================================#

# Module 6: Adjust interactive CPU governor tunables

M6(){

cpu="/sys/devices/system/cpu"

for x in $cpu/cpu*; do [ -e $x/cpufreq ] && first_cpu=$x && break; done

cat $first_cpu/cpufreq/scaling_available_governors | grep interactive >> /dev/null

if [ $? ]; then

lastfreq=0
curfreq=0

x=0; until [ $x == $kernel_max ]; do
if [ -e $cpu/cpu$x/cpufreq/cpuinfo_min_freq ]; then
curfreq=$(read $cpu/cpu$x/cpufreq/cpuinfo_min_freq)
[ ! $curfreq == $lastfreq ] && clusters="$clusters $x";
lastfreq=$curfreq; fi; x=$(($x+1)); done

counter=0

until [ $counter -gt $kernel_max ]; do
list_of_cores="$list_of_cores $counter";
counter=$(($counter+1)); done

unset lastfreq curfreq x counter

# example output for Moto G5 Qualcomm SD 430:
# $clusters=" 0 4" ( 0-3 big / 4-7 little )
# $list_of_cores=" 0 1 2 3 4 5 6 7" (0 to $kernel_max)

tunecpu(){

# This now is a per cluster function.
# It runs <cluster count> times. 2 times for big.LITTLE 

freq=$cpu/cpu$1/cpufreq/scaling_available_frequencies

if [ -e $freq ]; then
# get lowest frequency
minf=$(read $freq | awk '{ print $1 }'); fi

# Clear variable in case the device has
# more than 1 cluster (big.LITTLE or more tiers)

unset rev_list

# create a reversed list of this cluster frequencies

for x in $(read $freq); do
rev_list="$x $rev_list"; done

count=0
for x in $(read $freq); do count=$(($count+1)); done
numfreq=$count

# this creates a variable that equals the quantity of frequencies

for x in $rev_list; do
ef=$preef
preef=$x
[ $count == $(($numfreq-3)) ] && break; done

for x in "$cpu/cpu$1/cpufreq/interactive" "$cpu/cpufreq/interactive"; do [ -e $x ] && gov=$x; done

#wrl $gov/above_hispeed_delay "10000 $preef:100000 $ef:200000"
wrl $gov/above_hispeed_delay 100000
wrl $gov/boost 0
wrl $gov/boostpulse_duration 10000
wrl $gov/fast_ramp_down 0
wrl $gov/go_hispeed_load 90
wrl $gov/hispeed_freq $minf
wrl $gov/io_is_busy 0
wrl $gov/input_boost 0
wrl $gov/min_sample_time 100000 #80000
wrl $gov/timer_rate 100000 #20000
wrl $gov/timer_slack 30000
wrl $gov/use_sched_load 0
wrl $gov/target_loads "1 $minf:90 $ef:95";
}

for x in $clusters; do wrl $cpu/cpu$x/cpufreq/scaling_governor interactive; tunecpu $x; done; fi

unset clusters cpu gov kernel_max first_cpu list_of_cores x numfreq count minf ef preef freq rev_list

}

#===================================================#
#===================================================#
#===================================================#

# Module 7: Adjust Adreno gpu settings

M7(){

sys=/sys/class/kgsl/kgsl-3d0
if [ -e $sys ]; then
min=$(($(read $sys/num_pwrlevels)-1))
if [ ! $min == "" ]; then
wrl $sys/default_pwrlevel $min
wrl $sys/min_pwrlevel $min
wrl $sys/max_pwrlevel 0
fi; fi
unset sys min


}

#===================================================#
#===================================================#
#===================================================#

# Create needed functions:

read(){ [ -e $1 ] && cat $1; }

search(){ read $2 | grep $1 >> /dev/null; }

# search <string> <file>
# searches for string in file if it exists and returns
# just an error code, 0 (true) for "string found" or 
# 1 (false) for "not found". Does not print.

wr(){
[ -e $1 ] && $(echo -e $2 > $1 || echo "$1 write error."); }

wrl(){
[ -e $1 ] && chmod 666 $1 && echo $2 > $1 && chmod 444 $1; }

if [ $dumpE == 1 ]; then # initialize dump

dpath=/data/$scriptname

for x in $dpath*; do
[ -e $x ] && rm $x; done

dump="$dpath-$(date +%Y-%m-%d).txt"

wr(){
if [ -e $1 ]; then
echo -e "WR - A: $1 = $(cat $1)\nWR - B: $1 = $2\n" >> $dump; fi; }

wrl(){
if [ -e $1 ]; then
echo -e "WRL - A: $1 = $(cat $1)\nWRL - B: $1 = $2\n" >> $dump;
chmod 666 "$1"; fi; }

fi # end dump

marker="/data/$scriptname-last-run"

if [ $dumpE == 0 ]; then touch $marker; echo $(date) > $marker; fi
unset marker

# Get highest CPU core number
kernel_max=$(cat /sys/devices/system/cpu/kernel_max)

# Get RAM size in KB 
msize=$(cat /proc/meminfo | grep "MemTotal" | awk '{ print $2 }')

specific_opt

unset specific_opt dumpE msize kernel_max apply dump dpath marker

exit 0