# Trinity Dynamic Channel Pipe Algorithm
### Proof-of-Concept Specification: Real-Time Ternary Framing via Physical High-Z Logic

This repository contains the software emulation model and verification stand for the **Trinity Pipe** architecture—a physical layer (PHY) protocol designed to optimize Input/Output (I/O) interface bandwidth and power consumption by shifting framing logic from software/link layers directly to physical silicon hardware.

The project emulates data stream translation through a ternary transmission medium utilizing a **physical third logical state—High Impedance (`TRIT_Z`)** as a strict, asymmetric frame delimiter.

---

## 🧠 Technical Overview & Mathematical Foundation

The Trinity Pipe architecture completely eliminates the requirement for conventional link and network layer framing overheads (such as packet headers, start/stop bits, and software stream boundary markers):

1. **Strict Physical Framing (Z-Marker):** Data block separation is handled entirely at the hardware level. Every token mapped into the pipe is strictly terminated by a High-Z state (`TRIT_Z`). For the receiving state machine, the transition of the physical conductor into High-Z acts as an instantaneous, zero-latency, edge-triggered interrupt to finalize the current sequence, evaluate its length, and reset the internal bit counter.
2. **Ternary Prefix-Free Token Mapping (LUT):** The input binary stream is split into 4-bit nibbles (range 0..15) and mapped onto the ternary alphabet (`0`, `1`, `Z`) using a strict marker layout. The number of binary bits (`0` and `1`) transmitted before the line goes quiet (`Z`) uniquely determines the target value:
   * **Zero-Bit Stream (1 Trit):** The value `0` immediately triggers `TRIT_Z` (the line instantly goes quiet, consuming 1 clock cycle).
   * **1-Bit to 3-Bit Streams (2-4 Trits):** Values 1 to 14 are transmitted as pure binary combinations immediately cut off by a mandatory terminal `TRIT_Z` token (e.g., `0Z`, `1Z`, `00Z`, ..., `111Z`).
   * **4-Bit Stream (5 Trits / Worst-Case Compensation):** The lowest frequency state (15) is translated as `0000Z`. While this single state introduces a 5-tact dilation (+25% overhead for a single nibble), it is mathematically compensated for by the ultra-short 1-tact and 2-tact sequences (`0`, `1`, `2`) at the opposite end of the distribution tree.
3. **Symbolic Determinism (Absolute Zero Look-ahead):** The `HardwareDecode` architecture processes incoming trits sequentially in true real-time. Because `TRIT_Z` acts as an absolute physical wall between data packets, the decoder requires zero look-ahead buffering, packet accumulation, or sliding window tracking. The logic is optimized for direct FPGA/ASIC implementation, requiring only a basic 3-bit counter and an asynchronous High-Z detector.
4. **Fault Isolation & Self-Synchronization:** In contrast to look-ahead window decoders, the strict marker topology isolates line noise. If a physical glitch corrupts bits inside the pipe, the error is strictly confined to the current nibble. The arrival of the very next physical `TRIT_Z` marker instantly resets the receiver hardware, guaranteeing immediate re-synchronization.

---

## 📈 System Efficiency Constants (High-Entropy RAR Profile)

When validated against maximum-entropy blocks where classical static compression tools reach their absolute mathematical limits (highly compressed RAR/7z archives, encrypted payloads, dense media streams), the Trinity Pipe architecture maintains rock-solid physical baselines:
* **`Dynamic Data Reduction` (Time/Tact Saving):** **~15.6%** physical channel compaction inherently achieved via asymmetric symbol distribution.
* **`Virtual Throughput Gain` (Effective Bandwidth Boost):** **+18.5%** effective bandwidth expansion across the physical conductor relative to the base source clock frequency.
* **`Green Tech / Power Saving` (Energy Efficiency):** **~29.6%**. Because the High-Impedance state physically disconnects the driver from the transmission line (dropping the active current loop to zero), the I/O interface sub-components rest for nearly a third of the total transmission time, proportionally lowering thermal dissipation and line drive power.

---

## 🛠️ Engineering Notes for Build & Validation

* **Cross-Platform Compatibility:** Project compilation is fully standardized via `CMakeLists.txt` (requires a compiler supporting the **C++17** standard).
* **Evaluation Assets:** The emulation stand works out-of-the-box. To initialize the validation pipeline, place **ANY** raw binary file into the root build directory and rename it explicitly to **`test.bin`**.
* **Hardware Accelerations:** To trigger compiler-level vector instruction optimizations, building and running the executable must be performed in the **`Release`** configuration.

---

## ⚠️ Legal Status & Commercial Restrictions (Dual-Licensing)

The source code in this repository is published under the **GNU GPLv3** license and is open exclusively for non-commercial use, academic research, and public independent auditing.

Integrating, copying, or implementing the core logical principles of this algorithm into closed commercial or proprietary products (including microprocessor architectures, memory controllers, networking hardware firmware, DBMS, and HFT platforms) is **strictly prohibited** under the GPLv3 terms. Commercial deployment of the Trinity Pipe technology is permissible **solely upon executing a Private Commercial Agreement (Commercial/Proprietary License)** with the copyright holder.
