"""Publish only hash-verified committed ADS assets; preserve the legacy latest release."""
import hashlib
import json
import os
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent
manifest = json.loads((root / 'release.json').read_text(encoding='utf-8'))
tag = manifest['tag']
if tag != 'ADS-v1.0.0' or manifest['version'] != '1.0.0':
    raise SystemExit('Unexpected product version; update the reviewed release publisher.')
assets = []
names = [entry['name'] for entry in manifest['assets']]
if not names or len(set(names)) != len(names):
    raise SystemExit('The local release asset list is empty or contains duplicates.')
for entry in manifest['assets']:
    name = entry['name']
    if (pathlib.PurePosixPath(name).name != name
            or pathlib.PureWindowsPath(name).name != name
            or 'AtmosKeepAlive' in name):
        raise SystemExit('Unexpected asset name.')
    if not isinstance(entry['size'], int) or entry['size'] < 1 or not re.fullmatch(r'[a-f0-9]{64}', entry['sha256']):
        raise SystemExit('Invalid asset hash or size.')
    file = root / 'assets' / name
    if file.is_symlink() or not file.is_file():
        raise SystemExit('Missing or unsafe release asset.')
    raw = file.read_bytes()
    if len(raw) != entry['size'] or hashlib.sha256(raw).hexdigest() != entry['sha256']:
        raise SystemExit('Release asset does not match its committed manifest.')
    assets.append(str(file))
notes = root / 'RELEASE-NOTES.md'
endpoint = 'repos/' + os.environ['GH_REPO'] + '/releases/tags/' + tag
def api_get(path):
    response = subprocess.run(['gh', 'api', path], capture_output=True, text=True)
    if response.returncode == 0:
        return json.loads(response.stdout)
    if '(HTTP 404)' in response.stderr:
        return None
    raise SystemExit('GitHub could not be read; refusing to publish after an API failure.')

def verify_tag(require_exists=False):
    reference = api_get('repos/' + os.environ['GH_REPO'] + '/git/ref/tags/' + tag)
    if reference is None:
        if require_exists:
            raise SystemExit('The published release tag could not be verified.')
        return
    target = reference['object']
    for _ in range(5):
        if target['type'] == 'commit':
            break
        if target['type'] != 'tag':
            raise SystemExit('The existing release tag does not identify a commit.')
        target = api_get('repos/' + os.environ['GH_REPO'] + '/git/tags/' + target['sha'])['object']
    if target['type'] != 'commit' or target['sha'] != os.environ['COMMIT_SHA']:
        raise SystemExit('The release tag already points to a different commit.')

def verify_release(actual):
    if actual['draft'] or actual['prerelease'] or actual['tag_name'] != tag:
        raise SystemExit('The release is not a published final release for this tag.')
    expected = {entry['name']: entry for entry in manifest['assets']}
    remote = {entry['name']: entry for entry in actual['assets']}
    if len(remote) != len(actual['assets']) or set(remote) != set(expected):
        raise SystemExit('The release asset list differs; refusing to overwrite it.')
    for name, entry in expected.items():
        if (remote[name].get('digest') != 'sha256:' + entry['sha256']
                or remote[name].get('size') != entry['size']
                or remote[name].get('state') != 'uploaded'):
            raise SystemExit('The remote release asset was not verified.')

verify_tag()
actual = api_get(endpoint)
if actual is not None:
    verify_tag(require_exists=True)
    verify_release(actual)
    print('The exact release is already published.')
else:
    # A distinct tag and latest=false keep the signed legacy updater on its own feed.
    subprocess.run(['gh', 'release', 'create', tag, *assets,
                    '--target', os.environ['COMMIT_SHA'],
                    '--title', 'Atmos Direct Spatial 1.0.0',
                    '--notes-file', str(notes), '--latest=false'], check=True)
    verify_tag(require_exists=True)
    verified = api_get(endpoint)
    if verified is None:
        raise SystemExit('Published release could not be found.')
    verify_release(verified)
    print(verified['html_url'])
