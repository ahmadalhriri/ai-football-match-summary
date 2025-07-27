from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import re
import yt_dlp

HOST = '0.0.0.0'
PORT = 8001

def is_valid_url(url):
    pattern = r'^https?://[^\s]+$'
    return re.match(pattern, url) is not None

def download_video(url, resolution='bestvideo[height>=720]+bestaudio/best[height>=720]/best'):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, 'DownloadedMatches')
    
    output_path = os.path.expanduser(output_path)
    os.makedirs(output_path, exist_ok=True)

    ydl_opts = {
        'merge_output_format': 'mp4',
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        'format': resolution,
        'outtmpl': f'{output_path}/%(title)s.%(ext)s',
        'retries': 10,
        'fragment_retries': 10,
        'continuedl': True,
        'noplaylist': True,
        'quiet': False,
        'no_warnings': False,
    }

    try:
        # Clear cache
        with yt_dlp.YoutubeDL() as ydl:
            ydl.cache.remove()
            
        if not is_valid_url(url):
            return {'success': False, 'error': '❌ Invalid URL'}

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                info_dict = ydl.extract_info(url, download=True)
            except yt_dlp.utils.DownloadError:
                return {'success': False, 'error': '❌ Unsupported site'}

            return {
                'success': True,
                'title': info_dict.get('title'),
                'resolution': info_dict.get('height'),
                'vcodec': info_dict.get('vcodec')
            }

    except Exception as e:
        return {'success': False, 'error': f'❌ Failure: {str(e)}'}

if __name__ == '__main__':
    class SimpleHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/download':
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length)
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    url = data.get('url')
                    if not url:
                        raise ValueError("Missing URL")

                    result = download_video(url)
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(json.dumps(result).encode('utf-8'))

                except Exception as e:
                    self.send_response(400)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'success': False, 'error': str(e)}).encode('utf-8'))
            else:
                self.send_response(404)
                self.end_headers()

    server = HTTPServer((HOST, PORT), SimpleHandler)
    print(f"🚀 Server running at http://{HOST}:{PORT}")
    server.serve_forever()
