"""Real PostgreSQL integration tests in a disposable schema (never truncate user data)."""
import os
from uuid import uuid4

import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg import sql

from backend import app as module


@pytest.fixture
def client(monkeypatch):
    base_url = os.environ.get('TEST_DATABASE_URL') or os.environ.get('DATABASE_URL')
    if not base_url:
        pytest.fail('Set TEST_DATABASE_URL or configure backend/.env with a running PostgreSQL.')
    schema = 'test_' + uuid4().hex
    with psycopg.connect(base_url, autocommit=True) as db:
        db.execute(sql.SQL('CREATE SCHEMA {}').format(sql.Identifier(schema)))

    def test_connect():
        return psycopg.connect(base_url, options=f'-c search_path={schema}')

    monkeypatch.setattr(module, 'connect', test_connect)
    try:
        with TestClient(module.app) as session:
            yield session
    finally:
        with psycopg.connect(base_url, autocommit=True) as db:
            db.execute(sql.SQL('DROP SCHEMA {} CASCADE').format(sql.Identifier(schema)))


def book():
    return {'id': 'integration_book', 'title': 'Қара сөздер', 'author': 'Абай',
            'totalCopies': 3, 'availableCopies': 2}


def test_get_and_health(client):
    assert client.get('/health').json()['database'] == 'postgresql'
    response = client.get('/api/books')
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert client.get('/api/books/missing').status_code == 404


def test_post_persists_and_conflict(client):
    data = book()
    response = client.post('/api/books', json=data)
    assert response.status_code == 201
    assert client.get('/api/books/' + data['id']).json()['title'] == data['title']
    assert data['id'] in {row['id'] for row in client.get('/api/books', params={'q': 'Қара сөздер'}).json()}
    assert client.post('/api/books', json=data).status_code == 409


def test_put_persists_and_checks_id(client):
    data = book()
    client.post('/api/books', json=data)
    data['title'] = 'Өзгертілген кітап'
    assert client.put('/api/books/' + data['id'], json=data).status_code == 200
    assert client.get('/api/books/' + data['id']).json()['title'] == data['title']
    assert client.put('/api/books/wrong', json=data).status_code == 422
    data['id'] = 'missing'
    assert client.put('/api/books/missing', json=data).status_code == 404


def test_delete_persists(client):
    data = book()
    client.post('/api/books', json=data)
    response = client.delete('/api/books/' + data['id'])
    assert response.status_code == 204
    assert response.content == b''
    assert client.get('/api/books/' + data['id']).status_code == 404
    assert client.delete('/api/books/' + data['id']).status_code == 404


@pytest.mark.parametrize('changes', [{'title': ''}, {'pages': -1}, {'rating': 7},
                                      {'availableCopies': 4}, {'id': '../invalid'}])
def test_invalid_body(client, changes):
    assert client.post('/api/books', json=book() | changes).status_code == 422


def test_database_failure_is_503(client, monkeypatch):
    def fail():
        raise psycopg.OperationalError('private connection details')
    monkeypatch.setattr(module, 'connect', fail)
    response = client.get('/api/books')
    assert response.status_code == 503
    assert 'private' not in response.text


def test_empty_catalogue_does_not_reseed(client):
    for row in client.get('/api/books').json():
        assert client.delete('/api/books/' + row['id']).status_code == 204
    with TestClient(module.app) as restarted:
        assert restarted.get('/api/books').json() == []
