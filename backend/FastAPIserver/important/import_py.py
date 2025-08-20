import pickle
import math
import os
import json

class ImportantMomentsDetector:
    def __init__(self, detection_file, output_json):
        self.detection_file = detection_file
        self.output_json = output_json
        self.important_frames = []
        self.prev_ball_positions = []  # سجل مواضع الكرة
        self.max_history = 30  # أقصى عدد إطارات لحفظ سجل الكرة

    def distance(self, obj1, obj2):
        return math.sqrt((obj1['x'] - obj2['x'])**2 + (obj1['y'] - obj2['y'])**2)

    def is_ball_fast(self, current_ball, myspeed, frame_gap=5):
        self.prev_ball_positions.append(current_ball)

        if len(self.prev_ball_positions) > self.max_history:
            self.prev_ball_positions.pop(0)

        if len(self.prev_ball_positions) > frame_gap:
            past_ball = self.prev_ball_positions[-(frame_gap + 1)]
            speed = self.distance(past_ball, current_ball)
            return speed > myspeed
        return False

    def analyze(self):
        with open(self.detection_file, 'rb') as f:
            try:
                while True:
                    frame_index, frame_tracks = pickle.load(f)

                    boxes = []
                    class_ids = []

                    for player in frame_tracks['players'].values():
                        boxes.append(player['bbox'])
                        class_ids.append(2)

                    for referee in frame_tracks['referees'].values():
                        boxes.append(referee['bbox'])
                        class_ids.append(3)

                    for gk in frame_tracks['goalkeeper'].values():
                        boxes.append(gk['bbox'])
                        class_ids.append(1)

                    for ball in frame_tracks['ball'].values():
                        boxes.append(ball['bbox'])
                        class_ids.append(0)
                        break

                    simplified = {
                        'frame_index': frame_index,
                        'boxes': boxes,
                        'class_ids': class_ids
                    }

                    frame_result = self.analyze_frame(simplified)
                    if frame_result:
                        self.important_frames.append(frame_result)
            except EOFError:
                pass

        grouped_events = self.group_events()

        with open(self.output_json, 'w', encoding='utf-8') as out_f:
            json.dump(grouped_events, out_f, ensure_ascii=False, indent=2)
        print(f"✅ تم استخراج {len(grouped_events)} لحظة مهمة إلى {self.output_json}")

    def analyze_frame(self, simplified):
        frame_index = simplified['frame_index']
        boxes = simplified['boxes']
        class_ids = simplified['class_ids']

        players = []
        goalkeeper = None
        referee = None
        ball = None

        for box, class_id in zip(boxes, class_ids):
            x1, y1, x2, y2 = box
            x_center = (x1 + x2) / 2
            y_center = (y1 + y2) / 2
            w = x2 - x1
            h = y2 - y1
            obj = {'x': x_center, 'y': y_center, 'w': w, 'h': h}

            if class_id == 0:
                ball = obj
            elif class_id == 1:
                goalkeeper = obj
            elif class_id == 2:
                players.append(obj)
            elif class_id == 3:
                referee = obj

        events = []
        #واو واوو واوو يعني بيرفيكت
        # قاعدة 1: الكرة قريبة من الحارس ويوجد 8 لاعبين بالقرب → هدف أو فرصة خطيرة
        if goalkeeper  :
            close_players = [p for p in players if self.distance(goalkeeper, p) < 300]
            if  len(close_players) >= 1:
                events.append("فرصة خطيرة أو هدف")

        #واووو واوو واوو يعني ممتاز
        # قاعدة 3:   ركلات ترجيح"
        if  ball and goalkeeper:
            solo_players = [p for p in players ]
            if len(solo_players) == 1  and self.is_ball_fast(ball, 0, frame_gap=29):
                events.append("ركلات ترجيح")

        #✅ قاعدة 4: تسديدة سريعة أو تمريرة قوية (إذا كانت الكرة سريعة والحارس ظاهر)
        #if ball and self.is_ball_fast(ball, 2000, frame_gap=5) and goalkeeper:
            #events.append("تسديدة قوية أو تمريرة")

        if events:
            return {'frame_index': frame_index, 'events': events, 'confidence': len(events)}
        return None
    def group_events(self, min_duration=200):
        grouped = []
        prev_event = None
        for item in self.important_frames:
            if prev_event and item['frame_index'] - prev_event['end'] <= 200:
                prev_event['end'] = item['frame_index']
                prev_event['confidence'] += item['confidence']
                prev_event['events'].append(item['events'])
            else:
                if prev_event and (prev_event['end'] - prev_event['start'] >= min_duration):
                    # تسطيح قائمة الأحداث وإزالة التكرار
                    prev_event['events'] = list(set(
                        e for sublist in prev_event['events']
                        for e in (sublist if isinstance(sublist, list) else [sublist])
                    ))
                    grouped.append(prev_event)
                prev_event = {
                    'start': item['frame_index'],
                    'end': item['frame_index'],
                    'events': [item['events']],  # دائماً نخزن الأحداث داخل قائمة
                    'confidence': item['confidence']
                }
        if prev_event and (prev_event['end'] - prev_event['start'] >= min_duration):
            prev_event['events'] = list(set(
                e for sublist in prev_event['events']
                for e in (sublist if isinstance(sublist, list) else [sublist])
            ))
            grouped.append(prev_event)
        return grouped

