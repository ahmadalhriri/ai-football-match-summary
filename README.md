# ai-football-match-summary
 A cross-platform mobile app that summarizes football matches using computer vision and NLP techniques.

# مشروع تلخيص مباريات كرة القدم باستخدام الذكاء الاصطناعي

## الوصف
هذا المشروع يهدف إلى تحليل وتلخيص مباريات كرة القدم باستخدام تقنيات الذكاء الاصطناعي، ويحتوي على واجهة تطبيق مبنية بـ Flutter مع Backend باستخدام FastAPI لتحليل الفيديوهات والتعليقات الصوتية.

## المميزات
- تحليل الفيديوهات لتحديد اللحظات المهمة في المباراة.
- استخدام نموذج Whisper لتحويل الصوت إلى نص.
- توليد ملخصات تلقائية للمباريات.
- واجهة مستخدم تفاعلية وسهلة الاستخدام باستخدام Flutter.
- دعم أنظمة Android، iOS، Windows، macOS، وLinux.

## الهيكلية
- `lib/`: ملفات Flutter الخاصة بالواجهة الأمامية.
- `backend/FastAPIserver/`: ملفات السيرفر والذكاء الاصطناعي.
- `android/`, `ios/`, `windows/`, `macos/`, `linux/`: ملفات بناء التطبيق على مختلف المنصات.
- `pubspec.yaml`: إعدادات مشروع Flutter.
- `README.md`: هذا الملف.

## المتطلبات
- Flutter SDK
- Python 3.8+
- مكتبات Python (يمكن تثبيتها عبر `pip install -r backend/FastAPIserver/requirements.txt`)

## طريقة التشغيل

### تشغيل Backend (FastAPI):
1. افتح الطرفية في مجلد `backend/FastAPIserver/`
2. نفذ الأمر:
```

python main.py 

3. السيرفر رح يكون متاح على `http://localhost:8000`

### تشغيل تطبيق Flutter:
1. في مجلد المشروع الرئيسي، نفذ الأمر:
```

flutter run

```
2. أو استخدم IDE مثل Android Studio أو VS Code لتشغيل التطبيق على المحاكي أو جهاز فعلي.

## كيفية المساهمة
إذا كنت ترغب بالمساهمة في المشروع:
- قم بعمل Fork للمستودع.
- أنشئ فرعًا جديدًا لميزتك.
- بعد الانتهاء، أرسل Pull Request مع شرح التعديلات.

## الترخيص
يتم توزيع المشروع تحت رخصة MIT.

---

إذا عندك أي أسئلة أو اقتراحات، لا تتردد في التواصل.

---

**مطور المشروع:** أحمد الحريري  
**GitHub:** [ahmadalhriri](https://github.com/ahmadalhriri)
```
