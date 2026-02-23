# RM6785 / G90T Overclocking Scripts

Scripts for the **Realme RMX2001** (RM6785, MediaTek Helio G90T chipset).  
Author: **Arhan Das**

> **Requires root.** Run via a root-capable file manager (e.g. MiXplorer) or a terminal emulator with root access.

---

## Scripts

| Script                     | Purpose                                               |
| -------------------------- | ----------------------------------------------------- |
| `RMX2001_G90T_OC.sh`       | Maximum performance / overclock — gaming & benchmarks |
| `RMX2001_G90T_balanced.sh` | Balanced — smooth daily use with efficient battery    |

---

## RMX2001_G90T_OC.sh — Overclock Mode

Pushes every subsystem to its hardware maximum. Intended for gaming sessions or benchmark runs. **Device will heat up significantly. CPU can reach ~86 °C, battery up to ~50 °C. Use at your own risk.**

A `tweak()` helper function writes each value and then **chmod 444-locks** the sysfs node so Android cannot revert the setting after it is applied.

### What it does

#### GED (GPU Enhancement Driver) Modules

- Enables full **game mode**, force CPU boost, GPU boost, boost amplifier, boost extra, and 3D benchmark mode (`gx_3D_benchmark_on`).
- Sets **GPU custom boost frequency and upper-bound to 2000 MHz**, bottom floor to 600 MHz.
- GPU idle is forced to 0 — the GPU never voluntarily throttles down.
- GPU DVFS (dynamic voltage/frequency scaling) kept enabled for headroom.
- `gx_dfps` is dynamically read from the display refresh rate and written so GED targets the correct frame rate.

#### FPSGO — MediaTek Frame Performance Go Engine

- Boosts the top-app (TA) thread aggressively (`boost_ta`, `boost_VIP`).
- Disables frame-rate self-throttling (`enable_switch_down_throttle`, `fstb_self_ctrl_fps_enable`, `adopt_low_fps`).
- Enables affinity boosting (`boost_affinity`, `boost_LR`) and extra XGF sub-frame tracking (`xgf_extra_sub`, `xgf_uboost`).
- GCC (Game CPU Control) enabled with HWUI hints for smoother UI rendering.
- GPU boost level set to 101 (above the normal ceiling).

#### CPU Mode & Scheduler

- **CPU power mode 3** — full performance mode (vs. 1 = balanced, 0 = powersave).
- **CCI mode** (CPU-cluster interconnect) enabled for maximum inter-cluster bandwidth.
- CPU scheduler disabled from frequency hinting (`cpufreq_sched_disable 1`) so the governor has sole control.
- `sched_autogroup_enabled` off, `sched_child_runs_first` on, migration cost and granularity tuned for low-latency task placement.
- Scheduler features: `NEXT_BUDDY` (prefer the last woken sibling) and `NO_TTWU_QUEUE` (wake tasks immediately without queuing).
- **EAS (Energy Aware Scheduling) disabled** — switches from energy-saving to pure-performance scheduling.

#### I/O Scheduler

- **deadline** scheduler on the eMMC block device (`mmcblk0`).
- Read-ahead reduced to **32 KB** (lower latency over higher throughput).

#### CPU Performance Node

- `/sys/devices/system/cpu/perf/enable` → **1** — activates the MediaTek hardware performance assist node.

#### CPU Frequency — Locked to Maximum

- **Governor: `performance`** on all CPU policies (overrides schedutil/ondemand).
- **Big cluster (policy6):** min and max both locked to hardware max — **2050 MHz**.
- **Little cluster (policy0):** min and max both locked to hardware max — **2000 MHz**.
- PPM (Power Policy Manager) hard user-limits set to match, so nothing can scale them back down.

#### GPU Frequency & Thermal Bypass

- GPU max and min clock dynamically read from `/sys/kernel/gpu/gpu_freq_table`; max is the first (highest) entry, min set to the third entry for a high floor.
- GPU frequency set through both `/proc/gpufreq/gpufreq_opp_freq` and the sysfs gpu clock nodes.
- **Driver-level thermal limits bypassed:**
  - `gpufreq_limited_thermal_ignore` → 1
  - `gpufreq_limited_oc_ignore` → 1
  - `gpufreq_limited_low_batt_volume_ignore` → 1
  - `gpufreq_limited_low_batt_volt_ignore` → 1
  - `gpufreq_power_limited` → 0

#### GPU Power Policy (Mali)

- **`always_on` policy** — the Mali GPU is never power-gated; eliminates cold-start latency on every frame.
- `js_ctx_scheduling_mode` → 0 for round-robin context scheduling.

#### DRAM / Memory Bus

- **Helio DVFSRC (Dynamic Voltage & Frequency Scaling Resource Controller)** set to performance mode:
  - `dvfsrc_qos_mode` → 1 (QoS performance mode).
  - `dvfsrc_force_vcore_dvfs_opp` → 0 (let the performance governor pick the highest OPP).
  - `mtk-dvfsrc-devfreq` governor → **`performance`** (forces highest DRAM operating point).
  - `min_freq` and `max_freq` both locked to the highest available DRAM frequency.
- eMMC devfreq governor also set to **`performance`**.

#### Battery OC Throttle

- `battery_oc_protect_stop` → **stop 1** — disables the battery overcurrent protection throttle that would otherwise reduce CPU frequency when draw is high.

#### Thermal Daemon — Fully Stopped & Locked

- `thermal` service **stopped** entirely.
- `/sys/devices/virtual/thermal/thermal_message/cpu_limits` written with each CPU's hardware max frequency, then **chmod 000-locked** — the thermal framework cannot write frequency caps back even if it restarts.
- `scaling_max_freq` and `scaling_min_freq` for every CPU policy set to hardware maximum and locked.

#### PowerHAL Sport Mode

- Writes a game package list to `/data/vendor/powerhal/smart` so MediaTek's PowerHAL recognises these apps and applies Sport Mode automatically:
  - Mobile Legends, BGMI / PUBG Mobile, Genshin Impact, Free Fire, Free Fire MAX, COD Mobile, PUBG: New State, PES, Apex Legends Mobile, Wild Rift.

#### Networking — TCP

- Congestion control: **`cubic`** (high-throughput, standard Linux default).
- `tcp_low_latency` → 1.

#### Virtual Memory (RAM Management)

- **Swappiness → 10** — kernel aggressively keeps data in RAM, almost never swaps.
- `dirty_ratio` → 10, `dirty_background_ratio` → 5 — dirty pages flushed quickly so write cache stays small.
- `dirty_writeback_centisecs` → 1000 (10 s interval).
- `vfs_cache_pressure` → 80 — retains VFS dentries/inodes longer.
- `compaction_proactiveness` → 0, `page-cluster` → 0 — no proactive memory compaction, no read-ahead on swap.
- At the end: `drop_caches 3` — forcefully frees all page cache, dentries, and inodes to give the running game maximum free RAM.

#### CPUSet & SchedTune

- **Foreground & Top-App:** all 8 CPUs (0-7), `schedtune.util.max` 1024, `prefer_idle` on.
- **Background:** restricted to CPUs 0-2, util capped to 0, no boost.
- `sched_load_balance` disabled on foreground and global cpusets — eliminates inter-cluster migration overhead.

#### Kernel Debugging — Disabled

- Kernel tracing off, CCCI debug off, printk silenced, exception traces off.

#### RAM Cleanup

- Force-stops all installed third-party apps (except the keyboard and MiXplorer) using `am force-stop` so gaming gets a clean slate with maximum free memory.

---

## RMX2001_G90T_balanced.sh — Balanced Mode

Optimised for smooth everyday use. All subsystems are tuned to scale intelligently between low and high performance rather than being pinned to max. Thermal protection remains active. Battery life is preserved.

### What it does

#### GED Modules

- Game mode **off**, force CPU boost **off**, GPU boost extra **off**.
- `enable_cpu_boost` and `enable_gpu_boost` remain **on** — the driver can still boost on demand.
- `gpu_idle` → 50, `ged_smart_boost` → 50 — conservative half-power boost ceiling.
- `gx_boost_on` off; `ged_boost_enable` on.

#### CPU Mode & Scheduler

- **CPU power mode 1** — balanced (not powersave, not full performance).
- CCI mode off.
- **EAS (Energy Aware Scheduling) enabled (mode 1)** — kernel places tasks on the most energy-efficient core that can handle the load.

#### I/O Scheduler

- **mq-deadline** on `mmcblk0` — better latency than CFQ for modern eMMC.

#### CPU Performance Node

- Disabled — no always-on hardware performance assist.

#### CPU Frequency — Free Scaling

- **Governor: `schedutil`** — frequency tracks actual CPU utilisation in real time.
- **Big cluster (policy6):** 774 MHz – 2050 MHz (free range).
- **Little cluster (policy0):** 500 MHz – 2000 MHz (free range).

#### GPU Frequency

- Max set to highest entry in the GPU frequency table.
- Min set to the 7th (lower) entry — prevents UI stutter without holding a high floor.
- GPU freq written via `/proc/gpufreq/gpufreq_opp_freq` and the sysfs clock nodes (no thermal bypass).

#### GPU Power Policy (Mali)

- **`coarse_demand`** — Mali powers down when idle, saving battery; spins back up on demand.
- `always_on` → 0.

#### Thermal

- Thermal daemon **running normally** — device temperature is protected.

#### PPM (Power Policy Manager)

- Balanced subset of policies enabled; thermal and battery policies remain active.

#### Touch

- Game touch sampling (`game_switch_enable`) → 1 — kept on for responsiveness.
- `oplus_tp_direction` fix applied; touch limit disabled.

#### Display — CABC

- Content Adaptive Backlight Control **disabled** — display brightness is not reduced by content analysis, giving more accurate colors.

#### Logcat

- `logd` stopped to reduce background CPU usage from log collection.

#### Networking — TCP

- Congestion control: **`westwood`** — designed for wireless/mobile links; handles packet loss better than cubic on mobile networks.
- `tcp_low_latency` → 1.

#### Virtual Memory (RAM Management)

- `drop_caches 1` — soft page cache clear at script start.
- **Swappiness → 40** — moderate; allows some swap activity while still favouring RAM.
- `dirty_ratio` → 20, `dirty_background_ratio` → 10 — more write buffering than OC mode.
- `dirty_writeback_centisecs` → 1500.

#### CPUSet & SchedTune

- **Foreground & Top-App:** all 8 CPUs, util.max 1024, prefer_idle on.
- **Background:** CPUs 0-3, util.max 200, no boost.
- **System-Background:** CPUs 0-5.
- **Restricted:** CPUs 0-1.
- No kill of background apps — existing sessions survive the switch.

---

## Comparison at a Glance

| Feature              | OC Mode                         | Balanced Mode             |
| -------------------- | ------------------------------- | ------------------------- |
| CPU governor         | `performance`                   | `schedutil`               |
| CPU frequency        | Locked to hardware max          | Free scaling within range |
| Big cluster range    | 2050–2050 MHz (locked)          | 774–2050 MHz              |
| Little cluster range | 2000–2000 MHz (locked)          | 500–2000 MHz              |
| EAS scheduling       | Disabled                        | Enabled                   |
| GED game mode        | Full on                         | Off                       |
| FPSGO                | Fully configured                | Not configured            |
| GPU power policy     | `always_on`                     | `coarse_demand`           |
| GPU thermal bypass   | Yes (all limits ignored)        | No                        |
| DRAM governor        | `performance` (locked max freq) | Not modified              |
| Thermal daemon       | Stopped + locked                | Running normally          |
| Battery OC throttle  | Disabled                        | Active                    |
| TCP congestion       | `cubic`                         | `westwood`                |
| Swappiness           | 10                              | 40                        |
| Background apps      | Killed at end                   | Left running              |
| PowerHAL Sport Mode  | Registered for 10+ games        | Not configured            |
| Intended use         | Gaming / benchmarks             | Daily driver              |

---

## Warnings

- These scripts require **root** and are written for the **MediaTek Helio G90T** (RM6785). Running them on a different SoC may write incorrect values to unrelated sysfs nodes.
- OC mode stops the thermal daemon and locks CPU/GPU to max frequency. **Do not leave OC mode running indefinitely.** Switch back to balanced mode after your session.
- Battery OC throttle is disabled in OC mode. Monitor battery temperature during extended gaming.
- Settings applied by `tweak()` (chmod 444) persist until the device is rebooted, since they are written to in-memory sysfs nodes.
