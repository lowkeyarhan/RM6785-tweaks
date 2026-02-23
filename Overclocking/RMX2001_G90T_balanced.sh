#!/system/bin/sh

    clear
    echo Activating Balanced Mode
    echo Optimised for smooth daily use with efficient battery consumption
    echo
    
	# GED Modules - partial boost, not full game mode but not fully off either
	echo Configuring GED Modules
	echo 0 > /sys/module/ged/parameters/gx_game_mode
	echo 0 > /sys/module/ged/parameters/gx_force_cpu_boost
	echo 0 > /sys/module/ged/parameters/boost_amp
	echo 0 > /sys/module/ged/parameters/boost_extra
	echo 0 > /sys/module/ged/parameters/boost_gpu_enable
	echo 1 > /sys/module/ged/parameters/enable_cpu_boost
	echo 1 > /sys/module/ged/parameters/enable_gpu_boost
	echo 0 > /sys/module/ged/parameters/enable_game_self_frc_detect
	echo 50 > /sys/module/ged/parameters/gpu_idle
	echo 0 > /sys/module/ged/parameters/cpu_boost_policy
	echo 0 > /sys/module/ged/parameters/ged_force_mdp_enable
	echo 1 > /sys/module/ged/parameters/ged_boost_enable
	echo 50 > /sys/module/ged/parameters/ged_smart_boost
	echo 0 > /sys/module/ged/parameters/gx_frc_mode
	echo 0 > /sys/module/ged/parameters/gx_boost_on
	echo GED Modules configured for balanced mode
	echo
	
	# CPU Mode - mode 1 is balanced, not fully performance (3) nor fully powersave (0)
	echo CPU Mode
	echo 1 > /proc/cpufreq/cpufreq_power_mode
	cat /proc/cpufreq/cpufreq_power_mode
	echo 0 > /proc/cpufreq/cpufreq_cci_mode
	cat /proc/cpufreq/cpufreq_cci_mode
	echo
	
	# Sched - EAS mode 1, responsive but still energy aware
	echo Kernel Mode
	echo 1 > /sys/devices/system/cpu/eas/enable
	cat /sys/devices/system/cpu/eas/enable
	echo
	
    # Scheduler I/O - mq-deadline is better than cfq for modern eMMC
    echo Scheduler I/O
    echo mq-deadline > /sys/block/mmcblk0/queue/scheduler
    cat /sys/block/mmcblk0/queue/scheduler
    echo

	# Performance node - keep off for battery
	echo Performance
	echo 0 > /sys/devices/system/cpu/perf/enable
	cat /sys/devices/system/cpu/perf/enable
	echo
	
	# GPU frequency - set a sensible min so UI never stutters
	echo GPU Frequency
	GPU_FREQ_TABLE=$(cat /sys/kernel/gpu/gpu_freq_table)
	GPU_MAX=$(echo $GPU_FREQ_TABLE | awk '{print $1}')
	GPU_MIN=$(echo $GPU_FREQ_TABLE | awk '{print $7}')
	echo Detected GPU freq table: $GPU_FREQ_TABLE
	echo Setting GPU max to ${GPU_MAX}MHz - allows full boost when needed
	echo Setting GPU min to ${GPU_MIN}MHz - prevents UI stutter
	echo $((GPU_MAX * 1000)) > /proc/gpufreq/gpufreq_opp_freq
	echo $GPU_MAX > /sys/kernel/gpu/gpu_max_clock
	echo $GPU_MIN > /sys/kernel/gpu/gpu_min_clock
	echo GPU max: $(cat /sys/kernel/gpu/gpu_max_clock) MHz
	echo GPU min: $(cat /sys/kernel/gpu/gpu_min_clock) MHz
	echo
	
	# GPU Power Policy - coarse_demand is ideal for daily use, powers down when idle
	echo GPU Power Policy
	echo 0 > /proc/mali/always_on
	cat /proc/mali/always_on
	echo coarse_demand > /sys/devices/platform/13040000.mali/power_policy
	cat /sys/devices/platform/13040000.mali/power_policy
	echo

	# Thermal - keep it running in balanced mode, protect the device
	echo Thermal daemon running normally
	start thermal
	echo

	# PPM - keep enabled with balanced policies
	echo PPM :
	echo 1 > /proc/ppm/enabled
	echo 0 1 > /proc/ppm/policy_status
	echo 1 1 > /proc/ppm/policy_status
	echo 2 1 > /proc/ppm/policy_status
	echo 3 0 > /proc/ppm/policy_status
	echo 4 0 > /proc/ppm/policy_status
	echo 5 1 > /proc/ppm/policy_status
	echo 6 1 > /proc/ppm/policy_status
	echo 7 1 > /proc/ppm/policy_status
	echo 8 0 > /proc/ppm/policy_status
	echo 9 1 > /proc/ppm/policy_status
	cat /proc/ppm/policy_status
	echo
	
	# Governor - schedutil is perfect for balanced, smart and responsive
	echo Governor:
	echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
	echo schedutil > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
	cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
	echo
	
	# CPU frequency - unlock min/max so schedutil can breathe freely
	echo CPU Frequency - unlocked for smart scaling
	# big cluster
	echo Big cluster: 774MHz - 2050MHz
	echo 1 2050000 > /proc/ppm/policy/hard_userlimit_max_cpu_freq
	echo 1 774000 > /proc/ppm/policy/hard_userlimit_min_cpu_freq

	# LITTLE cluster
	echo Little cluster: 500MHz - 2000MHz
	echo 0 2000000 > /proc/ppm/policy/hard_userlimit_max_cpu_freq
	echo 0 500000 > /proc/ppm/policy/hard_userlimit_min_cpu_freq
	echo
	
	# Game Touch Sampling - keep on, never hurts
	echo Game Touch Sampling kept active
	echo 1 > /proc/touchpanel/game_switch_enable
	
	# Fix Touch Screen
	echo Fix Touch Screen
	echo 1 > /proc/touchpanel/oplus_tp_direction
	echo 0 > /proc/touchpanel/oplus_tp_limit_enable
	echo

	# Disable CABC - keep off, makes display look better
	echo Disable CABC
	echo 0 > /sys/kernel/oppo_display/LCM_CABC
	echo

	# Logcat
	echo Force stop logcat to reduce CPU hogging
	stop logd
	echo

    # TCP - westwood is better for daily mobile use
    echo TCP Congestion Control
    echo westwood > /proc/sys/net/ipv4/tcp_congestion_control
    cat /proc/sys/net/ipv4/tcp_congestion_control
    echo Enable TCP low latency
    echo 1 > /proc/sys/net/ipv4/tcp_low_latency
    echo

    # VM - balanced memory management, not aggressive
    echo VM Tweaks
    echo Soft RAM cache clear
    echo 1 > /proc/sys/vm/drop_caches
    echo Balanced swappiness
    echo 40 > /proc/sys/vm/swappiness
    cat /proc/sys/vm/swappiness
    echo 20 > /proc/sys/vm/dirty_ratio
    echo 10 > /proc/sys/vm/dirty_background_ratio
    echo 1500 > /proc/sys/vm/dirty_writeback_centisecs
    echo VM tweaks applied
    echo

	# CPUStune - balanced, background gets some CPU but foreground is prioritised
	echo Modify CPUStune
	
	# CPU Load
	echo 0-7 > /dev/cpuset/foreground/cpus
	echo 0-3 > /dev/cpuset/background/cpus
	echo 0-5 > /dev/cpuset/system-background/cpus
	echo 0-7 > /dev/cpuset/top-app/cpus
	echo 0-1 > /dev/cpuset/restricted/cpus
	
	# Realtime
	echo 0 > /dev/stune/rt/schedtune.boost
	echo 1 > /dev/stune/rt/schedtune.prefer_idle
	
	# Background - allow minimal activity
	echo 0 > /dev/stune/background/schedtune.util.max.effective
	echo 0 > /dev/stune/background/schedtune.util.min.effective
	echo 200 > /dev/stune/background/schedtune.util.max
	echo 0 > /dev/stune/background/schedtune.util.min
	echo 0 > /dev/stune/background/schedtune.boost
	echo 0 > /dev/stune/background/schedtune.prefer_idle
	
	# Foreground - responsive but not pinned to max
	echo 1024 > /dev/stune/foreground/schedtune.util.max.effective
	echo 0 > /dev/stune/foreground/schedtune.util.min.effective
	echo 1024 > /dev/stune/foreground/schedtune.util.max
	echo 0 > /dev/stune/foreground/schedtune.util.min
	echo 0 > /dev/stune/foreground/schedtune.boost
	echo 1 > /dev/stune/foreground/schedtune.prefer_idle
	
	# Top-App - fully responsive for whatever app you're using
	echo 1024 > /dev/stune/top-app/schedtune.util.max.effective
	echo 0 > /dev/stune/top-app/schedtune.util.min.effective
	echo 1024 > /dev/stune/top-app/schedtune.util.max
	echo 0 > /dev/stune/top-app/schedtune.util.min
	echo 0 > /dev/stune/top-app/schedtune.boost
	echo 1 > /dev/stune/top-app/schedtune.prefer_idle
	
	# Global
	echo 0 > /dev/stune/schedtune.util.min
	echo 1024 > /dev/stune/schedtune.util.max
	echo 1024 > /dev/stune/schedtune.util.max.effective
	echo 0 > /dev/stune/schedtune.util.min.effective
	echo 0 > /dev/stune/schedtune.boost
	echo 1 > /dev/stune/schedtune.prefer_idle
	echo
	
	echo Balanced Mode is activated
	echo Device is optimised for smooth daily use
	echo
