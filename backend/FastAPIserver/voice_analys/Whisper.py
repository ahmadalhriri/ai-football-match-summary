import os
import subprocess
import whisper
import json
from tqdm import tqdm
import torch

class WhisperTranscriber:
    def __init__(self, model_size="medium"):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"🚀 استخدام الجهاز: {self.device.upper()}")
        print(f"📦 تحميل نموذج Whisper بالحجم: {model_size}")
        self.model = whisper.load_model(model_size).to(self.device)

    def extract_audio_with_ffmpeg(self, video_path, output_audio_path="temp_audio.wav"):
        print("🎞️ استخراج الصوت من الفيديو...")
        command = [
            "ffmpeg", "-y",
            "-i", video_path,
            "-ac", "1",         # قناة صوتية واحدة
            "-ar", "16000",     # 16 kHz
            "-vn",              # بدون فيديو
            output_audio_path
        ]
        subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return output_audio_path

    def transcribe_audio_to_json(self, audio_path, json_path="transcription.json"):
        print("🧠 بدء التفريغ الصوتي...")
        result = self.model.transcribe(
            audio_path,
            word_timestamps=True,
            verbose=False,
            fp16=(self.device == "cuda")
        )

        words_data = []
        for segment in tqdm(result["segments"], desc="🔎 تحليل الكلمات"):
            for word_info in segment.get("words", []):
                words_data.append({
                    "word": word_info["word"].strip(),
                    "start": round(word_info["start"], 2),
                    "end": round(word_info["end"], 2)
                })

        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(words_data, f, ensure_ascii=False, indent=2)

        print(f"💾 تم حفظ النتائج في {json_path}")
        return result["text"]

    def transcribe_video(self, video_path, json_path="transcription.json"):
        audio_path = self.extract_audio_with_ffmpeg(video_path)
        full_text = self.transcribe_audio_to_json(audio_path, json_path)
        os.remove(audio_path)
        print("\n📝 النص الكامل:")
        print(full_text)
        return full_text

# 🧪 مثال على الاستخدام
if __name__ == "__main__":
    video_file = "inpute/xall.mp4"  # غيّر حسب مسار الفيديو
    transcriber = WhisperTranscriber(model_size="medium")
    text = transcriber.transcribe_video(video_file)
