#!/usr/bin/python3
"""Deploy the unified radar with fresh QML URLs, without restarting the shell."""
import hashlib
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

def deploy_ui(source, destination):
    """Give each QML generation a fresh URL in the running shell's cache."""
    files = sorted([*source.glob('*.qml'), *source.glob('*.js')])
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.name.encode() + b'\0' + path.read_bytes())
    generation = digest.hexdigest()[:20]
    runtime = destination / '.runtime' / generation
    runtime.parent.mkdir(parents=True, exist_ok=True)
    if not runtime.exists():
        temporary = Path(tempfile.mkdtemp(prefix='.staging-', dir=runtime.parent))
        try:
            for path in files:
                shutil.copy2(path, temporary / path.name)
            temporary.rename(runtime)
        finally:
            if temporary.exists():
                shutil.rmtree(temporary)
    manifest = json.loads((source / 'manifest.json').read_text())
    manifest['entryPoints']['barWidget'] = '.runtime/' + generation + '/Panel.qml'
    with tempfile.NamedTemporaryFile('w', prefix='.manifest-', dir=destination, delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    try:
        temporary.chmod(0o644)
        temporary.replace(destination / 'manifest.json')
    finally:
        temporary.unlink(missing_ok=True)
    return generation


def install():
    source = Path(__file__).resolve().parent
    destination = Path.home() / '.config/omarchy/plugins/lol.routers'
    subprocess.run(['omarchy-plugin-validate', str(source)], check=True)
    generation = deploy_ui(source, destination)
    shutil.copy2(source / 'collect.py', destination / 'collect.py')
    units = Path.home() / '.config/systemd/user'
    units.mkdir(parents=True, exist_ok=True)
    (units / 'omarchy-routers.service').write_text(
        '[Unit]\nDescription=9Router radar: usage and accounts\n\n'
        '[Service]\nType=oneshot\nExecStart=/usr/bin/python3 ' + json.dumps(str(destination / 'collect.py')) + '\n'
        'TimeoutStartSec=480\nUMask=0077\nNice=10\n')
    (units / 'omarchy-routers.timer').write_text(
        '[Unit]\nDescription=Refresh 9Router radar\n\n'
        '[Timer]\nOnStartupSec=15\nOnUnitInactiveSec=300\nAccuracySec=5\n\n'
        '[Install]\nWantedBy=timers.target\n')
    subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
    subprocess.run(['systemctl', '--user', 'enable', '--now', 'omarchy-routers.timer'], check=True)
    subprocess.run(['omarchy-shell', 'shell', 'rescanPlugins'], check=True)
    for _ in range(50):
        plugins = json.loads(subprocess.run(['omarchy-plugin-list', '--json'], check=True, capture_output=True, text=True).stdout)
        if any(p.get('id') == 'lol.routers' for p in plugins):
            break
        time.sleep(.1)
    if not any(p.get('id') == 'lol.routers' and p.get('enabled') for p in plugins):
        subprocess.run(['omarchy-plugin-enable', 'lol.routers', '--after', 'omarchy.bluetooth'], check=True)
    subprocess.run(['systemctl', '--user', 'start', '--no-block', 'omarchy-routers.service'], check=True)
    print('9Router instalado: ' + generation)


if __name__ == '__main__':
    install()
