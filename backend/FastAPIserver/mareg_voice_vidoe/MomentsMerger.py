import json
import cv2
from typing import List, Dict

class ImportantMomentsMerger:
    def __init__(
        self,
        video_json_path: str,
        audio_json_path: str,
        video_file_path: str,
        merge_threshold: float = 1.0,
        merge_penalty_gap: float = 1.0
    ):
        self.video_json_path = video_json_path
        self.audio_json_path = audio_json_path
        self.video_file_path = video_file_path
        self.merge_threshold = merge_threshold  # للفيديو فقط
        self.merge_penalty_gap = merge_penalty_gap  # للفحص مع الصوت
        self.fps = None
        self.video_moments = []
        self.audio_moments = []
        self.processed_video_moments = []

    def load_fps_from_video(self):
        cap = cv2.VideoCapture(self.video_file_path)
        if not cap.isOpened():
            raise ValueError(f"Failed to open video file: {self.video_file_path}")
        self.fps = cap.get(cv2.CAP_PROP_FPS)
        cap.release()

    def load_data(self):
        with open(self.video_json_path, 'r', encoding='utf-8') as f:
            all_moments = json.load(f)
            self.video_moments = [
                moment for moment in all_moments
                if moment.get("confidence", 0) > 0
            ]

        with open(self.audio_json_path, 'r', encoding='utf-8') as f:
            self.audio_moments = json.load(f)

    def convert_frames_to_seconds(self, frame: int) -> float:
        return frame / self.fps

    def merge_close_video_moments(self, max_gap_frames: int = 150) -> List[Dict]:
        if not self.video_moments:
            return []

        sorted_moments = sorted(self.video_moments, key=lambda x: x["start"])
        merged = [sorted_moments[0]]

        for moment in sorted_moments[1:]:
            last = merged[-1]
            if moment["start"] - last["end"] <= max_gap_frames:
                last["end"] = max(last["end"], moment["end"])
                last["events"] = list(set(last.get("events", []) + moment.get("events", [])))
            else:
                merged.append(moment)

        return merged

    def process_video_moments(self) -> List[Dict]:
        frame_step = 1
        max_gap_frames = int(self.fps * self.merge_threshold)
        merged_video = self.merge_close_video_moments(max_gap_frames)

        return [
            {
                "start": self.convert_frames_to_seconds(moment["start"] * frame_step),
                "end": self.convert_frames_to_seconds(moment["end"] * frame_step),
                "type": "video",
                "events": moment.get("events", [])
            }
            for moment in merged_video
        ]

    def find_audio_nearby(self, video_moment: Dict, gap: float) -> List[str]:
        """ترجع قائمة بالأحداث الصوتية القريبة زمنياً من لحظة الفيديو"""
        matched_labels = []
        for audio in self.audio_moments:
            # إذا تقاطع زمنياً أو قريب ضمن العتبة
            if (
                abs(audio["start"] - video_moment["end"]) <= gap or
                abs(audio["end"] - video_moment["start"]) <= gap or
                (audio["start"] <= video_moment["end"] and audio["end"] >= video_moment["start"])
            ):
                matched_labels.append(audio["label"])
        return matched_labels

    def filter_and_merge(self):
        filtered = []
        used_audio_indices = set()

        for moment in self.processed_video_moments:
            labels = moment["events"]
            merged_audio_labels = []
            for i, audio in enumerate(self.audio_moments):
                if (
                    abs(audio["start"] - moment["end"]) <= self.merge_penalty_gap or
                    abs(audio["end"] - moment["start"]) <= self.merge_penalty_gap or
                    (audio["start"] <= moment["end"] and audio["end"] >= moment["start"])
                ):
                    merged_audio_labels.append(audio["label"])
                    used_audio_indices.add(i)  # سجلنا هذه اللحظة الصوتية كمستخدمة

            has_penalty = any("ركلات ترجيح" in e for e in labels)
            has_chance_or_goal = any("فرصة خطيرة أو هدف" in e for e in labels)

            if has_penalty:
                if merged_audio_labels:
                    moment["type"] = "video+audio"
                    moment["events"] = list(set(labels + merged_audio_labels))
                filtered.append(moment)

            elif has_chance_or_goal:
                if merged_audio_labels:
                    moment["type"] = "video+audio"
                    moment["events"] = list(set(labels + merged_audio_labels))
                    filtered.append(moment)

            else:
                filtered.append(moment)

        # ✅ نضيف كل اللحظات الصوتية من نوع "card" سواء تم دمجها أو لا
        for i, audio in enumerate(self.audio_moments):
            if audio.get("label") == "card":
                # نتأكد فقط ما تم إضافتها مسبقًا مع فيديو
                already_added = any(
                    audio["start"] == m["start"] and
                    audio["end"] == m["end"] and
                    "audio" in m["type"]
                    for m in filtered
                )
                if not already_added:
                    filtered.append({
                        "start": audio["start"],
                        "end": audio["end"],
                        "type": "audio",
                        "events": [audio["label"]],
                        "text": audio.get("text", "")
                    })

        return filtered



    def run(self, output_path: str):
        self.load_fps_from_video()
        self.load_data()
        self.processed_video_moments = self.process_video_moments()
        self.merged_moments = self.filter_and_merge()
        self.save_output(output_path)

    def save_output(self, output_path: str):
        # ترتيب اللحظات حسب بداية الوقت (start)
        sorted_moments = sorted(self.merged_moments, key=lambda x: x["start"])
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(sorted_moments, f, ensure_ascii=False, indent=2)
