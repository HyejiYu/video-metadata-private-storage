from googleapiclient.discovery import build
from dotenv import load_dotenv
import os

load_dotenv()


# Your YouTube API key
API_KEY = os.getenv("YOUTUBE_API_KEY")
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'

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
            "views": int(views) if views != "N/A" else None,
            "likes": int(likes) if likes != "N/A" else None,
        }
    else:
        raise ValueError("Video not found or inaccessible")

# Example usage
video_url = "https://www.youtube.com/watch?v=kcNT1vM9NfM"
try:
    stats = get_youtube_video_stats(video_url)
    print(f"Views: {stats['views']}, Likes: {stats['likes']}")
except Exception as e:
    print(f"Error: {e}")