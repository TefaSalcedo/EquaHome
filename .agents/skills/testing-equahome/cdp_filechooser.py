import asyncio, json, urllib.request
import websockets

async def main():
    targets = json.load(urllib.request.urlopen('http://localhost:29229/json'))
    page = next(t for t in targets if t['type']=='page' and 'localhost:5000' in t['url'])
    ws_url = page['webSocketDebuggerUrl']
    async with websockets.connect(ws_url, max_size=50*1024*1024) as ws:
        mid = 0
        async def send(method, params=None):
            nonlocal mid
            mid += 1
            await ws.send(json.dumps({'id': mid, 'method': method, 'params': params or {}}))
            return mid
        await send('Page.enable')
        await send('DOM.enable')
        await send('Page.setInterceptFileChooserDialog', {'enabled': True})
        print('interception enabled; waiting for chooser...')
        async for raw in ws:
            msg = json.loads(raw)
            if msg.get('method') == 'Page.fileChooserOpened':
                p = msg['params']
                print('chooser opened:', json.dumps(p)[:300])
                await send('DOM.setFileInputFiles', {
                    'files': ['/tmp/room_test.png'],
                    'backendNodeId': p['backendNodeId'],
                })
                print('file set')
                await asyncio.sleep(1)
                return
asyncio.run(main())
