"""Real PostgreSQL + two WebSocket clients, using isolated test schemas."""
import pytest
from starlette.websockets import WebSocketDisconnect

from backend.test_api import client, book  # noqa: F401 (pytest fixture)


def test_sync_and_heartbeat(client):
    with client.websocket_connect('/ws/catalogue') as socket:
        socket.send_json({'type': 'sync'})
        assert socket.receive_json() == {'type': 'catalogue_changed'}
        socket.send_json({'type': 'ping'})
        assert socket.receive_json() == {'type': 'pong'}


def test_crud_broadcasts_to_both_clients_after_commit(client):
    with client.websocket_connect('/ws/catalogue') as first:
        with client.websocket_connect('/ws/catalogue') as second:
            data = book()
            assert client.post('/api/books', json=data).status_code == 201
            assert first.receive_json() == {'type': 'catalogue_changed'}
            assert second.receive_json() == {'type': 'catalogue_changed'}
            data['availableCopies'] = 0
            assert client.put('/api/books/' + data['id'], json=data).status_code == 200
            assert first.receive_json() == {'type': 'catalogue_changed'}
            assert second.receive_json() == {'type': 'catalogue_changed'}
            assert client.get('/api/books/' + data['id']).json()['isAvailable'] is False
            assert client.delete('/api/books/' + data['id']).status_code == 204
            assert first.receive_json() == {'type': 'catalogue_changed'}
            assert second.receive_json() == {'type': 'catalogue_changed'}
            assert client.get('/api/books/' + data['id']).status_code == 404


def test_reconnect_sync_recovers_changes_made_while_offline(client):
    with client.websocket_connect('/ws/catalogue') as socket:
        socket.send_json({'type': 'sync'})
        assert socket.receive_json()['type'] == 'catalogue_changed'
    data = book()
    assert client.post('/api/books', json=data).status_code == 201
    with client.websocket_connect('/ws/catalogue') as reconnected:
        reconnected.send_json({'type': 'sync'})
        assert reconnected.receive_json()['type'] == 'catalogue_changed'
        assert data['id'] in {item['id'] for item in client.get('/api/books').json()}


@pytest.mark.parametrize('message', ['{broken', '[]', '{"type":"unknown"}'])
def test_invalid_message_closes_only_offending_client(client, message):
    with client.websocket_connect('/ws/catalogue') as healthy:
        with client.websocket_connect('/ws/catalogue') as invalid:
            invalid.send_text(message)
            with pytest.raises(WebSocketDisconnect) as error:
                invalid.receive_json()
            assert error.value.code == 1003
        healthy.send_json({'type': 'ping'})
        assert healthy.receive_json() == {'type': 'pong'}
