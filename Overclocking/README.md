# RM6785 / G90T Overclocking Scripts

Scripts for the **Realme RMX2001** (RM6785, MediaTek Helio G90T chipset).  
Author: **Arhan Das**

> **Requires root.** Run via a root-capable file manager (e.g. MiXplorer) or a terminal emulator with root access.

---

## Scripts

| Script                     | Purpose                                                  |
| -------------------------- | -------------------------------------------------------- |
| `RMX2001_G90T_OC.sh`       | High Performance V4 / overclock — gaming & benchmarks    |
| `RMX2001_G90T_balanced.sh` | Balanced V3 — smooth daily use with battery-safe restore |

---

## RMX2001_G90T_OC.sh — High Performance V4 (Overclock Mode)

Pushes every subsystem to its hardware maximum. Intended for gaming sessions or benchmark runs. **Device will heat up significantly. CPU can reach ~86 °C, battery up to ~50 °C. Use at your own risk.**

A `tweak()` helper function writes each value and then **chmod 444-locks** the sysfs node so Android cannot revert the setting after it is applied.

V4 adds HyperEngine rapid-response tuning (FBT), UFS 2.1 queue tuning, touch latency tuning, charge-pause logic, and network-path optimizations.

### What it does

#### GED (GPU Enhancement Driver) Modules

- Enables full **game mode**, force CPU boost, GPU boost, boost amplifier, boost extra, and 3D benchmark mode (`gx_3D_benchmark_on`).
- Sets **GPU custom boost frequency and upper-bound to 2000 MHz**, bottom floor to 600 MHz.
- GPU idle is forced to 0 — the GPU never voluntarily throttles down.
- GPU DVFS (dynamic voltage/frequency scaling) kept enabled for headroom.
- `gx_dfps` is dynamically read from the display refresh rate and written so GED targets the correct frame rate.

#### Charge Pause (Thermal Control)

- Battery level is read at script start and shown in the header.
- If battery is **>= 40%**, charging is paused (`/proc/charger/stop_charging_enable`, `/proc/charger/mmi_charging_enable`) to eliminate battery charging heat during gameplay.
- If battery is below 40%, charging remains active for battery protection.
- Final status block explicitly reports whether charging is paused or active.

#### FPSGO — MediaTek Frame Performance Go Engine

- Boosts the top-app (TA) thread aggressively (`boost_ta`, `boost_VIP`).
- Disables frame-rate self-throttling (`enable_switch_down_throttle`, `fstb_self_ctrl_fps_enable`, `adopt_low_fps`).
- Enables affinity boosting (`boost_affinity`, `boost_LR`) and extra XGF sub-frame tracking (`xgf_extra_sub`, `xgf_uboost`).
- GCC (Game CPU Control) enabled with HWUI hints for smoother UI rendering.
- GPU boost level set to 101 (above the normal ceiling).

#### FBT (Frame Budget Tuner) — HyperEngine Rapid Response

- Enables the missing frame-budget rescue path with maximum aggressiveness.
- `rescue_percent` set to **100%** (including high-refresh rescue profiles).
- `sampling_period_MS` set to **1 ms** for fastest rescue reaction.
- `floor_bound` set to **0** (no floor restriction) so the rescue path is never artificially limited.
- Designed to reduce frame deadline misses by reacting before jank becomes visible.

#### CPU Mode & Scheduler

- **CPU power mode 3** — full performance mode (vs. 1 = balanced, 0 = powersave).
- **CCI mode** (CPU-cluster interconnect) enabled for maximum inter-cluster bandwidth.
- CPU scheduler disabled from frequency hinting (`cpufreq_sched_disable 1`) so the governor has sole control.
- `sched_autogroup_enabled` off, `sched_child_runs_first` on, migration cost and granularity tuned for low-latency task placement.
- Scheduler features: `NEXT_BUDDY` (prefer the last woken sibling) and `NO_TTWU_QUEUE` (wake tasks immediately without queuing).
- **WALT enabled** (`sched_use_walt_cpu_util`, `sched_use_walt_task_util`, `sched_walt_enable`) for improved CPU frequency/load prediction.
- **EAS (Energy Aware Scheduling) disabled** — switches from energy-saving to pure-performance scheduling.

#### I/O Scheduler (UFS 2.1 Path)

- Targets **`/dev/sda`** (UFS 2.1 on the 8/128 variant) instead of relying on eMMC-only paths.
- Applies **deadline** scheduler and tunes queue behavior for latency:
  - `read_ahead_kb` → 32
  - `rq_affinity` → 1
  - `nomerges` → 2
- Enables UFS **CMDQ** (`/sys/block/sda/device/cmdq_en` → 1) for better command handling under burst I/O.
- Keeps fallback tuning for `mmcblk0` when present.

#### CPU Performance Node

- `/sys/devices/system/cpu/perf/enable` → **1** — activates the MediaTek hardware performance assist node.
- Additional perf assists enabled when exposed by kernel:
  - `gpu_pmu_enable`
  - `fuel_gauge_enable`
  - `charger_enable`

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

#### Touch Input Pipeline

- Game touch mode stays enabled (`game_switch_enable` → 1) with direction fix and touch limit off.
- Sensitivity profile now uses:
  - `smooth_level` → **0** (least smoothing / sharpest response)
  - `sensitive_level` → **5** (highest touch sensitivity)

#### Networking — TCP

- HyperEngine network concurrency enabled via **`oplus_sla`** (`sla_enable` → 1) for WiFi/LTE cooperative behavior where supported.
- Congestion control: **`cubic`** (high-throughput, standard Linux default).
- `tcp_low_latency` → 1.
- TCP buffers tuned for low-latency gaming:
  - `tcp_rmem` → `4096 87380 16777216`
  - `tcp_wmem` → `4096 65536 16777216`
- `tcp_fastopen` → 1.

#### Virtual Memory (RAM Management)

- **Swappiness → 10** — kernel aggressively keeps data in RAM, almost never swaps.
- `dirty_ratio` → 10, `dirty_background_ratio` → 5 — dirty pages flushed quickly so write cache stays small.
- `dirty_writeback_centisecs` → 1000 (10 s interval).
- `vfs_cache_pressure` → 80 — retains VFS dentries/inodes longer.
- `compaction_proactiveness` → 0, `page-cluster` → 0 — no proactive memory compaction, no read-ahead on swap.
- Transparent Huge Pages forced to **`always`** (`enabled` and `shmem_enabled`) for performance-oriented memory mapping.
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

## RMX2001_G90T_balanced.sh — Balanced Mode V3

Optimised for smooth everyday use. All subsystems are tuned to scale intelligently between low and high performance rather than being pinned to max. Thermal protection remains active. Battery life is preserved.

V3 explicitly restores OC overrides in safe order (charging and thermal path first), then applies balanced defaults for networking, touch, storage, and scheduler behavior.

### What it does

#### Charging & Thermal Restore Order

- Charging is restored **first** (`stop_charging_enable` off, `mmi_charging_enable` on) before any other subsystem changes.
- Thermal message locks are unlocked, CPU min/max limits are restored, then the thermal daemon is restarted.
- Battery OC throttle protection is restored afterward (`battery_oc_protect_stop` -> `stop 0`).

#### GED Modules

- Game mode **off**, force CPU boost **off**, GPU boost extra **off**.
- `enable_cpu_boost` and `enable_gpu_boost` remain **on** — the driver can still boost on demand.
- `gpu_idle` → 50, `ged_smart_boost` → 50 — conservative half-power boost ceiling.
- `gx_boost_on` off; `ged_boost_enable` on.

#### FPSGO / FBT Restore

- FPSGO switches and advanced hooks are returned to non-OC defaults.
- FBT (Frame Budget Tuner) is restored to balanced values:
  - `rescue_percent` -> 50
  - `sampling_period_MS` -> 16
  - `floor_bound` -> 3

#### CPU Mode & Scheduler

- **CPU power mode 1** — balanced (not powersave, not full performance).
- CCI mode off.
- WALT hints are disabled for daily-use behavior (`sched_use_walt_cpu_util` and `sched_use_walt_task_util` -> 0).
- **EAS (Energy Aware Scheduling) enabled (mode 1)** — kernel places tasks on the most energy-efficient core that can handle the load.

#### I/O Scheduler (UFS 2.1 Balanced Restore)

- Primary storage path restored on **`sda`** (UFS 2.1 variant).
- **mq-deadline** scheduler with `read_ahead_kb` -> **128** for balanced throughput/latency.
- UFS devfreq governor restored to **`simple_ondemand`**.
- `mmcblk0` receives matching fallback restore values when present.

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
- Comfortable balanced defaults restored:
  - `smooth_level` -> **2**
  - `sensitive_level` -> **3**

#### Display — CABC

- Content Adaptive Backlight Control **disabled** — display brightness is not reduced by content analysis, giving more accurate colors.

#### Logcat

- `logd` stopped to reduce background CPU usage from log collection.

#### Networking — TCP

- HyperEngine SLA link aggregation is disabled for daily-use power behavior (`oplus_sla/sla_enable` -> 0).
- Congestion control: **`hybla`** — confirmed available in this kernel and suitable for mobile/high-latency paths.
- `tcp_low_latency` → 1.
- TCP buffers restored to balanced defaults:
  - `tcp_rmem` -> `4096 87380 6291456`
  - `tcp_wmem` -> `4096 16384 4194304`

#### Virtual Memory (RAM Management)

- `drop_caches 1` — soft page cache clear at script start.
- **Swappiness → 40** — moderate; allows some swap activity while still favouring RAM.
- `dirty_ratio` → 20, `dirty_background_ratio` → 10 — more write buffering than OC mode.
- `dirty_writeback_centisecs` → 1500.
- Transparent Huge Pages set to **`madvise`** for balanced performance and memory efficiency.

#### CPUSet & SchedTune

- **Foreground & Top-App:** all 8 CPUs, util.max 1024, prefer_idle on.
- **Background:** CPUs 0-3, util.max 200, no boost.
- **System-Background:** CPUs 0-5.
- **Restricted:** CPUs 0-1.
- No kill of background apps — existing sessions survive the switch.

---

## Comparison at a Glance

| Feature              | OC Mode                         | Balanced Mode                                      |
| -------------------- | ------------------------------- | -------------------------------------------------- |
| CPU governor         | `performance`                   | `schedutil`                                        |
| CPU frequency        | Locked to hardware max          | Free scaling within range                          |
| Big cluster range    | 2050–2050 MHz (locked)          | 774–2050 MHz                                       |
| Little cluster range | 2000–2000 MHz (locked)          | 500–2000 MHz                                       |
| EAS scheduling       | Disabled                        | Enabled                                            |
| WALT scheduling      | Enabled                         | Disabled                                           |
| GED game mode        | Full on                         | Off                                                |
| FPSGO                | Fully configured                | Not configured                                     |
| FBT frame rescue     | Max aggressiveness              | Balanced restore (50%, 16 ms)                      |
| GPU power policy     | `always_on`                     | `coarse_demand`                                    |
| GPU thermal bypass   | Yes (all limits ignored)        | No                                                 |
| Storage path tuning  | UFS `sda` + CMDQ + queue tuning | UFS `sda` mq-deadline + 128 KB + `simple_ondemand` |
| DRAM governor        | `performance` (locked max freq) | Not modified                                       |
| Thermal daemon       | Stopped + locked                | Running normally                                   |
| Charge handling      | Auto pause (if battery >= 40%)  | Charging restored first                            |
| Battery OC throttle  | Disabled                        | Active                                             |
| Touch profile        | smooth=0, sensitive=5           | smooth=2, sensitive=3                              |
| SLA network engine   | Enabled (`oplus_sla`)           | Disabled                                           |
| TCP network tuning   | `cubic` + low-latency buffers   | `hybla` + restored buffers                         |
| Transparent HugePage | `always`                        | `madvise`                                          |
| Swappiness           | 10                              | 40                                                 |
| Background apps      | Killed at end                   | Left running                                       |
| PowerHAL Sport Mode  | Registered for 10+ games        | Not configured                                     |
| Intended use         | Gaming / benchmarks             | Daily driver                                       |

---

## Warnings

- These scripts require **root** and are written for the **MediaTek Helio G90T** (RM6785). Running them on a different SoC may write incorrect values to unrelated sysfs nodes.
- OC mode stops the thermal daemon and locks CPU/GPU to max frequency. **Do not leave OC mode running indefinitely.** Switch back to balanced mode after your session.
- Battery OC throttle is disabled in OC mode. Monitor battery temperature during extended gaming.
- Settings applied by `tweak()` (chmod 444) persist until the device is rebooted, since they are written to in-memory sysfs nodes.
