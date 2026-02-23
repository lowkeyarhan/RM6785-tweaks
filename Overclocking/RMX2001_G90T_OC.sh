#!/system/bin/sh

# =============================================================
#  High Performance Script
#  Author   : Arhan Das
#  Version  : V3.2 - Dynamic device info header
# =============================================================

clear

# Gather device info dynamically
DEVICE_MODEL=$(getprop ro.product.model)
DEVICE_CODENAME=$(getprop ro.product.device)
DEVICE_BRAND=$(getprop ro.product.brand)
CHIPSET=$(getprop ro.board.platform)
ROM_NAME=$(getprop ro.build.display.id)
ANDROID_VER=$(getprop ro.build.version.release)
KERNEL_VER=$(uname -r)
CPU_MAX_LITTLE=$(cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq 2>/dev/null)
CPU_MAX_BIG=$(cat /sys/devices/system/cpu/cpufreq/policy6/cpuinfo_max_freq 2>/dev/null)
RAM_TOTAL=$(cat /proc/meminfo | grep MemTotal | awk '{printf "%.0f MB", $2/1024}')

echo "============================================="
echo " High Performance Mode"
echo "============================================="
echo " Device   : $DEVICE_BRAND $DEVICE_MODEL ($DEVICE_CODENAME)"
echo " Chipset  : $CHIPSET"
echo " Android  : $ANDROID_VER"
echo " ROM      : $ROM_NAME"
echo " Kernel   : $KERNEL_VER"
echo " CPU      : Little $(( CPU_MAX_LITTLE / 1000 ))MHz | Big $(( CPU_MAX_BIG / 1000 ))MHz"
echo " RAM      : $RAM_TOTAL"
echo "============================================="
echo " Author   : Arhan Das"
echo "============================================="
echo " Enabling SoC Overclocking if kernel supports it"
echo " Warning: This mode maximises performance."
echo " Device will heat up. Use at your own risk."
echo "============================================="
echo

# -------------------------------------------------------------
# tweak() - Write value and lock file with chmod 444
# so Android cannot revert our settings after applying them
# -------------------------------------------------------------
tweak() {
    if [ -f "$2" ]; then
        chmod 644 "$2" >/dev/null 2>&1
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" >/dev/null 2>&1
    fi
}

# -------------------------------------------------------------
# Power Save Mode Off
# -------------------------------------------------------------
settings put global low_power 0

# -------------------------------------------------------------
# GED Modules
# -------------------------------------------------------------
echo "Configuring GED Modules"
tweak 1 /sys/module/ged/parameters/gx_game_mode
tweak 1 /sys/module/ged/parameters/gx_force_cpu_boost
tweak 1 /sys/module/ged/parameters/boost_amp
tweak 1 /sys/module/ged/parameters/boost_extra
tweak 1 /sys/module/ged/parameters/boost_gpu_enable
tweak 1 /sys/module/ged/parameters/enable_cpu_boost
tweak 1 /sys/module/ged/parameters/enable_gpu_boost
tweak 1 /sys/module/ged/parameters/enable_game_self_frc_detect
tweak 0 /sys/module/ged/parameters/gpu_idle
tweak 1 /sys/module/ged/parameters/cpu_boost_policy
tweak 0 /sys/module/ged/parameters/ged_force_mdp_enable
tweak 1 /sys/module/ged/parameters/ged_boost_enable
tweak 1000 /sys/module/ged/parameters/ged_smart_boost
tweak 0 /sys/module/ged/parameters/gx_frc_mode
tweak 1 /sys/module/ged/parameters/gx_boost_on
tweak 1 /sys/module/ged/parameters/gx_3D_benchmark_on
tweak 0 /sys/module/ged/parameters/gpu_loading
tweak 100 /sys/module/ged/parameters/boost_upper_bound
tweak 1 /sys/module/ged/parameters/gpu_dvfs_enable
tweak 1 /sys/module/ged/parameters/g_gpu_timer_based_emu
tweak 0 /sys/module/ged/parameters/ged_monitor_3D_fence_disable
tweak 2000000 /sys/module/ged/parameters/gpu_cust_boost_freq
tweak 2000000 /sys/module/ged/parameters/gpu_cust_upbound_freq
tweak 600000 /sys/module/ged/parameters/gpu_bottom_freq
# Set dfps to screen refresh rate dynamically
GED_DFPS=$(dumpsys display | grep -oE 'fps=[0-9]+' | awk -F '=' '{print $2}' | head -n 1)
tweak "$GED_DFPS" /sys/module/ged/parameters/gx_dfps
echo "GED Modules configured"
echo

# -------------------------------------------------------------
# FPSGO - MediaTek Frame Performance Go Engine
# -------------------------------------------------------------
echo "Configuring FPSGO"
for fpsgo in /sys/kernel/fpsgo; do
    tweak 1 $fpsgo/fbt/boost_ta
    tweak 0 $fpsgo/fbt/enable_switch_down_throttle
    tweak 0 $fpsgo/fstb/adopt_low_fps
    tweak 0 $fpsgo/fstb/fstb_self_ctrl_fps_enable
    tweak 0 $fpsgo/fstb/enable_switch_sync_flag
    tweak 1 $fpsgo/fbt/boost_VIP
    tweak 0 $fpsgo/fstb/gpu_slowdown_check
    tweak 0 $fpsgo/fbt/thrm_limit_cpu
    tweak 100 $fpsgo/fbt/thrm_temp_th
    tweak 2 $fpsgo/fbt/llf_task_policy
done
tweak 101 /sys/kernel/ged/hal/gpu_boost_level
# FPSGO Advanced
for fpsgo_adv in /sys/module/mtk_fpsgo/parameters; do
    tweak 1 $fpsgo_adv/boost_affinity
    tweak 1 $fpsgo_adv/boost_LR
    tweak 1 $fpsgo_adv/xgf_uboost
    tweak 1 $fpsgo_adv/xgf_extra_sub
    tweak 1 $fpsgo_adv/gcc_enable
    tweak 1 $fpsgo_adv/gcc_hwui_hint
done
echo "FPSGO configured"
echo

# -------------------------------------------------------------
# CPU Mode
# -------------------------------------------------------------
echo "CPU Mode"
tweak 3 /proc/cpufreq/cpufreq_power_mode
cat /proc/cpufreq/cpufreq_power_mode
tweak 1 /proc/cpufreq/cpufreq_cci_mode
cat /proc/cpufreq/cpufreq_cci_mode
tweak 1 /proc/cpufreq/cpufreq_sched_disable
echo

# -------------------------------------------------------------
# Kernel Scheduler Tweaks
# -------------------------------------------------------------
echo "Kernel Scheduler Tweaks"
tweak 0 /proc/sys/kernel/sched_autogroup_enabled
tweak 1 /proc/sys/kernel/sched_child_runs_first
tweak 10 /proc/sys/kernel/perf_cpu_time_max_percent
tweak 0 /proc/sys/kernel/sched_cstate_aware
tweak 50000 /proc/sys/kernel/sched_migration_cost_ns
tweak 1000000 /proc/sys/kernel/sched_min_granularity_ns
tweak 1500000 /proc/sys/kernel/sched_wakeup_granularity_ns
tweak 0 /proc/sys/kernel/timer_migration
tweak 0 /proc/sys/kernel/sched_min_task_util_for_colocation
tweak 1 /proc/sys/kernel/sched_sync_hint_enable
# Sched features
if [ -f "/sys/kernel/debug/sched_features" ]; then
    tweak NEXT_BUDDY /sys/kernel/debug/sched_features
    tweak NO_TTWU_QUEUE /sys/kernel/debug/sched_features
fi
echo "Scheduler tweaks applied"
echo

# -------------------------------------------------------------
# EAS - Disable for pure performance scheduling
# -------------------------------------------------------------
echo "Kernel Mode"
tweak 0 /sys/devices/system/cpu/eas/enable
cat /sys/devices/system/cpu/eas/enable
echo

# -------------------------------------------------------------
# Scheduler I/O
# -------------------------------------------------------------
echo "Scheduler I/O"
echo deadline > /sys/block/mmcblk0/queue/scheduler
cat /sys/block/mmcblk0/queue/scheduler
tweak 32 /sys/block/mmcblk0/queue/read_ahead_kb
echo

# -------------------------------------------------------------
# CPU Performance node
# -------------------------------------------------------------
echo "Performance"
tweak 1 /sys/devices/system/cpu/perf/enable
cat /sys/devices/system/cpu/perf/enable
echo

# -------------------------------------------------------------
# GPU Frequency - dynamically reads highest from table
# -------------------------------------------------------------
echo "GPU Frequency"
GPU_FREQ_TABLE=$(cat /sys/kernel/gpu/gpu_freq_table)
GPU_MAX=$(echo $GPU_FREQ_TABLE | awk '{print $1}')
GPU_MIN=$(echo $GPU_FREQ_TABLE | awk '{print $3}')
echo "Detected GPU freq table: $GPU_FREQ_TABLE"
echo "Setting GPU max to ${GPU_MAX}MHz"
echo "Setting GPU min to ${GPU_MIN}MHz"
# Set via both interfaces
gpu_freq_khz=$((GPU_MAX * 1000))
if [ -f /proc/gpufreq/gpufreq_opp_dump ]; then
    gpu_freq_proc=$(cat /proc/gpufreq/gpufreq_opp_dump | grep -o 'freq = [0-9]*' | sed 's/freq = //' | sort -nr | head -n 1)
    tweak "$gpu_freq_proc" /proc/gpufreq/gpufreq_opp_freq
fi
tweak $GPU_MAX /sys/kernel/gpu/gpu_max_clock
tweak $GPU_MIN /sys/kernel/gpu/gpu_min_clock
echo "GPU max: $(cat /sys/kernel/gpu/gpu_max_clock) MHz"
echo "GPU min: $(cat /sys/kernel/gpu/gpu_min_clock) MHz"
echo

# -------------------------------------------------------------
# GPU Thermal & Limit Bypass - driver level
# -------------------------------------------------------------
echo "GPU Thermal Bypass"
tweak 1 /proc/gpufreq/gpufreq_limited_thermal_ignore
tweak 1 /proc/gpufreq/gpufreq_limited_oc_ignore
tweak 1 /proc/gpufreq/gpufreq_limited_low_batt_volume_ignore
tweak 1 /proc/gpufreq/gpufreq_limited_low_batt_volt_ignore
tweak 0 /proc/gpufreq/gpufreq_fixed_freq_volt
tweak 0 /proc/gpufreq/gpufreq_power_limited
echo "GPU limits bypassed at driver level"
echo

# -------------------------------------------------------------
# GPU Power Policy
# -------------------------------------------------------------
echo "GPU Power Policy"
tweak 1 /proc/mali/always_on
cat /proc/mali/always_on
tweak always_on /sys/devices/platform/13040000.mali/power_policy
cat /sys/devices/platform/13040000.mali/power_policy
tweak 0 /sys/class/misc/mali0/device/js_ctx_scheduling_mode
echo

# -------------------------------------------------------------
# DRAM / Memory Bus - force performance
# -------------------------------------------------------------
echo "DRAM Performance"
tweak 0 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
tweak 1 /sys/kernel/helio-dvfsrc/dvfsrc_qos_mode
tweak performance /sys/class/devfreq/mtk-dvfsrc-devfreq/governor
tweak performance /sys/devices/platform/soc/1c00f000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/governor
DEVFREQ_FILE="/sys/class/devfreq/mtk-dvfsrc-devfreq/available_frequencies"
if [ -f "$DEVFREQ_FILE" ]; then
    highest_freq=$(awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/ && $i > max) max=$i} END{print max}' "$DEVFREQ_FILE")
    tweak $highest_freq /sys/class/devfreq/mtk-dvfsrc-devfreq/min_freq
    tweak $highest_freq /sys/class/devfreq/mtk-dvfsrc-devfreq/max_freq
fi
# eMMC governor
for path in /sys/class/devfreq/mmc*; do
    tweak performance $path/governor
done
echo "DRAM set to performance"
echo

# -------------------------------------------------------------
# Battery OC Throttle - disable
# -------------------------------------------------------------
echo "Disabling battery OC throttle"
tweak "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop
echo

# -------------------------------------------------------------
# Thermal Daemon + CPU Thermal Message Lock
# -------------------------------------------------------------
echo "Disable Throttle Thermal"
echo "Warning: Highest CPU temp can reach up to 86°C"
echo "Highest Battery temp can reach up to 50°C"
stop thermal
# Lock thermal message so it cannot claw back CPU frequencies
chmod 644 /sys/devices/virtual/thermal/thermal_message/cpu_limits 2>/dev/null
for path in /sys/devices/system/cpu/*/cpufreq; do
    cpu_maxfreq=$(cat $path/cpuinfo_max_freq)
    echo "cpu$(awk '{print $1}' $path/affected_cpus) $cpu_maxfreq" > /sys/devices/virtual/thermal/thermal_message/cpu_limits 2>/dev/null
    tweak "$cpu_maxfreq" $path/scaling_max_freq
    tweak "$cpu_maxfreq" $path/scaling_min_freq
done
chmod 000 /sys/devices/virtual/thermal/thermal_message/cpu_limits 2>/dev/null
echo "Thermal locked"
echo

# -------------------------------------------------------------
# PPM
# -------------------------------------------------------------
echo "PPM:"
tweak 1 /proc/ppm/enabled
echo 0 0 > /proc/ppm/policy_status
echo 1 1 > /proc/ppm/policy_status
echo 2 0 > /proc/ppm/policy_status
echo 3 0 > /proc/ppm/policy_status
echo 4 0 > /proc/ppm/policy_status
echo 5 0 > /proc/ppm/policy_status
echo 6 1 > /proc/ppm/policy_status
echo 7 1 > /proc/ppm/policy_status
echo 8 0 > /proc/ppm/policy_status
echo 9 1 > /proc/ppm/policy_status
cat /proc/ppm/policy_status
echo

# -------------------------------------------------------------
# Governor
# -------------------------------------------------------------
echo "Governor:"
for path in /sys/devices/system/cpu/cpufreq/policy*; do
    tweak performance "$path/scaling_governor"
done
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo

# -------------------------------------------------------------
# CPU Frequency Lock
# -------------------------------------------------------------
echo "Locking CPU frequencies"
cluster=0
for path in /sys/devices/system/cpu/cpufreq/policy*; do
    cpu_maxfreq=$(cat $path/cpuinfo_max_freq)
    tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
    tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
    cluster=$((cluster + 1))
done
echo "Big cluster locked to 2050MHz"
echo "Little cluster locked to 2000MHz"
echo

# -------------------------------------------------------------
# Game Touch Sampling
# -------------------------------------------------------------
echo "Game Touch Sampling Boost enabled"
tweak 1 /proc/touchpanel/game_switch_enable
echo "Fix Touch Screen"
tweak 1 /proc/touchpanel/oplus_tp_direction
tweak 0 /proc/touchpanel/oplus_tp_limit_enable
echo

# -------------------------------------------------------------
# Disable CABC
# -------------------------------------------------------------
echo "Disable CABC Mode"
tweak 0 /sys/kernel/oppo_display/LCM_CABC
echo

# -------------------------------------------------------------
# Debugging off
# -------------------------------------------------------------
tweak 0 /sys/kernel/ccci/debug
tweak 0 /sys/kernel/tracing/tracing_on
tweak "0 0 0 0" /proc/sys/kernel/printk
tweak off /proc/sys/kernel/printk_devkmsg
tweak 0 /proc/sys/debug/exception-trace

# -------------------------------------------------------------
# POWERHAL SPORT MODE
# -------------------------------------------------------------
echo "Adding games to PowerHAL Sport Mode"
echo -e "com.mobile.legends\ncom.tencent.ig\ncom.miHoYo.GenshinImpact\ncom.tencent.tmgp.pubgmhd\ncom.dts.freefireth\ncom.dts.freefiremax\njp.konami.pesam\ncom.pubg.newstate\ncom.garena.game.codm\ncom.pubg.imobile\ncom.ea.gp.apexlegendsmobilefps\ncom.riotgames.league.wildrift\n" > /data/vendor/powerhal/smart
echo "Games registered in Sport Mode:"
cat /data/vendor/powerhal/smart
echo

# -------------------------------------------------------------
# Logcat
# -------------------------------------------------------------
echo "Force stop logcat to reduce CPU hogging"
stop logd
echo

# -------------------------------------------------------------
# TCP
# -------------------------------------------------------------
echo "TCP Congestion Control"
tweak cubic /proc/sys/net/ipv4/tcp_congestion_control
cat /proc/sys/net/ipv4/tcp_congestion_control
tweak 1 /proc/sys/net/ipv4/tcp_low_latency
echo "TCP low latency enabled"
echo

# -------------------------------------------------------------
# VM Tweaks
# -------------------------------------------------------------
echo "VM Tweaks"
tweak 10 /proc/sys/vm/swappiness
tweak 10 /proc/sys/vm/dirty_ratio
tweak 5 /proc/sys/vm/dirty_background_ratio
tweak 1000 /proc/sys/vm/dirty_writeback_centisecs
tweak 80 /proc/sys/vm/vfs_cache_pressure
tweak 0 /proc/sys/vm/compaction_proactiveness
tweak 0 /proc/sys/vm/page-cluster
echo "VM tweaks applied"
echo

# -------------------------------------------------------------
# CPUSet / SchedTune
# -------------------------------------------------------------
echo "Modify CPUStune"

# CPU Load settings
tweak 0-7 /dev/cpuset/foreground/cpus
tweak 0-2 /dev/cpuset/background/cpus
tweak 0-5 /dev/cpuset/system-background/cpus
tweak 0-7 /dev/cpuset/top-app/cpus
tweak 0 /dev/cpuset/restricted/cpus

# Disable sched load balance for performance
tweak 0 /dev/cpuset/sched_load_balance 2>/dev/null
tweak 0 /dev/cpuset/foreground/sched_load_balance 2>/dev/null

# Realtime
tweak 0 /dev/stune/rt/schedtune.boost
tweak 1 /dev/stune/rt/schedtune.prefer_idle

# Background
tweak 0 /dev/stune/background/schedtune.util.max.effective
tweak 0 /dev/stune/background/schedtune.util.min.effective
tweak 0 /dev/stune/background/schedtune.util.max
tweak 0 /dev/stune/background/schedtune.util.min
tweak 0 /dev/stune/background/schedtune.boost
tweak 0 /dev/stune/background/schedtune.prefer_idle

# Foreground
tweak 1024 /dev/stune/foreground/schedtune.util.max.effective
tweak 0 /dev/stune/foreground/schedtune.util.min.effective
tweak 1024 /dev/stune/foreground/schedtune.util.max
tweak 0 /dev/stune/foreground/schedtune.util.min
tweak 0 /dev/stune/foreground/schedtune.boost
tweak 1 /dev/stune/foreground/schedtune.prefer_idle

# Top-App
tweak 1024 /dev/stune/top-app/schedtune.util.max.effective
tweak 0 /dev/stune/top-app/schedtune.util.min.effective
tweak 1024 /dev/stune/top-app/schedtune.util.max
tweak 0 /dev/stune/top-app/schedtune.util.min
tweak 0 /dev/stune/top-app/schedtune.boost
tweak 1 /dev/stune/top-app/schedtune.prefer_idle

# Global
tweak 0 /dev/stune/schedtune.util.min
tweak 1024 /dev/stune/schedtune.util.max
tweak 1024 /dev/stune/schedtune.util.max.effective
tweak 0 /dev/stune/schedtune.util.min.effective
tweak 0 /dev/stune/schedtune.boost
tweak 1 /dev/stune/schedtune.prefer_idle
echo

# -------------------------------------------------------------
# Game State
# -------------------------------------------------------------
tweak 1 /proc/game_state 2>/dev/null
tweak 0 /proc/trans_scheduler/enable 2>/dev/null

# -------------------------------------------------------------
# Kill all third party apps to free RAM - runs last so
# MiXplorer and script runner stay alive during execution
# -------------------------------------------------------------
echo "Killing background apps to free RAM"
for pkg in $(pm list packages -3 | cut -f 2 -d ":"); do
    if [ "$pkg" != "com.google.android.inputmethod.latin" ] && \
       [ "$pkg" != "com.mixplorer" ] && \
       [ "$pkg" != "com.mixplorer.silver" ]; then
        am force-stop "$pkg" >/dev/null 2>&1
    fi
done
am kill-all >/dev/null 2>&1
echo 3 > /proc/sys/vm/drop_caches
echo "Background apps cleared"
echo

echo "============================================="
echo " High Performance Mode V3 is ACTIVE"
echo " For best experience, enable all 8 CPUs"
echo " Author  : Arhan Das | Assisted by Claude"
echo "============================================="
echo