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
            from backend.access import add_account
            credentials = {'email': 'admin@libflow.test', 'password': 'test-admin-password'}
            with test_connect() as db:
                add_account(db, credentials['email'], 'Test Admin', credentials['password'], 'admin')
            token = session.post('/api/auth/login', json=credentials).json()['token']
            session.headers['Authorization'] = f'Bearer {token}'
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



def test_role_change_is_admin_only_and_revokes_sessions(client):
    reader = {'email': 'reader@libflow.test', 'password': 'reader-test-password', 'name': 'Reader'}
    assert client.post('/api/auth/register', json=reader | {'role': 'admin'}).status_code == 422
    registered = client.post('/api/auth/register', json=reader)
    assert registered.status_code == 201
    account = registered.json()['user']
    assert account['role'] == 'reader'
    reader_headers = {'Authorization': 'Bearer ' + registered.json()['token'], 'X-Role': 'admin'}
    path = f"/api/admin/users/{account['id']}/access"
    change = {'role': 'librarian', 'blocked': False}
    assert client.put(path, json=change, headers={'Authorization': ''}).status_code == 401
    assert client.put(path, json=change, headers=reader_headers).status_code == 403
    assert client.post('/api/books', json=book(), headers=reader_headers).status_code == 403
    assert client.get('/api/staff/summary', headers=reader_headers).status_code == 403
    assert client.put(path, json=change).json()['role'] == 'librarian'
    assert client.get('/api/auth/me', headers=reader_headers).status_code == 401
    login = client.post('/api/auth/login', json={key: reader[key] for key in ('email', 'password')})
    staff_headers = {'Authorization': 'Bearer ' + login.json()['token']}
    assert client.put(path, json={'role': 'admin', 'blocked': False}, headers=staff_headers).status_code == 403
    assert client.post('/api/books', json=book(), headers=staff_headers).status_code == 201
    admin_id = client.get('/api/auth/me').json()['id']
    assert client.put(f'/api/admin/users/{admin_id}/access', json=change).status_code == 409
    assert client.put(path, json=change | {'blocked': True}).status_code == 200
    assert client.get('/api/staff/summary', headers=staff_headers).status_code == 401
    assert len(client.get('/api/admin/audit').json()) == 2


def test_reservation_ownership_stock_and_single_issue(client):
    from datetime import date, timedelta

    def reader(alias):
        response = client.post('/api/auth/register', json={
            'email': f'{alias}@libflow.test', 'password': 'reader-test-password', 'name': alias,
        })
        assert response.status_code == 201
        return {'Authorization': 'Bearer ' + response.json()['token']}

    first, second = reader('first'), reader('second')
    data = book() | {'availableCopies': 1}
    assert client.post('/api/books', json=data).status_code == 201
    root = f"/api/books/{data['id']}"
    response = client.post(root + '/reserve', headers=first)
    assert response.status_code == 201
    result = response.json()
    code = result['reservation']['code']
    assert result['book']['availableCopies'] == 0
    assert client.get('/api/reservations/mine', headers=second).json() == []
    assert client.post(f'/api/reservations/{code}/cancel', headers=second).status_code == 404
    assert client.post(root + '/reserve', headers=second).status_code == 409
    staff_path = f'/api/staff/reservations/{code}'
    assert client.get(staff_path, headers=first).status_code == 403
    assert client.get(staff_path).json()['display_status'] == 'reserved'
    issue = {'due': (date.today() + timedelta(days=7)).isoformat()}
    assert client.post(staff_path + '/issue', json=issue).status_code == 200
    assert client.post(staff_path + '/issue', json=issue).status_code == 409
    assert client.post(staff_path + '/return').json()['book']['availableCopies'] == 1
    assert client.post(staff_path + '/return').status_code == 409
    assert client.get('/api/reservations/mine', headers=first).json()[0]['status'] == 'returned'
