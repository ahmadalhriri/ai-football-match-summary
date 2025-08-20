import os
import re
import cv2
import json
import pickle
import numpy as np
from sklearn.cluster import KMeans
from ultralytics import YOLO
from rich.progress import Progress, BarColumn, TimeRemainingColumn, SpinnerColumn


def get_player_team_static(frame_path, bbox, player_id, team_colors):
    x1, y1, x2, y2 = map(int, bbox)
    frame = cv2.imread(frame_path)
    if frame is None:
        return player_id, -1

    image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    cropped = image_rgb[y1:y2, x1:x2]

    if cropped.shape[0] < 10 or cropped.shape[1] < 10:
        return player_id, -1

    top_half = cropped[:cropped.shape[0] // 2, :]
    reshaped = top_half.reshape(-1, 3)

    kmeans = KMeans(n_clusters=2, random_state=0, n_init=10)
    kmeans.fit(reshaped)
    labels = kmeans.labels_.reshape(top_half.shape[:2])
    corners = [labels[0, 0], labels[0, -1], labels[-1, 0], labels[-1, -1]]
    non_player_cluster = max(set(corners), key=corners.count)
    player_cluster = 1 - non_player_cluster

    player_color = kmeans.cluster_centers_[player_cluster]

    def color_distance(c1, c2):
        return np.linalg.norm(c1 - c2)

    distances = {team_id: color_distance(player_color, color_center)
                 for team_id, color_center in team_colors.items()}

    best_team = min(distances, key=distances.get)
    return player_id, best_team


class TeamAssigner:
    def __init__(self) -> None:
        self.team_colors: dict[int, np.ndarray] = {}
        self.player_team_dict: dict[int, int] = {}

    def extract_team_colors(self, frame: np.ndarray, model_path: str, json_path: str = "team_colors.json") -> None:
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        model = YOLO(model_path)
        model.to('cuda')
        results = model(image_rgb, conf=0.25)
        boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)
        class_ids = results[0].boxes.cls.cpu().numpy().astype(int)

        player_colors = []

        for box, class_id in zip(boxes, class_ids):
            if class_id != 2:
                continue

            x1, y1, x2, y2 = box
            cropped = image_rgb[y1:y2, x1:x2]

            if cropped.shape[0] < 10 or cropped.shape[1] < 10:
                continue

            top_half = cropped[:cropped.shape[0] // 2, :]
            reshaped = top_half.reshape(-1, 3)

            kmeans = KMeans(n_clusters=2, random_state=0, n_init=10)
            kmeans.fit(reshaped)

            labels = kmeans.labels_.reshape(top_half.shape[:2])
            corners = [labels[0, 0], labels[0, -1], labels[-1, 0], labels[-1, -1]]
            non_player_cluster = max(set(corners), key=corners.count)
            player_cluster = 1 - non_player_cluster

            player_color = kmeans.cluster_centers_[player_cluster].astype(int)
            player_colors.append(player_color)

        if not player_colors:
            raise ValueError("❌ لم يتم العثور على لاعبين لاستخراج الألوان.")

        color_array = np.array(player_colors)
        kmeans_team = KMeans(n_clusters=min(2, len(player_colors)), random_state=0, n_init=10)
        kmeans_team.fit(color_array)

        for i, center in enumerate(kmeans_team.cluster_centers_):
            self.team_colors[i] = center.astype(int)

        # ✅ حفظ ألوان الفريقين في ملف JSON
        team_colors_json = {i: self.team_colors[i].tolist() for i in self.team_colors}
        with open(json_path, "w") as f:
            json.dump(team_colors_json, f, indent=2)

        print(f"✅ تم حفظ مراكز ألوان الفريقين في: {json_path}")

    def load_team_colors(self, json_path: str = "team_colors.json") -> None:
        with open(json_path, "r") as f:
            loaded_colors = json.load(f)
        self.team_colors = {int(k): np.array(v) for k, v in loaded_colors.items()}
        print(f"📥 تم تحميل ألوان الفريقين من {json_path}")

    @staticmethod
    def extract_frame_number(filename):
        match = re.search(r'frame[_]?(\d+)\.jpg', filename)
        return int(match.group(1)) if match else -1

    def assign_teams_to_detections(self, frames_folder: str, input_track_file: str, output_teams_file: str):
        frame_files = {}
        for f in os.listdir(frames_folder):
            if f.lower().endswith(('.jpg', '.png')):
                idx = self.extract_frame_number(f)
                if idx >= 0:
                    frame_files[idx] = os.path.join(frames_folder, f)

        if not frame_files:
            raise ValueError("❌ لم يتم العثور على أي صورة بإسم frame#.jpg أو .png في المجلد.")

        # تحميل كل البيانات من ملف التتبع
        track_data_list = []
        with open(input_track_file, 'rb') as f:
            try:
                while True:
                    data = pickle.load(f)
                    track_data_list.append(data)
            except EOFError:
                pass

        if not track_data_list:
            raise ValueError("❌ ملف التتبع فارغ.")

        print(f"🧠 جاري معالجة {len(track_data_list)} إطار على عملية واحدة...")

        all_records = []

        with Progress(SpinnerColumn(), "[progress.description]{task.description}", BarColumn(), TimeRemainingColumn()) as progress:
            task_id = progress.add_task("📊 جاري المعالجة", total=len(track_data_list))
            for frame_idx, data in track_data_list:
                frame_path = frame_files.get(frame_idx)
                if frame_path is None:
                    progress.update(task_id, advance=1)
                    continue

                players = data.get('players', {})
                for player_id, player_info in players.items():
                    bbox = player_info.get('bbox')
                    if bbox is None:
                        continue
                    player_id, team_id = get_player_team_static(frame_path, bbox, player_id, self.team_colors)
                    all_records.append({
                        "frame_index": frame_idx,
                        "player_id": player_id,
                        "team": team_id
                    })
                progress.update(task_id, advance=1)

        all_records.sort(key=lambda r: r["frame_index"])

        with open(output_teams_file, 'wb') as fout:
            for record in all_records:
                pickle.dump(record, fout)

        print(f"✅ تم حفظ ملف ربط اللاعبين بالفريق في: {output_teams_file}")
