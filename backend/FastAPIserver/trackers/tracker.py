from ultralytics import YOLO
import supervision as sv
import pickle
import os
import sys
import multiprocessing
from tqdm import tqdm
sys.path.append('../')
from utils import get_center_of_bbox, get_bbox_width, get_foot_position
import cv2
import pandas as pd
import gzip
import numpy as np
import re
import pandas as pd
def extract_frame_number(filename):
    """استخراج رقم الإطار من اسم الملف"""
    match = re.search(r'frame(\d+)\.(jpg|png)', filename)
    return int(match.group(1)) if match else -1

class Tracker:
    def __init__(self, model_path):
        self.model = YOLO(model_path)
        self.model.to('cuda')
        self.model_path = model_path  # نستخدمه لاحقًا في العمليات الفرعية
        self.tracker = sv.ByteTrack()
    
    def interpolate_ball_positions_from_track_file(self, input_track_file: str, output_track_file: str, max_gap: int = 40):

        # 1. تحميل كل البيانات من ملف التتبع
        all_frames = []
        with open(input_track_file, 'rb') as f:
            try:
                while True:
                    item = pickle.load(f)
                    all_frames.append(item)
            except EOFError:
                pass

        # 2. استخراج مواضع الكرة لكل فريم مع وضع NaN إذا الكرة غير موجودة فعلياً
        ball_positions = []
        presence_flags = []  # هل الكرة موجودة في الفريم فعلاً

        for frame_index, frame_data in all_frames:
            ball = frame_data.get("ball", {})
            ball_bbox = ball.get(1, {}).get("bbox") if isinstance(ball, dict) else None

            if ball_bbox is None or len(ball_bbox) != 4 or any(v is None for v in ball_bbox):
                ball_positions.append([np.nan, np.nan, np.nan, np.nan])
                presence_flags.append(False)
            else:
                ball_positions.append(ball_bbox)
                presence_flags.append(True)

        df = pd.DataFrame(ball_positions, columns=["x1", "y1", "x2", "y2"])

        # 3. نحدد الفترات المتتالية من الفريمات المفقودة
        is_nan = df.isna().any(axis=1)
        nan_groups = []
        start = None

        for i, val in enumerate(is_nan):
            if val and start is None:
                start = i
            elif not val and start is not None:
                nan_groups.append((start, i - 1))
                start = None
        if start is not None:
            nan_groups.append((start, len(df) - 1))

        # 4. نعوض فقط المجموعات التي طولها <= max_gap
        df_interp = df.copy()

        for start, end in nan_groups:
            gap_length = end - start + 1
            if gap_length <= max_gap:
                # نأخذ القيم قبل وبعد الفترة لتعويض
                # نعمل interpolate للفترة هذه فقط
                # لاستخدام interpolate نحتاج مجموعة بيانات مع قيمة قبل وبعد
                # عشان هيك نستخدم full interpolation ثم نرجع القيم لمواضع أخرى

                # مثلاً، نقدر نعمل تعويض كامل مرة واحدة:
                # لكن الأفضل هو تعويض كامل ثم نرجع القيم الباقية NaN عشان ما نعوض لفترات طويلة
                pass  # سنطبق تعويض كامل بعد الحلقة

            else:
                # نتركهم NaN لأن الفترة طويلة
                continue

        # 5. تعويض كامل باستخدام interpolate و bfill وffill
        df_full_interp = df.interpolate().bfill().ffill()

        # 6. نسخ القيم المعوضة فقط للمجموعات القصيرة <= max_gap
        for start, end in nan_groups:
            gap_length = end - start + 1
            if gap_length <= max_gap:
                df_interp.iloc[start:end+1] = df_full_interp.iloc[start:end+1]

        # 7. تحديث البيانات الأصلية بناء على df_interp
        updated_frames = []
        for i, (frame_index, frame_data) in enumerate(all_frames):
            bbox = df_interp.iloc[i].tolist()
            if any(np.isnan(b) for b in bbox):
                frame_data["ball"] = {}
            else:
                frame_data["ball"] = {1: {"bbox": bbox}}
            updated_frames.append((frame_index, frame_data))

        # 8. حفظ الملف المعدل
        with open(output_track_file, 'wb') as f:
            for item in updated_frames:
                pickle.dump(item, f)

        print(f"✅ تم تعويض مواضع الكرة وحفظ الملف الجديد في: {output_track_file}")

    


    def detect_frames_from_folder(self, frames_folder, output_file, batch_size=20):
        # --- ترتيب الإطارات ترتيبًا رقميًا باستخدام frame number ---
        frame_files = sorted([
            os.path.join(frames_folder, f)
            for f in os.listdir(frames_folder)
            if f.endswith(('.jpg', '.png'))
        ], key=lambda x: extract_frame_number(os.path.basename(x)))

        print(f"📸 عدد الإطارات: {len(frame_files)}")

        with open(output_file, 'wb') as f:
            for i in tqdm(range(0, len(frame_files), batch_size), desc="📦 الكشف على الإطارات", unit="batch"):
                batch_files = frame_files[i:i+batch_size]
                batch_frames = [cv2.imread(f) for f in batch_files]

                detections_batch = self.model.predict(batch_frames, conf=0.3)

                for j, detection in enumerate(detections_batch):
                    frame_index = i + j  # يعتمد على ترتيب الملفات بعد الفرز

                    simplified = {
                        'frame_index': frame_index,
                        'boxes': detection.boxes.xyxy.cpu().numpy().tolist() if detection.boxes is not None else [],
                        'confidences': detection.boxes.conf.cpu().numpy().tolist() if detection.boxes is not None else [],
                        'class_ids': detection.boxes.cls.cpu().numpy().tolist() if detection.boxes is not None else []
                    }

                    pickle.dump(simplified, f)

        print(f"✅ تم حفظ بيانات الكشف في {output_file}")



    def get_object_tracks(self, detection_file, output_file):
        max_frame_index = -1

        # الخطوة 1: حساب عدد الإطارات
        frame_count = 0
        with open(detection_file, 'rb') as f:
            try:
                while True:
                    _ = pickle.load(f)
                    frame_count += 1
            except EOFError:
                pass

        # الخطوة 2: فتح الملف للمعالجة وكتابة النتائج مضغوطة
        with open(detection_file, 'rb') as f_in, open(output_file, 'wb') as f_out, tqdm(total=frame_count, desc="🚀 تتبع الكائنات") as pbar:
            try:
                while True:
                    detection = pickle.load(f_in)

                    frame_index = detection['frame_index']
                    boxes = np.array(detection['boxes'], dtype=np.float32)
                    class_ids = np.array(detection['class_ids'], dtype=int)
                    confidences = np.array(detection['confidences'], dtype=np.float32)

                    # ✅ تأكد أن الشكل مناسب حتى لو كانت فارغة
                    if boxes.size == 0:
                        boxes = np.zeros((0, 4), dtype=np.float32)
                    if class_ids.size == 0:
                        class_ids = np.zeros((0,), dtype=int)
                    if confidences.size == 0:
                        confidences = np.zeros((0,), dtype=np.float32)

                    max_frame_index = max(max_frame_index, frame_index)

                    # تحويل البيانات إلى كائن supervision.Detections
                    detection_supervision = sv.Detections(
                        xyxy=boxes,
                        class_id=class_ids,
                        confidence=confidences
                    )

                    # تتبع
                    detection_with_tracks = self.tracker.update_with_detections(detection_supervision)

                    # تجميع النتائج
                    frame_tracks = {
                        "players": {},
                        "referees": {},
                        "goalkeeper": {},
                        "ball": {}
                    }

                    for frame_detection in detection_with_tracks:
                        bbox = frame_detection[0].tolist()
                        cls_id = int(frame_detection[3])
                        track_id = int(frame_detection[4])

                        if cls_id == 2:  # player
                            frame_tracks["players"][track_id] = {"bbox": bbox}
                        elif cls_id == 3:  # referee
                            frame_tracks["referees"][track_id] = {"bbox": bbox}
                        elif cls_id == 1:  # goalkeeper
                            frame_tracks["goalkeeper"][track_id] = {"bbox": bbox}

                    # نضيف الكرة من detections الأصلية (بدون تتبع)
                    for i, cls_id in enumerate(class_ids):
                        if cls_id == 0:  # ball
                            bbox = boxes[i].tolist()
                            frame_tracks["ball"][1] = {"bbox": bbox}
                            break  # واحدة فقط تكفي

                    pickle.dump((frame_index, frame_tracks), f_out)
                    pbar.update(1)

            except EOFError:
                pass




    def draw_ellipse(self,frame,bbox,color,track_id=None):
        y2 = int(bbox[3])
        x_center, _ = get_center_of_bbox(bbox)
        width = get_bbox_width(bbox)

        cv2.ellipse(
            frame,
            center=(x_center,y2),
            axes=(int(width), int(0.35*width)),
            angle=0.0,
            startAngle=-45,
            endAngle=235,
            color = color,
            thickness=2,
            lineType=cv2.LINE_4
        )

        return frame

    def draw_traingle(self,frame,bbox,color):
        y= int(bbox[1])
        x,_ = get_center_of_bbox(bbox)

        triangle_points = np.array([
            [x,y],
            [x-10,y-20],
            [x+10,y-20],
        ])
        cv2.drawContours(frame, [triangle_points],0,color, cv2.FILLED)
        cv2.drawContours(frame, [triangle_points],0,(0,0,0), 2)

        return frame
    
    def draw_annotations_single_frame(self, frame, tracks, frame_teams):
        frame = frame.copy()
        player_dict = tracks.get("players", {})
        ball_dict = tracks.get("ball", {})
        referee_dict = tracks.get("referees", {})
        goalkeeper_dict = tracks.get("goalkeeper", {})

        # بناء خريطة player_id -> team_id من frame_teams
        player_team_map = {}
        for record in frame_teams:
            pid = record.get("player_id")
            team = record.get("team", -1)
            if pid is not None:
                player_team_map[pid] = team

        # ألوان الفريقين (يمكن تعديل أو إضافة ألوان ديناميكياً لو تبي)
        team_colors = {
            0: (0, 0, 255),     # فريق 1 - أحمر
            1: (0, 255, 255),     # فريق 2 - أزرق
            -1: (128, 128, 128) # مجهول - رمادي
        }

        # اللاعبين مع تحديد اللون حسب الفريق من player_team_map
        for track_id, player in player_dict.items():
            team_id = player_team_map.get(track_id, -1)  # إذا غير موجود اعتبر مجهول
            color = team_colors.get(team_id, (128, 128, 128))  # لون الفريق أو رمادي
            bbox = player.get("bbox")
            if bbox is not None:
                 if track_id==198 or track_id==239:
                    frame = self.draw_ellipse(frame, bbox, (0, 0, 0), track_id)
                 else:
                    frame = self.draw_ellipse(frame, bbox, color, track_id)

        # الكرة
        for track_id, ball in ball_dict.items():
            bbox = ball.get("bbox")
            if bbox is not None:
                frame = self.draw_traingle(frame, bbox, (0, 255, 0))

        # الحكّام
        for track_id, referee in referee_dict.items():
            bbox = referee.get("bbox")
            if bbox is not None:
                if track_id==198 or track_id==239:
                    frame = self.draw_ellipse(frame, bbox, (0, 0, 0), track_id)
                else:
                    frame = self.draw_ellipse(frame, bbox, (255, 0, 255), track_id)

        # الحراس
        for track_id, goalkeeper in goalkeeper_dict.items():
            bbox = goalkeeper.get("bbox")
            if bbox is not None:
                if track_id==198 or track_id==239:
                    frame = self.draw_ellipse(frame, bbox, (0, 0, 0), track_id)
                else:
                    frame = self.draw_ellipse(frame, bbox, (255, 255, 0), track_id)
        return frame

