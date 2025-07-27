import cv2
import os
import multiprocessing
from tqdm import tqdm
import cv2
import os
from trackers import Tracker
from tqdm import tqdm
import pickle
import gzip
from team_assigner import TeamAssigner
import os
import re
import cv2
import pickle
from tqdm import tqdm
from find_best import find_and_save_best_frame_only
import cv2
import os
import multiprocessing
from tqdm import tqdm



def get_total_frames(video_path):
    cap = cv2.VideoCapture(video_path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    cap.release()
    return total

def extract_frames_range(video_path, output_dir, start_frame, end_frame, counter, lock, step):
    cap = cv2.VideoCapture(video_path)
    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

    current_frame = start_frame
    while current_frame < end_frame:
        success, frame = cap.read()
        if not success:
            break

        if current_frame % step == 0:
            filename = os.path.join(output_dir, f"frame{current_frame}.jpg")
            cv2.imwrite(filename, frame)
            with lock:
                counter.value += 1

        current_frame += 1

    cap.release()

def parallel_extract(video_path, output_dir, step=2, num_processes=None):
    total_frames = get_total_frames(video_path)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    num_processes = num_processes or multiprocessing.cpu_count() - 2
    chunk_size = total_frames // num_processes

    total_extracted = (total_frames + step - 1) // step  # تقريبي
    manager = multiprocessing.Manager()
    counter = manager.Value('i', 0)
    lock = manager.Lock()

    processes = []
    for i in range(num_processes):
        start = i * chunk_size
        end = (i + 1) * chunk_size if i != num_processes - 1 else total_frames
        p = multiprocessing.Process(
            target=extract_frames_range,
            args=(video_path, output_dir, start, end, counter, lock, step)
        )
        processes.append(p)
        p.start()

    with tqdm(total=total_extracted, desc=f"📦 استخراج الإطارات (كل {step})") as pbar:
        prev = 0
        while any(p.is_alive() for p in processes):
            with lock:
                diff = counter.value - prev
                prev = counter.value
            pbar.update(diff)

        with lock:
            pbar.update(counter.value - prev)

    for p in processes:
        p.join()




def extract_frame_number(filename):
    """استخراج رقم الإطار من اسم الملف"""
    match = re.search(r'frame(\d+)\.jpg', filename)
    return int(match.group(1)) if match else -1
def process_and_save_video(frames_folder, tracks_file_path, teams_file_path, output_video_path, input_video_path):
    tracker = Tracker('models/best.pt')
    ii=0
    # استخراج FPS من الفيديو الأصلي
    cap = cv2.VideoCapture(input_video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.release()
    print(f"📹 معدل الإطارات المستخرج من الفيديو الأصلي: {fps}")

    # ترتيب ملفات الإطارات
    frame_files = sorted([
        os.path.join(frames_folder, f)
        for f in os.listdir(frames_folder)
        if f.endswith(('.jpg', '.png'))
    ], key=lambda x: extract_frame_number(os.path.basename(x)))

    if not frame_files:
        print("❌ لم يتم العثور على إطارات في المجلد.")
        return

    first_frame = cv2.imread(frame_files[0])
    height, width = first_frame.shape[:2]
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_video_path, fourcc, fps, (width, height))

    # فتح ملف التتبع وملف الفرق
    with open(tracks_file_path, 'rb') as f_tracks, open(teams_file_path, 'rb') as f_teams, tqdm(total=len(frame_files), desc="🔄 معالجة الإطارات") as pbar:
        try:
            # قراءة أول سجل فرق (للتأكد من البداية)
            current_team_record = None
            try:
                current_team_record = pickle.load(f_teams)
            except EOFError:
                current_team_record = None

            for frame_index, frame_path in enumerate(frame_files):
                frame = cv2.imread(frame_path)

                # قراءة بيانات التتبع للإطار الحالي
                track_frame_index, track_data = pickle.load(f_tracks)

                if frame_index != track_frame_index:
                    print(f"⚠️ تعارض في رقم الإطار. (متوقع {frame_index}، الموجود {track_frame_index})")
                    continue

                # تجميع بيانات الفرق الخاصة بالإطار الحالي
                # الفريق عبارة عن قائمة من dicts لكل لاعب، نحتاج فقط بيانات اللاعبين للإطار الحالي
                frame_teams = []
                while current_team_record and current_team_record["frame_index"] == frame_index:
                    frame_teams.append(current_team_record)
                    try:
                        current_team_record = pickle.load(f_teams)
                    except EOFError:
                        current_team_record = None
                        break

                # تمرير بيانات الفرق مع بيانات التتبع لدالة الرسم
                annotated_frame = tracker.draw_annotations_single_frame(frame, track_data, frame_teams)
                cv2.imwrite("out_d/frame{}.jpg".format(ii), annotated_frame)
                ii+=1
                out.write(annotated_frame)
                pbar.update(1)

        except EOFError:
            print("✅ تم الانتهاء من معالجة جميع الإطارات.")

    out.release()
    print(f"🎬 تم حفظ الفيديو في: {output_video_path}")
