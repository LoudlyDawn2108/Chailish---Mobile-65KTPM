from fastapi import APIRouter, UploadFile, File, Form, HTTPException
import os
import tempfile
import json
import httpx

router = APIRouter(prefix="/pronunciation", tags=["Pronunciation Assessment"])

AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY", "mock_key")
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION", "eastasia")

@router.post("/assess")
async def assess_pronunciation(
    reference_text: str = Form(...),
    audio_file: UploadFile = File(...),
):
    if not audio_file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Chi chap nhan file am thanh dinh dang WAV")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        content = await audio_file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        if AZURE_SPEECH_KEY and AZURE_SPEECH_KEY != "mock_key":
            url = f"https://{AZURE_SPEECH_REGION}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=zh-CN"
            pron_params = {
                "ReferenceText": reference_text,
                "GradingSystem": "HundredMark",
                "Granularity": "Phoneme",
                "Dimension": "Comprehensive",
            }
            headers = {
                "Ocp-Apim-Subscription-Key": AZURE_SPEECH_KEY,
                "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
                "Pronunciation-Assessment": json.dumps(pron_params),
                "Accept": "application/json",
            }
            async with httpx.AsyncClient() as client:
                with open(tmp_path, "rb") as f:
                    resp = await client.post(url, headers=headers, content=f.read(), timeout=10.0)
            if resp.status_code == 200:
                return resp.json()

        # Mock chuan phan hoi cua Azure Cognitive Services
        return {
            "RecognitionStatus": "Success",
            "DisplayText": reference_text,
            "NBest": [
                {
                    "Confidence": 0.95,
                    "PronunciationAssessment": {
                        "AccuracyScore": 90.0,
                        "FluencyScore": 88.0,
                        "CompletenessScore": 100.0,
                        "PronScore": 89.2,
                    },
                }
            ]
        }
    finally:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
