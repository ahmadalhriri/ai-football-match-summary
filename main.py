from read import parallel_extract,process_and_save_video
from trackers import Tracker
import time
from important import ImportantMomentsDetector
from match_sum import MatchSummarizer
from team_assigner import TeamAssigner
from voice_analys import MomentClassifier,WhisperTranscriber
import cv2
from mareg_voice_vidoe import ImportantMomentsMerger

def main():
    video_file = "input_videos/interb.mkv"
    output_file="output_videos/summary.mp4"
    tracker = Tracker('models/best.pt')
    parallel_extract(video_file,"output_frame")
    tracker.detect_frames_from_folder("output_frame","stubs/detection_file")
    tracker.get_object_tracks("stubs/detection_file","stubs/tracks_file")
    tracker.interpolate_ball_positions_from_track_file("stubs/tracks_file","stubs/tracks_file_inter_ball")

    importent=ImportantMomentsDetector("stubs/tracks_file","important_frames.json")
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
        merge_penalty_gap=1#اذا رجعتها 10 بمزل الملخص الى 31 دقيقه
    )

    merger.run("merged_moments.json")



    summarizer = MatchSummarizer(
        video_path=video_file,
       moments_json="merged_moments.json",
       output_path="output_file",
       time_window=0  # ثواني قبل وبعد كل لحظة
    )

    summarizer.summarize()





if __name__=="__main__":
    start = time.time()
    main()
    end = time.time()
    print(f"⏱️ وقت التنفيذ (مع المعالجة المتوازية): {end - start:.2f} ثانية")
