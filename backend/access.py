"""Account and role enforcement shared by all privileged API routes."""
import hashlib
import hmac
import secrets
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from psycopg.rows import dict_row
from pydantic import BaseModel, ConfigDict, Field

Role = Literal['reader', 'librarian', 'admin']
bearer = HTTPBearer(auto_error=False)
ITERATIONS = 600_000
PROFILE = 'id, email, name, ticket, role, blocked'


def migrate_access(db):
    db.execute('''CREATE TABLE IF NOT EXISTS accounts (
        id UUID PRIMARY KEY, email TEXT UNIQUE NOT NULL, name TEXT NOT NULL,
        ticket TEXT UNIQUE NOT NULL, password_salt BYTEA NOT NULL, password_hash BYTEA NOT NULL,
        role TEXT NOT NULL DEFAULT 'reader' CHECK (role IN ('reader', 'librarian', 'admin')),
        blocked BOOLEAN NOT NULL DEFAULT false
    )''')
    db.execute('''CREATE TABLE IF NOT EXISTS account_sessions (
        token_hash BYTEA PRIMARY KEY, account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        expires_at TIMESTAMPTZ NOT NULL
    )''')
    db.execute('CREATE INDEX IF NOT EXISTS account_sessions_account ON account_sessions (account_id)')
    db.execute('''CREATE TABLE IF NOT EXISTS access_audit (
        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        actor_id UUID NOT NULL REFERENCES accounts(id), target_id UUID NOT NULL REFERENCES accounts(id),
        previous_role TEXT NOT NULL, new_role TEXT NOT NULL, blocked BOOLEAN NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )''')


def password_hash(password, salt):
    return hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, ITERATIONS)


def normalized_email(email):
    email = email.strip().lower()
    local, separator, domain = email.partition('@')
    if not separator or not local or '.' not in domain or '@' in domain or any(c.isspace() for c in email):
        raise HTTPException(422, 'Email мекенжайы дұрыс емес.')
    return email


def add_account(db, email, name, password, role='reader'):
    salt = secrets.token_bytes(16)
    hashed = password_hash(password, salt)
    with db.cursor(row_factory=dict_row) as cur:
        return cur.execute(f'''INSERT INTO accounts
            (id, email, name, ticket, password_salt, password_hash, role)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (email) DO NOTHING RETURNING {PROFILE}''',
            (uuid4(), email, name, 'LF-' + secrets.token_hex(12), salt, hashed, role)).fetchone()


def digest(token):
    return hashlib.sha256(token.encode('utf-8')).digest()


class Credentials(BaseModel):
    model_config = ConfigDict(extra='forbid')
    email: str = Field(max_length=254)
    password: str = Field(min_length=8, max_length=256)


class Registration(Credentials):
    name: str = Field(min_length=2, max_length=120)


class AccessChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    role: Role
    blocked: bool


def routes(connect):
    from uuid import UUID

    router = APIRouter()

    def authorize(db, credential, roles=None):
        if credential is None or len(credential.credentials) != 43:
            raise HTTPException(401, 'Жүйеге кіріңіз.', headers={'WWW-Authenticate': 'Bearer'})
        with db.cursor(row_factory=dict_row) as cur:
            account = cur.execute('''SELECT a.id, a.email, a.name, a.ticket, a.role, a.blocked
                FROM account_sessions s JOIN accounts a ON a.id = s.account_id
                WHERE s.token_hash = %s AND s.expires_at > now() AND NOT a.blocked''',
                (digest(credential.credentials),)).fetchone()
        if account is None:
            raise HTTPException(401, 'Сессия аяқталған немесе аккаунт бұғатталған.',
                                headers={'WWW-Authenticate': 'Bearer'})
        if roles is not None and account['role'] not in roles:
            raise HTTPException(403, 'Бұл әрекетке рұқсат жоқ.')
        return account

    def require(*roles):
        def dependency(credential: HTTPAuthorizationCredentials | None = Depends(bearer)):
            with connect() as db:
                return authorize(db, credential, roles or None)
        return dependency

    current = require()
    admin = require('admin')
    staff = require('librarian', 'admin')

    def new_session(db, account):
        token = secrets.token_urlsafe(32)
        db.execute('DELETE FROM account_sessions WHERE account_id = %s AND expires_at <= now()', (account['id'],))
        db.execute('''INSERT INTO account_sessions (token_hash, account_id, expires_at)
            VALUES (%s, %s, now() + interval '30 days')''', (digest(token), account['id']))
        return {'token': token, 'user': account}

    @router.post('/api/auth/register', status_code=201)
    def register(body: Registration):
        if len(body.name.strip()) < 2:
            raise HTTPException(422, 'Аты-жөніңізді енгізіңіз.')
        with connect() as db:
            account = add_account(db, normalized_email(body.email), body.name.strip(), body.password)
            if account is None:
                raise HTTPException(409, 'Бұл email бұрын тіркелген.')
            return new_session(db, account)

    @router.post('/api/auth/login')
    def login(body: Credentials):
        email = normalized_email(body.email)
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            account = cur.execute(f'''SELECT {PROFILE}, password_salt, password_hash
                FROM accounts WHERE email = %s''', (email,)).fetchone()
            salt = account.pop('password_salt') if account else bytes(16)
            expected = account.pop('password_hash') if account else bytes(32)
            matches = hmac.compare_digest(password_hash(body.password, salt), expected)
            if not matches or not account or account['blocked']:
                raise HTTPException(401, 'Email немесе құпиясөз қате.')
            return new_session(db, account)

    @router.get('/api/auth/me')
    def me(account=Depends(current)):
        return account

    @router.post('/api/auth/logout', status_code=204)
    def logout(credential: HTTPAuthorizationCredentials | None = Depends(bearer)):
        if credential is not None and len(credential.credentials) == 43:
            with connect() as db:
                db.execute('DELETE FROM account_sessions WHERE token_hash = %s', (digest(credential.credentials),))
        return Response(status_code=204)

    @router.get('/api/admin/users')
    def users(q: str = '', role: Role | None = None, account=Depends(admin)):
        query = q.strip()[:254]
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            counts = cur.execute('SELECT role, count(*) FROM accounts GROUP BY role').fetchall()
            rows = cur.execute(f'''SELECT {PROFILE} FROM accounts
                WHERE (%s = '' OR strpos(lower(email), lower(%s)) > 0 OR strpos(lower(name), lower(%s)) > 0)
                    AND (%s::text IS NULL OR role = %s)
                ORDER BY name, id LIMIT 100''', (query, query, query, role, role)).fetchall()
            return {'users': rows, 'counts': {row['role']: row['count'] for row in counts}}

    @router.put('/api/admin/users/{account_id}/access')
    def change_access(account_id: UUID, body: AccessChange,
                      credential: HTTPAuthorizationCredentials | None = Depends(bearer)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            authorize(db, credential, ('admin',))
            cur.execute('SELECT pg_advisory_xact_lock(1280199750)')
            actor = authorize(db, credential, ('admin',))
            if actor['id'] == account_id:
                raise HTTPException(409, 'Өз рөліңізді немесе аккаунт күйін өзгерте алмайсыз.')
            old = cur.execute(f'SELECT {PROFILE} FROM accounts WHERE id = %s FOR UPDATE', (account_id,)).fetchone()
            if old is None:
                raise HTTPException(404, 'Аккаунт табылмады.')
            if (old['role'], old['blocked']) == (body.role, body.blocked):
                return old
            updated = cur.execute(f'''UPDATE accounts SET role = %s, blocked = %s WHERE id = %s
                RETURNING {PROFILE}''', (body.role, body.blocked, account_id)).fetchone()
            cur.execute('DELETE FROM account_sessions WHERE account_id = %s', (account_id,))
            cur.execute('''INSERT INTO access_audit (actor_id, target_id, previous_role, new_role, blocked)
                VALUES (%s, %s, %s, %s, %s)''',
                (actor['id'], account_id, old['role'], body.role, body.blocked))
            return updated

    @router.get('/api/admin/audit')
    def audit(account=Depends(admin)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            return cur.execute('''SELECT event.id, actor.email AS actor, target.email AS target,
                event.previous_role, event.new_role, event.blocked, event.created_at
                FROM access_audit event JOIN accounts actor ON actor.id = event.actor_id
                JOIN accounts target ON target.id = event.target_id ORDER BY event.id DESC LIMIT 100''').fetchall()

    return router, current, staff
