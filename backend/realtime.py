"""Single-process catalogue notifications; REST remains the source of truth."""
import asyncio
import logging

from fastapi import WebSocket, WebSocketDisconnect

log = logging.getLogger('uvicorn.error.libflow.realtime')


class CatalogueHub:
    def __init__(self):
        self.clients: dict[WebSocket, asyncio.Lock] = {}

    async def send(self, socket, message):
        lock = self.clients.get(socket)
        if lock is None:
            return
        async with lock:
            await asyncio.wait_for(socket.send_json(message), timeout=5)

    async def broadcast(self):
        async def deliver(socket):
            try:
                await self.send(socket, {'type': 'catalogue_changed'})
            except (OSError, RuntimeError, asyncio.TimeoutError):
                self.clients.pop(socket, None)
                log.warning('realtime.delivery_failed')
                try:
                    await asyncio.wait_for(socket.close(code=1011), timeout=1)
                except (OSError, RuntimeError, asyncio.TimeoutError):
                    pass

        await asyncio.gather(*(deliver(socket) for socket in list(self.clients)))
        log.info('catalogue.changed')

    async def handle(self, socket: WebSocket):
        await socket.accept()
        self.clients[socket] = asyncio.Lock()
        log.info('realtime.connected')
        try:
            while True:
                message = await socket.receive_json()
                if not isinstance(message, dict):
                    raise ValueError('Expected object')
                if message.get('type') == 'ping':
                    await self.send(socket, {'type': 'pong'})
                elif message.get('type') == 'sync':
                    await self.send(socket, {'type': 'catalogue_changed'})
                else:
                    raise ValueError('Unknown message')
        except WebSocketDisconnect:
            pass
        except ValueError:
            log.warning('realtime.invalid_message')
            await socket.close(code=1003)
        except (OSError, RuntimeError, asyncio.TimeoutError):
            log.warning('realtime.connection_failed')
        finally:
            self.clients.pop(socket, None)
            log.info('realtime.disconnected')


hub = CatalogueHub()
