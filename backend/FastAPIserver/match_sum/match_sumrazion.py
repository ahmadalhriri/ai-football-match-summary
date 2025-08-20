import os
import json
import subprocess

class MatchSummarizer:
    def __init__(self, video_path, moments_json, output_path, time_window=3):
        self.video_path = video_path
        self.moments_json = moments_json
        self.output_path = output_path
        self.time_window = time_window
        self.moments = []
        self.temp_dir = "temp_clips"

    def load_important_frames(self):
        with open(self.moments_json, 'r', encoding='utf-8') as f:
            self.moments = json.load(f)

    def generate_clips_with_audio(self):
        os.makedirs(self.temp_dir, exist_ok=True)
        list_file_path = os.path.join(self.temp_dir, "clips_list.txt")

        with open(list_file_path, "w", encoding="utf-8") as list_file:
            for i, moment in enumerate(self.moments):
                start = max(moment["start"] - self.time_window, 0)
                end = moment["end"] + self.time_window
                duration = end - start
                clip_path = os.path.join(self.temp_dir, f"clip_{i:04d}.mp4")

                cmd = [
                    "ffmpeg",
                    "-y",
                    "-ss", str(start),
                    "-t", str(duration),
                    "-i", self.video_path,
                    "-c", "copy",
                    clip_path
                ]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

                # اكتب فقط اسم الملف بدون مسار المجلد داخل قائمة الدمج
                list_file.write(f"file 'clip_{i:04d}.mp4'\n")

        return list_file_path

    def concatenate_clips(self, list_file_path):
        cmd = [
            "ffmpeg",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", list_file_path,
            "-c", "copy",
            self.output_path
        ]
        subprocess.run(cmd)
        print(f"✅ تم حفظ ملخص المباراة في: {self.output_path}")

    def summarize(self):
        print("🔄 جاري تحميل اللحظات المهمة...")
        self.load_important_frames()
        print(f"✅ تم تحميل {len(self.moments)} لحظة")

        print("✂️ جاري قص اللحظات المهمة من الفيديو مع الصوت...")
        list_file_path = self.generate_clips_with_audio()

        print("🎬 جاري دمج المقاطع في فيديو واحد...")
        self.concatenate_clips(list_file_path)
