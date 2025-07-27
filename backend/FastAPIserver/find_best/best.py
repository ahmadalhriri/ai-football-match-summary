import cv2
import os
import pickle
import numpy as np
from itertools import combinations
from tqdm import tqdm
import re

def extract_frame_number(name):
    match = re.search(r'(\d+)', os.path.splitext(name)[0])
    return int(match.group(1)) if match else -1

def calculate_iou(boxA, boxB):
    xA = max(boxA[0], boxB[0])
    yA = max(boxA[1], boxB[1])
    xB = min(boxA[2], boxB[2])
    yB = min(boxA[3], boxB[3])

    interArea = max(0, xB - xA) * max(0, yB - yA)
    boxAArea = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
    boxBArea = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1])
    unionArea = boxAArea + boxBArea - interArea

    return interArea / unionArea if unionArea != 0 else 0

def find_and_save_best_frame_only(frames_folder, detection_file, output_folder):
    os.makedirs(output_folder, exist_ok=True)

    best_frame_image = None
    best_frame_number = -1
    max_objects = 0

    frame_files = sorted([
        os.path.join(frames_folder, f)
        for f in os.listdir(frames_folder)
        if f.endswith(('.jpg', '.png'))
    ], key=lambda x: extract_frame_number(os.path.basename(x)))

    with open(detection_file, 'rb') as f:
        for frame_index, frame_path in tqdm(enumerate(frame_files), total=len(frame_files), desc="🔍 البحث عن أفضل إطار"):
            frame = cv2.imread(frame_path)

            try:
                detection = pickle.load(f)
            except EOFError:
                print("📁 انتهى ملف الكشف قبل انتهاء الإطارات.")
                break

            boxes = np.array(detection['boxes'], dtype=int)
            class_ids = np.array(detection['class_ids'], dtype=int)

            player_boxes = [boxes[i] for i in range(len(boxes)) if class_ids[i] == 0]

            overlap_found = False
            for boxA, boxB in combinations(player_boxes, 2):
                if calculate_iou(boxA, boxB) > 0:
                    overlap_found = True
                    break

            num_detections = len(boxes)

            if not overlap_found and num_detections > max_objects:
                max_objects = num_detections
                best_frame_image = frame.copy()
                best_frame_number = frame_index

    if best_frame_image is not None:
        best_frame_path = os.path.join(output_folder, 'the_best.jpg')
        cv2.imwrite(best_frame_path, best_frame_image)
        print(f"✅ تم حفظ أفضل إطار (رقم {best_frame_number}) بعدد كائنات = {max_objects} بدون تداخل.")
        return best_frame_path, best_frame_number
    else:
        print("❌ لم يتم العثور على إطار مناسب.")
        return None, None
