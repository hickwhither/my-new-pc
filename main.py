import http.server
import socketserver
import os

PORT = 8000

# Lấy thư mục chứa file main.py
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

os.chdir(BASE_DIR)  # đảm bảo serve đúng folder chứa main.py

Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving at http://localhost:{PORT}")
    httpd.serve_forever()
