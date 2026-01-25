# 🧠 Brainstorm: Audio Kit Expansion (Utterance)

**Date:** 2026-01-25
**Topic:** Deep Dive into Audio Engineering & Expansion

---

## 1. Advanced DSP (Digital Signal Processing)
*Mục tiêu: Biến Audio từ "nghe được" thành "nghe hay/chuẩn".*

- [ ] **Voice Isolation / Noise Reduction:** Tự cài đặt thuật toán lọc ồn (RNNoise, vDSP) để làm sạch giọng nói.
- [ ] **Automatic Gain Control (AGC):** Tự động cân bằng âm lượng (Normalize audio levels).
- [ ] **Silence Removal / Trimming:** Tự động cắt bỏ khoảng lặng (Truncate silence) real-time để tối ưu storage/transmission.

## 2. Audio Analysis & Intelligence
*Mục tiêu: Hiểu dữ liệu âm thanh đang có gì.*

- [ ] **Advanced VAD (Voice Activity Detection):** Nhận diện chính xác câu nói (Sentence Boundary) thay vì chỉ phát hiện âm thanh đơn thuần.
- [ ] **Real-time FFT (Fast Fourier Transform):** Phân tích tần số cho Visualizer chuyên nghiệp (Frequency Spectrum).
- [ ] **Pitch Detection:** Nhận diện cao độ, ngữ điệu (Intonation/Pitch Tracking).

## 3. Audio Graph Architecture (AVAudioEngine Deep Dive)
*Mục tiêu: Xây dựng Audio Graph phức tạp thay vì chỉ Recorder đơn giản.*

- [ ] **Mixer Node:** Trộn nhiều nguồn (Mic + System Audio + Music).
- [ ] **Effect Nodes:** Thêm hiệu ứng thời gian thực (Reverb, EQ, Distortion).
- [ ] **Tap on Bus:** Can thiệp vào Raw Buffer (Audio Tap) để xử lý trước khi ghi hoặc phát.

## 4. Resiliency & System Ops
*Mục tiêu: Vận hành bền bỉ, xử lý ngắt quãng mượt mà.*

- [ ] **Robust Interruption Handling:** Xử lý Call interruptions, Route changes (Headphones/Speaker), Siri interruptions.
- [ ] **Audio Session Policy:** Quản lý Category/Mode/Options chuyên sâu (MixWithOthers, DuckOthers, DefaultToSpeaker).

## 5. Data & Streaming Optimization
*Mục tiêu: Tối ưu lưu trữ và truyền tải.*

- [ ] **Opus/FLAC Encoding:** Hỗ trợ nén âm thanh chất lượng cao/low-latency.
- [ ] **Ring Buffer Strategy:** Bộ đệm vòng tròn cho tính năng "Pre-recording" hoặc xử lý độ trễ thấp.
