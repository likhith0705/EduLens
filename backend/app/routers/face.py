
import email

from fastapi import APIRouter, File, HTTPException, UploadFile
from firebase_admin import firestore, storage

from app.firebase import db
from app.services.face_embedding import generate_face_embedding
from app.services.face_recognition import recognize_classroom_image

router = APIRouter(
    prefix="/face",
    tags=["Face Registration"],
)

BUCKET_NAME = "edulens-95199.firebasestorage.app"
MAX_IMAGE_SIZE = 5 * 1024 * 1024


def _validate_student(email: str) -> str:
    email = email.strip().lower()

    student_doc = db.collection("students").document(email).get()

    if not student_doc.exists:
        raise HTTPException(status_code=404, detail="Student not found")

    return email


@router.get("/status/{email}")
def face_status(email: str):
    email = _validate_student(email)

    doc = (
        db.collection("face_registrations")
        .document(email)
        .get()
    )

    if not doc.exists:
        return {
            "email": email,
            "registered": False,
            "image_registered": False,
            "embedding_status": "not_registered",
            "storage_path": None,
            "registered_at": None,
        }

    data = doc.to_dict() or {}

    # Never return the biometric embedding through this endpoint.
    return {
        "email": email,
        "registered": data.get("registered", False),
        "image_registered": data.get("image_registered", False),
        "embedding_status": data.get(
            "embedding_status", "pending"
        ),
        "embedding_model": data.get("embedding_model"),
        "storage_path": data.get("storage_path"),
        "filename": data.get("filename"),
        "content_type": data.get("content_type"),
        "size": data.get("size"),
        "registered_at": data.get("registered_at"),
    }


@router.post("/register/{email}")
async def register_face(
    email: str,
    image: UploadFile = File(...),
):
    email = _validate_student(email)

    if (
        not image.content_type
        or image.content_type.lower()
        not in {"image/jpeg", "image/png", "image/webp"}
    ):
        raise HTTPException(
            status_code=400,
            detail="Upload a JPEG, PNG, or WebP image.",
        )

    image_data = await image.read(MAX_IMAGE_SIZE + 1)

    if not image_data:
        raise HTTPException(
            status_code=400,
            detail="Uploaded image is empty.",
        )

    if len(image_data) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=400,
            detail="Image must be smaller than 5 MB.",
        )

    # Generate the embedding before uploading anything.
    try:
        embedding = generate_face_embedding(image_data)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        # Log the detailed error on the server; don't expose it
        # to the client.
        import logging

        logging.getLogger(__name__).exception(
            "Face embedding generation failed"
        )
        raise HTTPException(
            status_code=500,
            detail="Face processing failed. Please try another image.",
        ) from exc

    storage_path = f"students/{email}/face/profile.jpg"
    blob = None

    try:
        # 1. Upload the image to Firebase Storage.
        bucket = storage.bucket(BUCKET_NAME)
        blob = bucket.blob(storage_path)

        blob.upload_from_string(
            image_data,
            content_type=image.content_type,
        )

        # 2. Store the embedding and registration metadata.
        doc_ref = (
            db.collection("face_registrations")
            .document(email)
        )

        doc_ref.set(
            {
                "email": email,
                "registered": True,
                "image_registered": True,
                "embedding": embedding,
                "embedding_status": "completed",
                "embedding_model": "buffalo_l",
                "storage_path": storage_path,
                "filename": "profile.jpg",
                "content_type": image.content_type,
                "size": len(image_data),
                "registered_at": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        return {
            "message": "Face image and embedding registered successfully",
            "email": email,
            "registered": True,
            "image_registered": True,
            "embedding_status": "completed",
            "embedding_model": "buffalo_l",
            "storage_path": storage_path,
        }

    except HTTPException:
        raise
    except Exception as exc:
        import logging

        logging.getLogger(__name__).exception(
            "Face registration failed"
        )
        raise HTTPException(
            status_code=500,
            detail="Face registration failed. Please try again.",
        ) from exc
    finally:
        await image.close()

import os

from fastapi import Depends, Header
from google.auth.transport import requests
from google.oauth2 import id_token


def require_teacher(
    authorization: str = Header(...),
) -> str:
    """Verify a Google ID token and require a teacher role."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="A valid Bearer token is required.",
        )

    client_id = os.getenv("GOOGLE_CLIENT_ID")
    if not client_id:
        raise HTTPException(
            status_code=500,
            detail="Google Client ID is not configured.",
        )

    token = authorization.removeprefix("Bearer ").strip()

    try:
        google_user = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            client_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Google ID token.",
        ) from exc

    email = str(google_user.get("email", "")).strip().lower()

    if (not email.endswith("@saividya.ac.in") and email != "likhith.0037@gmail.com"):
        raise HTTPException(
            status_code=403,
            detail="Institute account required.",
        )

    
    teacher_doc = db.collection("teachers").document(email).get()

    if not teacher_doc.exists:
        raise HTTPException(
            status_code=403,
            detail="Teacher account is not registered.",
    )

    account = teacher_doc.to_dict() or {}

    if account.get("role") != "teacher":
        raise HTTPException(
            status_code=403,
            detail="Teacher access required.",
        )


    return email


@router.post("/recognize")
async def recognize_classroom(
    image: UploadFile = File(...),
    teacher_email: str = Depends(require_teacher),
):
    """Recognize faces in a classroom image; does not mark attendance."""
    if image.content_type not in {
        "image/jpeg",
        "image/png",
        "image/webp",
    }:
        raise HTTPException(
            status_code=400,
            detail="Upload a JPEG, PNG, or WebP image.",
        )

    try:
        image_data = await image.read(MAX_IMAGE_SIZE + 1)

        if not image_data:
            raise HTTPException(
                status_code=400,
                detail="Uploaded image is empty.",
            )

        if len(image_data) > MAX_IMAGE_SIZE:
            raise HTTPException(
                status_code=400,
                detail="Image must be smaller than 5 MB.",
            )

        try:
            result = recognize_classroom_image(image_data)
        except ValueError as exc:
            raise HTTPException(
                status_code=400,
                detail=str(exc),
            ) from exc

        return {
            "message": "Recognition completed. Attendance was not modified.",
            "teacher_email": teacher_email,
            **result,
        }
    finally:
        await image.close()


