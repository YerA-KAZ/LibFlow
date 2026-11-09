"""Transactional reservations and circulation for the existing catalogue."""
import secrets
from datetime import date, datetime, time, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from pydantic import BaseModel

from backend.realtime import hub


def migrate_circulation(db):
    db.execute('''CREATE TABLE IF NOT EXISTS account_favorites (
        account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        PRIMARY KEY (account_id, book_id)
    )''')
    db.execute('CREATE INDEX IF NOT EXISTS account_favorites_book ON account_favorites (book_id)')
    db.execute('''CREATE TABLE IF NOT EXISTS reservations (
        code TEXT PRIMARY KEY, book_id TEXT NOT NULL, title TEXT NOT NULL,
        reader_id UUID NOT NULL REFERENCES accounts(id),
        status TEXT NOT NULL CHECK (status IN ('reserved','issued','cancelled','returned','expired')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '24 hours',
        due_at TIMESTAMPTZ, updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )''')
    db.execute("""CREATE UNIQUE INDEX IF NOT EXISTS reservation_active_pair
        ON reservations (reader_id, book_id) WHERE status IN ('reserved','issued')""")
    db.execute('CREATE INDEX IF NOT EXISTS reservations_book ON reservations (book_id)')
    db.execute('CREATE INDEX IF NOT EXISTS reservations_reader ON reservations (reader_id, created_at DESC)')


class Favorite(BaseModel):
    selected: bool


class Issue(BaseModel):
    due: date


def stock(db, book_id):
    row = db.execute('SELECT data FROM books WHERE id = %s FOR UPDATE', (book_id,)).fetchone()
    if row is None:
        raise HTTPException(404, 'Кітап табылмады.')
    return row[0]


def save_stock(db, book, delta):
    book['availableCopies'] = min(book['totalCopies'], book['availableCopies'] + delta)
    book['isAvailable'] = book['availableCopies'] > 0
    db.execute('UPDATE books SET data = %s, updated_at = now() WHERE id = %s',
               (Jsonb(book), book['id']))
    return book


def expire(db, book):
    expired = db.execute("""UPDATE reservations SET status = 'expired', updated_at = now()
        WHERE book_id = %s AND status = 'reserved' AND expires_at <= now()""", (book['id'],)).rowcount
    if expired:
        save_stock(db, book, expired)


FIELDS = """r.*, CASE WHEN r.status = 'reserved' AND r.expires_at <= now()
    THEN 'expired' ELSE r.status END AS display_status"""


def routes(connect, current, staff):
    router = APIRouter()

    @router.get('/api/favorites')
    def favorites(account=Depends(current)):
        with connect() as db:
            return [row[0] for row in db.execute(
                'SELECT book_id FROM account_favorites WHERE account_id = %s', (account['id'],)).fetchall()]

    @router.put('/api/books/{book_id}/favorite', status_code=204)
    def favorite(book_id: str, body: Favorite, account=Depends(current)):
        with connect() as db:
            if body.selected:
                row = db.execute('SELECT 1 FROM books WHERE id = %s FOR KEY SHARE', (book_id,)).fetchone()
                if row is None:
                    raise HTTPException(404, 'Кітап табылмады.')
                db.execute('''INSERT INTO account_favorites (account_id, book_id) VALUES (%s, %s)
                    ON CONFLICT DO NOTHING''', (account['id'], book_id))
            else:
                db.execute('DELETE FROM account_favorites WHERE account_id = %s AND book_id = %s',
                           (account['id'], book_id))
        return Response(status_code=204)

    @router.get('/api/staff/summary')
    def summary(account=Depends(staff)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            result = cur.execute("""SELECT count(*) AS books,
                COALESCE(sum((data->>'totalCopies')::int), 0) AS copies,
                COALESCE(sum((data->>'availableCopies')::int), 0) AS available
                FROM books""").fetchone()
            result.update(cur.execute("""SELECT
                count(*) FILTER (WHERE status = 'reserved' AND expires_at > now()) AS reserved,
                count(*) FILTER (WHERE status = 'issued') AS issued,
                count(*) FILTER (WHERE status = 'issued' AND due_at < now()) AS overdue
                FROM reservations""").fetchone())
            if account['role'] == 'admin':
                result.update(cur.execute("""SELECT count(*) AS accounts,
                    count(*) FILTER (WHERE role = 'librarian' AND NOT blocked) AS librarians
                    FROM accounts""").fetchone())
            return result

    @router.post('/api/reservations/{code}/extend')
    def extend(code: str, account=Depends(current)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            row = cur.execute("""UPDATE reservations SET due_at = due_at + interval '7 days', updated_at = now()
                WHERE code = %s AND reader_id = %s AND status = 'issued' RETURNING *""",
                (code, account['id'])).fetchone()
            if row is None:
                raise HTTPException(404, 'Белсенді берілім табылмады.')
            book = db.execute('SELECT data FROM books WHERE id = %s', (row['book_id'],)).fetchone()[0]
            return {'reservation': row, 'book': book}

    @router.get('/api/reservations/mine')
    def mine(account=Depends(current)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            return cur.execute(f'''SELECT {FIELDS} FROM reservations r
                WHERE reader_id = %s ORDER BY created_at DESC''', (account['id'],)).fetchall()

    @router.get('/api/staff/reservations')
    def reservations(q: str = '', account=Depends(staff)):
        query = q.strip()[:254]
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            return cur.execute(f'''SELECT {FIELDS}, a.name AS reader
                FROM reservations r JOIN accounts a ON a.id = r.reader_id
                WHERE %s = '' OR strpos(lower(a.name), lower(%s)) > 0
                    OR strpos(lower(r.title), lower(%s)) > 0
                ORDER BY r.created_at DESC LIMIT 200''', (query, query, query)).fetchall()

    @router.get('/api/staff/reservations/{code}')
    def lookup(code: str, account=Depends(staff)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            row = cur.execute(f'''SELECT {FIELDS}, a.name AS reader
                FROM reservations r JOIN accounts a ON a.id = r.reader_id
                WHERE code = %s''', (code,)).fetchone()
            if row is None:
                raise HTTPException(404, 'Бронь табылмады.')
            return row

    @router.post('/api/books/{book_id}/reserve', status_code=201)
    def reserve(book_id: str, tasks: BackgroundTasks, account=Depends(current)):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            book = stock(db, book_id)
            expire(db, book)
            if not book['isAvailable'] or book['availableCopies'] <= 0:
                raise HTTPException(409, 'Қолда бар дана жоқ.')
            code = 'LIBFLOW-' + secrets.token_hex(16).upper()
            row = cur.execute("""INSERT INTO reservations (code, book_id, title, reader_id, status)
                VALUES (%s, %s, %s, %s, 'reserved') ON CONFLICT DO NOTHING RETURNING *""",
                (code, book_id, book['title'], account['id'])).fetchone()
            if row is None:
                raise HTTPException(409, 'Бұл кітапқа белсенді бронь немесе берілім бар.')
            save_stock(db, book, -1)
        tasks.add_task(hub.broadcast)
        return {'reservation': row, 'book': book}

    def transition(code, action, tasks, account, due=None, staff_access=False):
        with connect() as db, db.cursor(row_factory=dict_row) as cur:
            initial = cur.execute('SELECT book_id, reader_id FROM reservations WHERE code = %s', (code,)).fetchone()
            if initial is None or (not staff_access and initial['reader_id'] != account['id']):
                raise HTTPException(404, 'Бронь табылмады.')
            book = stock(db, initial['book_id'])
            row = cur.execute(f'SELECT {FIELDS} FROM reservations r WHERE code = %s FOR UPDATE', (code,)).fetchone()
            status = row['display_status']
            allowed = {'cancelled': 'reserved', 'issued': 'reserved', 'returned': 'issued'}
            if action == 'cancelled' and status == 'expired' and row['status'] == 'reserved':
                action = 'expired'
            elif status != allowed[action]:
                raise HTTPException(409, 'Бронь күйі бұл әрекетке сәйкес емес.')
            row = cur.execute('''UPDATE reservations SET status = %s, updated_at = now(),
                due_at = COALESCE(%s, due_at) WHERE code = %s RETURNING *''',
                (action, due, code)).fetchone()
            if action != 'issued':
                save_stock(db, book, 1)
        tasks.add_task(hub.broadcast)
        return {'reservation': row, 'book': book}

    @router.post('/api/reservations/{code}/cancel')
    def cancel(code: str, tasks: BackgroundTasks, account=Depends(current)):
        return transition(code, 'cancelled', tasks, account)

    @router.post('/api/staff/reservations/{code}/cancel')
    def staff_cancel(code: str, tasks: BackgroundTasks, account=Depends(staff)):
        return transition(code, 'cancelled', tasks, account, staff_access=True)

    @router.post('/api/staff/reservations/{code}/issue')
    def issue(code: str, body: Issue, tasks: BackgroundTasks, account=Depends(staff)):
        due = datetime.combine(body.due, time.max, timezone.utc)
        if due <= datetime.now(timezone.utc):
            raise HTTPException(422, 'Қайтару күнін тексеріңіз.')
        return transition(code, 'issued', tasks, account, due, staff_access=True)

    @router.post('/api/staff/reservations/{code}/return')
    def returned(code: str, tasks: BackgroundTasks, account=Depends(staff)):
        return transition(code, 'returned', tasks, account, staff_access=True)

    return router
