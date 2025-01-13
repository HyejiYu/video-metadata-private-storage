import json
import subprocess

# JSON 파일 경로
json_file = "video_bulk_single_line.json"

def send_requests_from_json(json_file):
    """
    JSON 파일에서 각 객체를 읽어와 curl 요청을 전송합니다.
    """
    try:
        # JSON 파일 읽기
        with open(json_file, "r", encoding="utf-8") as file:
            data = json.load(file)  # [{}] 형태의 리스트로 읽음

        # JSON 배열의 각 객체를 순회하며 curl 요청 전송
        for index, item in enumerate(data):
            print(f"Sending request for item {index + 1}...")
            response = subprocess.run(
                [
                    "curl", "-X", "POST", "http://localhost:3000/upload/youtube",
                    "-H", "Content-Type: multipart/form-data",
                    "-F", f"data={json.dumps(item, ensure_ascii=False)}"
                ],
                capture_output=True, text=True
            )
            # 결과 출력
            if response.returncode == 0:
                print(f"Response: {response.stdout.strip()}")
            else:
                print(f"Error sending item {index + 1}: {response.stderr.strip()}")

    except FileNotFoundError:
        print(f"Error: {json_file} 파일을 찾을 수 없습니다.")
    except json.JSONDecodeError as e:
        print(f"Error: JSON 파일 형식이 잘못되었습니다. {e}")
    except Exception as e:
        print(f"Error: 요청 중 문제가 발생했습니다. {e}")

# 실행
if __name__ == "__main__":
    send_requests_from_json(json_file)
