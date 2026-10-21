#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Auto-publisher script for Telegram Channel: @antigravity_proxy
Sends the release installer ProksiFi_v2.0_Setup.exe with a minimal description.
"""

import os
import sys
import requests

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "YOUR_BOT_TOKEN_HERE")
CHAT_ID = "@antigravity_proxy"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
RELEASE_FILE = os.path.join(PROJECT_ROOT, "release", "ProksiFi_v2.0_Setup.exe")

CAPTION = (
    "<b>🚀 ProksiFi v2.0 — Официальный релиз</b>\n\n"
    "Автономный 1-клик сервис обхода блокировок для Windows:\n"
    "• Google Gemini, AI Studio и NotebookLM\n"
    "• Среда разработки Google Antigravity IDE\n"
    "• Telegram (десктоп-клиент, звонки и медиа)\n"
    "• YouTube и сервисы Google\n\n"
    "<b>Инструкция:</b> скачайте файл ➔ запустите от имени администратора ➔ нажмите «Установить»."
)

def publish():
    if not os.path.exists(RELEASE_FILE):
        print(f"[ERROR] Release file not found: {RELEASE_FILE}")
        sys.exit(1)

    file_size_mb = os.path.getsize(RELEASE_FILE) / (1024 * 1024)
    print(f"[*] Preparing to upload: {os.path.basename(RELEASE_FILE)} ({file_size_mb:.2f} MB)")
    print(f"[*] Destination channel: {CHAT_ID}")

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"

    try:
        with open(RELEASE_FILE, "rb") as f:
            files = {"document": (os.path.basename(RELEASE_FILE), f)}
            data = {
                "chat_id": CHAT_ID,
                "caption": CAPTION,
                "parse_mode": "HTML"
            }

            print("[*] Uploading document to Telegram... (this may take a few seconds)")
            resp = requests.post(url, data=data, files=files, timeout=120)

            result = resp.json()
            if result.get("ok"):
                message_id = result["result"]["message_id"]
                print(f"[OK] Published successfully to {CHAT_ID}! Message ID: {message_id}")
                print(f"[OK] Post URL: https://t.me/antigravity_proxy/{message_id}")
                return True
            else:
                print(f"[FAIL] Telegram API Error: {result}")
                return False

    except Exception as e:
        print(f"[ERROR] Failed to publish: {e}")
        return False

if __name__ == "__main__":
    success = publish()
    sys.exit(0 if success else 1)

