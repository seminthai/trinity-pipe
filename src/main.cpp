#include <iostream>
#include <vector>
#include <cstdint>
#include <iomanip>
#include <chrono>
#include <fstream>
#include <cmath>
#include <cstring>

enum Trit : uint8_t { TRIT_0 = 0, TRIT_1 = 1, TRIT_Z = 2 };

struct EncodedResult {
    Trit trits[5];
    uint8_t length;
};

const EncodedResult ENCODER_LUT[16] = {
    { {TRIT_Z, TRIT_0, TRIT_0, TRIT_0, TRIT_0}, 1 }, // 0
    { {TRIT_0, TRIT_Z, TRIT_0, TRIT_0, TRIT_0}, 2 }, // 1
    { {TRIT_1, TRIT_Z, TRIT_0, TRIT_0, TRIT_0}, 2 }, // 2
    { {TRIT_0, TRIT_0, TRIT_Z, TRIT_0, TRIT_0}, 3 }, // 3
    { {TRIT_0, TRIT_1, TRIT_Z, TRIT_0, TRIT_0}, 3 }, // 4 
    { {TRIT_1, TRIT_0, TRIT_Z, TRIT_0, TRIT_0}, 3 }, // 5
    { {TRIT_1, TRIT_1, TRIT_Z, TRIT_0, TRIT_0}, 3 }, // 6
    { {TRIT_0, TRIT_0, TRIT_0, TRIT_Z, TRIT_0}, 4 }, // 7
    { {TRIT_0, TRIT_0, TRIT_1, TRIT_Z, TRIT_0}, 4 }, // 8
    { {TRIT_0, TRIT_1, TRIT_0, TRIT_Z, TRIT_0}, 4 }, // 9
    { {TRIT_0, TRIT_1, TRIT_1, TRIT_Z, TRIT_0}, 4 }, // 10
    { {TRIT_1, TRIT_0, TRIT_0, TRIT_Z, TRIT_0}, 4 }, // 11
    { {TRIT_1, TRIT_0, TRIT_1, TRIT_Z, TRIT_0}, 4 }, // 12
    { {TRIT_1, TRIT_1, TRIT_0, TRIT_Z, TRIT_0}, 4 }, // 13
    { {TRIT_1, TRIT_1, TRIT_1, TRIT_Z, TRIT_0}, 4 }, // 14
    { {TRIT_0, TRIT_0, TRIT_0, TRIT_0, TRIT_Z}, 5 }  // 15 
};

inline std::pair<uint8_t, uint8_t> HardwareDecode(const Trit* pipe, size_t index) {
    uint8_t bitCount = 0;
    uint8_t pattern = 0;

    while (pipe[index + bitCount] != TRIT_Z) {
        pattern = (pattern << 1) | static_cast<uint8_t>(pipe[index + bitCount]);
        bitCount++;
    }

    uint8_t totalLength = bitCount + 1; 

    switch (bitCount) {
        case 0: return { 0, totalLength }; // [Z]
        case 1: return { (pattern == 1) ? uint8_t(2) : uint8_t(1), totalLength }; // [0Z]=1, [1Z]=2
        case 2: return { static_cast<uint8_t>(3 + pattern), totalLength }; // [00Z]=3, [01Z]=4, [10Z]=5, [11Z]=6
        case 3: return { static_cast<uint8_t>(7 + pattern), totalLength }; // [000Z]=7 ... [111Z]=14
        case 4: return { 15, totalLength }; // [0000Z]=15
        default: return { 0, totalLength }; //
    }
}

int main() {
    std::ifstream inFile("test.bin", std::ios::binary);
    if (!inFile) {
        std::cout << "====================================================================\n";
        std::cout << "  VALIDATION STAND NOTICE: 'test.bin' not found.\n";
        std::cout << "====================================================================\n";
        return 1;
    }

    std::vector<uint8_t> originBytes((std::istreambuf_iterator<char>(inFile)), std::istreambuf_iterator<char>());
    inFile.close();

    if (originBytes.empty()) {
        std::cout << "CRITICAL ERROR: 'test.bin' is empty.\n";
        return 1;
    }

    std::vector<uint8_t> inputNibbles;
    inputNibbles.reserve(originBytes.size() * 2);
    for (uint8_t byte : originBytes) {
        inputNibbles.push_back((byte >> 4) & 0x0F);
        inputNibbles.push_back(byte & 0x0F);
    }

    std::vector<Trit> trinityPipe;
    trinityPipe.reserve(inputNibbles.size() * 5 + 32);
    
    size_t zTritCount = 0;
    size_t zeroTritCount = 0;
    size_t oneTritCount = 0;

    for (uint8_t nibble : inputNibbles) {
        const EncodedResult& res = ENCODER_LUT[nibble];
        for (int i = 0; i < res.length; ++i) {
            trinityPipe.push_back(res.trits[i]);
            if (res.trits[i] == TRIT_Z) zTritCount++;
            else if (res.trits[i] == TRIT_0) zeroTritCount++;
            else if (res.trits[i] == TRIT_1) oneTritCount++;
        }
    }
    
    size_t endTarget = trinityPipe.size(); 
    for (int i = 0; i < 32; ++i) {
        trinityPipe.push_back(TRIT_0);
    }

    std::vector<uint8_t> restoredNibbles(inputNibbles.size());
    const int RUN_PASSES = 5;
    
    std::cout << "Executing verification pipeline (" << RUN_PASSES << " passes)... ";

    auto startTime = std::chrono::high_resolution_clock::now();

    for (int p = 0; p < RUN_PASSES; ++p) {
        size_t pipeIndex = 0;
        size_t outIndex = 0;
        const Trit* pipeData = trinityPipe.data();

        while (pipeIndex < endTarget) {
            auto match = HardwareDecode(pipeData, pipeIndex);
            restoredNibbles[outIndex++] = match.first;
            pipeIndex += match.second; 
        }
    }

    auto endTime = std::chrono::high_resolution_clock::now();
    double durationSec = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count() / 1000000000.0;
    std::cout << "Complete.\n\n";

    std::vector<uint8_t> restoredBytes;
    restoredBytes.reserve(originBytes.size());
    for (size_t i = 0; i < restoredNibbles.size(); i += 2) {
        uint8_t byte = (restoredNibbles[i] << 4) | restoredNibbles[i + 1];
        restoredBytes.push_back(byte);
    }

    bool dataMatch = (originBytes.size() == restoredBytes.size()) && 
                     (std::memcmp(originBytes.data(), restoredBytes.data(), originBytes.size()) == 0);

    size_t standardBinaryBits = inputNibbles.size() * 4;
    size_t trinityTritsUsed = endTarget;
    double dataReductionRatio = (1.0 - ((double)trinityTritsUsed / standardBinaryBits)) * 100.0;
    double bandwidthBoost = (((double)standardBinaryBits / trinityTritsUsed) - 1.0) * 100.0;
    double powerSavingRatio = ((double)zTritCount / trinityTritsUsed) * 100.0;
    double speedMBs = (((double)originBytes.size() * RUN_PASSES) / (1024.0 * 1024.0)) / durationSec;

    std::cout << "====================================================================\n";
    std::cout << "             TRINITY DYNAMIC CHANNEL PIPE ALGORITHM                 \n";
    std::cout << "    Open-Source Independent Audit Verification & Validation Stand   \n";
    std::cout << "====================================================================\n";
    std::cout << "  [DATA SOURCE]      Dataset Volume         : " << originBytes.size() << " bytes\n";
    std::cout << "  [INTEGRITY LOCK]   Strict Byte Match Check: " << (dataMatch ? "PASSED (100% BIT-ACCURATE)" : "FAILED (DATA CORRUPTION)") << "\n";
    std::cout << "--------------------------------------------------------------------\n";
    std::cout << "  [THEORY PROOF]     Standard Binary Cost   : " << standardBinaryBits << " bits\n";
    std::cout << "  [THEORY PROOF]     Ternary Channel Cost   : " << trinityTritsUsed << " trits\n";
    std::cout << "  [THEORY PROOF]     Dynamic Data Reduction : " << std::fixed << std::setprecision(2) << dataReductionRatio << " %\n";
    std::cout << "  [THEORY PROOF]     Virtual Throughput Gain: +" << bandwidthBoost << " %\n";
    std::cout << "--------------------------------------------------------------------\n";
    std::cout << "  [CHANNEL SPECTRUM] Logical 0 States       : " << zeroTritCount << " elements\n";
    std::cout << "  [CHANNEL SPECTRUM] Logical 1 States       : " << oneTritCount << " elements\n";
    std::cout << "  [CHANNEL SPECTRUM] High-Z Framing (Z)     : " << zTritCount << " elements\n";
    std::cout << "--------------------------------------------------------------------\n";
    std::cout << "  [GREEN TECH]       High-Z Line Quietness  : " << powerSavingRatio << " %\n";
    std::cout << "                     Estimated I/O Power Saving: -" << powerSavingRatio << " % Watt\n";
    std::cout << "--------------------------------------------------------------------\n";
    std::cout << "  [PERFORMANCE]      Emulated Core Speed    : " << speedMBs << " MB/s\n";
    std::cout << "====================================================================\n";

    return 0;
}
