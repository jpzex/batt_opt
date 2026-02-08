# batt_opt.sh
# Version 1.2
# 2026-02-08 @ 01:43 (UTC)
# ID: 5s41d
# Do not steal
# Written by @jpzex (XDA & Telegram)
# with help of @InoCity (Telegram)
# and ChatGPT (proper vibe coding is so real, guys)
# Use at your own risk!

#set -xv # debug

##### USER SET VARIABLES #####

# Dump mode (0 or 1): save a log of before and after for every value to be changed.
dump=0

# Dry run mode (0 or 1): do not apply any value, print on screen what it would change.
dryrun=0

##### DO NOT EDIT BELOW THIS LINE #####

scriptname=batt_opt

# Efficient optimizations focused
# on extending the battery time.

main_opt(){

M2
M3
M4
M5
M6
M7

}

#===================================================#

# Module 2: Sysctl Tweaks with focus on a better battery life

M2(){
local sys=/proc/sys

sysctl_list=$(echo "

fs.file-max = 1048576
fs.inotify.max_queued_events = 1024
fs.leases-enable = 0
fs.lease-break-time = 1
fs.nr_open = 1048576
fs.pipe-max-size = 262144
fs.pipe-user-pages-hard = 8192
fs.pipe-user-pages-soft = 4096
fs.suid_dumpable = 0
fs.verity.require_signatures = 0

kernel.hung_task_timeout_secs = 0
kernel.random.urandom_min_reseed_secs = 600
kernel.random.write_wakeup_threshold = 4096
kernel.sched_boost = 0
kernel.sched_child_runs_first = 0
kernel.sched_downmigrate = 50
kernel.sched_energy_aware = 1
kernel.sched_force_lb_enable = 0
kernel.sched_group_downmigrate = 50
kernel.sched_group_upmigrate = 95
kernel.sched_latency_ns = 30000000
kernel.sched_migration_cost_ns = 10000000
kernel.sched_min_granularity_ns = 4000000
kernel.sched_min_task_util_for_boost = 1024
kernel.sched_nr_migrate = 16
kernel.sched_prefer_spread = 0
kernel.sched_rr_timeslice_ms = 20
kernel.sched_rt_period_us = 1000000
kernel.sched_rt_runtime_us = 950000
kernel.sched_sync_hint_enable = 0
kernel.sched_upmigrate = 95
kernel.sched_user_hint = 0
kernel.sched_util_clamp_max = 1024
kernel.sched_util_clamp_min = 0
kernel.sched_wakeup_granularity_ns = 4000000
kernel.sched_walt_rotate_big_tasks = 0
kernel.sched_window_stats_policy = 0
kernel.soft_watchdog = 0
kernel.softlockup_panic = 0
kernel.timer_migration = 0
kernel.walt_low_latency_task_threshold = 0
kernel.walt_rtg_cfs_boost_prio = 0
kernel.watchdog = 0

net.core.netdev_max_backlog = 256
net.core.optmem_max = 65536
net.core.rmem_default = 131072
net.core.rmem_max = 1048576
net.core.wmem_default = 131072
net.core.wmem_max = 1048576
net.ipv4.ipfrag_high_thresh = 262144
net.ipv4.ipfrag_low_thresh = 196608
net.ipv4.tcp_limit_output_bytes = 1048576
net.ipv4.tcp_low_latency = 0
net.ipv4.tcp_max_orphans = 16384
net.ipv4.tcp_max_syn_backlog = 512
net.ipv4.tcp_max_tw_buckets = 2048
net.ipv4.tcp_mem = 131072 262144 524288
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_slow_start_after_idle = 1
net.ipv4.tcp_wmem = 4096 65536 4194304
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv6.ip6frag_high_thresh = 262144
net.ipv6.ip6frag_low_thresh = 196608
net.netfilter.nf_conntrack_max = 65536
net.unix.max_dgram_qlen = 512

vm.admin_reserve_kbytes = 8192
vm.compact_memory = 1
vm.compact_unevictable_allowed = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 1000
vm.extra_free_kbytes = 16384
vm.min_free_kbytes = 16384
vm.page-cluster = 4
vm.percpu_pagelist_fraction = 0
vm.swappiness = 100
vm.user_reserve_kbytes = 16384
vm.vfs_cache_pressure = 150
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 150
vm.want_old_faultaround_pte = 0

" | tr ' ' '&')

for x in $sysctl_list; do
detr=$(echo $x | tr '&' ' ')
key=$(echo $detr | cut -d '=' -f 1 | tr '.' '/')
value=$(echo $detr | cut -d '=' -f 2)
wrs $sys/$key $value
unset $x
done

unset x sys sysctl_list detr key value
}

#===================================================#

# Module 3: LMK Tweaks (if running on old Android)

M3(){

[ -d /sys/module/lowmemorykiller ] || return

local params=/sys/module/lowmemorykiller/parameters
local extramb=$(($msize/4096))
local tend=$(($msize/102400))

t(){
echo $((($1*$tend*32)+32*$extramb))
}

lmk(){
echo "$(t $1),$(t $2),$(t $3),$(t $4),$(t $5),$(t $6)"
}

wrl $params/minfree $(lmk 10 16 25 34 54 86)
wrl $params/cost 32

unset params extramb tend t lmk 

}

#===================================================#

# Module 4: borrowed from base_opt (but helps battery)

M4(){

wr /sys/block/zram0/max_comp_streams 1

}

#===================================================#

# Module 5: Kernel modules toggles

M5(){

wrs /sys/module/workqueue/parameters/power_efficient Y

local a="/sys/module/msm_performance/parameters"

local count="$kernel_max"

while [ "$count" -ge "0" ]; do
local cpulist+="$count ";
local count=$((count-1)); done

for x in $cpulist; do
local list+=" $x:0"; done

wrl $a/cpu_min_freq "$list"
wrl $a/io_enter_cycles 0
wrl $a/io_exit_cycles 0
wrl $a/ip_evt_trig_thr 999999

unset list

for x in $cpulist; do
local list+=" $x:10000000"; done # maybe 10GHz is enough

wrl $a/cpu_max_freq "$list"

unset a list cpulist count cpu x

}

#===================================================#

# Module 6: Adjust CPU governor

M6(){

cpu="/sys/devices/system/cpu"
setgov=none

for x in $cpu/cpu*; do [ -e $x/cpufreq ] && first_cpu=$x && break; done

lastfreq=0
curfreq=0

# Identify first CPU of each cluster

x=0; until [ $x == $kernel_max ]; do
if [ -e $cpu/cpu$x/cpufreq/cpuinfo_min_freq ]; then
curfreq=$(readf $cpu/cpu$x/cpufreq/cpuinfo_min_freq)
[ ! $curfreq == $lastfreq ] && clusters+="$x ";
lastfreq=$curfreq; fi; x=$(($x+1)); done
unset x

# example output for Moto G5 Qualcomm SD 430:
# $clusters=" 0 4" ( 0-3 big / 4-7 little )
#
# example output for Moto G34 Qualcomm SD 695:
# $clusters=" 0 6" ( 0-5 little / 6-7 big )

getfreqs(){

# This function runs <cluster count> times.

freq=$cpu/cpu$1/cpufreq/scaling_available_frequencies

if [ -e $freq ]; then
# get lowest frequency for core
minf=$(readf $freq | awk '{ print $1 }'); fi

# Clear variable in case the device has
# more than 1 cluster (big.LITTLE or more tiers)

unset rev_list

# create a reversed list of this cluster frequencies

for x in $(readf $freq); do
rev_list="$x $rev_list"; done

# this creates a variable that equals the quantity of frequencies

count=0
for x in $(readf $freq); do count=$(($count+1)); done
numfreq=$count

for x in $rev_list; do
ef=$preef
preef=$x
[ $count == $((numfreq-3)) ] && break; done
}

if grep -q schedutil $first_cpu/cpufreq/scaling_available_governors; then
setgov=schedutil

tunegov(){

getfreqs $1

for x in "$cpu/cpu$1/cpufreq/$setgov" "$cpu/cpufreq/$setgov"; do [ -e $x ] && gov=$x; done

# schedutil governor tweak

wrl $gov/up_rate_limit_us 6000
wrl $gov/down_rate_limit_us 1500

}

elif grep -q interactive $first_cpu/cpufreq/scaling_available_governors; then
setgov=interactive

tunegov(){

getfreqs $1

for x in "$cpu/cpu$1/cpufreq/$setgov" "$cpu/cpufreq/$setgov"; do [ -e $x ] && gov=$x; done

# interactive governor tweaks

wrl $gov/above_hispeed_delay 100000
wrl $gov/go_hispeed_load 90
wrl $gov/hispeed_freq $minf
wrl $gov/min_sample_time 100000
wrl $gov/timer_rate 200000
wrl $gov/target_loads "1 $minf:90 $ef:95";
}

fi

if [ $setgov == "none" ]; then return; else

for x in $clusters; do wrl $cpu/cpu$x/cpufreq/scaling_governor $setgov; tunegov $x; done

unset gov freq minf rev_list numfreq count ef preef tunegov getfreqs

fi

unset cpu setgov x first_cpu lastfreq curfreq clusters

}

#===================================================#

# Module 7: Adjust GPU (battery oriented)

M7(){

# Adreno
if [ -d /sys/class/kgsl/kgsl-3d0 ]; then

sys=/sys/class/kgsl/kgsl-3d0
min=$(($(readf $sys/num_pwrlevels)-1))

if [ ! "$min" = "" ]; then
wrl $sys/default_pwrlevel $min
wrl $sys/min_pwrlevel $min
wrl $sys/max_pwrlevel 1

fi

wrl $sys/force_bus_on 0
wrl $sys/force_clk_on 0
wrl $sys/force_no_nap 0

unset sys min

# Mali
elif sys=$(ls -d /sys/class/devfreq/*mali* /sys/class/devfreq/*gpu* 2>/dev/null | head -n1); then

freqs=$(readf $sys/available_frequencies)
min=$(echo $freqs | awk '{print $NF}')

if [ ! "$min" = "" ]; then
wrl $sys/min_freq $min
fi

unset sys freqs min

# Samsung (sgpu / Xclipse)
elif [ -d /sys/class/sgpu ]; then

sys=/sys/class/sgpu
min=$(($(readf $sys/num_pwrlevels)-1))

if [ ! "$min" = "" ]; then
wrl $sys/default_pwrlevel $min
fi

wrl $sys/force_bus_on 0
wrl $sys/force_clk_on 0
wrl $sys/force_no_nap 0

unset sys min

fi

}

#===================================================#

prep(){

np=/dev/null

which busybox > $np

[ $? != 0 ] && echo "No busybox found, please install it first. If you just installed, a reboot may be necessary." && exit 1

alias_list="mountpoint awk echo grep chmod fstrim cat mount uniq date"

for x in $alias_list; do
    alias $x="busybox $x";
done

marker="/data/lastrun_$scriptname"

if [ $dryrun -eq 0 ]; then touch $marker; echo $(date) > $marker; fi
unset marker

} # end prep

vars(){

# Get max cpu num kernel_max
kernel_max=$(cat /sys/devices/system/cpu/kernel_max)

# Get RAM size in KB 
msize=$(cat /proc/meminfo | grep "MemTotal" | awk '{ print $2 }')

readf(){ [ -e $1 ] && cat $1; }

search(){ readf $2 | grep $1 > $np; }

# search <string> <file>
# searches for string in file if it exists and returns
# just an error code, 0 (true) for "string found" or 
# 1 (false) for "not found". Does not print.

#=DUMP=AND=DRY=RUN=START============================#

if [ $dryrun -eq 0 ]; then
    have="have"

wr(){
    [ -e "$1" ] && echo -e "$2" > "$1" || \
    echo "ERROR: Cannot write $2 to $1."
}

wrs(){ # silent wr
    [ -e "$1" ] && echo -e "$2" > "$1"
}

wrl(){
    [ -e $1 ] && chmod 666 $1 && \
    echo -e "$2" > "$1" && chmod 444 $1
}

else
    have="have not"
    wr(){ [ -e $1 ] && echo -e "WR : $2 > $1"; }
    wrl(){ [ -e $1 ] && echo -e "WRL: $2 > $1"; }
fi

if [ $dump -eq 1 ]; then
    dpath=/data/$scriptname
    for x in $dpath*; do
        [ -e $x ] && rm $x
    done
    dpath="$dpath-$(date +%Y-%m-%d).txt"
    echo "The dump file is located in: $dpath. The values $have been applied because dryrun=$dryrun."

    wr(){
    if [ $dump -eq 1 ]; then
        if [ -e $1 ]; then
            echo -e "WR - A: $1 = $(cat $1)\nWR - B: $1 = $2\n" >> $dpath
            [ $dryrun -eq 0 ] && echo -e "$2" > "$1" || echo "$1 write error.";
        fi
     fi
    }

    wrl(){
    if [ $dump -eq 1 ]; then
        if [ -e $1 ]; then
            echo -e "WRL - A: $1 = $(cat $1)\nWRL - B: $1 = $2\n" >> $dpath
             [ $dryrun -eq 0 ] && chmod 666 $1 && echo $2 > $1 && chmod 444 $1
        fi
    fi
    }

fi # end dump

#=DUMP=AND=DRY=RUN=END==============================#

} # end vars

prep && vars && main_opt

unset main_opt scriptname alias_list dump dryrun dpath wr wrl readf search have np

exit 0

references(){

# https://haydenjames.io/linux-performance-almost-always-add-swap-part2-zram/

}
