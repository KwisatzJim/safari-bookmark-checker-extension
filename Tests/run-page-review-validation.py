from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os, subprocess, threading, time

project = Path(__file__).resolve().parents[1]
class Fixture(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        status = 200
        content_type = 'text/html; charset=utf-8'
        if self.path == '/redirect':
            self.send_response(302)
            self.send_header('Location', '/article')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        elif self.path == '/article':
            body = b'<head><title>CS50 &amp; C</title><script>hidden</script></head><body><nav>hidden navigation</nav><h1>C programming</h1><p>Learn loops and arrays.</p></body>'
        elif self.path == '/login':
            status = 404
            body = b'<title>Sign in</title><h1>Sign in to access your CS50 course</h1><p>This page requires an enrolled student session.</p>'
        elif self.path == '/large':
            body = b'<title>Large page</title><p>' + b'content ' * 100000
        elif self.path == '/file':
            content_type = 'application/pdf'
            body = b'%PDF-fixture'
        elif self.path == '/empty':
            body = b'<script>loadPage()</script>'
        elif self.path == '/slow':
            time.sleep(1)
            body = b'<p>Late result</p>'
        else:
            status, body = 404, b'<p>Page not found</p>'
        try:
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
    executable = project / 'Build/PageReviewValidation'
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(project/'Build/ModuleCache'),
                    '-external-plugin-path', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server',
                    '-parse-as-library', str(project/'Sources/PageContent.swift'),
                    str(project/'Sources/AIPageReviewer.swift'), str(project/'Tests/PageReviewValidation.swift'),
                    '-o', str(executable)], env=env, check=True)
    subprocess.run([str(executable), f'http://127.0.0.1:{server.server_port}', '--model'], check=True)
finally:
    server.shutdown()
    server.server_close()
