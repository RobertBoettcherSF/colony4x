#!/usr/bin/env python3
"""Colony4X launcher: serves this folder on localhost, opens the browser, and
writes the live feedback log the game POSTs after every action.
Usage:  python3 play.py [--port 8642] [--no-browser]"""
import http.server, json, os, re, sys, threading, webbrowser, time
HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[sys.argv.index('--port') + 1]) if '--port' in sys.argv else 8642
LOCK = threading.Lock()

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=HERE, **k)
    def log_message(self, *a): pass
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store'); super().end_headers()
    def do_GET(self):
        if self.path.startswith('/api/ping'):
            return self._json({'ok': True, 'live': True, 'dir': HERE})
        return super().do_GET()
    def do_POST(self):
        if not self.path.startswith('/api/log'):
            return self._json({'ok': False}, 404)
        n = int(self.headers.get('Content-Length', 0))
        if n > 50_000_000: return self._json({'ok': False, 'err': 'too big'}, 413)
        body = self.rfile.read(n)
        try: json.loads(body)
        except Exception as e: return self._json({'ok': False, 'err': str(e)}, 400)
        sess = re.sub(r'[^0-9A-Za-z_-]', '', self.headers.get('X-Session', ''))[:40] or time.strftime('%Y%m%d-%H%M%S')
        with LOCK:
            for name in ('col-feedback.json', 'col-feedback-%s.json' % sess):
                p = os.path.join(HERE, name); tmp = p + '.tmp'
                with open(tmp, 'wb') as f: f.write(body)
                os.replace(tmp, p)
        return self._json({'ok': True, 'file': 'col-feedback.json', 'session': 'col-feedback-%s.json' % sess})
    def _json(self, o, code=200):
        b = json.dumps(o).encode(); self.send_response(code)
        self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(b)))
        self.end_headers(); self.wfile.write(b)

def main():
    srv = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H)
    url = 'http://127.0.0.1:%d/index.html' % PORT
    print('Colony4X running at', url)
    print('Live feedback log:', os.path.join(HERE, 'col-feedback.json'), '(+ one col-feedback-<session>.json per session)')
    print('Press Ctrl+C to stop.')
    if '--no-browser' not in sys.argv:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try: srv.serve_forever()
    except KeyboardInterrupt: print('\nStopped.')

if __name__ == '__main__': main()
