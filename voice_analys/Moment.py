import json
import re
from tqdm import tqdm
from sentence_transformers import SentenceTransformer, util

class MomentClassifier:
    def __init__(self, window_size=2, threshold=0.95):
        print("📦 تحميل نموذج التصنيف...")
        self.model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
        self.window_size = window_size
        self.threshold = threshold
        self.reference_phrases = {
        "goal": ["هدف", "غووول", "سجلها", "الشباك", "المرمى","يسجل","الأول" ,"الثاني"," الثالث","الرابع","الخامس","فعلها","هدفان","يسدد","يسجل","قول","التعادل","تدخل","الرئسية","غول","وتسديده","يحط","التعادل","مش ممكن"," لمن الحل","جول"],
        "chance": ["خطيرة", "هجومية", "مرتدة", "انفراد", "ممكنة","مباشرة","عرضية","ركنية"],
        "save": ["تصدى", "أنقذها", "إبعاد", "صدها", "منع","اضاعها","يضيعها","ضاعت"],
        "card": ["بطاقة حمراء", "بطاقة صفراء", "إنذار", "تدخل عنيف", "طرد مباشر","كرت اصفر", "كرت احمر"],
        "penalty": ["جزاء", "بلنتي", "جزاء","يسدد","يسجل"],
        "shot": ["ألاهي","الله","الله","قوية", "صاروخ", "قذيفة","سهلة"," جميلة","ريمونتادة","تسلل"],
        "excitement": ["مجنونة", "خطيرة","ضغط"]
        }
        self.reference_embeddings = self._embed_reference_phrases()

    def _clean_text(self, text):
        text = re.sub(r'(.)\1{2,}', r'\1', text)
        text = re.sub(r'[^\w\s]', '', text)
        return text.strip().lower()

    def _embed_reference_phrases(self):
        print("🔍 حساب تمثيلات الجمل المرجعية...")
        embeddings = {}
        for label, phrases in self.reference_phrases.items():
            embeddings[label] = self.model.encode(phrases, convert_to_tensor=True)
        return embeddings

    def load_transcription(self, file_path):
        with open(file_path, encoding="utf-8") as f:
            return json.load(f)

    def generate_segments(self, words):
        segments = []
        for i in range(len(words) - self.window_size + 1):
            segment_text = " ".join([self._clean_text(words[j]['word']) for j in range(i, i + self.window_size)])
            segments.append({
                "text": segment_text,
                "start": words[i]['start'],
                "end": words[i + self.window_size - 1]['end']
            })
        return segments

    def classify_segments(self, segments):
        important_moments = []
        for seg in tqdm(segments, desc="🧠 تصنيف الجمل"):
            seg_embedding = self.model.encode(seg['text'], convert_to_tensor=True)
            best_label = None
            best_score = 0.0

            for label, refs in self.reference_embeddings.items():
                score = util.pytorch_cos_sim(seg_embedding, refs).max().item()
                if score > self.threshold and score > best_score:
                    best_label = label
                    best_score = score

            if best_label:
                important_moments.append({
                    "label": best_label,
                    "text": seg['text'],
                    "start": seg['start'],
                    "end": seg['end'],
                    "score": round(best_score, 2)
                })

        return important_moments

    def save_results(self, results, output_file="important_moments.json"):
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        print(f"✅ تم حفظ اللحظات المهمة في: {output_file}")

    def process(self, transcription_path, output_path="important_moments.json"):
        print("📂 تحميل تفريغ Whisper...")
        words = self.load_transcription(transcription_path)
        print("📄 إنشاء مقاطع قصيرة...")
        segments = self.generate_segments(words)
        print("🔎 تصنيف اللحظات المهمة...")
        moments = self.classify_segments(segments)
        self.save_results(moments, output_path)
        return moments
