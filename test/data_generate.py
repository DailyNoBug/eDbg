import json
import random
import socket
import time
from datetime import datetime, timezone

UDP_HOST = "127.0.0.1"  # adjust if the app runs on another machine
UDP_PORT = 54431

def make_packet(seq: int) -> dict:
    now = datetime.now(tz=timezone.utc)
    return {
        "type": "demo",
        "timestamp": now.timestamp(),  # seconds; app converts automatically
        "data": {
            "temperature": 20 + random.uniform(-1, 1),
            "pressure": 101.3 + random.uniform(-0.5, 0.5),
            "seq": seq,
        },
    }

def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    seq = 0
    try:
        while True:
            packet = make_packet(seq)
            payload = json.dumps(packet).encode("utf-8")
            sock.sendto(payload, (UDP_HOST, UDP_PORT))
            print(f"Sent #{seq}: {payload}")
            seq += 1
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopped by user.")
    finally:
        sock.close()

if __name__ == "__main__":
    main()
