from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    resp = client.get("/api/health")
    assert resp.status_code == 200

def test_pronunciation_assess_rejects_non_wav():
    resp = client.post(
        "/api/pronunciation/assess",
        data={"reference_text": "你好"},
        files={"audio_file": ("test.mp3", b"fake audio content", "audio/mpeg")},
    )
    assert resp.status_code == 400
    assert "WAV" in resp.json()["detail"]

def test_pronunciation_assess_rejects_ogg():
    resp = client.post(
        "/api/pronunciation/assess",
        data={"reference_text": "你好"},
        files={"audio_file": ("audio.ogg", b"OggS...", "audio/ogg")},
    )
    assert resp.status_code == 400

def test_pronunciation_assess_rejects_m4a():
    resp = client.post(
        "/api/pronunciation/assess",
        data={"reference_text": "你好"},
        files={"audio_file": ("audio.m4a", b"ftypM4A ....", "audio/m4a")},
    )
    assert resp.status_code == 400

def test_pronunciation_assess_wav_mock():
    resp = client.post(
        "/api/pronunciation/assess",
        data={"reference_text": "你好"},
        files={"audio_file": ("test.wav", b"RIFF....WAVEfmt ....data....", "audio/wav")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "overall" in data
    assert data["source"] == "online"
    assert len(data["syllables"]) == 2

def test_pronunciation_assess_empty_text():
    resp = client.post(
        "/api/pronunciation/assess",
        data={"reference_text": ""},
        files={"audio_file": ("test.wav", b"RIFF....WAVEfmt ....data....", "audio/wav")},
    )
    assert resp.status_code == 200
    assert len(resp.json()["syllables"]) == 0
