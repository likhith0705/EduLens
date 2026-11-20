
import logging

import cv2
import numpy as np

from app.firebase import db
from app.services.face_embedding import get_face_model

logger = logging.getLogger(__name__)

# Initial threshold inherited from the prototype.
# Validate this with genuine and non-matching faces before deployment.
DEFAULT_THRESHOLD = 0.45


def cosine_similarity(a, b) -> float:
    vector_a = np.asarray(a, dtype=np.float32).reshape(-1)
    vector_b = np.asarray(b, dtype=np.float32).reshape(-1)

    if vector_a.shape != vector_b.shape:
        return -1.0

    norm_a = float(np.linalg.norm(vector_a))
    norm_b = float(np.linalg.norm(vector_b))

    if norm_a == 0 or norm_b == 0:
        return -1.0

    return float(
        np.dot(vector_a, vector_b) / (norm_a * norm_b)
    )


def recognize_classroom_image(
    image_bytes: bytes,
    threshold: float = DEFAULT_THRESHOLD,
) -> dict:
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("The uploaded file is not a valid image.")

    model = get_face_model()
    detected_faces = model.get(image)

    registered = []

    for doc in db.collection("face_registrations").stream():
        data = doc.to_dict() or {}

        if (
            not data.get("registered")
            or data.get("embedding_status") != "completed"
        ):
            continue

        email = str(data.get("email") or doc.id).strip().lower()
        embedding = data.get("embedding")

        if not email or not isinstance(embedding, (list, tuple)):
            continue

        try:
            vector = np.asarray(
                embedding,
                dtype=np.float32,
            ).reshape(-1)
        except (TypeError, ValueError):
            continue

        if vector.size == 0 or not np.all(np.isfinite(vector)):
            continue

        registered.append({
            "email": email,
            "embedding": vector,
        })

    matches = []

    for face in detected_faces:
        query = np.asarray(
            face.normed_embedding,
            dtype=np.float32,
        )

        best_email = None
        best_score = -1.0

        for record in registered:
            score = cosine_similarity(
                query,
                record["embedding"],
            )

            if score > best_score:
                best_score = score
                best_email = record["email"]

        bbox = [int(value) for value in face.bbox]

        if best_email and best_score >= threshold:
            student_doc = (
                db.collection("students")
                .document(best_email)
                .get()
            )
            student = student_doc.to_dict() if student_doc.exists else {}

            matches.append({
                "email": best_email,
                "name": (student or {}).get("name", "Student"),
                "status": "matched",
                "similarity": round(best_score, 4),
                "bbox": bbox,
            })
        else:
            matches.append({
                "email": None,
                "name": "Unknown",
                "status": "unknown",
                "similarity": round(max(best_score, 0.0), 4),
                "bbox": bbox,
            })

    return {
        "faces_detected": len(detected_faces),
        "registered_embeddings_checked": len(registered),
        "matches": matches,
    }
