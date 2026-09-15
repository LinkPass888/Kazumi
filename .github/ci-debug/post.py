import json
import os
import urllib.error
import urllib.request

REPO = os.environ.get('GITHUB_REPOSITORY', '')
TOKEN = os.environ.get('GH_TOKEN', '')
BRANCH = os.environ.get('GITHUB_REF_NAME', '')
SHA = os.environ.get('GITHUB_SHA', '')
API = 'https://api.github.com'


def api(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(API + path, data=data, method=method)
    request.add_header('Authorization', 'token ' + TOKEN)
    request.add_header('Accept', 'application/vnd.github+json')
    if data is not None:
        request.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode())


def read_log(path, limit=26000):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as handle:
            text = handle.read()
    except OSError as error:
        return 'missing %s: %s' % (path, error)
    if len(text) > limit:
        text = text[:limit] + '\n... (truncated)'
    return text


def main():
    body = '\n'.join([
        '### CI Debug',
        '',
        '**flutter analyze**',
        '```',
        read_log('/tmp/analyze.log'),
        '```',
        '**flutter test**',
        '```',
        read_log('/tmp/test.log'),
        '```',
    ])
    prs = api(
        'GET',
        '/repos/%s/pulls?state=open&head=%s:%s' % (REPO, REPO.split('/')[0], BRANCH),
    )
    if prs:
        api('POST', '/repos/%s/issues/%d/comments' % (REPO, prs[0]['number']), {'body': body})
        print('posted to PR #%d' % prs[0]['number'])
        return
    api('POST', '/repos/%s/commits/%s/comments' % (REPO, SHA), {'body': body})
    print('posted to commit %s' % SHA)


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        print('HTTP error: %s %s' % (error.code, error.read().decode(errors='replace')))
        raise
