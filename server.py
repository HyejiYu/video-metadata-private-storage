from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os, io, json, logging, re
import boto3
import subprocess
import yt_dlp
import time, uuid
from google.cloud import speech
from google.cloud import speech_v1p1beta1 as speech
from pydub import AudioSegment
from datetime import timedelta, datetime
from elasticsearch import Elasticsearch, exceptions
from dotenv import load_dotenv
from googleapiclient.discovery import build


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(filename)s:%(lineno)d] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S %z"
)
logger = logging.getLogger(__name__)

load_dotenv()

# 환경 변수 로드
AWS_ACCESS_KEY = os.getenv('AWS_ACCESS_KEY')
AWS_SECRET_KEY = os.getenv('AWS_SECRET_KEY')
S3_BUCKET_NAME = os.getenv('S3_BUCKET_NAME')
AWS_REGION = os.getenv('AWS_REGION')
PORT = int(os.getenv('PORT', 3000))
VIDEO_INDEX = os.getenv("VIDEO_INDEX")
VIDEO_SCRIPT_INDEX = os.getenv("VIDEO_SCRIPT_INDEX")
ELASTIC_USER=os.getenv("ELASTIC_USER")
ELASTIC_PASSWORD=os.getenv("ELASTIC_PASSWORD")
API_KEY = os.getenv("YOUTUBE_API_KEY")
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'

# Flask 앱 설정
app = Flask(__name__)
# 요청 크기 제한을 300MB로 설정
app.config['MAX_CONTENT_LENGTH'] = 300 * 1024 * 1024 

# ElasticSearch
es = Elasticsearch(
    hosts=["http://localhost:9200"],
    basic_auth = (ELASTIC_USER, ELASTIC_PASSWORD)
)
    

# AWS S3 설정
s3_client = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=AWS_REGION,
)

# Google Cloud Speech-to-Text 클라이언트 초기화
speech_client = speech.SpeechClient()

# 임시 디렉토리 설정
TEMP_DIR = "tmp/directly"
if not os.path.exists(TEMP_DIR):
    os.makedirs(TEMP_DIR)


def get_max_ES_id():
    response = es.search(index=VIDEO_INDEX, 
        body={
            "size": 1,
            "sort": {
                "_id": {
                    "order": "desc"
                }
            },
            "_source": False
        }
    )
    largest_id = response['hits']['hits'][0]['_id'] if response['hits']['hits'] else None
    numeric_id = int(re.search(r'\d+', largest_id).group()) if largest_id is not None and re.search(r'\d+', largest_id) else 0

    return numeric_id

es_id = get_max_ES_id() + 1

"""
{ 
    "title": "LECTURE.3 Flutter 기반 모바일 앱 개발 Part.7", 
    "description": "이성원 교수님의 Dart, Flutter를 활용한 풀스택서비스프로그래밍 강좌 중 일부 입니다. LECTURE.3 Flutter 기반 모바일 앱 개발 Part.7 입니다.", 
    "category": "FullStack", 
    "owner": "hyejiyu", 
    "password": "abc123", 
    "is_open": true, 
    "created_at": "2024-05-31 12:00:00", 
    "likes": 1, 
    "views": 93, 
    "is_youtube": true, 
    "video_url": "https://www.youtube.com/watch?v=wtjsW0j6a78&list=PLz7S5PHCu4Ola4fWvmPJOIL_2vtb-Iduk&index=18", 
    "keywords": ["Dart", "Flutter", "풀스택", "프로그래밍"]
}
"""
def VIDEO_add_document(title: str,              # Required
                    description: str,     # Optional
                    owner: str,           # Optional
                    pw: str,              # Optional
                    is_open: bool,        # Required
                    category: str,        # Required
                    is_youtube: bool,     # Required
                    video_url: str,       # Required
                    keywords: list[str],
                    likes: int = 0,
                    views: int = 0): # Optional
    if title is None or category is None or video_url is None:
        return 400, "Invalid" # title, category, video_url **Required**
    
    global es_id
    # created_at, likes, views, keywords: list
    current_time = datetime.now()
    created_at = current_time.strftime("%Y-%m-%d %H:%M:%S")
    data = json.dumps({
        "title": title,
        "description": description,
        "category": category,
        "owner": owner,
        "password": pw,
        "is_open": is_open,
        "created_at": created_at,
        "likes": likes,
        "views": views,
        "is_youtube": is_youtube,
        "video_url": video_url,
        "keywords": keywords
    })
    try:
        res = es.index(index=VIDEO_INDEX, id=f"id_{es_id}", body=data)
        return 200, res
    except exceptions.ConnectionError as e:
        return 500, f"ConnectionError: {str(e)}"
    except exceptions.RequestError as e:
        return 400, f"RequestError: {str(e)}"
    except Exception as e:
        return 500, f"UnexpectedError: {str(e)}"
        

def VIDEO_SCRIPT_add_document(video_id: str, script: list[dict]):
    data = json.dumps({
        "video_id": video_id,
        "scripts": script
    })
    
    global es_id
    try:
        res = es.index(index=VIDEO_SCRIPT_INDEX, id=f"id_{es_id}", body=data)
        return 200, res
    except exceptions.ConnectionError as e:
        return 500, f"ConnectionError: {str(e)}"
    except exceptions.RequestError as e:
        return 400, f"RequestError: {str(e)}"
    except Exception as e:
        return 500, f"UnexpectedError: {str(e)}"
    
def increase_es_id():
    global es_id
    es_id += 1

def split_audio_and_generate_bytes(input_path, segment_length_ms=50000):
    # 오디오 파일 로드
    audio = AudioSegment.from_file(input_path)

    # 오디오를 segment_length_ms 간격으로 분할
    segments = [
        audio[i:i + segment_length_ms]
        for i in range(0, len(audio), segment_length_ms)
    ]

    # 각 오디오 조각을 바이너리 데이터로 변환
    audio_bytes_list = []
    for i, segment in enumerate(segments):
        audio_bytes_io = io.BytesIO()
        segment.export(audio_bytes_io, format="wav")
        audio_bytes = audio_bytes_io.getvalue()
        audio_bytes_list.append(audio_bytes)
        logger.info(f"Segment {i + 1} of {len(segments)} generated successfully.")

    return audio_bytes_list

# S3 파일 다운로드
def download_from_s3(bucket, key, local_path):
    s3_client.download_file(bucket, key, local_path)

# S3 파일 업로드
def upload_to_s3(file_path, bucket, key):
    s3_client.upload_file(file_path, bucket, key, ExtraArgs={"ContentType": "video/mp4"})

# 비디오에서 오디오 추출
def extract_audio(video_path, audio_path):
    command = ["ffmpeg", "-i", video_path, "-ac", "1", "-ar", "16000", audio_path]
    # print(" ".join(command))
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as e:
        logger.info(f"FFmpeg command failed: {e}")
        logger.info(f"FFmpeg stderr: {e.stderr.decode() if e.stderr else 'No stderr available'}")
        raise

# YouTube에서 오디오 다운로드
def download_youtube_audio(url, output_path):
    if os.path.exists(output_path):
        os.remove(output_path)
    
    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": output_path,  # 다운로드할 파일 이름
        "ffmpeg_location": "/opt/homebrew/bin/",  # FFmpeg 경로 지정
        "quiet": False,  # 디버깅 로그 활성화
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

# Google Speech-to-Text
def transcribe_with_timestamps(audio_path):
    client = speech.SpeechClient()

    audio_bytes_list = split_audio_and_generate_bytes(audio_path)
    result_data = []
    for i, audio_bytes in enumerate(audio_bytes_list):
        
        # 요청 구성
        audio = {"content": audio_bytes}
        config = {
            "encoding": "LINEAR16",
            "sample_rate_hertz": 16000,
            "language_code": "ko-KR",
            "enable_word_time_offsets": True
        }

        response = client.recognize(config=config, audio=audio)
        logger.info("Waiting for TRANSCRIBING AUDIO to text...")

        
        for result in response.results:
            for alternative in result.alternatives:
                # transcript = alternative.transcript
                # print(f"Transcript: {transcript}")
                
                words = [
                    {
                        "word": word_info.word,
                        "start_time": word_info.start_time.total_seconds(),
                        "end_time": word_info.end_time.total_seconds()
                    }
                    for word_info in alternative.words
                ]
                result_data.append(words)
                # print(f"word: {word_info.word}")
    
    # print(result_data)
    # sorted_data = sorted(unique_data.items())
    # result = [{"time": k, "text": v} for k, v in sorted_data]
    # print("\n\n\n\n\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@result@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@", result)
    return result_data

# Helper function: seconds to "MM:SS" format
def seconds_to_time_format(seconds):
    return str(timedelta(seconds=int(seconds)))[2:]

# n초 단위로 그룹화
def group_words_by_time(data, interval=10):
    plus_helper = 0.0
    current_start_time = plus_helper
    total_word = ""
    result = []
    for segment in data:
        for i, word in enumerate(segment):
            text = word['word']
            start_time = word['start_time'] + plus_helper
            # print(f"text: {text}, start_time: {start_time}, current_start_time: {current_start_time}")
            
            current_text = []

            if start_time >= current_start_time + interval:
                logger.info(f"[INTERVAL 10s CHECK]\n  ... start_time: {start_time}\tcurrent_start_time: {current_start_time}\ttotal_word: {total_word}")
                result.append({
                    "time": seconds_to_time_format(round(current_start_time)),
                    "text": total_word,
                })                
                current_start_time += interval
                total_word = ""
            
            if (i == len(segment) - 1):
                logger.info(f"[INTERVAL 50s CHECK]\n  ... start_time: {start_time}\tcurrent_start_time: {current_start_time}\ttotal_word: {total_word}")
                result.append({
                    "time": seconds_to_time_format(round(current_start_time)),
                    "text": total_word,
                })
                
                plus_helper += word['end_time']
                # print(f"{i}th plus_helper: {plus_helper}")
                current_start_time = plus_helper
                total_word = ""
                
            # 현재 word를 텍스트에 추가
            total_word += (text + " ")

        # 마지막 남은 텍스트 추가
        if current_text:
            result.append({
                "time": seconds_to_time_format(current_start_time),
                "text": total_word,
            })
    return result

# 최종 스크립트 저장
def save_script_to_file(segments, output_path):
    with open(output_path, "w") as file:
        for segment in segments:
            file.write(f"{segment}\n")
    logger.info(f"Script saved to {output_path}")

# script 병합
def merge_transcripts(audio_files):
    all_results = []

    for audio_file in audio_files:
        print(f"Processing {audio_file}...")
        results = transcribe_with_timestamps(audio_file)
        all_results.extend(results)

    return all_results

def convert_to_full_datetime(date_str):
    try:
        # 'yyyy-MM-dd' 형식의 날짜를 받아서 'yyyy-MM-dd HH:mm:ss' 형식으로 변환
        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
        return date_obj.strftime('%Y-%m-%d %H:%M:%S')
    except ValueError:
        return 'Invalid date format'

def increase_view(doc_id):
    try:
        response = es.update(
            index=VIDEO_INDEX,
            id=doc_id,
            body = {
                "script": {
                    "source": f"ctx._source.views += 1",
                    "lang": "painless"
                }
            }
        )
        logger.info(f"'View' Field in document {doc_id} incrementated successfully")
        return response
    except exceptions.NotFoundError:
        print(f"Document with ID {doc_id} not found in index {VIDEO_INDEX}.")
        return None
    except Exception as e:
        print(f"Error occurred: {e}")
        return None
        
        
        
def upload_video_elastic_save(data, scripts):
    if not data:
        return jsonify({ "error": "JSON body required." }), 400
    
    if data.get('is_youtube'):
        youtube_info = get_youtube_video_stats(data.get('video_url'))
        views = youtube_info['views']
        likes = youtube_info['likes']
    else:
        views, likes = 0, 0
    
    status_code, msg = VIDEO_add_document(data.get('title'), data.get('description'), data.get('owner'), data.get('password'),
                data.get('is_open'), data.get('category'), data.get('is_youtube'), data.get('video_url'), data.get('keywords'), likes, views)

    if status_code == 400:
        return jsonify({"error": "title, category, video_url Required"}), 400
    elif status_code == 200:
        status_code, script_msg = VIDEO_SCRIPT_add_document(msg['_id'], scripts)
        
        if status_code == 200:
            increase_es_id()
            return jsonify({
                "message": "Text Transcription and ES Saving Completed Successfully.",
                "VIDEO _id": msg['_id'],
                "VIDEO_SCRIPT _id": script_msg['_id'],
                "VIDEO result": msg['result'],
                "VIDEO_SCRIPT result": script_msg['result']
            }), 200
        elif status_code == 400:
            return jsonify({"error": "Invalid script data. Check required fields."}), 400
        elif status_code == 500:
            return jsonify({"error": f"Failed to save script data to Elasticsearch: {script_msg}"}), 500
        else:
            return jsonify({"error": "Unexpected status code from VIDEO_SCRIPT_add_document."}), 500
    else:
        return jsonify({"error": str(msg)}), 500

def get_VIDEO_document(doc_id):
    try:
        res = es.get(index=VIDEO_INDEX, id=doc_id)
        return res["_source"]
    except exceptions.NotFoundError:
        return 404 # Document not found

def get_VIDEO_SCRIPT_document(doc_id):
    try:
        res = es.get(index=VIDEO_SCRIPT_INDEX, id=doc_id)
        return res["_source"]
    except exceptions.NotFoundError:
        return 404 # Document not found


def get_youtube_video_stats(video_url):
    # Extract the video ID from the URL
    if "v=" in video_url:
        video_id = video_url.split("v=")[1].split("&")[0]
    else:
        raise ValueError("Invalid YouTube URL")

    # Build the YouTube service
    youtube = build(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION, developerKey=API_KEY)

    # Call the YouTube Data API to get video details
    request = youtube.videos().list(
        part="statistics",
        id=video_id
    )
    response = request.execute()

    # Parse the response for statistics
    if "items" in response and len(response["items"]) > 0:
        stats = response["items"][0]["statistics"]
        views = stats.get("viewCount", "N/A")
        likes = stats.get("likeCount", "N/A")
        return {
            "views": int(views) if views != "N/A" else 0,
            "likes": int(likes) if likes != "N/A" else 0,
        }
    else:
        raise ValueError("Video not found or inaccessible")


################################################################################

# MP4 파일 스트리밍 요청
@app.route("/video", methods=["GET"])
def get_video():
    doc_id = request.args.get("doc_id")
    video_msg = get_VIDEO_document(doc_id)
    script_msg = get_VIDEO_SCRIPT_document(doc_id)
    # 조회수 올리기
    if video_msg == 404:
        return jsonify({"error": "Document not found"})
    elif isinstance(video_msg, dict) and video_msg:
        inc_view_res = increase_view(doc_id)
        # youtube 영상이 아니면 S3 객체에 대해 presigned url 생성해서 리턴
        if (not video_msg['is_youtube']):
            try:
                url = s3_client.generate_presigned_url(
                    "get_object",
                    Params={"Bucket": S3_BUCKET_NAME, "Key": video_msg['video_url']},
                    ExpiresIn=3600,
                )
                return jsonify(
                    {
                        "is_youtube": 0,
                        "title": video_msg['title'],
                        "description": video_msg['description'],
                        "created_at": video_msg['created_at'],
                        "views": video_msg['views'],
                        "likes": video_msg['likes'],
                        "presignedUrl": url,
                        "scripts": script_msg['scripts']
                    }), 200
            except Exception as e:
                return jsonify({"error": str(e)}), 500
        # youtube 영상이면 클라이언트 쪽에서 Youtube API 사용하도록
        else:
            return jsonify(
                {
                    "is_youtube": 1,
                    "title": video_msg['title'],
                    "description": video_msg['description'],
                    "created_at": video_msg['created_at'],
                    "views": video_msg['views'],
                    "likes": video_msg['likes'],
                    "scripts": script_msg['scripts']
                }), 200
    return jsonify({ "error": "Unexpected document format"}), 500
    
# 직접 업로드 처리
@app.route("/upload/file", methods=["POST"])
def upload_file():
    if "video" not in request.files:
        return jsonify({"error": "Video File Required."}), 400
    # if request.content_type.startswith('multipart/form-data'):
    #     return jsonify({"error": "Content-Type must be multipart/form-data."}), 415

    file = request.files["video"]
    filename = secure_filename(file.filename)
    local_path = os.path.join(TEMP_DIR, filename)
    unique_id = uuid.uuid4().hex
    video_id = filename
    
    try:
        file.save(local_path)
        print("Uploading file to S3...")
        
        # S3에 업로드
        logger.info("Uploading file to S3...")
        upload_to_s3(local_path, S3_BUCKET_NAME, filename)

        # 오디오 추출
        logger.info("Extracting audio from video...")
        audio_path = f"{local_path}.wav"
        text_path = os.path.abspath(os.path.join("tmp/directly", f"{video_id[:-4]}_{unique_id}.txt"))
        extract_audio(local_path, audio_path)

        # 텍스트 변환
        logger.info("Transcribing audio to text...")
        segments = transcribe_with_timestamps(audio_path)
        
        # 텍스트를 약 10초 단위로 분할
        grouped_segments = group_words_by_time(segments, interval=10)
        logger.info("Text transcription and segmentation completed.")
        
        # 최종 스크립트 저장
        # save_script_to_file(grouped_segments, text_path)
        
        if "data" not in request.form:
            return jsonify({"error": "JSON data is required."}), 400
        try:
            json_data = json.loads(request.form['data'])
        except json.JSONDecodeError:
            return jsonify({ "error": "Invalid JSON format" }), 400
        return upload_video_elastic_save(json_data, grouped_segments)

    except FileNotFoundError as e:
        logger.error(f"File not found: {e}")
        return jsonify({"error": "File not found."}), 404
    except KeyError as e:
        logger.error(f"Missing required key: {e}")
        return jsonify({"error": f"Missing required field: {str(e)}"}), 400
    except exceptions.ConnectionError as e:
        logger.error(f"Missing Elasticsearch Connection: {e}")
        return jsonify({ "error": f"ConnectionError: {str(e)}" }), 500
    except exceptions.RequestError as e:
        logger.error(f"Elasticsearch Request: {e}")
        return jsonify({ "error": f"RequestError: {str(e)}" }), 400 
    except Exception as e:
        logger.exception("An unexpected error occurred.")
        return jsonify({"error": "An unexpected error occurred.", "details": str(e)}), 500
    finally:
        # 파일 삭제 시도
        try:
            if os.path.exists(local_path):
                os.remove(local_path)
            if os.path.exists(audio_path):
                os.remove(audio_path)
        except Exception as e:
            logger.warning(f"Failed to clean up temporary files: {e}")

# YouTube 업로드 처리
@app.route("/upload/youtube", methods=["POST"])
def upload_youtube():
    ydl_opts = {
        "quiet": False,  # 로그 활성화
    }
    if "data" not in request.form:
        return jsonify({"error": "JSON data is required."}), 400
    
    try:
        json_data = json.loads(request.form['data'])
    except json.JSONDecodeError:
        return jsonify({"error": "Invalid JSON format."}), 400    
    
    video_url = json_data.get("video_url")
    
    # if request.content_type.startswith('multipart/form-data'):
    #     return jsonify({"error": "Content-Type must be multipart/form-data."}), 415

    if not video_url:
        return jsonify({"error": "Invalid Youtube URL."}), 400

    audio_path = None
    wav_path = None

    try:
        logger.info("Extracting video info...")
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            video_id = ydl.extract_info(video_url, download=False)['id']
                    
        unique_id = uuid.uuid4().hex
        audio_path = os.path.abspath(os.path.join("tmp/youtube", f"{video_id}_{unique_id}.mp3"))
        wav_path = os.path.abspath(os.path.join("tmp/youtube", f"{video_id}_{unique_id}.wav"))
        text_path = os.path.abspath(os.path.join("tmp/youtube", f"{video_id}_{unique_id}.txt"))
        # segment_path = os.path.abspath(os.path.join("tmp", f"{video_id}_{unique_id}_"))
        
        # if os.path.exists(audio_path):
        #     print(f"Existing audio file found: {audio_path}. Deleting...")
        #     os.remove(audio_path)

        # YouTube에서 오디오 다운로드
        logger.info("Downloading video from Youtube...")
        download_youtube_audio(video_url, audio_path)
        time.sleep(3)
        
        # if os.path.exists(wav_path):
        #     print(f"Existing WAV file found: {wav_path}. Deleting...")
        #     os.remove(wav_path)

        # 오디오 추출
        logger.info("Extracting audio from video...")
        extract_audio(audio_path, wav_path)

        logger.info("Transcribing audio to text...")
        segments = transcribe_with_timestamps(wav_path)
        # with open(text_path, "w") as file:
        #     for segment in segments:
        #         for word in segment:
        #             print(word)
        #             file.write(f"{word}\n")        
        
        # 텍스트를 약 10초 단위로 분할
        grouped_segments = group_words_by_time(segments, interval=10)
        logger.info("Text transcription and segmentation completed.")

        # 최종 스크립트 저장
        # save_script_to_file(grouped_segments, text_path)
        
        
        return upload_video_elastic_save(json_data, grouped_segments)
        

    except FileNotFoundError as e:
        logger.error(f"File not found: {e}")
        return jsonify({"error": "File not found."}), 404
    except KeyError as e:
        logger.error(f"Missing required key: {e}")
        return jsonify({"error": f"Missing required field: {str(e)}"}), 400
    except exceptions.ConnectionError as e:
        logger.error(f"Missing Elasticsearch Connection: {e}")
        return jsonify({ "error": f"ConnectionError: {str(e)}" }), 500
    except exceptions.RequestError as e:
        logger.error(f"Elasticsearch Request: {e}")
        return jsonify({ "error": f"RequestError: {str(e)}" }), 400 
    except Exception as e:
        logger.exception("An unexpected error occurred.")
        return jsonify({"error": "An unexpected error occurred.", "details": str(e)}), 500

    finally:
        try:
            if audio_path and os.path.exists(audio_path):
                os.remove(audio_path)
            if wav_path and os.path.exists(wav_path):
                os.remove(wav_path)
        except Exception as e:
            logger.warning(f"Failed to clean up temporary files: {e}")

def match_VIDEO_keywords(word):
    body = {
        "query": {
            "multi_match": {
                "query": word,
                "fields": ["title^3", "description", "category", "keywords^2"],
                "type": "best_fields",
                "fuzziness": "AUTO",
                "minimum_should_match": "1"
            }
        },
        "size": 10
    }
    try:
        response = es.search(index=VIDEO_INDEX, body=body)
        results = [
            {
                "id": hit["_id"],
                "score": hit["_score"],
                # "source": hit["_source"]
            }
            for hit in response['hits']['hits']
        ]
        return results
    except Exception as e:
        return []


def match_VIDEO_SCRIPT_keywords(word):
    body = {
        "query": {
            "nested": {
                "path": "scripts",
                "query": {
                    "match": {
                        "scripts.text": {
                            "query": word,
                            "fuzziness": "AUTO"
                        }
                    }
                }
            }
        }
    }
    try:
        response = es.search(index=VIDEO_SCRIPT_INDEX, body=body)
        results = [
            {
                "id": hit["_id"],
                "score": hit["_score"],
                # "source": hit["_source"]
            }
            for hit in response['hits']['hits']
        ]
        # print(f"word: {word}, results: {results}")
        return results
    except Exception as e:
        return []

@app.route('/search', methods=['GET'])
def search():
    """ 
        curl -X GET "http://localhost:3000/search?query=news%20forest"  
    """
    query = request.args.get('query')
    words = query.split(" ")
    
    all_results = []
    for word in words:
        video_res = match_VIDEO_keywords(word)
        video_script_res = match_VIDEO_SCRIPT_keywords(word)
        
        # if not video_res and not video_script_res:
        #     return jsonify({ "message": "No results found" }), 404
        all_results += ( video_res + video_script_res )
        # print(f"word: {word}\n  video_res: {video_res}\n  video_script_res: {video_script_res}")
        
    if not all_results:
        return jsonify({ "message": "No results found" }), 404
    
    unique_results = {result['id']: result for result in all_results}.values()
    print(unique_results)
    
    info_result = []
    for single_res in unique_results:
        msg = get_VIDEO_document(single_res['id'])
        info_result += [
            {
                "id": single_res['id'],
                "score": single_res['score'],
                "title": msg['title'],
                "description": msg['description'],
                "category": msg['category'],
                "keywords": msg['keywords'],
                "created_at": msg['created_at'],
                "views": msg['views'],
                "likes": msg['likes']
            }
        ]
    
    return jsonify(info_result), 200

@app.route('/search/detail', methods=['GET'])
def search_detail():
    """ 
        curl -X GET "http://localhost:3000/search/detail?category=fullstack&keywords=dart,flutter,javascript&..."  
        - category  : fullstack
        - keywords  : dart,flutter,javascript
        - created_at: 2024-01-01,2024-12-31
        - likes     : 0
        - views     : 0
        - is_script : 1, XXX
        - query     : flutter XXX
    """
    category = request.args.get('category')
    keywords = request.args.get('keywords', '')
    if keywords:
        keywords_list = keywords.split(',')
    else:
        keywords_list = []
    
    created_at = request.args.get('created_at')
    if created_at:
        try:
            created_at_list = created_at.split(',')
            created_at_start = convert_to_full_datetime(created_at_list[0])
            created_at_end = convert_to_full_datetime(created_at_list[1])
            
        except ValueError:
            return 'Invalid date format'
    else:
        created_at_start = convert_to_full_datetime('2024-01-01')
        created_at_end = convert_to_full_datetime(str(datetime.now())[:10])
    
    likes = int(request.args.get('likes', 0))
    views = int(request.args.get('views', 0))
    # is_script = request.args.get('is_script', 1)
    # query = request.args.get('query', '')
    
    # Elasticsearch 쿼리 빌드
    must_queries = []
    
    # category는 완전히 일치하는 데이터만
    if category:
        must_queries.append({
            'term': {'category.keyword': category}  # exact match using keyword field
        })
    
    # keywords는 모든 값들을 OR 연산해서
    if keywords:
        must_queries.append({
            'bool': {
                'should': [{'match': {'keywords': keyword}} for keyword in keywords_list],
                'minimum_should_match': 1 
            }
        })
    
    # created_at은 날짜 범위 조건
    if created_at_start and created_at_end:
        must_queries.append({
            'range': {
                'created_at': {
                    'gte': created_at_start,
                    'lte': created_at_end,
                    'format': 'yyyy-MM-dd'  # 날짜 형식 지정
                }
            }
        })

    if likes > 0:
        must_queries.append({
            'range': {'likes': {'gte': likes}}
        })
    if views > 0:
        must_queries.append({
            'range': {'views': {'gte': views}}
        })

    # 최종 Elasticsearch 쿼리 구성
    search_body = {
        'query': {
            'bool': {
                'must': must_queries
            }
        }
    }
    
    print(f"search_body: \n{search_body}")
    
    try:
        response = es.search(index=VIDEO_INDEX, body=search_body)
    except exceptions.ConnectionError:
        return jsonify({'error': 'Failed to connect to Elasticsearch'}), 500
    except exceptions.RequestError as e:
        return jsonify({'error': f'Elasticsearch query error: {str(e)}'}), 400

    all_results = []
    if response['hits']['hits']:
        for doc in response['hits']['hits']:
            all_results.append({
                "id": doc['_id'],
                "score": doc['_score'],
                "title": doc['_source']['title'],
                "description": doc['_source']['description'],
                "category": doc['_source']['category'],
                "keywords": doc['_source']['keywords'],
                "created_at": doc['_source']['created_at'],
                "views": doc['_source']['views'],
                "likes": doc['_source']['likes']
            })
        return jsonify(all_results)
    else:
        return jsonify({'message': 'No results found'}), 404

@app.route("/get_all", methods=['GET'])
def get_all_video():
    body = {
        'query': {
            'match_all': {}
        },
        'size': 15
    }
    
    try:
        response = es.search(index=VIDEO_INDEX, body=body)
    except exceptions.ConnectionError:
        return jsonify({'error': 'Failed to connect to Elasticsearch'}), 500
    except exceptions.RequestError as e:
        return jsonify({'error': f'Elasticsearch query error: {str(e)}'}), 400
    
    all_results = []
    if response['hits']['hits']:
        for doc in response['hits']['hits']:
            all_results.append({
                "id": doc['_id'],
                "title": doc['_source']['title'],
                "description": doc['_source']['description'],
                "category": doc['_source']['category'],
                "keywords": doc['_source']['keywords'],
                "created_at": doc['_source']['created_at'],
                "views": doc['_source']['views'],
                "likes": doc['_source']['likes']
            })
        return jsonify(all_results)
    else:
        return jsonify({'message': 'No results found'}), 404


# 서버 실행
if __name__ == "__main__":
    app.run(port=PORT)