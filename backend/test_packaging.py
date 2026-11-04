"""Check exactly the Python package layout copied into the Docker image."""
import os
import subprocess
import sys
from pathlib import Path
from shutil import copy2


def test_docker_package_import_in_clean_directory(tmp_path):
    root = Path(__file__).parent
    package = tmp_path / 'backend'
    package.mkdir()
    for name in ['__init__.py', 'app.py', 'realtime.py', 'seed_books.json']:
        copy2(root / name, package / name)
    environment = dict(os.environ, PYTHONPATH=str(tmp_path))
    result = subprocess.run(
        [sys.executable, '-c',
         "from backend.app import app; "
         "assert any(r.path == '/ws/catalogue' for r in app.routes); print('package import OK')"],
        cwd=tmp_path, env=environment, capture_output=True, text=True, timeout=20,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == 'package import OK'
    dockerfile = (root / 'Dockerfile').read_text()
    assert 'COPY __init__.py app.py realtime.py seed_books.json ./backend/' in dockerfile
    assert '"backend.app:app"' in dockerfile
