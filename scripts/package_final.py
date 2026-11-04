"""Assemble source, APK and evidence without copying credentials or caches."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from shutil import copy2
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {'.git', '.dart_tool', '.gradle', '.cxx', '.idea', '.vscode',
             '.venv', '.postgres', '__pycache__', '.pytest_cache', 'build',
             'ephemeral', 'Pods', '.symlinks', 'node_modules'}
SKIP_FILES = {'.env', 'local.properties', 'key.properties',
              'Generated.xcconfig', 'flutter_export_environment.sh',
              '.flutter-plugins-dependencies', '.DS_Store'}
SOURCE_DIRS = {'lib', 'test', 'integration_test', 'android', 'ios', 'linux',
               'macos', 'windows', 'web', 'backend', 'docs', 'scripts'}
SOURCE_FILES = {'README.md', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml',
                'compose.yaml', '.gitignore', '.metadata', 'LICENSE'}


def safe_source(path):
    rel = path.relative_to(ROOT)
    return (not path.is_symlink() and not (set(rel.parts) & SKIP_DIRS)
            and path.name not in SKIP_FILES
            and path.suffix.lower() not in {'.log', '.pyc', '.jks', '.keystore'}
            and not path.name.endswith('.iml'))


def assemble(apk):
    target = ROOT / 'delivery' / 'LibFlow_Final_2026-11-04'
    target.mkdir(parents=True, exist_ok=True)
    source = target / 'source'
    files = []
    for directory in sorted(SOURCE_DIRS):
        for current, directories, names in os.walk(ROOT / directory, followlinks=False):
            directories[:] = [name for name in directories if name not in SKIP_DIRS
                              and not (Path(current) / name).is_symlink()]
            files.extend(Path(current) / name for name in names
                         if safe_source(Path(current) / name))
    files.extend(ROOT / name for name in SOURCE_FILES if (ROOT / name).is_file())
    for path in files:
        destination = source / path.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        copy2(path, destination)
    with ZipFile(target / 'LibFlow_source.zip', 'w', ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob('*')):
            if path.is_file():
                archive.write(path, 'LibFlow/' + path.relative_to(source).as_posix())
    apk_target = target / 'apk' / 'LibFlow-1.0.0.apk'
    apk_target.parent.mkdir(exist_ok=True)
    copy2(apk, apk_target)
    for path in (ROOT / 'docs' / 'final').rglob('*'):
        if path.is_file():
            destination = target / 'documents' / path.relative_to(ROOT / 'docs' / 'final')
            destination.parent.mkdir(parents=True, exist_ok=True)
            copy2(path, destination)
    evidence = target / 'evidence'
    evidence.mkdir(exist_ok=True)
    for name in ['analyze.log', 'flutter-tests.jsonl', 'backend-tests.log',
                 'backend-junit.xml', 'android-integration-final.log',
                 'apk-build.log', 'device-launch.log', 'environment.log',
                 'test-summary.json', 'android-launch.png', 'apk-info.json',
                 'release-network-attempt.log']:
        path = ROOT / 'build' / 'final-evidence' / name
        if path.exists():
            copy2(path, evidence / name)
    copy2(ROOT / 'docs' / 'final' / 'DELIVERY_README.md', target / 'README.md')
    entries = []
    for path in sorted(target.rglob('*')):
        if path.is_file() and path.name != 'MANIFEST.json':
            entries.append({'path': path.relative_to(target).as_posix(),
                            'bytes': path.stat().st_size,
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (target / 'MANIFEST.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding='utf-8')
    assert not any(Path(item['path']).name in SKIP_FILES for item in entries)
    with ZipFile(target / 'LibFlow_source.zip') as archive:
        assert archive.testzip() is None
    print(json.dumps({'folder': str(target), 'source_files': len(files),
                      'manifest_files': len(entries), 'apk_bytes': apk_target.stat().st_size}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path, default=ROOT / 'build/app/outputs/flutter-apk/app-debug.apk')
    arguments = parser.parse_args()
    if not arguments.apk.is_file():
        parser.error('Build the APK first or pass --apk PATH')
    assemble(arguments.apk)
