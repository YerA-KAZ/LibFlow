"""LibFlow catalogue REST API. Personal reading state stays on the device."""
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

import psycopg
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from psycopg.types.json import Jsonb
from pydantic import BaseModel, ConfigDict, Field, model_validator

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / '.env')


class BookRecord(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    id: str = Field(min_length=1, max_length=120, pattern=r'^[A-Za-z0-9_-]+$')
    title: str = Field(min_length=1, max_length=500)
    author: str = Field(min_length=1, max_length=500)
    authorId: str | None = None
    category: str = 'Жалпы әдебиет'
    categoryId: str | None = None
    rating: float = Field(default=0, ge=0, le=5)
    reviewCount: int = Field(default=0, ge=0)
    pages: int = Field(default=0, ge=0)
    publishYear: int = Field(default=2026, ge=1, le=9999)
    isbn: str = ''
    description: str = ''
    coverUrl: str | None = None
    source: str = 'LibFlow'
    previewUrl: str | None = None
    infoUrl: str | None = None
    isAvailable: bool = True
    availableCopies: int = Field(default=1, ge=0)
    totalCopies: int = Field(default=1, ge=0)
    hasEBook: bool = False
    hasAudio: bool = False
    audioDuration: str = ''
    readingContent: str = ''

    @model_validator(mode='after')
    def check_copies(self):
        if self.availableCopies > self.totalCopies:
            raise ValueError('availableCopies cannot exceed totalCopies')
        if self.availableCopies == 0:
            self.isAvailable = False
        return self


def connect():
    url = os.environ.get('DATABASE_URL')
    if not url:
        raise RuntimeError('Set DATABASE_URL in backend/.env (see .env.example)')
    return psycopg.connect(url, connect_timeout=5, options='-c statement_timeout=5000')


@asynccontextmanager
async def lifespan(_app):
    # Context managers commit successful transactions and roll back failures.
    with connect() as db:
        db.execute('''CREATE TABLE IF NOT EXISTS books (
            id TEXT PRIMARY KEY,
            data JSONB NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            CHECK (data->>'id' = id)
        )''')
        db.execute('CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY)')
        # Seed once only: deleting every book must not reseed on restart.
        if not db.execute('SELECT 1 FROM schema_migrations WHERE version = 1').fetchone():
            for item in json.loads((ROOT / 'seed_books.json').read_text(encoding='utf-8')):
                book = BookRecord.model_validate(item)
                db.execute('INSERT INTO books(id, data) VALUES (%s, %s) ON CONFLICT DO NOTHING',
                           (book.id, Jsonb(book.model_dump())))
            db.execute('INSERT INTO schema_migrations(version) VALUES (1)')
    yield


app = FastAPI(title='LibFlow REST API', version='1.0.0', lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv('CORS_ORIGINS', '').split(','),
    allow_methods=['GET', 'POST', 'PUT', 'DELETE'],
    allow_headers=['Content-Type'],
)


@app.exception_handler(psycopg.Error)
async def database_error(_request, exc):
    logging.getLogger(__name__).error('Database operation failed: %s', type(exc).__name__)
    return JSONResponse(status_code=503, content={'detail': 'Деректер қоры уақытша қолжетімсіз.'})


@app.get('/health')
def health():
    with connect() as db:
        db.execute('SELECT 1')
    return {'status': 'ok', 'database': 'postgresql'}


@app.get('/api/books', response_model=list[BookRecord])
def list_books(q: Annotated[str, Query(max_length=200)] = ''):
    with connect() as db:
        rows = db.execute('''SELECT data FROM books
            WHERE %s = '' OR strpos(lower(data->>'title'), lower(%s)) > 0
            OR strpos(lower(data->>'author'), lower(%s)) > 0
            OR strpos(lower(data->>'isbn'), lower(%s)) > 0
            ORDER BY id''', (q, q, q, q)).fetchall()
    return [row[0] for row in rows]


@app.get('/api/books/{book_id}', response_model=BookRecord)
def get_book(book_id: str):
    with connect() as db:
        row = db.execute('SELECT data FROM books WHERE id = %s', (book_id,)).fetchone()
    if row is None:
        raise HTTPException(404, 'Кітап табылмады.')
    return row[0]


@app.post('/api/books', response_model=BookRecord, status_code=201)
def create_book(book: BookRecord):
    with connect() as db:
        row = db.execute('''INSERT INTO books(id, data) VALUES (%s, %s)
            ON CONFLICT DO NOTHING RETURNING data''',
            (book.id, Jsonb(book.model_dump()))).fetchone()
    if row is None:
        raise HTTPException(409, 'Бұл ID бар кітап бұрын қосылған.')
    return row[0]


@app.put('/api/books/{book_id}', response_model=BookRecord)
def update_book(book_id: str, book: BookRecord):
    if book_id != book.id:
        raise HTTPException(422, 'URL және JSON ішіндегі ID бірдей болуы тиіс.')
    with connect() as db:
        row = db.execute('''UPDATE books SET data = %s, updated_at = now()
            WHERE id = %s RETURNING data''', (Jsonb(book.model_dump()), book_id)).fetchone()
    if row is None:
        raise HTTPException(404, 'Кітап табылмады.')
    return row[0]


@app.delete('/api/books/{book_id}', status_code=204)
def delete_book(book_id: str):
    with connect() as db:
        row = db.execute('DELETE FROM books WHERE id = %s RETURNING id', (book_id,)).fetchone()
    if row is None:
        raise HTTPException(404, 'Кітап табылмады.')
    return Response(status_code=204)
