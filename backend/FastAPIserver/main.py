
from fastapi import FastAPI, HTTPException, Request, Body
from fastapi.responses import StreamingResponse, JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import logging
from typing import List, Dict
import datetime
from urllib.parse import unquote, quote
import subprocess
import yt_dlp
import sys

###################################################################
from read import parallel_extract, process_and_save_video
from trackers import Tracker
import time
from important import ImportantMomentsDetector
from match_sum import MatchSummarizer
from team_assigner import TeamAssigner
from voice_analys import MomentClassifier, WhisperTranscriber
import cv2
from mareg_voice_vidoe import ImportantMomentsMerger
import os
import glob

def summarize():
    # ✅ اختيار أحدث فيديو من DownloadedMatches
    downloaded_matches_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../DownloadedMatches"))
    print("ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
    video_files = glob.glob(os.path.join(downloaded_matches_dir, "*.mp4"))
    if not video_files:
        raise FileNotFoundError("❌ لا يوجد أي فيديو في مجلد DownloadedMatches.")
    latest_video_path = max(video_files, key=os.path.getmtime)

    # ✅ إعداد اسم الإخراج داخل summarises باسم "ملخص ..."
    summarises_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../summarises"))
    video_name = os.path.basename(latest_video_path)
    output_name = f"ملخص {video_name}"
    output_video_path = os.path.join(summarises_dir, output_name)

    video_file = latest_video_path
    output_file = output_video_path

    tracker = Tracker(os.path.join(os.path.dirname(__file__), 'models', 'best.pt'))

    parallel_extract(video_file, "output_frame")
    tracker.detect_frames_from_folder("output_frame", "stubs/detection_file")
    tracker.get_object_tracks("stubs/detection_file", "stubs/tracks_file")
    tracker.interpolate_ball_positions_from_track_file("stubs/tracks_file", "stubs/tracks_file_inter_ball")

    importent = ImportantMomentsDetector("stubs/tracks_file", "important_frames.json")
    importent.analyze()

    transcriber = WhisperTranscriber(model_size="medium")
    text = transcriber.transcribe_video(video_file)

    classifier = MomentClassifier()
    classifier.process("transcription.json")

    merger = ImportantMomentsMerger(
        video_json_path="important_frames.json",
        audio_json_path="important_moments.json",
        video_file_path=video_file,
        merge_threshold=1,
        merge_penalty_gap=1  # اذا رجعتها 10 بنزل الملخص إلى 31 دقيقة
    )

    merger.run("merged_moments.json")

    summarizer = MatchSummarizer(
        video_path=video_file,
        moments_json="merged_moments.json",
        output_path=output_file,
        time_window=0  # ثواني قبل وبعد كل لحظة
    )

    summarizer.summarize()

##############################################################
# Add the parent directory to the path to allow importing downloadmatch
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from downloadmatch import download_video as dm_download_video

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Video folder path
VIDEO_FOLDER = os.path.abspath(os.path.join("..", "DownloadedMatches"))
logger.info(f"Video folder path: {VIDEO_FOLDER}")

# Add a new constant for the summaries folder
SUMMARIES_FOLDER = os.path.abspath(os.path.join("..", "summarises"))
logger.info(f"Summaries folder path: {SUMMARIES_FOLDER}")

# THUMBNAIL_FOLDER is only used for DownloadedMatches videos
THUMBNAIL_FOLDER = VIDEO_FOLDER  # Store thumbnails for DownloadedMatches videos only

def generate_thumbnail(video_path, thumbnail_path):
    if not os.path.exists(thumbnail_path):
        try:
            subprocess.run([
                'ffmpeg', '-y', '-i', video_path,
                '-ss', '00:00:01.000', '-vframes', '1', thumbnail_path
            ], check=True)
        except Exception as e:
            logger.error(f"Failed to generate thumbnail for {video_path}: {e}")

@app.get("/video")
@app.head("/video")
async def stream_video(name: str, request: Request):
    try:
        decoded_name = unquote(name)
        file_path = os.path.join(VIDEO_FOLDER, decoded_name)
        if not os.path.exists(file_path):
            file_path = os.path.join(SUMMARIES_FOLDER, decoded_name)
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail="File not found")

        file_size = os.path.getsize(file_path)
        if not decoded_name.lower().endswith((".mp4", ".avi", ".mov", ".mkv")):
            raise HTTPException(status_code=400, detail="Invalid file type")

        range_header = request.headers.get('range')
        start = 0
        end = file_size - 1
        if range_header:
            try:
                range_str = range_header.replace('bytes=', '')
                if '-' in range_str:
                    start_str, end_str = range_str.split('-')
                    start = int(start_str) if start_str else 0
                    end = int(end_str) if end_str else file_size - 1
                else:
                    start = int(range_str)
            except ValueError:
                start, end = 0, file_size - 1

        content_length = end - start + 1
        headers = {
            "Content-Length": str(content_length),
            "Content-Type": "video/mp4",
            "Accept-Ranges": "bytes",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, HEAD",
            "Access-Control-Allow-Headers": "Range",
            "Access-Control-Expose-Headers": "Content-Range, Accept-Ranges, Content-Length",
            "Cache-Control": "no-cache",
        }
        if range_header:
            headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"

        if request.method == "HEAD":
            return JSONResponse(content={"size": file_size, "range": f"{start}-{end}"}, headers=headers)

        async def video_stream():
            chunk_size = 8192
            with open(file_path, 'rb') as f:
                f.seek(start)
                remaining = content_length
                while remaining > 0:
                    chunk = f.read(min(chunk_size, remaining))
                    if not chunk:
                        break
                    yield chunk
                    remaining -= len(chunk)

        return StreamingResponse(video_stream(), media_type="video/mp4", headers=headers, status_code=206 if range_header else 200)

    except Exception as e:
        logger.error(f"Error streaming video: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get('/thumbnails/{filename}')
async def get_thumbnail(filename: str):
    thumb_path = os.path.join(SUMMARIES_FOLDER, filename)
    if os.path.exists(thumb_path):
        return FileResponse(thumb_path, media_type='image/jpeg')
    return FileResponse('/path/to/default.jpg', media_type='image/jpeg')

@app.get("/summaries")
async def get_summaries():
    try:
        summaries = []
        if not os.path.exists(SUMMARIES_FOLDER):
            return []

        for filename in os.listdir(SUMMARIES_FOLDER):
            if filename.endswith((".mp4", ".avi", ".mov", ".mkv")):
                path = os.path.join(SUMMARIES_FOLDER, filename)
                size = os.path.getsize(path)
                minutes = round(size / (1024 * 1024 * 5), 2)

                encoded_filename = quote(filename)
                video_url = f'http://192.168.84.116:8000/video?name={encoded_filename}'

                thumb_name = f'{os.path.splitext(filename)[0]}.jpg'
                thumb_path = os.path.join(SUMMARIES_FOLDER, thumb_name)
                generate_thumbnail(path, thumb_path)
                thumbnail_url = f'http://192.168.84.116:8000/thumbnails/{quote(thumb_name)}'
                if not os.path.exists(thumb_path):
                    thumbnail_url = 'https://via.placeholder.com/320x180.png?text=No+Thumbnail'

                summaries.append({
                    'title': filename,
                    'description': f'ملخص {filename}',
                    'date': datetime.datetime.now().strftime('%Y-%m-%d'),
                    'duration': f'{int(minutes)}:{int((minutes % 1) * 60):02d}',
                    'video_url': video_url,
                    'thumbnail_url': thumbnail_url
                })
        return summaries
    except Exception as e:
        logger.error(f"Error getting summaries: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/download")
async def download_video_endpoint(data: dict = Body(...)):
    url = data.get('url')
    if not url:
        raise HTTPException(status_code=400, detail="URL is required")

    result = dm_download_video(url)

    if not result.get('success'):
        raise HTTPException(status_code=500, detail=result.get('error', 'Unknown error'))

    try:
        # تنفيذ التلخيص
        logger.info("🔁 Starting summarization...")
        summarize()
        logger.info("✅ Summarization completed.")

        # حذف أحدث فيديو تم تنزيله
        video_files = [f for f in os.listdir(VIDEO_FOLDER) if f.endswith((".mp4", ".mkv", ".avi"))]
        if video_files:
            latest_video_path = max([os.path.join(VIDEO_FOLDER, f) for f in video_files], key=os.path.getmtime)
            os.remove(latest_video_path)
            logger.info(f"🗑️ Deleted downloaded video: {latest_video_path}")
        else:
            logger.warning("⚠️ No video found to delete after summarization.")

        return {
            "success": True,
            "message": "📥 Video downloaded, summarized, and original file deleted."
        }

    except Exception as e:
        logger.error(f"❌ Summarization failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Summarization failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    logger.info("🚀 Starting FastAPI server...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
