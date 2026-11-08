import pytest
from backend.app import BookRecord
from backend.test_api import client, book  # noqa: F401


def test_media_roundtrip_in_postgresql(client):
    data = book() | {'chapters': [{'id': 'one', 'title': 'Тарау', 'text': 'Толық мәтін'}],
                     'audioUrl': 'https://example.org/book.mp3', 'hasAudio': True, 'hasEBook': True}
    assert client.post('/api/books', json=data).status_code == 201
    saved = client.get('/api/books/' + data['id']).json()
    assert saved['chapters'] == data['chapters']
    assert saved['audioUrl'] == data['audioUrl']
    data['audioUrl'] = None
    assert client.put('/api/books/' + data['id'], json=data).json()['audioUrl'] is None


@pytest.mark.parametrize('source', ['http://example.org/book.mp3', 'file:///secret',
                                     'javascript:alert(1)', 'https://user:pass@example.org/a.mp3'])
def test_audio_source_validation(source):
    with pytest.raises(ValueError):
        BookRecord.model_validate(book() | {'audioUrl': source})


def test_legacy_and_duplicate_chapters():
    assert BookRecord.model_validate(book()).chapters == []
    chapter = {'id': 'same', 'title': 'Title', 'text': 'Text'}
    with pytest.raises(ValueError):
        BookRecord.model_validate(book() | {'chapters': [chapter, chapter]})
