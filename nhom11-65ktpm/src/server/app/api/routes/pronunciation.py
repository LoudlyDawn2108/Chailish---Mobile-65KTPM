from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import Optional
import os
import tempfile
import json
import httpx

from app.core.config import settings

router = APIRouter(prefix="/pronunciation", tags=["pronunciation"])

MAX_AUDIO_SIZE = 2 * 1024 * 1024  # 2MB

@router.post("/assess")
async def assess_pronunciation(
    reference_text: str = Form(..., min_length=1),
    audio_file: UploadFile = File(...),
):
    """
    API Cham phat am truc tuyen voi Azure Speech Pronunciation Assessment (zh-CN)
    Theo hop dong du lieu: tra ve hop dong PronunciationResult chung, loi 503 khi khong co key
    """
    if not audio_file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Chi chap nhan file am thanh dinh dang WAV")

    content = await audio_file.read()
    if len(content) > MAX_AUDIO_SIZE:
        raise HTTPException(status_code=400, detail="File am thanh vuot qua gioi han 2MB")

    # Neu server khong co Azure Speech Key thi tra ve 503 de app tu fallback ve offline
    if not settings.AZURE_SPEECH_KEY:
        raise HTTPException(status_code=503, detail="Dich vu cham phat am Azure online chua duoc cau hinh tren server")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        url = f"https://{settings.AZURE_SPEECH_REGION}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=zh-CN"
        pron_params = {
            "ReferenceText": reference_text,
            "GradingSystem": "HundredMark",
            "Granularity": "Phoneme",
            "Dimension": "Comprehensive",
            "EnableMiscue": True,
        }
        headers = {
            "Ocp-Apim-Subscription-Key": settings.AZURE_SPEECH_KEY,
            "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
            "Pronunciation-Assessment": json.dumps(pron_params),
            "Accept": "application/json",
        }
        async with httpx.AsyncClient() as client:
            with open(tmp_path, "rb") as f:
                resp = await client.post(url, headers=headers, content=f.read(), timeout=10.0)

        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail=f"Loi goi Azure Speech API: {resp.status_code}")

        azure_data = resp.json()
        nbest = azure_data.get("NBest", [])
        if not nbest:
            raise HTTPException(status_code=502, detail="Khong nhan duoc ket qua tu Azure")

        first = nbest[0]
        pron = first.get("PronunciationAssessment", {})
        accuracy = float(pron.get("AccuracyScore", 0.0))
        fluency = float(pron.get("FluencyScore", 0.0))
        completeness = float(pron.get("CompletenessScore", 0.0))
        overall = float(pron.get("PronScore", accuracy))

        # Chuyen doi sang dinh dang hop dong PronunciationResult
        chars = [c for c in reference_text if '\u4e00' <= c <= '\u9fff']
        words_raw = first.get("Words", [])

        syllables = []
        for i, c in enumerate(chars):
            w_score = accuracy
            errs = []
            if i < len(words_raw):
                w_info = words_raw[i]
                w_pron = w_info.get("PronunciationAssessment", {})
                w_score = float(w_pron.get("AccuracyScore", accuracy))
                err_type = w_pron.get("ErrorType", "None")
                if err_type == "Mispronunciation":
                    errs.append("initial")
                elif err_type == "Omission":
                    errs.append("missing")

            status = "ok"
            if w_score < 60:
                status = "error"
            elif w_score < 80:
                status = "warn"

            syllables.append({
                "hanzi": c,
                "expected": {"initial": "", "final": "", "tone": 5},
                "actual": {"initial": "", "final": "", "tone": 5},
                "score": w_score,
                "status": status,
                "errors": errs,
            })

        return {
            "overall": overall,
            "accuracy": accuracy,
            "tone": accuracy,
            "fluency": fluency,
            "completeness": completeness,
            "source": "online",
            "recognized_text": first.get("Display", reference_text),
            "syllables": syllables,
        }
    finally:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
